# Interactive Runbook — nvim ↔ herdr Navigation (human-run steps)

Both the nvim side (Tasks 1, 2, 4) and the herdr side (Task 3) are implemented, reviewed,
and committed on branch `patch/herdr-config-stow`. These steps need a **live herdr + nvim
session** to *verify* the shipped feature and cannot be run headless. Do them in order; each
says exactly what to type and what you should see.

Full detail lives in `docs/superpowers/plans/2026-07-06-nvim-herdr-navigation.md`
(Task 0 is the empirical verification gate). This is the condensed operator's version.

---

## Prereq: pick up the branch's nvim changes

The plugin was installed headlessly during implementation, but restart nvim once so the
new spec + backend load cleanly in your real session.

```bash
nvim --headless "+Lazy! sync" +qa   # ensure smart-splits is present, vim-tmux-navigator gone
grep -c smart-splits nvim/.config/nvim/lazy-lock.json   # expect >= 1
```

---

## STEP A — Task 0.1: confirm the send-keys key format  (produces FORWARD_KEY)

Open a herdr pane, launch nvim, `:vsp` for two splits. From another shell, find the nvim pane:

```bash
herdr pane list | jq -r '.result[]? // .result.panes[]? | "\(.pane_id)\t\(.agent // "-")"'
```

Try each candidate against the nvim pane (replace `<NVIM_PANE>`):

```bash
herdr pane send-keys <NVIM_PANE> ctrl+h   # candidate A
herdr pane send-keys <NVIM_PANE> C-h      # candidate B
```

**Watch nvim:** whichever form moves the cursor to the left split is your `FORWARD_KEY`.
Confirm the same form works for `j/k/l` and for the resize chords (`ctrl+alt+h` etc).
→ Record `FORWARD_KEY` (expected: `ctrl+h`).

## STEP B — Task 0.2: the loop test (produces SEND_KEYS_LOOPS)  ⚠️ the key risk

Temporarily add to `herdr/.config/herdr/config.toml` (it's stowed → edits are live):

```toml
[[keys.command]]
key = "ctrl+h"
type = "shell"
command = "sh -c 'echo hit >> /tmp/herdr-loop-test.log; herdr pane send-keys $HERDR_ACTIVE_PANE_ID ctrl+h'"
```

```bash
: > /tmp/herdr-loop-test.log
herdr server reload-config | jq '.result.diagnostics // .diagnostics'   # expect []
# focus a PLAIN SHELL pane, press Ctrl-h ONCE, then:
wc -l /tmp/herdr-loop-test.log
```

- Result `1` → **no loop** (`SEND_KEYS_LOOPS=false`, expected). Proceed with STEP D as written.
- Result climbing (2,3,…) → **loops** (`SEND_KEYS_LOOPS=true`). Use the STEP D mitigation variant.

Now **remove that temp binding** from `config.toml` and reload:

```bash
herdr server reload-config | jq '.result.diagnostics // .diagnostics'   # expect []
```

---

## STEP C — verify the nvim side already works (Task 1 Step 6 + Task 2 Step 4)

Inside a herdr pane running nvim:

1. `:vsp` and `:sp` → **`C-h/j/k/l`** move between nvim splits; at the outer edge with no
   herdr backend yet reachable it just stops (no error, no wrap). Check `:messages` is clean.
2. Backend sanity:
   - `:lua =require('smart-splits.mux').get().type` → `herdr`
   - `:lua =require('smart-splits.mux').get().is_in_session()` → `true`
3. With a herdr pane to nvim's right and nvim at its rightmost split → **`C-l` crosses into the
   herdr pane**. `C-h` at nvim's leftmost split (when the herdr pane is at herdr's left edge) stops.
4. **`C-A-l`** at nvim's right edge resizes across the herdr boundary. Confirm the step size feels
   like ~5% (the resize-ratio fix, commit 180943c) — not a huge jump.
   `C-A-h/j/k/l` inside nvim resize the nvim split normally (step of 3 cells).

If all pass, the shipped nvim side is verified.

---

## STEP D — Task 3: herdr-side script + bindings (already implemented)

Task 3 is now **committed on this branch** (`herdr/.config/herdr/scripts/nav.sh` + the 8
`[[keys.command]]` blocks in `config.toml`). No files to create — these steps are just to
verify the shipped artifacts load and behave. The `send-keys` re-entrancy risk from STEP B
was verified safe (see the `nav.sh` header comment), so the forwarding variant is in use.

The nvim backend and `nav.sh` both use a 0.05 resize ratio so cross-boundary and direct
resize match (see the resize-ratio fix rationale).

**D1. Confirm both artifacts are present and stowed live:**

```bash
test -x herdr/.config/herdr/scripts/nav.sh && echo "nav.sh present + executable"
grep -c 'nav.sh' herdr/.config/herdr/config.toml   # expect 8 (focus + resize x h/j/k/l)
```

**D2. Reload and verify zero diagnostics:**

```bash
herdr server reload-config | jq '.result.diagnostics // .diagnostics'   # MUST be []
```

A non-empty array = a rejected binding (partial reload). Fix the reported field/key and reload again.

---

## STEP E — Final behavioral matrix (whole feature)

All must pass in a real herdr session:

1. ≥2 nvim splits in one pane → `C-h/j/k/l` moves between splits, never leaves the pane.
2. nvim at outer edge + adjacent herdr pane → `C-h/j/k/l` crosses into it.
3. Plain-shell herdr pane → `C-h/j/k/l` moves herdr panes; nothing leaks into the prompt.
4. Repeat 1–3 for `C-A-h/j/k/l` resize (steps feel consistent across the boundary).
5. `prefix+h/j/k/l` still force-moves herdr panes regardless of nvim.
6. `herdr server reload-config` → empty `diagnostics[]`.
7. nvim launched OUTSIDE herdr → `C-h/j/k/l` = plain split nav, no errors.

---

## STEP F — finish + PR (already open)

Branch `patch/herdr-config-stow` is pushed and PR #86 is open. Once STEP E passes in a real
session, drop the confirmation in the PR's test-plan checklist and merge.

**PR labels: do NOT add `tribe:`/`squad:`** — this is the personal `omarch7/dotfiles` repo,
not a HelloFresh org repo (per your label policy).
