# Seamless nvim ↔ herdr Pane Navigation & Resizing

**Date:** 2026-07-06
**Status:** Approved

## Summary

Replicate the current tmux + `vim-tmux-navigator` seamless-navigation experience under
[herdr](https://herdr.dev) (the new terminal workspace manager, installed at `~/.local/bin/herdr`,
v0.7.1). A single set of muscle-memory keys — bare `Ctrl-h/j/k/l` to move and `Ctrl-Alt-h/j/k/l`
to resize — must move/resize *within* nvim's own splits and cross into the adjacent **herdr pane**
once nvim is at its outermost split edge, in either direction.

herdr has no built-in equivalent of vim-tmux-navigator's tmux integration (no user-settable pane
variable like `@pane-is-vim`, no process-aware conditional keybindings). So the behavior is rebuilt
from two cooperating pieces plus a herdr-side foreground-process check.

"Namespaces" in the original request = **herdr panes** (split regions within a tab), the direct
analog of tmux panes. herdr tabs/workspaces are out of scope.

## Background: how the tmux version works today

`vim-tmux-navigator` binds bare `C-h/j/k/l` in tmux with a conditional:

```tmux
bind-key -n C-h if -F "#{@pane-is-vim}" 'send-keys C-h' 'select-pane -L'
```

`@pane-is-vim` is a pane-local tmux option the plugin sets on nvim startup (`bind_key_vim` /
the `is_vim` ps check in `vim-tmux-navigator.tmux`). If nvim owns the pane, the key is forwarded
into nvim; otherwise tmux moves the pane. Inside nvim, the plugin maps `<C-h>` to move to the next
nvim split, or — when already at nvim's edge — shell out to `tmux select-pane -L`.

The current dotfiles wiring:
- `nvim/.config/nvim/lua/plugins/specs/vim-tmux-navigator.lua` — plugin spec, maps `<c-h/j/k/l>` and `<c-\>`.
- `nvim/.config/nvim/lua/core/keymaps.lua:65-69` — the same maps in terminal mode (`"t"`).
- No other config claims `C-h/j/k/l` (verified via grep of `lua/`).

Under herdr, `$TMUX` is unset and there is no `tmux` socket, so `vim-tmux-navigator`'s shell-outs
are dead — hence the replacement.

## Approach

