# Linux / Omarchy dark-light theming — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the existing catppuccin dark/light switcher work on native Linux/Omarchy, covering starship, tmux, glow, bat, and lsd, while keeping macOS/WSL2 behavior intact.

**Architecture:** Keep `tmux/.tmux/scripts/detect-theme.sh` as the single hub. Extend its `detect_mode` with a native-Linux branch (Omarchy `light.mode` marker → `gsettings color-scheme` → default dark), move the change-detection gate from a tmux option to an `XDG_CACHE_HOME` state file so it works from both tmux focus-in and an Omarchy hook, guard the tmux block on a running server, add starship to the switch (new `catppuccin_latte` palette), pick glow's config path by OS, and skip television on Linux. A new `omarchy` stow package ships a `theme-set.d` hook that re-runs the script on theme change.

**Tech Stack:** Bash, catppuccin palettes, starship TOML, GNU Stow, Omarchy hooks.

**Spec:** `docs/superpowers/specs/2026-05-31-linux-dark-light-theming-design.md`

---

### Task 1: Add the `catppuccin_latte` palette to starship

**Files:**
- Modify: `starship/.config/starship.toml` (append after the `catppuccin_mocha` block ending at line 102)

- [ ] **Step 1: Append the latte palette block**

Add this block at the end of `starship/.config/starship.toml` (after the last line of `[palettes.catppuccin_mocha]`). These are the official Catppuccin Latte hex values:

```toml

[palettes.catppuccin_latte]
rosewater = "#dc8a78"
flamingo = "#dd7878"
pink = "#ea76cb"
mauve = "#8839ef"
red = "#d20f39"
maroon = "#e64553"
peach = "#fe640b"
yellow = "#df8e1d"
green = "#40a02b"
teal = "#179299"
sky = "#04a5e5"
sapphire = "#209fb5"
blue = "#1e66f5"
lavender = "#7287fd"
text = "#4c4f69"
subtext1 = "#5c5f77"
subtext0 = "#6c6f85"
overlay2 = "#7c7f93"
overlay1 = "#8c8fa1"
overlay0 = "#9ca0b0"
surface2 = "#acb0be"
surface1 = "#bcc0cc"
surface0 = "#ccd0da"
base = "#eff1f5"
mantle = "#e6e9ef"
crust = "#dce0e8"
```

- [ ] **Step 2: Verify both palettes are present and the file still parses**

Run:
```bash
grep -c '^\[palettes.catppuccin_' starship/.config/starship.toml
python3 - <<'PY'
import tomllib
with open("starship/.config/starship.toml","rb") as f:
    d = tomllib.load(f)
pals = d["palettes"]
assert "catppuccin_latte" in pals and "catppuccin_mocha" in pals, "missing palette"
assert pals["catppuccin_latte"]["base"] == "#eff1f5", "latte base wrong"
print("OK", sorted(k for k in pals))
PY
```
Expected: first command prints `4`; Python prints `OK ['catppuccin_frappe', 'catppuccin_latte', 'catppuccin_macchiato', 'catppuccin_mocha']`.

(If `tomllib` is unavailable — Python < 3.11 — the `grep -c` returning `4` is sufficient.)

- [ ] **Step 3: Commit**

```bash
git add starship/.config/starship.toml
git commit -m "feat(starship): add catppuccin latte palette for light mode"
```

---

### Task 2: Rewrite `detect-theme.sh` (Linux detection, state-file gate, per-tool fixes)

**Files:**
- Modify (full rewrite): `tmux/.tmux/scripts/detect-theme.sh`

- [ ] **Step 1: Replace the entire file with the new version**

Write `tmux/.tmux/scripts/detect-theme.sh` with exactly this content:

