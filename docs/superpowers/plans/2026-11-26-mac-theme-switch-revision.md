# macOS Theme-Switch Revision Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make macOS appearance changes propagate to all switched CLI tools, enable Herdr's built-in light/dark auto-switching, and move Glow onto the stow-managed symlink-swap pattern.

**Architecture:** A launchd agent (stow-managed plist) runs `dark-notify`, which fires the existing state-gated `detect-theme.sh` on every macOS appearance change — closing the trigger gap left by tmux no longer running. Herdr switches its own UI via `auto_switch = true` in the tracked config. Glow gains a stow package with per-flavor configs swapped by symlink, matching the starship pattern.

**Tech Stack:** GNU stow 2.4.1, bash, dark-notify (`cormacrelf/tap`), launchd, Herdr

**Spec:** `docs/superpowers/specs/2026-11-26-mac-theme-switch-revision-design.md`

## Global Constraints

- Files are provisioned with GNU stow (target `$HOME`); packages live at repo root (`starship/`, `tmux/`, …).
- **No theme switch may mutate the contents of any git-tracked file** — the only repo paths a switch touches are script-owned symlinks (`~/.config/starship.toml`, and after this plan `~/.config/glow/glow.yml`).
- Verified facts to build on: glow (built from source) reads `~/Library/Preferences/glow/glow.yml` on macOS; glow does **not** expand `~` in `style:` paths but **does** resolve relative paths against the config file's directory (`themes/catppuccin-mocha.json` works from any cwd); tmux is not running on the Mac; the current macOS mode is dark; the current herdr `[theme]` is `name = "catppuccin"`, `auto_switch = false`.
- Stow ignore patterns live at the package root and are path-anchored, e.g. `.config/starship\.toml`.
- Commit messages end with `Co-Authored-By: Claude Code <noreply@anthropic.com>`; staging/commit follows the user's standing rule — confirm before staging when executing interactively.
- macOS-only pieces (launchd, dark-notify) must not alter Linux/Omarchy behavior; the Omarchy hook (`omarchy/.config/omarchy/hooks/theme-set.d/10-sync-cli-theme`) stays untouched.

## Review Focus

1. **Switch while nothing is open** — dark-notify fires with no terminal running; the next glow/starship/herdr launch must already show the right flavor. (Task 4 verification.)
2. **Rapid/duplicate triggers** — two fires in a row (launchd restart, focus event) must be a no-op via the state-file gate; no duplicate symlinks or git dirt. (Task 2 and Task 4 verification.)
3. **Stow conflict with pre-existing live files** — `~/.config/glow/themes/` and `~/Library/Preferences/glow/glow.yml` are real files today; stow must run only after they're moved out of the way or every later stow breaks. (Task 1 ordering.)
4. **Herdr never receives the appearance notification** — if Ghostty doesn't report it, herdr stays stale silently; the live test in Task 3 must settle auto_switch vs the WINCH/terminal fallback rather than assume.
5. **glow rewriting its own config** — glow only writes the config via explicit `glow config`; if that's ever used it would write *through* the symlink chain into the tracked flavor file and dirty the repo. Watch for it during verification; if seen, the flavor files need to move out of the write-through path.

---

### Task 1: Glow stow package and live migration

**Files:**
- Create: `glow/.stow-local-ignore`
- Create: `glow/.config/glow/glow-mocha.yml`, `glow/.config/glow/glow-latte.yml`
- Create: `glow/.config/glow/themes/catppuccin-{latte,mocha,frappe,macchiato}.json` (copied from the live untracked dir)

**Interfaces:**
- Produces: `~/.config/glow/glow-{mocha,latte}.yml` (stow symlinks to the repo files) — consumed by Task 2's swap. Style values are relative (`themes/catppuccin-<flavor>.json`), so the files work on both macOS and Linux.

- [ ] **Step 1: Copy the live theme JSONs into the repo package**