Replace `vim-tmux-navigator` with [`smart-splits.nvim`](https://github.com/mrjones2014/smart-splits.nvim),
which is designed with a pluggable multiplexer backend (built-in `tmux`/`wezterm`/`kitty`/`zellij`
modules under `lua/smart-splits/mux/`). We add a **custom `herdr` backend module** implementing the
same interface, driving the `herdr` CLI. On the herdr side, a **custom command** bound to the bare
chords performs the is-nvim check and either forwards the key or moves/resizes the pane.

### Verified herdr CLI facts (v0.7.1)

Confirmed empirically before design:
- `herdr pane focus --direction left|right|up|down [--pane ID|--current]` — move focus.
- `herdr pane resize --direction left|right|up|down [--amount FLOAT] [--pane ID|--current]` — resize.
- `herdr pane neighbor --direction ... [--current]` — returns neighbor pane id (or self if none) as JSON.
- `herdr pane edges [--current]` — returns `{left,right,up,down: bool}` edge flags + layout incl. `zoomed`.
- `herdr pane current` — returns focused pane info as JSON (`pane_id`, `tab_id`, `workspace_id`, ...).
- `herdr pane process-info --current` — returns `foreground_processes[]` with `name`/`argv0`/`cmdline`.
- `herdr pane send-keys <pane_id> <key> [key ...]` — inject keystroke(s) into a pane.
- `herdr server reload-config` — hot-reloads `config.toml`; returns JSON `diagnostics[]` (empty = clean;
  invalid bindings are reported and disabled, config not applied atomically as "partial").
- Inside a herdr pane the shell has env: `HERDR_ENV=1`, `HERDR_PANE_ID`, `HERDR_TAB_ID`,
  `HERDR_WORKSPACE_ID`, `HERDR_SOCKET_PATH`. There is **no** `$TMUX` analog beyond `HERDR_ENV`.
- Custom commands (`[[keys.command]]`) accept **bare/direct chords** (e.g. `ctrl+h`), not only `prefix+…`
  (verified: reloaded a `ctrl+g` shell command with zero diagnostics). They receive
  `HERDR_ACTIVE_PANE_ID` (+ tab/workspace/cwd) in their environment.

### Component 1 — nvim: swap plugin, keep keys

Replace `vim-tmux-navigator.lua` with a `smart-splits.lua` spec. smart-splits.nvim maps nothing by
itself, so we set the maps explicitly (matching today's keys):

```lua
-- move (normal + terminal mode, mirroring current keymaps.lua)
<C-h> → require('smart-splits').move_cursor_left
<C-j> → require('smart-splits').move_cursor_down
<C-k> → require('smart-splits').move_cursor_up
<C-l> → require('smart-splits').move_cursor_right
-- resize
<C-A-h> → resize_left      <C-A-j> → resize_down
<C-A-k> → resize_up        <C-A-l> → resize_right
```

Config: `at_edge = 'stop'` (do NOT wrap; hand off to herdr at the edge instead — wrapping inside nvim
would defeat crossing the pane boundary), and `multiplexer_integration = 'herdr'` so smart-splits
loads our custom backend. Because the mux backend must be present at load and the integration is
active immediately, the plugin is **not** lazy-loaded (`lazy = false` / `event = "VeryLazy"`), matching
smart-splits' own guidance for multiplexer use.

`<C-\>` (navigate-previous) has no herdr CLI equivalent (no "last pane" focus command exposed) and is
dropped — noted in Out of Scope.

### Component 2 — nvim: custom `herdr` mux backend module

A new Lua module implementing smart-splits' `SmartSplitsMultiplexer` interface, modeled line-for-line
on the built-in `tmux.lua`. It shells out to `herdr` via `smart-splits.utils.system`. Functions:

| Interface fn | herdr implementation |
|---|---|
| `is_in_session()` | `vim.env.HERDR_ENV == '1'` (and `HERDR_PANE_ID` present) |
| `current_pane_id()` | `vim.env.HERDR_PANE_ID` (no CLI call needed) |
| `current_pane_at_edge(dir)` | `herdr pane edges --current` → parse JSON, return the flag for `dir` |
| `next_pane(dir)` | `herdr pane focus --direction <dir> --current` |
| `resize_pane(dir, amount)` | `herdr pane resize --direction <dir> --amount <amount> --current` |
| `current_pane_is_zoomed()` | `herdr pane edges --current` → `layout.zoomed` |
| `split_pane(dir, size)` | `herdr pane split --current --direction right\|down [--ratio]` (best-effort; not used by nav/resize with `at_edge='stop'`) |

Direction mapping: smart-splits `left/right/up/down` → herdr `left/right/up/down` (1:1, no translation
table needed unlike tmux's `L/R/U/D`). JSON parsed with `vim.json.decode`. On any non-zero exit or parse
failure the function returns `false`/`nil`, which smart-splits treats as "stay in nvim" (fail-safe).

Where the file lives: smart-splits resolves backends via `require('smart-splits.mux.' .. integration)`,
i.e. inside the *plugin's* runtime path. Rather than patch the plugin dir (blown away on update), the
module is shipped in our own config as `lua/smart-splits/mux/herdr.lua` (our `~/.config/nvim/lua` is on
`runtimepath`, and Lua `require` resolves the first match — our copy shadows/extends the plugin
namespace). The design records this as the load mechanism; the implementation plan will confirm resolution
order and fall back to setting `multiplexer_integration` to a live function table if `require` shadowing
proves unreliable.

### Component 3 — herdr: is-nvim check + keybindings

herdr owns the bare chords when focus is in a pane. A custom shell command per direction decides whether
to forward the key into the pane (nvim handles it) or move/resize the herdr pane directly. Pseudologic
of the helper script (one script, direction passed as arg):

```
# $1 = herdr direction (left|right|up|down); $2 = key to forward (e.g. C-h)
fg=$(herdr pane process-info --current | jq -r '.result.process_info.foreground_processes[].name')
if printf '%s\n' "$fg" | grep -qiE '(^|/)n?vim$'; then
    herdr pane send-keys "$HERDR_ACTIVE_PANE_ID" "$2"        # let nvim's smart-splits handle it
else
    herdr pane focus --direction "$1" --current              # move pane directly
fi
```

Resize variants call `herdr pane resize` instead of `focus`. The nvim-detection pattern is narrowed to
what herdr's `process-info` actually reports for a running editor (`nvim`/`vim`), rather than
vim-tmux-navigator's broader `ps`-based `(view|l?n?vim?x?|fzf)` pattern. Script is stored in the
dotfiles repo and referenced by absolute path from `config.toml`.

herdr `config.toml` gains (alongside the existing prefix / split / focus_pane / tab keys):

```toml
[[keys.command]]
key = "ctrl+h"
type = "shell"
command = "~/.config/herdr/scripts/nav.sh left C-h"
# … j/k/l, then ctrl+alt+h/j/k/l → resize variants
```

`prefix+h/j/k/l` (already configured) stays as the always-move-the-pane escape hatch that ignores nvim.

### Key open risk (to resolve first in implementation)

**Does `herdr pane send-keys <pane> C-h` re-enter herdr's own `ctrl+h` keybinding?** If herdr's
custom-command interception sits *above* pane input routing, the injected `C-h` could re-trigger
`nav.sh`, forwarding again → infinite loop. The tmux design is immune because `send-keys` writes
straight to the pane pty below the binding layer. This must be verified empirically before building
the rest: bind a `ctrl+h` command that logs + `send-keys`, press once, confirm the log fires exactly
once. Mitigations if it does loop: (a) rely on smart-splits inside nvim owning `C-h` and drop the
herdr-side forward entirely for nvim panes (herdr only handles non-nvim panes); or (b) forward a
sentinel/alternate keycode nvim maps but herdr doesn't intercept. The implementation plan treats this
as task 0.

## Data Flow — one `Ctrl-h` press, focus in a herdr pane

1. herdr intercepts bare `ctrl+h` → runs `nav.sh left C-h`.
2. `herdr pane process-info --current` → foreground is `nvim` → `herdr pane send-keys <pane> C-h`.
3. nvim's `<C-h>` (smart-splits) fires:
   - another nvim split to the left → move there; herdr not involved again.
   - already at nvim's leftmost split → smart-splits calls the `herdr` backend →
     `current_pane_at_edge('left')` false → `next_pane('left')` → `herdr pane focus --direction left`.
4. If step 2's foreground is **not** nvim (plain shell, `lazygit`, `btop`) → skip send-keys →
   `herdr pane focus --direction left` directly (one hop, no key leaked into the app).

## Error Handling

- `process-info` returns nothing (pane create/teardown race) → helper falls open to
  `herdr pane focus` directly (worst case: one press moves a pane instead of reaching nvim,
  self-corrects next press — same failure mode as tmux's `if -F`).
- mux backend CLI call fails / not under herdr → `is_in_session()` false → smart-splits stops at
  nvim's edge, identical to running nvim standalone.
- `config.toml` reload surfaces `diagnostics[]`; a non-empty array means a binding was rejected and the
  reload is "partial" — the install step must check for empty diagnostics before considering it applied.

## Testing (manual / behavioral)

1. ≥2 nvim splits in one herdr pane → `Ctrl-h/j/k/l` moves between nvim splits, never leaves the pane.
2. nvim at outer edge + adjacent herdr pane → `Ctrl-h/j/k/l` crosses into that pane.
3. Focus on a non-nvim herdr pane (plain shell) → `Ctrl-h/j/k/l` moves herdr panes directly; nothing
   leaks into the shell prompt.
4. Repeat 1–3 for `Ctrl-Alt-h/j/k/l` resize.
5. `prefix+h/j/k/l` still force-moves herdr panes regardless of nvim.
6. `herdr server reload-config` returns empty `diagnostics[]` after config change.
7. nvim launched outside herdr (no `HERDR_ENV`) → `Ctrl-h/j/k/l` behaves as plain nvim split nav, no errors.

## Repository / Packaging

Repo uses GNU Stow; each top-level dir mirrors `$HOME`. Two new stow packages / files:

- **nvim** (existing package): delete `lua/plugins/specs/vim-tmux-navigator.lua`, add
  `lua/plugins/specs/smart-splits.lua` and `lua/smart-splits/mux/herdr.lua`; update the terminal-mode
  maps in `lua/core/keymaps.lua`; update `lazy-lock.json` on install.
- **herdr** (new package `herdr/.config/herdr/`): `config.toml` (currently a hand-written file at
  `~/.config/herdr/config.toml` — bring it under stow) and `scripts/nav.sh`. Follows the existing
  starship-package precedent for `.config/` stow layout. README + CLAUDE.md updated to document it.

## Out of Scope

- herdr tab/workspace navigation (already wired: `alt+1..9`, `alt+left/right`, `rename_tab`).
- `<C-\>` navigate-to-previous-pane — herdr exposes no "last pane" focus command.
- Nested nvim-in-nvim (`:terminal` running nvim) — vim-tmux-navigator has the same known limitation.
- Zoomed-pane nuance beyond reading `layout.zoomed` (no per-direction zoom semantics like tmux).
- Automated tests — this is a cross-process keybinding integration; verification is behavioral.
- Changing the existing `prefix`, split, `focus_pane_*`, or tab keybindings.