```bash
#!/usr/bin/env bash
# Detect system dark/light mode and sync the catppuccin flavor across CLI tools
# (tmux, starship, bat, lsd, glow, television) that aren't themed elsewhere.
# Supports macOS, WSL2, and native Linux (Omarchy marker + freedesktop fallback).

detect_mode() {
    case "$(uname -s)" in
        Darwin)
            # macOS: defaults returns "Dark" in dark mode, fails in light mode
            if defaults read -g AppleInterfaceStyle &>/dev/null; then
                echo "dark"
            else
                echo "light"
            fi
            ;;
        Linux)
            if grep -qi microsoft /proc/version 2>/dev/null; then
                # WSL2: query Windows registry (0 = dark, 1 = light)
                local val
                val=$(powershell.exe -NoProfile -NonInteractive -Command \
                    "Get-ItemPropertyValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name AppsUseLightTheme" 2>/dev/null | tr -d '\r')
                if [ "$val" = "0" ]; then
                    echo "dark"
                else
                    echo "light"
                fi
            elif [ -e "$HOME/.config/omarchy/current/theme/light.mode" ]; then
                # Omarchy: light themes drop a light.mode marker in the active theme dir
                echo "light"
            elif gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | grep -qi light; then
                # Freedesktop fallback (GNOME-based DEs)
                echo "light"
            else
                echo "dark"
            fi
            ;;
        *)
            echo "dark"
            ;;
    esac
}

apply_theme() {
    local mode flavor state_file current

    mode=$(detect_mode)
    if [ "$mode" = "light" ]; then
        flavor="latte"
    else
        flavor="mocha"
    fi

    # Gate on a state file so this is correct whether triggered by tmux
    # focus-in or the Omarchy theme-set hook (which has no attached client).
    state_file="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles-theme/flavor"
    current=""
    [ -f "$state_file" ] && current=$(cat "$state_file")
    [ "$current" = "$flavor" ] && return 0

    # --- tmux (only when a server is running) ---
    if tmux info &>/dev/null; then
        # Unset all catppuccin-generated options so the -o flag doesn't skip them.
        # This covers @thm_* (palette), @_ctp_* (internals), @catppuccin_status_*
        # (compiled modules), and @catppuccin_*_color (module accent colors).
        tmux show-options -g \
            | awk '/^@(thm_|_ctp_|catppuccin_status_|catppuccin_[a-z_]+_color )/ {print $1}' \
            | while read -r opt; do
                tmux set -gu "$opt"
            done

        tmux set -g @catppuccin_flavor "$flavor"
        bash ~/.tmux/plugins/tmux/catppuccin.tmux
        tmux source ~/.tmux/scripts/status.conf
        # Re-run plugin scripts to replace #{battery_percentage} etc. with #(script) calls
        bash ~/.tmux/plugins/tmux-battery/battery.tmux
        bash ~/.tmux/plugins/tmux-cpu/cpu.tmux
    fi

    # --- starship ---
    starship_config="$HOME/.config/starship.toml"
    if [ -f "$starship_config" ]; then
        sed -i'' -e "s/^palette = \"catppuccin_[a-z]*\"/palette = \"catppuccin_${flavor}\"/" "$starship_config"
    fi

    # --- lsd ---
    lsd_theme="$HOME/.config/lsd/themes/catppuccin-${flavor}/colors.yaml"
    if [ -f "$lsd_theme" ]; then
        cp "$lsd_theme" "$HOME/.config/lsd/colors.yaml"
    fi

    # --- bat ---
    bat_config="$HOME/.config/bat/config"
    if [ -f "$bat_config" ]; then
        # Capitalize first letter: mocha -> Mocha, latte -> Latte
        bat_flavor="$(echo "$flavor" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
        sed -i'' -e "s/--theme=\"Catppuccin .*\"/--theme=\"Catppuccin ${bat_flavor}\"/" "$bat_config"
    fi

    # --- glow (config path differs by OS) ---
    if [ "$(uname -s)" = "Darwin" ]; then
        glow_config="$HOME/Library/Preferences/glow/glow.yml"
    else
        glow_config="$HOME/.config/glow/glow.yml"
    fi
    if [ -f "$glow_config" ]; then
        glow_theme="$HOME/.config/glow/themes/catppuccin-${flavor}.json"
        sed -i'' -e "s|style: \".*\"|style: \"${glow_theme}\"|" "$glow_config"
    fi

    # --- television (random accent; skipped on Linux, not installed there) ---
    if [ "$(uname -s)" != "Linux" ]; then
        tv_config="$HOME/.config/television/config.toml"
        if [ -f "$tv_config" ]; then
            accents=(blue flamingo green lavender maroon mauve peach pink red rosewater sapphire sky teal yellow)
            accent="${accents[$((RANDOM % ${#accents[@]}))]}"
            sed -i'' -e "s/theme = \"catppuccin-[a-z]*-[a-z]*\"/theme = \"catppuccin-${flavor}-${accent}\"/" "$tv_config"
        fi
    fi

    # Persist the applied flavor for the next run's gate.
    mkdir -p "$(dirname "$state_file")"
    echo "$flavor" > "$state_file"
}

# Run only when executed directly (sourcing for tests must have no side effects).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    apply_theme
fi
```