```bash
mkdir -p /Users/oc/dotfiles/glow/.config/glow/themes
cp ~/.config/glow/themes/catppuccin-{latte,mocha,frappe,macchiato}.json \
   /Users/oc/dotfiles/glow/.config/glow/themes/
```

- [ ] **Step 2: Create the two flavor configs from the current glow.yml**

The current `~/Library/Preferences/glow/glow.yml` is the mocha flavor. Turn its absolute style path into the relative one:

```bash
sed 's|style: .*|style: "themes/catppuccin-mocha.json"|' \
    ~/Library/Preferences/glow/glow.yml > /Users/oc/dotfiles/glow/.config/glow/glow-mocha.yml
sed 's|style: .*|style: "themes/catppuccin-latte.json"|' \
    ~/Library/Preferences/glow/glow.yml > /Users/oc/dotfiles/glow/.config/glow/glow-latte.yml
```

Check: each flavor file's `style:` line is exactly `style: "themes/catppuccin-mocha.json"` / `...latte.json"`; all other lines match the current config (mouse, pager, width 140, all).

- [ ] **Step 3: Create `glow/.stow-local-ignore`**

One line, mirroring the starship convention:

```
.config/glow\.yml
```

- [ ] **Step 4: Move the live files out of stow's way**

```bash
rm -rf ~/.config/glow/themes
rm ~/Library/Preferences/glow/glow.yml ~/Library/Preferences/glow/glow.yml-e
```

(The theme JSONs are already copied into the repo in Step 1; `glow.yml-e` is a stale sed artifact.)

- [ ] **Step 5: Stow and wire the macOS path**

```bash
cd /Users/oc/dotfiles && stow glow
ln -sfn "$HOME/.config/glow/glow.yml" ~/Library/Preferences/glow/glow.yml
```

Expected: `stow` silent. `~/.config/glow/{themes,glow-mocha.yml,glow-latte.yml}` are now symlinks into the repo.

- [ ] **Step 6: Run the script to create the script-owned config symlink**

```bash
bash ~/.tmux/scripts/detect-theme.sh
```

Verify the chain resolves and glow renders:

```bash
ls -la ~/.config/glow/glow.yml ~/Library/Preferences/glow/glow.yml
glow /Users/oc/dotfiles/README.md >/dev/null && echo "glow ok"
```

Expected (dark mode): `~/.config/glow/glow.yml -> .../glow-mocha.yml`; `glow ok`.

- [ ] **Step 7: Verify the repo stays clean after a forced re-switch**

```bash
rm -f ~/.cache/dotfiles-theme/flavor && bash ~/.tmux/scripts/detect-theme.sh
cd /Users/oc/dotfiles && git status --porcelain
```

Expected: only this task's new/modified files; nothing else. Run the script once more with the state file present — expected: exits early, `git status` unchanged.

- [ ] **Step 8: Commit**

```bash
cd /Users/oc/dotfiles
git add glow/
git commit -m "feat(glow): track themes and configs as a stow package

Glow's theme JSONs and per-flavor configs move into the repo. Style
paths are relative to the config dir so one set of files serves macOS
and Linux. glow.yml is stow-ignored and owned by the theme script
(symlink swap, like starship). macOS's ~/Library/Preferences/glow/glow.yml
symlinks to ~/.config/glow/glow.yml.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 2: detect-theme.sh glow block → symlink swap

**Files:**
- Modify: `tmux/.tmux/scripts/detect-theme.sh:118-127` (the `# --- glow ---` block)

**Interfaces:**
- Consumes: `~/.config/glow/glow-{mocha,latte}.yml` from Task 1.
- Produces: the script-owned `~/.config/glow/glow.yml` symlink, same pattern as the starship block at lines 97-102.

- [ ] **Step 1: Replace the OS-branch + sed block**

Replace the entire glow block (from `# --- glow (config path differs by OS) ---` through its closing `fi`) with:

