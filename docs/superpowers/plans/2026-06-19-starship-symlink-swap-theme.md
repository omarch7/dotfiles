# Starship Symlink-Swap Theme Switching Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `sed`-based starship palette mutation with a symlink swap so theme switching never makes the git repo dirty.

**Architecture:** Two flavor-specific toml files (`starship-latte.toml`, `starship-mocha.toml`) are tracked by stow. A `.stow-local-ignore` entry tells stow to leave `~/.config/starship.toml` alone. The `detect-theme.sh` script owns that symlink and re-points it atomically on each theme switch.

**Tech Stack:** GNU stow, bash, starship

## Global Constraints

- Stow package root: `starship/` inside `/Users/oc/dotfiles`
- Theme script: `tmux/.tmux/scripts/detect-theme.sh`
- Only the `palette =` line differs between flavor files; all other config is identical
- macOS `ln -sf` is used for the symlink (same as the btop block already in the script)

---

### Task 1: Create flavor-specific starship config files and stow ignore entry

**Files:**
- Create: `starship/.config/starship-mocha.toml`
- Create: `starship/.config/starship-latte.toml`
- Create: `starship/.config/.stow-local-ignore`

**Interfaces:**
- Produces: `~/.config/starship-mocha.toml` and `~/.config/starship-latte.toml` (symlinked by stow), used by Task 2's `ln -sf` call

- [ ] **Step 1: Copy current config to mocha flavor file**

The current `starship/.config/starship.toml` already has `palette = "catppuccin_latte"` (it was last saved in light mode). Copy it and set the palette to mocha:

```bash
cp /Users/oc/dotfiles/starship/.config/starship.toml \
   /Users/oc/dotfiles/starship/.config/starship-mocha.toml
```

Then open `starship/.config/starship-mocha.toml` and change line 3 from:
```toml
palette = "catppuccin_latte"
```
to:
```toml
palette = "catppuccin_mocha"
```

- [ ] **Step 2: Copy current config to latte flavor file**

```bash
cp /Users/oc/dotfiles/starship/.config/starship.toml \
   /Users/oc/dotfiles/starship/.config/starship-latte.toml
```

Verify line 3 reads `palette = "catppuccin_latte"` — it should already be correct since it was copied from the current file.

- [ ] **Step 3: Create .stow-local-ignore**

Create `starship/.config/.stow-local-ignore` with exactly this content (one line):

```
starship\.toml
```

The backslash-escaped dot tells stow to treat this as a literal filename match (stow uses Perl regex for ignore patterns; `\.` matches a literal dot).

- [ ] **Step 4: Verify stow sees the ignore entry**

```bash
cd /Users/oc/dotfiles
stow --simulate starship 2>&1
```

Expected: stow lists `starship-latte.toml`, `starship-mocha.toml`, and `.stow-local-ignore` as links to create — but does NOT mention `starship.toml`. If `starship.toml` still appears, the ignore file path or pattern is wrong.

- [ ] **Step 5: Remove the current stow-managed symlink**

```bash
rm ~/.config/starship.toml
```

- [ ] **Step 6: Restow the starship package**

```bash
cd /Users/oc/dotfiles
stow starship
```

Expected output: silent (stow only prints on conflict). Verify:

```bash
ls -la ~/.config/starship*.toml
```

Expected:
```
~/.config/starship-latte.toml  -> /Users/oc/dotfiles/starship/.config/starship-latte.toml
~/.config/starship-mocha.toml  -> /Users/oc/dotfiles/starship/.config/starship-mocha.toml
```

`~/.config/starship.toml` should NOT exist yet (the script will create it in Task 2).

- [ ] **Step 7: Commit**

```bash
cd /Users/oc/dotfiles
git add starship/.config/starship-latte.toml \
        starship/.config/starship-mocha.toml \
        starship/.config/.stow-local-ignore
git commit -m "feat(starship): add per-flavor config files and stow ignore entry

starship-latte.toml and starship-mocha.toml are the light/dark variants.
.stow-local-ignore excludes starship.toml from stow management so the
theme script can own that symlink without causing git dirty state."
```

---

### Task 2: Update detect-theme.sh to use symlink swap

**Files:**
- Modify: `tmux/.tmux/scripts/detect-theme.sh:97-101`

**Interfaces:**
- Consumes: `~/.config/starship-${flavor}.toml` symlinks produced by Task 1
- Produces: `~/.config/starship.toml` symlink pointing to the active flavor file

- [ ] **Step 1: Replace the sed block with ln -sf**

In `tmux/.tmux/scripts/detect-theme.sh`, find this block (around lines 97–101):

```bash
    # --- starship ---
    starship_config="$HOME/.config/starship.toml"
    if [ -f "$starship_config" ]; then
        sed -i'' -e "s/^palette = \"catppuccin_[a-z]*\"/palette = \"catppuccin_${flavor}\"/" "$starship_config"
    fi
```

Replace it with:

```bash
    # --- starship ---
    starship_config="$HOME/.config/starship.toml"
    starship_source="$HOME/.config/starship-${flavor}.toml"
    if [ -f "$starship_source" ]; then
        ln -sf "$starship_source" "$starship_config"
    fi
```

- [ ] **Step 2: Run the script to create the initial symlink**

```bash
bash /Users/oc/dotfiles/tmux/.tmux/scripts/detect-theme.sh
```

Expected: silent exit. Then verify:

```bash
ls -la ~/.config/starship.toml
```

Expected (on a light-mode macOS session):
```
~/.config/starship.toml -> /Users/oc/.config/starship-latte.toml
```

Or `starship-mocha.toml` if the system is currently in dark mode.

- [ ] **Step 3: Verify starship reads the active config correctly**

```bash
starship prompt
```

Expected: a rendered prompt with no errors. If starship prints config warnings, check that the symlink target is valid toml.

- [ ] **Step 4: Verify git repo is clean**

```bash
cd /Users/oc/dotfiles
git status
```

Expected: `nothing to commit, working tree clean` (or only the detect-theme.sh modification staged). The `starship/.config/starship.toml` entry that was previously showing as `M` should be gone entirely — that file no longer exists in the stow package.

- [ ] **Step 5: Commit**

```bash
cd /Users/oc/dotfiles
git add tmux/.tmux/scripts/detect-theme.sh
git commit -m "feat(starship): switch to symlink swap for theme switching

Replace sed-based palette mutation with ln -sf pointing starship.toml
at the active flavor file. This keeps the stow-tracked source files
immutable so git never sees them as dirty after a theme switch."
```