- [ ] **Step 2: Lint the script**

Run:
```bash
bash -n tmux/.tmux/scripts/detect-theme.sh && echo "syntax OK"
command -v shellcheck >/dev/null && shellcheck -S error tmux/.tmux/scripts/detect-theme.sh && echo "shellcheck clean" || echo "shellcheck skipped/clean"
```
Expected: `syntax OK`, and shellcheck reports no errors (or is skipped if not installed).

- [ ] **Step 3: Smoke-test detection by sourcing (no side effects)**

Run:
```bash
bash -c '
  source tmux/.tmux/scripts/detect-theme.sh
  HOME=$(mktemp -d)
  mkdir -p "$HOME/.config/omarchy/current/theme"
  touch "$HOME/.config/omarchy/current/theme/light.mode"
  echo "marker -> $(detect_mode)"          # expect light
  rm "$HOME/.config/omarchy/current/theme/light.mode"
  gsettings() { echo "prefer-dark"; }
  echo "no-marker/dark -> $(detect_mode)"  # expect dark
'
```
Expected: `marker -> light` then `no-marker/dark -> dark`. (Confirms sourcing runs no `apply_theme` side effects and the new branches work.)

- [ ] **Step 4: Commit**

```bash
git add tmux/.tmux/scripts/detect-theme.sh
git commit -m "feat(theme): native Linux/Omarchy detection + state-file gating

Add Omarchy light.mode + gsettings detection, gate on an XDG cache
state file (works outside tmux), guard the tmux block on a running
server, switch starship palette, pick glow path by OS, skip
television on Linux. Refactor into detect_mode/apply_theme with a
source guard for testability."
```

---

### Task 3: Add a regression test for Linux detection

**Files:**
- Create: `tmux/.tmux/scripts/test-detect-theme.sh`

- [ ] **Step 1: Write the test script**

Write `tmux/.tmux/scripts/test-detect-theme.sh` with exactly this content:

```bash
#!/usr/bin/env bash
# Tests for detect_mode() native-Linux detection in detect-theme.sh.
# Sources the script (which must be side-effect-free) and overrides HOME +
# gsettings to exercise each branch. Run on Linux: `bash test-detect-theme.sh`.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/detect-theme.sh"

fail=0
assert_eq() {
    if [ "$1" = "$2" ]; then
        echo "PASS: $3"
    else
        echo "FAIL: $3 — expected '$2', got '$1'"
        fail=1
    fi
}

if [ "$(uname -s)" != "Linux" ]; then
    echo "SKIP: Linux-only detection tests (uname=$(uname -s))"
    exit 0
fi

tmp=$(mktemp -d)
export HOME="$tmp"
gsettings() { return 1; }  # default: no light signal

# 1. Omarchy light.mode marker present -> light
mkdir -p "$HOME/.config/omarchy/current/theme"
touch "$HOME/.config/omarchy/current/theme/light.mode"
assert_eq "$(detect_mode)" "light" "omarchy light.mode marker -> light"

# 2. Marker absent, gsettings reports light -> light (fallback)
rm -f "$HOME/.config/omarchy/current/theme/light.mode"
gsettings() { echo "'prefer-light'"; }
assert_eq "$(detect_mode)" "light" "gsettings prefer-light -> light"

# 3. Marker absent, gsettings reports dark -> dark
gsettings() { echo "'prefer-dark'"; }
assert_eq "$(detect_mode)" "dark" "gsettings prefer-dark -> dark"

# 4. Marker absent, gsettings unavailable -> dark (default)
gsettings() { return 1; }
assert_eq "$(detect_mode)" "dark" "no signal -> dark default"

rm -rf "$tmp"
exit $fail
```

- [ ] **Step 2: Make it executable and run it**

Run:
```bash
chmod +x tmux/.tmux/scripts/test-detect-theme.sh
bash tmux/.tmux/scripts/test-detect-theme.sh; echo "exit=$?"
```
Expected: four `PASS:` lines and `exit=0`.

- [ ] **Step 3: Commit**

```bash
git add tmux/.tmux/scripts/test-detect-theme.sh
git commit -m "test(theme): cover native Linux detect_mode branches"
```

---

### Task 4: Add the Omarchy `theme-set` hook (new stow package)

**Files:**
- Create: `omarchy/.config/omarchy/hooks/theme-set.d/10-sync-cli-theme`

- [ ] **Step 1: Create the hook script**