```bash
    # --- glow (config lives in ~/.config/glow; on macOS
    #     ~/Library/Preferences/glow/glow.yml is a one-time symlink to it,
    #     so one swap serves both OSes) ---
    glow_config="$HOME/.config/glow/glow.yml"
    glow_source="$HOME/.config/glow/glow-${flavor}.yml"
    if [ -f "$glow_source" ]; then
        ln -sf "$glow_source" "$glow_config"
    fi
```

- [ ] **Step 2: Exercise both flavors**

```bash
rm -f ~/.cache/dotfiles-theme/flavor
bash ~/.tmux/scripts/detect-theme.sh
readlink ~/.config/glow/glow.yml
```

Expected: `.../glow-mocha.yml` (macOS currently dark). Then flip the real input to prove the swap follows: toggle appearance to light (`osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to false'` — grants an automation permission once, if asked; if refused, toggle System Settings → Appearance by hand), run the script again, `readlink ~/.config/glow/glow.yml` → expect `glow-latte.yml`. Toggle back to dark, run the script, expect `glow-mocha.yml`. (No auto-trigger exists yet — dark-notify arrives in Task 4 — so each toggle is followed by a manual script run here.)

- [ ] **Step 3: Verify repo clean and starship unaffected**

```bash
cd /Users/oc/dotfiles && git status --porcelain
readlink ~/.config/starship.toml
```

Expected: only `tmux/.tmux/scripts/detect-theme.sh` modified; starship symlink still `starship-mocha.toml`.

- [ ] **Step 4: Commit**

```bash
cd /Users/oc/dotfiles
git add tmux/.tmux/scripts/detect-theme.sh
git commit -m "refactor(glow): switch detect-theme.sh to symlink swap

Replace the OS-branched sed mutation with the same ln -sf pattern
starship uses, so glow's tracked flavor files are never mutated.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 3: Herdr built-in auto-switching

**Files:**
- Modify: `herdr/.config/herdr/config.toml` (`[theme]` block, ~line 89-92)

**Interfaces:**
- Consumes: Herdr's built-in catppuccin theme pair (`catppuccin` dark, `catppuccin-latte` light) and the host terminal's (Ghostty's) appearance report.
- Produces: nothing downstream; the remaining tasks are independent of it.

- [ ] **Step 1: Enable auto_switch in the tracked config**

The `[theme]` block becomes:

```toml
[theme]
name = "catppuccin"
auto_switch = true
light_name = "catppuccin-latte"
dark_name = "catppuccin"
```

- [ ] **Step 2: Validate and reload**

```bash
herdr config check
herdr server reload-config
```

Expected: `config: ok`; reload succeeds.

- [ ] **Step 3: Live-test the appearance flip**

Toggle macOS appearance (`osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to false'`, or System Settings by hand). Wait ~3 s, then ask the user to confirm the Herdr sidebar/panes switched to latte. Toggle back to dark and confirm the return flip.

