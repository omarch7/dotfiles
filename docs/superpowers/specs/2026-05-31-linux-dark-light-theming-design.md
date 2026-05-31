# Linux / Omarchy dark-light theming — design

**Date:** 2026-05-31
**Status:** Approved design (pending spec review)

## Problem

The dotfiles already switch CLI tools between catppuccin **mocha** (dark) and
**latte** (light) based on the OS appearance setting, but detection only works on
**macOS** and **WSL2**. On native Linux (the user runs Omarchy, a Hyprland/Arch
setup), the hub script `tmux/.tmux/scripts/detect-theme.sh` falls through to a
hardcoded `"dark"`, so light mode never applies. Several tools are also either
mis-pathed for Linux (glow) or not wired into the switcher at all (starship).

Omarchy already themes some apps itself (Ghostty, foot, btop, waybar, etc.), but
it does **not** cover starship, tmux, glow, bat, or lsd.

## Goal

Make the existing dark/light switching work on native Linux/Omarchy, covering
**starship, tmux, glow, bat, lsd**, while keeping macOS and WSL2 behavior intact.

### Non-goals

- Matching arbitrary Omarchy themes per-tool. CLI tools track **light/dark only**
  and always render as catppuccin latte/mocha, regardless of which Omarchy theme
  is active. (Per-theme tool palettes would be a large, separate effort.)
- Theming tools Omarchy already handles (Ghostty/foot/btop/waybar/etc.).
- television: excluded on Linux (not installed). Its existing macOS/WSL logic stays.

## Architecture

Keep the single hub script `tmux/.tmux/scripts/detect-theme.sh` as the one source
of truth. Three structural changes plus per-tool updates.

### 1. Detection (`detect_mode`)

Extend the `Linux` branch. Current order of precedence for **native** Linux
(the existing WSL2 sub-branch is unchanged and still takes priority when
`/proc/version` contains `microsoft`):

1. **Omarchy marker** — if `~/.config/omarchy/current/theme/light.mode` exists →
   `light`. (Omarchy creates this file in the active theme dir for light themes.)
2. **Freedesktop fallback** — else if
   `gsettings get org.gnome.desktop.interface color-scheme` output contains
   `light` → `light`. Portable to other GNOME-based DEs.
3. **Default** — else `dark`.

`gsettings` absent or erroring → treated as not-light, falls through to default.

Darwin and WSL2 branches are untouched.

### 2. Gating via a state file (replaces tmux-as-state)

Today the script decides "did the flavor change?" by reading the tmux option
`@catppuccin_flavor`. That only works from inside tmux. Replace the gate with a
cache file:

- State file: `${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles-theme/flavor`
- Read last-applied flavor from it; compare to the freshly-detected flavor.
- If unchanged → exit early (no work).
- If changed → apply all tool updates, then write the new flavor to the state file.

This makes the script correct whether triggered by tmux focus-in **or** the
Omarchy hook (which runs with no attached tmux client). The cache dir is created
on demand (`mkdir -p`).

### 3. Triggers

- **Existing (unchanged):** `tmux.conf` runs `detect-theme.sh` on load and on the
  `client-focus-in` hook.
- **New:** an `omarchy` stow package shipping
  `omarchy/.config/omarchy/hooks/theme-set.d/10-sync-cli-theme`. Omarchy's
  `omarchy-theme-set` ends with `omarchy-hook theme-set <name>`, which executes
  every file in `~/.config/omarchy/hooks/theme-set.d/`. The hook script just
  invokes `~/.tmux/scripts/detect-theme.sh` so a theme switch re-syncs the CLI
  tools immediately, even outside tmux. The hook must be executable.

## Per-tool changes

| Tool        | Change |
|-------------|--------|
| **tmux**    | Same catppuccin-flavor swap logic, now guarded behind a running server (`tmux info &>/dev/null`) so it no-ops when fired from the Omarchy hook with no server. |
| **starship**| *New to the switcher.* Add a `[palettes.catppuccin_latte]` block to `starship/.config/starship.toml` (currently only frappe/macchiato/mocha). Script `sed`-swaps the top-level `palette = "catppuccin_mocha"` ↔ `"catppuccin_latte"`. Starship re-reads the file each prompt, so it updates live. |
| **glow**    | Choose config path by OS: macOS `~/Library/Preferences/glow/glow.yml`, Linux `~/.config/glow/glow.yml`. Theme JSONs under `~/.config/glow/themes/` are already shared. Guarded by `-f`. |
| **bat**     | Unchanged — already edits `~/.config/bat/config`, path-portable. Now under the new gate. |
| **lsd**     | Unchanged — already copies `~/.config/lsd/themes/...`, path-portable. Now under the new gate. |
| **television** | macOS/WSL: unchanged. Linux: explicitly skipped by wrapping the television block in a `[ "$(uname -s)" != Linux ]` guard. |

## Error handling

- `gsettings` missing/errors → not-light → default dark.
- Missing tool config files → already `-f`-guarded; silently skipped.
- No tmux server → tmux block skipped via `tmux info` guard.
- `omarchy-hook` already runs hooks non-fatally (`|| echo "Hook failed: ..."`),
  so a failing sync never blocks an Omarchy theme change.

## Files touched

- `tmux/.tmux/scripts/detect-theme.sh` — Linux detection, state-file gating,
  tmux-server guard, glow path-by-OS, starship swap, television Linux-guard.
- `starship/.config/starship.toml` — add `[palettes.catppuccin_latte]`.
- `omarchy/.config/omarchy/hooks/theme-set.d/10-sync-cli-theme` — **new**, the
  Omarchy theme-set hook (new stow package).

## Testing (manual)

1. **Detection unit-ish checks:** run `detect_mode` (or the script with debug
   output) while toggling `~/.config/omarchy/current/theme/light.mode` present/
   absent, and confirm light↔dark; remove the marker and flip `gsettings`
   `color-scheme` to confirm the fallback path.
2. **End-to-end via Omarchy:** `omarchy-theme-set` to a light theme then a dark
   theme; confirm bat, lsd, glow, starship, and tmux all flip flavor. Verify the
   hook fires by watching the state file change.
3. **State gating:** run `detect-theme.sh` twice in a row; second run is a no-op.
4. **Cross-platform safety:** confirm the television block still runs on
   macOS/WSL and is skipped on Linux; confirm the tmux block no-ops when no
   server is running.
