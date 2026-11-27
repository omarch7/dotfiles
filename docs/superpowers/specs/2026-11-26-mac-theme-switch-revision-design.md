# macOS + Omarchy theme-switch revision — design

**Date:** 2026-11-26
**Status:** Approved in conversation (pending doc review)

## Intent

dark → catppuccin-mocha, light → catppuccin-latte, followed automatically by
every CLI tool on **both** the Mac and Omarchy — with no theme switch ever
leaving the stow repo dirty.

## Problem

The hub script `tmux/.tmux/scripts/detect-theme.sh` already switches tmux,
starship, lsd, bat, glow, claude code, television and btop, and the starship
symlink-swap pattern (2026-06-19 plan) keeps switches git-clean. But:

1. **No macOS trigger.** The script's only triggers are tmux load,
   tmux `client-focus-in`, and the Omarchy theme-set hook. tmux is no longer
   running on the Mac (Herdr replaced it), so macOS appearance changes
   re-sync nothing until something happens to fire the script.
2. **Herdr opts out.** `herdr/.config/herdr/config.toml` has
   `[theme] name = "catppuccin"` with `auto_switch = false`; Herdr's built-in
   light/dark auto-switching is unused.
3. **Glow is untracked.** Its config is `sed`-mutated at
   `~/Library/Preferences/glow/glow.yml` (macOS), the theme JSONs in
   `~/.config/glow/themes/` are not in the repo, and the pattern doesn't
   follow the symlink-swap convention.

## Goals

- macOS appearance changes propagate to all switched tools without user action.
- Herdr's UI follows light/dark on both platforms.
- Glow's config and themes are stow-managed and switch via symlink swap.
- Omarchy behavior unchanged (hook already fires instantly).

### Non-goals / anti-goals

- No per-tool tracking of arbitrary Omarchy themes (light/dark only).
- No mutation of any git-tracked file during a theme switch.
- No changes to tmux's own theming or trigger path.

## Approaches considered (macOS trigger)

1. **zsh precmd hook** — zero installs, but `~/.zshrc` is a plain untracked
   file (not stow-managed), so the hook would live outside the repo; and
   updates land only on the next prompt. **Rejected.**
2. **dark-notify + stowed launchd agent** — instant, system-wide, works with
   no terminal open; one tap formula + one tracked plist. **Picked.**
3. **Pure launchd WatchPath** — macOS exposes no file that changes with
   appearance; cannot work without a resident helper anyway. **Rejected.**

## Decisions

1. **macOS trigger:** `dark-notify` (from `cormacrelf/tap`) running
   `dark-notify -c $HOME/.tmux/scripts/detect-theme.sh` under a launchd agent,
   `RunAtLoad` + `KeepAlive`, stowed as a new `launchd` package at
   `~/Library/LaunchAgents/local.oc.dotfiles-theme.plist`. The script's
   state-file gate keeps repeat fires free. One-time: `brew install
   cormacrelf/tap/dark-notify`, stow the package, `launchctl bootstrap`.
2. **Herdr:** in the tracked `config.toml`, set `auto_switch = true` with
   `light_name = "catppuccin-latte"` and `dark_name = "catppuccin"`. Herdr then
   follows the host terminal's appearance report. Live-test with Ghostty; if
   Ghostty doesn't report the change, fall back to Herdr's documented recipe:
   `detect-theme.sh` sends `kill -WINCH` to the Herdr client after a switch
   (client PID only; panes keep running).
3. **Glow:** new `glow` stow package holding `.config/glow/glow-mocha.yml`,
   `glow-latte.yml`, `.config/glow/themes/*.json` (tracked), and
   `.stow-local-ignore` excluding `glow.yml` (mirrors starship). The script
   swaps `~/.config/glow/glow.yml` via `ln -sf` to the active flavor file;
   the macOS-specific `~/Library/Preferences/glow/glow.yml` becomes a one-time
   symlink to `~/.config/glow/glow.yml` so one swap serves both OSes. The
   stale `glow.yml-e` sed artifact is deleted during migration.
4. **Starship:** unchanged (symlink swap already correct).
5. **Dirty-git guarantee:** the only repo-tracked file a switch touches is the
   symlink the script owns (`starship.toml`, now `glow.yml`) — never a tracked
   file's contents.

## Left to the builder

- Exact launchd plist keys and log paths.
- The Herdr appearance-report test (auto_switch vs WINCH fallback) — settle
  by live test, not by asking.
- Commit sequencing per the repo's usual commit-per-task style.

## Revision during execution (2026-11-27)

Live testing changed two decisions:

1. **The glow symlink swap was dropped** (Decisions 3 and 5 above no longer
   describe what shipped). Glow resolves relative `style:` paths against its
   **current working directory**, not the config file's directory, so tracked
   flavor files cannot be OS-portable, and glow auto-creates a default config
   (write-through symlinks) whenever its config path is missing. What shipped
   instead: the `glow` package tracks only the **theme JSONs**; the live
   `glow.yml` stays untracked and sed-swapped by the script (it was never
   git-tracked, so no dirt either way). The macOS `Preferences` path stays a
   real file.
2. **Herdr's fallback branch was not needed**: `auto_switch = true` was
   verified live flipping both directions; Ghostty reports the appearance
   change to Herdr on its own.

The plan's sed-idiom work surfaced a pre-existing bug: `sed -i'' -e` makes
BSD sed treat `-e` as the in-place backup suffix, littering `*-e` files on
every switch; the fix (pipe through a temp file and `mv`) is portable to
GNU sed, which the BSD-only form also broke. The launchd plist carries an
explicit `PATH` including `/opt/homebrew/bin`, without which the script
silently skipped Homebrew tools like btop — and the state-file gate would
then have kept them stuck on the old flavor.

**Addition (also 2026-11-27): Claude Code live theming.** Spike-verified
behavior of Claude Code 2.1.332: a `theme` change in `settings.json` only
reaches new sessions, but a running session **live-re-renders when the
selected custom theme file's content changes while its `name` stays
identical** (changing the name breaks the selection identity). The script
therefore maintains one stable slug: on every switch it copies the active
flavor's palette onto `~/.claude/themes/catppuccin.json` with the name
pinned to "Catppuccin", and `settings.json` permanently points at
`custom:catppuccin`. Open sessions need a one-time `/theme` selection of
the slug; every session after that follows appearance changes live with
no script-visible manual step.