**Decision branch:** if Herdr does NOT flip:
1. Try Herdr's documented fallback: `kill -WINCH` the attached Herdr *client* PID after the switch (find it via `herdr status`; never the server). If the flip then works on next toggle, add that poke to `detect-theme.sh` (guarded to macOS + only when a herdr client is found) and include it in this task's commit.
2. If even that fails, switch `[theme]` to `name = "terminal"` (Herdr follows the host terminal's catppuccin ANSI palette) plus the WINCH poke, and note the outcome in the design doc's "Left to the builder" section.

- [ ] **Step 4: Verify repo clean**

```bash
cd /Users/oc/dotfiles && git status --porcelain
```

Expected: only `herdr/.config/herdr/config.toml` (and, if the fallback branch fired, `detect-theme.sh`).

- [ ] **Step 5: Commit**

```bash
cd /Users/oc/dotfiles
git add herdr/.config/herdr/config.toml tmux/.tmux/scripts/detect-theme.sh
git commit -m "feat(herdr): enable built-in light/dark theme auto-switching

Herdr now follows the host terminal's appearance report and flips
between catppuccin (dark) and catppuccin-latte on its own; no script
involvement needed. [Adjust if the fallback branch was taken.]

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 4: macOS trigger — dark-notify launchd agent

**Files:**
- Create: `launchd/Library/LaunchAgents/local.oc.dotfiles-theme.plist` (new `launchd` stow package)

**Interfaces:**
- Consumes: `~/.tmux/scripts/detect-theme.sh` (unchanged interface), `dark-notify` binary from brew.
- Produces: a resident launchd agent that runs the script at login and on every macOS appearance change. Independent of Task 3.

- [ ] **Step 1: Install dark-notify**

```bash
brew install cormacrelf/tap/dark-notify
```

- [ ] **Step 2: Create the plist**

`launchd/Library/LaunchAgents/local.oc.dotfiles-theme.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>local.oc.dotfiles-theme</string>
    <key>ProgramArguments</key>
    <array>
        <string>/opt/homebrew/bin/dark-notify</string>
        <string>-c</string>
        <string>/Users/oc/.tmux/scripts/detect-theme.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/local.oc.dotfiles-theme.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/local.oc.dotfiles-theme.log</string>
</dict>
</plist>
```

Absolute paths are deliberate: launchd doesn't expand `$HOME`, and this package is macOS-only. dark-notify runs the `-c` command once at startup and on every change, so login self-heals any drift.

- [ ] **Step 3: Stow and load the agent**

```bash
cd /Users/oc/dotfiles && stow launchd
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/local.oc.dotfiles-theme.plist
launchctl kickstart gui/$(id -u)/local.oc.dotfiles-theme
```

Expected: silent; `launchctl print gui/$(id -u)/local.oc.dotfiles-theme` shows state running; `/tmp/local.oc.dotfiles-theme.log` contains `light` or `dark` (dark-notify's startup line) and the script ran once.

- [ ] **Step 4: End-to-end live test**

Toggle macOS appearance (osascript or System Settings). Within a second or two, verify all script-owned pieces flipped:

```bash
cat ~/.cache/dotfiles-theme/flavor
readlink ~/.config/starship.toml ~/.config/glow/glow.yml
grep theme ~/.claude/settings.json
```

Expected: all four agree on the new flavor. Toggle back; verify again. Confirm with the user that Herdr's UI also flipped (covered by Task 3 if it passed).

- [ ] **Step 5: Verify repo clean, second fire is a no-op**

```bash
cd /Users/oc/dotfiles && git status --porcelain
bash ~/.tmux/scripts/detect-theme.sh   # manual re-fire
git status --porcelain                 # unchanged
```

- [ ] **Step 6: Commit**

```bash
cd /Users/oc/dotfiles
git add launchd/
git commit -m "feat(launchd): sync CLI theme on macOS appearance change

dark-notify watches macOS light/dark and fires detect-theme.sh, which
tmux focus-in no longer covers now that Herdr replaced tmux on the Mac.
The agent is stow-managed; RunAtLoad + KeepAlive keep it resident and
self-healing (dark-notify re-syncs once at every start).

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 5: Update the README theming notes

**Files:**
- Modify: `README.md` (the theming/dotfiles overview section)

**Interfaces:** none.

- [ ] **Step 1: Update the README**

In the section describing tool theming, add one short paragraph: macOS appearance changes are picked up by the `local.oc.dotfiles-theme` launchd agent (dark-notify → `detect-theme.sh`); Herdr auto-switches via `theme.auto_switch` in its config; Glow follows the same symlink-swap pattern as Starship. Keep it to 3-4 lines matching the README's existing voice.

- [ ] **Step 2: Commit**

```bash
cd /Users/oc/dotfiles
git add README.md
git commit -m "docs: describe the macOS theme-switch trigger and Herdr auto-switching

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```
