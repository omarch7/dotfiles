# Seamless nvim ↔ herdr Pane Navigation & Resizing — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replicate the current tmux + `vim-tmux-navigator` seamless navigation/resize experience under [herdr](https://herdr.dev) v0.7.1, so bare `Ctrl-h/j/k/l` move and `Ctrl-Alt-h/j/k/l` resize both *within* nvim splits and *across* into adjacent herdr panes.

**Architecture:** Replace `vim-tmux-navigator` with [`smart-splits.nvim`](https://github.com/mrjones2014/smart-splits.nvim) configured with a **custom `herdr` multiplexer backend** (a Lua module shipped in our own config, driving the `herdr` CLI). On the herdr side, bare chords run a shell script (`nav.sh`) that checks whether the focused pane's foreground process is nvim: if so it forwards the key into the pane (nvim's smart-splits handles it, handing back to herdr at the edge); otherwise it moves/resizes the herdr pane directly.

**Tech Stack:** Neovim (Lua), lazy.nvim plugin manager, smart-splits.nvim, herdr CLI (`~/.local/bin/herdr` v0.7.1), Bash + `jq`, GNU Stow.

## Global Constraints

- **Keys are fixed muscle-memory:** move = bare `C-h/j/k/l`; resize = `C-A-h/j/k/l`. Do not change them.
- **`at_edge = 'stop'`** in smart-splits — never `'wrap'`/`'split'`. Verified against `smart-splits/move.lua`: at an edge, `mux.move_pane()` is attempted *first*; only if it returns false does `'stop'` halt. Wrapping inside nvim would defeat crossing the pane boundary.
- **`multiplexer_integration = 'herdr'`** — verified against `smart-splits/mux/init.lua`: `M.get()` does `require('smart-splits.mux.' .. config.multiplexer_integration)` with **no allowlist**, so an arbitrary `'herdr'` string resolves `require('smart-splits.mux.herdr')`. Our `~/.config/nvim/lua` is on `runtimepath`, so shipping the module at `lua/smart-splits/mux/herdr.lua` is found without patching the plugin dir. **A table/function is NOT accepted** — the value must be the string `'herdr'`.
- **Not lazy-loaded:** the mux backend must be resolvable and the integration active at startup (`lazy = false`).
- **herdr direction words are 1:1 with smart-splits:** `left/right/up/down` (no `L/R/U/D` translation, unlike tmux).
- **Fail-safe everywhere:** any non-zero CLI exit or JSON parse failure in the backend returns `false`/`nil` → smart-splits stays in nvim. `mux.move_pane`/`resize_pane` already wrap backend calls in `pcall`.
- **Repo uses GNU Stow.** `nvim/` and `herdr/` are stow packages mirroring `$HOME`. `~/.config/nvim` and `~/.config/herdr/config.toml` are symlinks into this repo — editing the repo file edits the live config.
- **This is a personal repo (`omarch7/dotfiles`), not a HelloFresh org repo** — per the PR-labels policy, do NOT add `tribe:`/`squad:` labels to the PR.
- **No automated test framework exists in this repo** and the spec places automated tests out of scope. Verification is **behavioral**: each task ends with exact manual commands and expected output. Treat those as the task's test gate.

**Reference source (fetched from smart-splits.nvim master during planning):** the built-in `lua/smart-splits/mux/tmux.lua` is the line-for-line model for our backend. `utils.system(cmd_table)` runs `vim.system(cmd, {text=true}):wait()` and returns `(stdout_or_stderr, code)`. `types.Direction` values are the strings `'left'|'right'|'up'|'down'`.

---

## File Structure

**nvim package** (`nvim/.config/nvim/`):
- **Delete** `lua/plugins/specs/vim-tmux-navigator.lua` — the old plugin spec.
- **Create** `lua/plugins/specs/smart-splits.lua` — new plugin spec + all keymaps (move + resize, normal mode).
- **Create** `lua/smart-splits/mux/herdr.lua` — custom multiplexer backend implementing `SmartSplitsMultiplexer`.
- **Modify** `lua/core/keymaps.lua:64-69` — terminal-mode maps: `TmuxNavigate*` → smart-splits.
- **Update** `lazy-lock.json` — pin smart-splits.nvim, drop vim-tmux-navigator (done by `:Lazy` on install).

**herdr package** (`herdr/.config/herdr/`):
- **Create** `scripts/nav.sh` — is-nvim check + forward-or-move helper (one script, args select action/direction/key).
- **Modify** `config.toml` — append 8 `[[keys.command]]` blocks (4 move + 4 resize).

**Docs:**
- **Modify** `README.md` — herdr section: document the nav script + smart-splits backend.
- **Modify** `CLAUDE.md` — note the plugin swap under key components / keybindings.
- **Update** `.superpowers/sdd/progress.md` — new ledger for this plan.

---

## Task 0: Resolve the two load-bearing empirical unknowns (GATE)

The design flags one hard risk and one open detail that must be settled *before* building, because the rest branches on them. This task writes no product code — its deliverable is a recorded decision. Run these **interactively inside a real herdr session** (focus must be in the pane under test).

**Files:**
- Create (scratch, git-ignored): `.superpowers/sdd/task-0-findings.md`

**Interfaces:**
- Produces: `FORWARD_KEY` — the exact string `herdr pane send-keys` needs to deliver a keystroke nvim receives as `<C-h>` (one of `"ctrl+h"`, `"C-h"`, or a raw byte). Consumed by Task 3's `nav.sh` and `config.toml`.
- Produces: `SEND_KEYS_LOOPS` — boolean: does `herdr pane send-keys <pane> <ctrl+h-form>` re-enter herdr's own `ctrl+h` binding? Determines Task 3's architecture.

- [ ] **Step 1: Confirm the send-keys key-name format**

Open a herdr pane, run nvim with two vertical splits (`nvim` then `:vsp`). From *another* pane (or a second shell), inject a key and observe. First find the nvim pane id:

```bash
herdr pane list | jq -r '.result[]? // .result.panes[]? | "\(.pane_id)\t\(.agent // "-")"'
```

Then try each candidate against the nvim pane (replace `<NVIM_PANE>`):

```bash
herdr pane send-keys <NVIM_PANE> ctrl+h   # candidate A
herdr pane send-keys <NVIM_PANE> C-h      # candidate B
```

Expected: exactly one form makes nvim move the cursor to the left split (or, if nvim maps aren't installed yet, produces `<C-h>` visibly via `:map <C-h>` / insert-mode `^H`). Record the working form as `FORWARD_KEY`. Repeat for `j/k/l` and the `ctrl+alt+*` resize chords to confirm the same pattern holds (e.g. `ctrl+alt+h`).

- [ ] **Step 2: Test the send-keys re-entry loop (THE risk)**

Add a temporary logging command to `herdr/.config/herdr/config.toml`, reload, and press `ctrl+h` once with focus in a **plain shell** pane (not nvim):

```toml
[[keys.command]]
key = "ctrl+h"
type = "shell"
command = "sh -c 'echo hit $(date +%s%N) >> /tmp/herdr-loop-test.log; herdr pane send-keys $HERDR_ACTIVE_PANE_ID ctrl+h'"
```

```bash
: > /tmp/herdr-loop-test.log
herdr server reload-config | jq '.result.diagnostics // .diagnostics'   # expect [] (empty)
# focus a plain shell pane, press Ctrl-h ONCE, then:
wc -l /tmp/herdr-loop-test.log
```

Expected (no loop): `1`. If it climbs (2, 3, …) or the log explodes, `SEND_KEYS_LOOPS = true`.

- [ ] **Step 3: Record the decision and remove the temp binding**

Write `.superpowers/sdd/task-0-findings.md` with `FORWARD_KEY`, `SEND_KEYS_LOOPS`, and the chosen Task-3 architecture:
- **If `SEND_KEYS_LOOPS = false` (expected):** Task 3 proceeds as written — `nav.sh` forwards `FORWARD_KEY` into nvim panes, moves herdr panes for non-nvim panes.
- **If `SEND_KEYS_LOOPS = true`:** switch Task 3 to **mitigation (a)** — herdr binds the chords **only to act on non-nvim panes**; for nvim panes the herdr command does nothing and lets nvim's own `<C-h>` (which reaches the pty below the binding layer) drive smart-splits directly. Concretely, `nav.sh` returns early (exit 0, no send-keys) when the foreground is nvim. This requires nvim to receive `C-h` even though herdr bound it — verify by pressing `C-h` in nvim after the early-return binding is live; if nvim does NOT receive it, fall back to **mitigation (b)**: forward a sentinel keycode nvim maps but herdr doesn't bind.

Remove the temporary binding from `config.toml` and reload:

```bash
herdr server reload-config | jq '.result.diagnostics // .diagnostics'   # expect []
```

- [ ] **Step 4: Commit the findings**

```bash
git add docs/superpowers/plans/2026-07-06-nvim-herdr-navigation.md
git commit -m "docs(herdr): add nvim navigation implementation plan

Turns the approved design into a task-by-task plan; records Task 0
send-keys/loop findings feed Task 3.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

(`.superpowers/` is git-ignored, so `task-0-findings.md` is not committed — that is intentional.)

---

## Task 1: Swap nvim plugin (vim-tmux-navigator → smart-splits), keep keys

Delivers working intra-nvim split navigation + resize with the same keys, verifiable **standalone** (outside herdr). No herdr crossing yet — that is Task 2.

**Files:**
- Delete: `nvim/.config/nvim/lua/plugins/specs/vim-tmux-navigator.lua`
- Create: `nvim/.config/nvim/lua/plugins/specs/smart-splits.lua`
- Modify: `nvim/.config/nvim/lua/core/keymaps.lua:64-69`
- Update: `nvim/.config/nvim/lazy-lock.json` (via `:Lazy`)

**Interfaces:**
- Consumes: nothing.
- Produces: a loaded `smart-splits.nvim` with `multiplexer_integration = 'herdr'` and `at_edge = 'stop'`; normal-mode maps `<C-h/j/k/l>` → `move_cursor_{left,down,up,right}` and `<C-A-h/j/k/l>` → `resize_{left,down,up,right}`. Task 2 supplies the `smart-splits.mux.herdr` module these look up at edges.

- [ ] **Step 1: Create the smart-splits plugin spec**

Create `nvim/.config/nvim/lua/plugins/specs/smart-splits.lua`:

```lua
return {
  {
    "mrjones2014/smart-splits.nvim",
    -- Not lazy: the herdr mux backend must be resolvable and the multiplexer
    -- integration active at startup (matches smart-splits' guidance for mux use).
    lazy = false,
    opts = {
      at_edge = "stop",                  -- hand off to herdr at the edge; never wrap inside nvim
      multiplexer_integration = "herdr", -- loads lua/smart-splits/mux/herdr.lua from our runtimepath
    },
    config = function(_, opts)
      require("smart-splits").setup(opts)
      local ss = require("smart-splits")
      local map = vim.keymap.set
      -- move (normal mode) — mirrors the old vim-tmux-navigator C-h/j/k/l
      map("n", "<C-h>", ss.move_cursor_left,  { silent = true, desc = "Move to left split / herdr pane" })
      map("n", "<C-j>", ss.move_cursor_down,  { silent = true, desc = "Move to below split / herdr pane" })
      map("n", "<C-k>", ss.move_cursor_up,    { silent = true, desc = "Move to above split / herdr pane" })
      map("n", "<C-l>", ss.move_cursor_right, { silent = true, desc = "Move to right split / herdr pane" })
      -- resize (normal mode)
      map("n", "<C-A-h>", ss.resize_left,  { silent = true, desc = "Resize split left" })
      map("n", "<C-A-j>", ss.resize_down,  { silent = true, desc = "Resize split down" })
      map("n", "<C-A-k>", ss.resize_up,    { silent = true, desc = "Resize split up" })
      map("n", "<C-A-l>", ss.resize_right, { silent = true, desc = "Resize split right" })
    end,
  },
}
```

- [ ] **Step 2: Update the terminal-mode maps in keymaps.lua**

In `nvim/.config/nvim/lua/core/keymaps.lua`, replace the block at lines 64-69 (the `-- Tmux Navigator mappings` section). `<C-\>` (navigate-previous) is dropped — herdr has no "last pane" focus command (spec: Out of Scope). Terminal-mode navigation leaves insert with `<C-\><C-n>` first, then calls smart-splits:

```lua
-- Smart-splits navigation (terminal mode): leave terminal-insert, then move
keymap("t", "<C-h>", [[<C-\><C-n><Cmd>lua require('smart-splits').move_cursor_left()<CR>]],  { noremap = true, silent = true, desc = "Move to left split / herdr pane" })
keymap("t", "<C-j>", [[<C-\><C-n><Cmd>lua require('smart-splits').move_cursor_down()<CR>]],  { noremap = true, silent = true, desc = "Move to below split / herdr pane" })
keymap("t", "<C-k>", [[<C-\><C-n><Cmd>lua require('smart-splits').move_cursor_up()<CR>]],    { noremap = true, silent = true, desc = "Move to above split / herdr pane" })
keymap("t", "<C-l>", [[<C-\><C-n><Cmd>lua require('smart-splits').move_cursor_right()<CR>]], { noremap = true, silent = true, desc = "Move to right split / herdr pane" })
```

- [ ] **Step 3: Delete the old plugin spec**

```bash
git rm nvim/.config/nvim/lua/plugins/specs/vim-tmux-navigator.lua
```

- [ ] **Step 4: Install the plugin and update the lock file**

Launch nvim; lazy.nvim installs smart-splits and removes vim-tmux-navigator. Sync + regenerate the lock:

```bash
nvim --headless "+Lazy! sync" +qa
```

Expected: no errors; `nvim/.config/nvim/lazy-lock.json` now contains a `smart-splits.nvim` entry and no `vim-tmux-navigator` entry:

```bash
grep -E 'smart-splits|tmux-navigator' nvim/.config/nvim/lazy-lock.json
```

Expected: one `smart-splits.nvim` line, zero `vim-tmux-navigator` lines.

- [ ] **Step 5: Verify the backend is wired (health) and no load errors**

```bash
nvim --headless "+lua print(vim.fn.executable('herdr'))" +qa
```

Expected: prints `1` (herdr is on nvim's `$PATH`). If it prints `0`, the backend's `utils.system` would `error()` (caught by mux's pcall → fails safe, but nav won't work). Fix by ensuring `~/.local/bin` is on `$PATH` for GUI-launched nvim before continuing.

```bash
nvim --headless "+lua require('smart-splits'); print('ss ok')" +qa
```

Expected: prints `ss ok` with no stack trace.

- [ ] **Step 6: Behavioral check — intra-nvim splits (standalone)**

Open nvim, create splits (`:vsp` then `:sp`), and verify with the real keys:
- `C-h/j/k/l` move the cursor between nvim splits.
- At the outermost split with no herdr backend resolved yet (Task 2 not done) it simply stops (no error, no wrap) — `at_edge = 'stop'`.
- `C-A-h/j/k/l` resize the focused split.

Expected: all four moves and four resizes work; no errors in `:messages`.

- [ ] **Step 7: Commit**

```bash
git add nvim/.config/nvim/lua/plugins/specs/smart-splits.lua \
        nvim/.config/nvim/lua/core/keymaps.lua \
        nvim/.config/nvim/lazy-lock.json
git commit -m "feat(nvim): swap vim-tmux-navigator for smart-splits.nvim

Keeps C-h/j/k/l move + C-A-h/j/k/l resize; sets at_edge='stop' and
multiplexer_integration='herdr' for the custom backend (added next).
Drops C-\\ navigate-previous (no herdr last-pane command).

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Custom `herdr` multiplexer backend

Delivers crossing from nvim's edge into an adjacent herdr pane (and resize spilling into herdr). Verifiable inside a herdr session.

**Files:**
- Create: `nvim/.config/nvim/lua/smart-splits/mux/herdr.lua`

**Interfaces:**
- Consumes: `smart-splits.types` (`Direction` strings), `smart-splits.utils` (`.system(cmd_table) -> (text, code)`). Config `multiplexer_integration = 'herdr'` from Task 1 makes `require('smart-splits.mux').get()` load this module.
- Produces: a module implementing `SmartSplitsMultiplexer`: `is_in_session()`, `current_pane_id()`, `current_pane_at_edge(dir)`, `next_pane(dir)`, `resize_pane(dir, amount)`, `current_pane_is_zoomed()`, `split_pane(dir, size)`, `update_mux_layout_details()`, field `type='herdr'`.

- [ ] **Step 1: Create the backend module**

Create `nvim/.config/nvim/lua/smart-splits/mux/herdr.lua`. JSON shapes below are verified against `herdr` v0.7.1 (`pane edges --current` → `.result.edges.{left,right,up,down}` bools + `.result.edges.layout.zoomed`; `pane focus/resize` exit 0 on success):

```lua
-- Custom smart-splits.nvim multiplexer backend for herdr (https://herdr.dev).
-- Resolved by smart-splits via require('smart-splits.mux.herdr') when
-- `multiplexer_integration = 'herdr'`. Our nvim config's lua/ dir is on
-- 'runtimepath', so this is found without patching the plugin. Modeled on the
-- built-in smart-splits/mux/tmux.lua. herdr direction words match smart-splits
-- (left/right/up/down) 1:1, so no translation table is needed.
--
-- Fail-safe: any non-zero exit / JSON parse failure returns false/nil, which
-- smart-splits treats as "stay in nvim". (mux.move_pane/resize_pane also pcall.)

local types = require("smart-splits.types")
local Direction = types.Direction
local utils = require("smart-splits.utils")

---Run a herdr CLI command; return its decoded `.result` table (or nil) and exit code.
---@param args string[]
---@return table|nil result, integer code
local function herdr_json(args)
  local cmd = vim.list_extend({ "herdr" }, args)
  local text, code = utils.system(cmd)
  if code ~= 0 or not text or #text == 0 then
    return nil, code
  end
  local ok, decoded = pcall(vim.json.decode, text)
  if not ok or type(decoded) ~= "table" then
    return nil, code
  end
  return decoded.result, code
end

---@type SmartSplitsMultiplexer
local M = {} ---@diagnostic disable-line: missing-fields

M.type = "herdr" ---@diagnostic disable-line: assign-type-mismatch

function M.is_in_session()
  local pane = vim.env.HERDR_PANE_ID
  return vim.env.HERDR_ENV == "1" and pane ~= nil and #pane > 0
end

-- Returns the *static* pane id from the environment (no CLI call). This is
-- correct ONLY with at_edge='stop': smart-splits' move_multiplexer_inner()
-- compares this id before/after next_pane() to detect a move, but under 'stop'
-- that return value is never used for a wrap-back -- the real gate is
-- current_pane_at_edge(). If at_edge is ever changed to 'wrap', switch this to
-- read `.result.edges.layout.focused_pane_id` so before/after differs.
function M.current_pane_id()
  return vim.env.HERDR_PANE_ID
end

function M.current_pane_at_edge(direction)
  if not M.is_in_session() then
    return false
  end
  local result = herdr_json({ "pane", "edges", "--current" })
  if not result or type(result.edges) ~= "table" then
    return false
  end
  return result.edges[direction] == true
end

function M.next_pane(direction)
  if not M.is_in_session() then
    return false
  end
  local _, code = herdr_json({ "pane", "focus", "--direction", direction, "--current" })
  return code == 0
end

function M.resize_pane(direction, amount)
  if not M.is_in_session() then
    return false
  end
  local _, code = herdr_json({
    "pane", "resize", "--direction", direction, "--amount", tostring(amount), "--current",
  })
  return code == 0
end

function M.current_pane_is_zoomed()
  local result = herdr_json({ "pane", "edges", "--current" })
  if not result or type(result.edges) ~= "table" or type(result.edges.layout) ~= "table" then
    return false
  end
  return result.edges.layout.zoomed == true
end

function M.split_pane(direction, size)
  -- Not exercised by nav/resize with at_edge='stop'. Best-effort: herdr only
  -- splits right|down, so map left->right and up->down.
  local herdr_dir = (direction == Direction.left or direction == Direction.right) and "right" or "down"
  local args = { "pane", "split", "--current", "--direction", herdr_dir }
  if size then
    vim.list_extend(args, { "--ratio", tostring(size) })
  end
  local _, code = herdr_json(args)
  return code == 0
end

function M.update_mux_layout_details()
  -- No cached layout: edges are queried live on each call. Nothing to do.
end

return M
```

- [ ] **Step 2: Verify the backend resolves and reports the session**

Inside a herdr pane, run nvim and check:

```vim
:lua =require('smart-splits.mux').get().type
```

Expected: `herdr`.

```vim
:lua =require('smart-splits.mux').get().is_in_session()
```

Expected: `true` (when launched inside herdr). Launch nvim **outside** herdr and expect `false` (or `get()` non-nil but `is_in_session()` false) — no errors either way.

- [ ] **Step 3: Verify edge detection matches the live layout**

With nvim in a herdr pane that has a pane to its right but not its left:

```vim
:lua =require('smart-splits.mux').get().current_pane_at_edge('left')
:lua =require('smart-splits.mux').get().current_pane_at_edge('right')
```

Expected: `left` → `true`, `right` → `false` (mirrors `herdr pane edges --current`). Cross-check:

```bash
herdr pane edges --current | jq '.result.edges | {left,right,up,down}'
```

- [ ] **Step 4: Behavioral check — nvim edge crosses into herdr pane**

Set up: one herdr pane split into two (nvim on the left, anything on the right). In nvim, `:vsp` so there are two nvim splits.
- From the left nvim split, `C-l` moves to the right nvim split (intra-nvim).
- From the right nvim split (nvim's right edge, `current_pane_at_edge('right')` true only if no further nvim split), `C-l` **crosses into the right herdr pane**.
- `C-h` from the leftmost nvim split, when the pane is at herdr's left edge, stops (stays in nvim).
- `C-A-l` at the nvim right edge resizes across the herdr split boundary.

Expected: focus crosses exactly at the nvim edge; interior moves stay in nvim; no error in `:messages`.

Note (by design): with `current_pane_id()` static, `mux.move_pane()` returns `false` even when the herdr focus *did* move; move.lua then hits the `at_edge='stop'` return. Net effect is correct — focus has already left nvim. This is why `at_edge` MUST stay `'stop'`.

- [ ] **Step 5: Commit**

```bash
git add nvim/.config/nvim/lua/smart-splits/mux/herdr.lua
git commit -m "feat(nvim): add herdr multiplexer backend for smart-splits

Implements SmartSplitsMultiplexer against the herdr CLI (pane
edges/focus/resize). Lives in our config's lua/ so it resolves via
require('smart-splits.mux.herdr') without patching the plugin. Fails
safe to 'stay in nvim' on any CLI/JSON error.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: herdr side — is-nvim check + keybindings

Delivers the other half: bare chords owned by herdr that forward into nvim panes or move/resize herdr panes for non-nvim panes. **Branch on Task 0's `SEND_KEYS_LOOPS` result** (steps below assume the expected `false`; if `true`, apply the Task-0 mitigation to `nav.sh`). Uses `FORWARD_KEY` from Task 0 (shown as `ctrl+h` etc. below — substitute the confirmed form).

**Files:**
- Create: `herdr/.config/herdr/scripts/nav.sh`
- Modify: `herdr/.config/herdr/config.toml`

**Interfaces:**
- Consumes: `FORWARD_KEY` and `SEND_KEYS_LOOPS` from Task 0; the nvim-side backend from Task 2 (which handles the key once forwarded).
- Produces: 8 bare-chord bindings (`ctrl+h/j/k/l` move, `ctrl+alt+h/j/k/l` resize) routed through `nav.sh`.

- [ ] **Step 1: Create nav.sh**

Create `herdr/.config/herdr/scripts/nav.sh` (make executable in the next step):

```bash
#!/usr/bin/env bash
# Seamless nvim <-> herdr pane navigation/resize, herdr side.
# Bound to bare ctrl+h/j/k/l (move) and ctrl+alt+h/j/k/l (resize) in config.toml.
#
# Usage: nav.sh <action> <direction> <forward_key> [amount]
#   action      : focus | resize
#   direction   : left | right | up | down
#   forward_key : key string sent into nvim (Task 0 FORWARD_KEY, e.g. ctrl+h)
#   amount      : resize ratio for herdr (FLOAT); default 0.05, ignored for focus
#
# If the focused pane's foreground process is (n)vim, forward the key so nvim's
# smart-splits handles it (and crosses back to herdr at the edge via the mux
# backend). Otherwise act on the herdr pane directly.
set -euo pipefail

action="$1"
direction="$2"
forward_key="${3:-}"
amount="${4:-0.05}"
pane="${HERDR_ACTIVE_PANE_ID:?HERDR_ACTIVE_PANE_ID not set}"

foreground_is_vim() {
  herdr pane process-info --pane "$pane" 2>/dev/null \
    | jq -e '[.result.process_info.foreground_processes[]?.name]
             | any(test("(^|/)n?vim$"; "i"))' >/dev/null 2>&1
}

if [ -n "$forward_key" ] && foreground_is_vim; then
  exec herdr pane send-keys "$pane" "$forward_key"
fi

if [ "$action" = "resize" ]; then
  exec herdr pane resize --direction "$direction" --amount "$amount" --pane "$pane"
else
  exec herdr pane focus --direction "$direction" --pane "$pane"
fi
```

> **If Task 0 found `SEND_KEYS_LOOPS = true`:** replace the forward block with an early no-op for nvim panes, so nvim's own `<C-h>` (reaching the pty below the binding layer) drives smart-splits:
> ```bash
> if foreground_is_vim; then exit 0; fi   # let nvim handle its own C-h; herdr only moves non-nvim panes
> ```

- [ ] **Step 2: Make nav.sh executable**

```bash
chmod +x herdr/.config/herdr/scripts/nav.sh
```

Verify:

```bash
test -x herdr/.config/herdr/scripts/nav.sh && echo "executable ok"
```

Expected: `executable ok`.

- [ ] **Step 3: Append the keybindings to config.toml**

Append to `herdr/.config/herdr/config.toml` (below the existing `rename_tab` line). Substitute the Task-0 `FORWARD_KEY` form if it is not `ctrl+*`:

```toml
# --- Seamless nvim <-> herdr pane navigation (smart-splits.nvim) ---
# Bare ctrl+h/j/k/l move; nav.sh forwards to nvim when it is the focused pane's
# foreground process, else moves the herdr pane directly. prefix+h/j/k/l above
# remains the always-move-the-pane escape hatch.
[[keys.command]]
key = "ctrl+h"
type = "shell"
command = "~/.config/herdr/scripts/nav.sh focus left ctrl+h"

[[keys.command]]
key = "ctrl+j"
type = "shell"
command = "~/.config/herdr/scripts/nav.sh focus down ctrl+j"

[[keys.command]]
key = "ctrl+k"
type = "shell"
command = "~/.config/herdr/scripts/nav.sh focus up ctrl+k"

[[keys.command]]
key = "ctrl+l"
type = "shell"
command = "~/.config/herdr/scripts/nav.sh focus right ctrl+l"

# Resize: ctrl+alt+h/j/k/l
[[keys.command]]
key = "ctrl+alt+h"
type = "shell"
command = "~/.config/herdr/scripts/nav.sh resize left ctrl+alt+h"

[[keys.command]]
key = "ctrl+alt+j"
type = "shell"
command = "~/.config/herdr/scripts/nav.sh resize down ctrl+alt+j"

[[keys.command]]
key = "ctrl+alt+k"
type = "shell"
command = "~/.config/herdr/scripts/nav.sh resize up ctrl+alt+k"

[[keys.command]]
key = "ctrl+alt+l"
type = "shell"
command = "~/.config/herdr/scripts/nav.sh resize right ctrl+alt+l"
```

- [ ] **Step 4: Reload config and verify zero diagnostics**

The config file is symlinked into `~/.config/herdr/` via stow, so editing the repo file edits the live config. Reload:

```bash
herdr server reload-config | jq '.result.diagnostics // .diagnostics'
```

Expected: `[]` (empty). A non-empty array means a binding was rejected and the reload is *partial* — fix the reported binding (likely a `key`/`type`/`command` field-name or key-syntax mismatch) before proceeding. If `[[keys.command]]` fields differ from what herdr accepts, adjust to the reported schema and reload again.

- [ ] **Step 5: Behavioral check — non-nvim pane and forwarding**

- Focus a **plain shell** pane with a shell pane to its right → `C-l` moves the herdr focus right; nothing leaks into the prompt.
- Focus an **nvim** pane → `C-h/j/k/l` navigate nvim splits and cross into herdr panes at the edge (Task 2 behavior, now driven through herdr's binding).
- `C-A-h/j/k/l` in a plain shell pane resizes the herdr pane; in nvim resizes splits then herdr at the edge.
- `prefix+h/j/k/l` still force-moves herdr panes regardless of foreground process.

Expected: all of the above; no keystroke leaks into non-nvim apps; no runaway (confirms Task 0 loop finding holds in practice).

- [ ] **Step 6: Commit**

```bash
git add herdr/.config/herdr/scripts/nav.sh herdr/.config/herdr/config.toml
git commit -m "feat(herdr): bind C-hjkl nav/resize with is-nvim forwarding

nav.sh forwards the chord into nvim when the focused pane runs (n)vim,
else moves/resizes the herdr pane directly. Bare ctrl+h/j/k/l move and
ctrl+alt+h/j/k/l resize; prefix+hjkl stays as the force-move escape hatch.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Documentation + progress ledger

Delivers the repo docs the spec requires updated, plus the SDD ledger.

**Files:**
- Modify: `README.md` (herdr section ~line 278-294)
- Modify: `CLAUDE.md` (Navigation & keybindings)
- Update: `.superpowers/sdd/progress.md`

**Interfaces:**
- Consumes: the shipped nav feature. Produces: nothing downstream.

- [ ] **Step 1: Update README.md herdr section**

In `README.md`, extend the `## Herdr Configuration` section. Update the **Structure** block to include the script, and add a bullet describing seamless nav:

```
herdr/.config/herdr/
├── config.toml         # Herdr keybindings
└── scripts/
    └── nav.sh          # nvim <-> herdr seamless navigation/resize helper
```

Add under **Key Features**:

```markdown
- **Seamless nvim ↔ pane navigation**: bare `Ctrl-h/j/k/l` move and
  `Ctrl-Alt-h/j/k/l` resize both within Neovim splits and across into adjacent
  Herdr panes. `scripts/nav.sh` checks the focused pane's foreground process: if
  it is `(n)vim` the chord is forwarded into the pane (handled by
  [smart-splits.nvim](https://github.com/mrjones2014/smart-splits.nvim) via a
  custom `herdr` multiplexer backend at `nvim/.config/nvim/lua/smart-splits/mux/herdr.lua`);
  otherwise Herdr moves/resizes the pane directly. `prefix+h/j/k/l` remains the
  always-move escape hatch.
```

- [ ] **Step 2: Update CLAUDE.md**

In `/Users/oc/dotfiles/CLAUDE.md`, under **Navigation & Productivity** (or Key Components), note the swap so future sessions have the context:

```markdown
7. **Navigation & Productivity**:
   - Telescope for fuzzy finding and navigation
   - NvimTree for file browsing
   - smart-splits.nvim for split/pane navigation and resizing, with a custom
     `herdr` multiplexer backend (`lua/smart-splits/mux/herdr.lua`) for seamless
     nvim ↔ herdr pane movement (`C-h/j/k/l` move, `C-A-h/j/k/l` resize).
     Replaces vim-tmux-navigator.
```

- [ ] **Step 3: Update the SDD progress ledger**

Overwrite `.superpowers/sdd/progress.md`:

```markdown
# SDD Progress Ledger

Plan: docs/superpowers/plans/2026-07-06-nvim-herdr-navigation.md
Started: 2026-07-06

## Tasks

Task 0: <status> — send-keys FORWARD_KEY=<value>, SEND_KEYS_LOOPS=<bool>
Task 1: <status> — plugin swap (smart-splits, keymaps, lazy-lock)
Task 2: <status> — herdr mux backend
Task 3: <status> — herdr nav.sh + config.toml bindings
Task 4: <status> — docs
```

- [ ] **Step 4: Commit**

```bash
git add README.md CLAUDE.md
git commit -m "docs: document smart-splits herdr navigation

README herdr section gains the nav.sh script + seamless-nav feature;
CLAUDE.md notes the vim-tmux-navigator -> smart-splits swap.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Final Verification (whole spec, behavioral)

Run the spec's test matrix end-to-end in a real herdr session (all must pass):

1. ≥2 nvim splits in one herdr pane → `Ctrl-h/j/k/l` moves between nvim splits, never leaves the pane.
2. nvim at outer edge + adjacent herdr pane → `Ctrl-h/j/k/l` crosses into that pane.
3. Focus a non-nvim herdr pane (plain shell) → `Ctrl-h/j/k/l` moves herdr panes directly; nothing leaks into the prompt.
4. Repeat 1–3 for `Ctrl-Alt-h/j/k/l` resize.
5. `prefix+h/j/k/l` still force-moves herdr panes regardless of nvim.
6. `herdr server reload-config` returns empty `diagnostics[]`.
7. nvim launched outside herdr (no `HERDR_ENV`) → `Ctrl-h/j/k/l` behaves as plain nvim split nav, no errors.

Then finish the branch per superpowers:finishing-a-development-branch (branch `patch/herdr-config-stow` already exists). **PR: no `tribe:`/`squad:` labels** — this is a personal repo, not a HelloFresh org repo.

---

## Self-Review (against the spec)

**Spec coverage:**
- Component 1 (swap plugin, keep keys) → Task 1. ✓
- Component 2 (herdr mux backend) → Task 2. ✓ (module path/resolution verified against `mux/init.lua`; the spec's shadowing-fallback is unnecessary — confirmed no allowlist.)
- Component 3 (is-nvim check + keybindings) → Task 3. ✓
- "Key open risk" (send-keys re-entry loop) → Task 0 (gate) + Task 3 branch. ✓
- Data-flow, error handling → encoded in backend fail-safe + nav.sh fallbacks. ✓
- Testing matrix → Final Verification. ✓
- Repository/Packaging (stow, two packages) → files placed in `nvim/` and `herdr/` packages; README/CLAUDE.md → Task 4. ✓
- Out of scope (`<C-\>`, tabs, nested nvim, zoom nuance, automated tests) → respected; `<C-\>` explicitly dropped in Task 1 Step 2. ✓

**Placeholder scan:** No TBD/TODO. `FORWARD_KEY`/`SEND_KEYS_LOOPS` are deliberately produced by Task 0 and consumed by Task 3 — real interface values, not placeholders; the default `ctrl+h` form is shown concretely.

**Type/name consistency:** Backend function names, `Direction` string values, `utils.system` return contract, and JSON paths (`.result.edges.{dir}`, `.result.edges.layout.zoomed`, `.result.process_info.foreground_processes[].name`) all match the fetched smart-splits source and probed herdr v0.7.1 output. `at_edge='stop'` + static `current_pane_id()` interaction is verified against `move.lua`/`mux/init.lua` and documented at both sites.