Write `omarchy/.config/omarchy/hooks/theme-set.d/10-sync-cli-theme` with exactly this content:

```bash
#!/usr/bin/env bash
# Omarchy theme-set hook: re-sync the catppuccin light/dark flavor across CLI
# tools (tmux, starship, bat, lsd, glow) that Omarchy itself doesn't theme.
# Omarchy runs this via `omarchy-hook theme-set <name>` after switching themes;
# the theme name arg is ignored because we re-detect light/dark from scratch.
exec "$HOME/.tmux/scripts/detect-theme.sh"
```

- [ ] **Step 2: Make it executable (stow preserves the mode)**

Run:
```bash
chmod +x omarchy/.config/omarchy/hooks/theme-set.d/10-sync-cli-theme
test -x omarchy/.config/omarchy/hooks/theme-set.d/10-sync-cli-theme && echo "executable OK"
```
Expected: `executable OK`. (`git add` in Step 4 records the executable bit automatically.)

- [ ] **Step 3: Stow the package and verify the symlink**

Run:
```bash
stow -v -t "$HOME" omarchy
ls -l "$HOME/.config/omarchy/hooks/theme-set.d/10-sync-cli-theme"
```
Expected: a symlink pointing into the repo's `omarchy/.config/omarchy/hooks/theme-set.d/10-sync-cli-theme`.

(If `stow` reports a conflict because `~/.config/omarchy/hooks/` is a real dir owned by Omarchy, run `stow --no-folding -v -t "$HOME" omarchy` so only the leaf file is symlinked rather than the whole directory.)

- [ ] **Step 4: Commit**

```bash
git add omarchy/.config/omarchy/hooks/theme-set.d/10-sync-cli-theme
git commit -m "feat(omarchy): hook theme-set to re-sync CLI catppuccin flavor"
```

---

### Task 5: End-to-end verification on Omarchy

**Files:** none (verification + docs only)

- [ ] **Step 1: Capture current state**

Run:
```bash
cat "${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles-theme/flavor" 2>/dev/null || echo "(no state yet)"
grep '^palette' "$HOME/.config/starship.toml"
grep -E 'theme=' "$HOME/.config/bat/config" 2>/dev/null || true
```
Note the values to compare after switching.

- [ ] **Step 2: Switch to a dark Omarchy theme and confirm the cascade**

Pick a dark theme from `omarchy-theme-list` (one WITHOUT a `light.mode`) and run:
```bash
omarchy-theme-set "Tokyo Night"   # or any installed dark theme
sleep 1
cat "${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles-theme/flavor"   # expect: mocha
grep '^palette' "$HOME/.config/starship.toml"                 # expect: catppuccin_mocha
grep -E 'theme=' "$HOME/.config/bat/config"                   # expect: Catppuccin Mocha
readlink -f "$HOME/.config/lsd/colors.yaml" 2>/dev/null
```
Expected: state file `mocha`, starship `catppuccin_mocha`, bat `Catppuccin Mocha`. Open a fresh prompt to see starship update live.

- [ ] **Step 3: Switch to a light Omarchy theme and confirm the flip**

Pick a light theme (one that ships `light.mode`, e.g. "Catppuccin Latte" or "Rose Pine Dawn"):
```bash
omarchy-theme-set "Catppuccin Latte"
sleep 1
cat "${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles-theme/flavor"   # expect: latte
grep '^palette' "$HOME/.config/starship.toml"                 # expect: catppuccin_latte
grep -E 'theme=' "$HOME/.config/bat/config"                   # expect: Catppuccin Latte
test -e "$HOME/.config/omarchy/current/theme/light.mode" && echo "light.mode present"
```
Expected: state file `latte`, starship `catppuccin_latte`, bat `Catppuccin Latte`, `light.mode present`. Confirm `bat <somefile>` and `lsd` render in light colors.

- [ ] **Step 4: Confirm the no-op gate and tmux path**

Run (with a tmux server running):
```bash
"$HOME/.tmux/scripts/detect-theme.sh"; echo "second run exit=$?"   # no-op, exit 0
tmux show-option -gqv @catppuccin_flavor                           # expect: latte
```
Expected: second run does nothing (flavor unchanged) and tmux reports `latte`.

- [ ] **Step 5: Restore preferred theme and finalize**

Run:
```bash
omarchy-theme-set "<your-usual-theme>"
git status
```
Expected: working tree clean (all changes already committed in Tasks 1–4). No commit needed for this task.
