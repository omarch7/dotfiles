#!/usr/bin/env bash
# Seamless nvim <-> herdr pane navigation/resize, herdr side.
# Bound to bare ctrl+h/j/k/l (move) and ctrl+alt+h/j/k/l (resize) in config.toml.
#
# Usage: nav.sh <action> <direction> <forward_key> [amount]
#   action      : focus | resize
#   direction   : left | right | up | down
#   forward_key : key string sent into nvim (verified FORWARD_KEY, e.g. ctrl+h)
#   amount      : resize ratio for herdr (FLOAT); default 0.05, ignored for focus
#
# If the focused pane's foreground process is (n)vim, forward the key so nvim's
# smart-splits handles it (moving between nvim splits, and crossing back into
# herdr at the edge via the mux backend). Otherwise act on the herdr pane
# directly. Verified: herdr `send-keys` writes below the keybinding layer, so
# forwarding ctrl+h does NOT re-trigger this binding (no loop).
#
# Debug: set HERDR_NAV_DEBUG=1 in the herdr environment to append a trace line
# to /tmp/herdr-nav.log on every invocation (the only signal available, since
# keybindings can't be triggered programmatically).
set -euo pipefail

action="${1:?usage: nav.sh <focus|resize> <direction> [forward_key] [amount]}"
direction="${2:?missing direction}"
forward_key="${3:-}"
amount="${4:-0.05}"

# Resolve the pane the key was pressed in. herdr exports HERDR_ACTIVE_PANE_ID to
# command processes; fall back to querying the focused pane if it is absent, so
# nav.sh does not hard-fail on an env-var name change across herdr versions.
pane="${HERDR_ACTIVE_PANE_ID:-}"
if [ -z "$pane" ]; then
  # `|| pane=""` keeps set -e/pipefail from aborting here if `herdr pane list`
  # fails (daemon down, CLI error): fall through to the graceful exit below.
  pane="$(herdr pane list 2>/dev/null \
    | jq -r '.result.panes[] | select(.focused==true) | .pane_id' 2>/dev/null \
    | head -n1)" || pane=""
fi

if [ -n "${HERDR_NAV_DEBUG:-}" ]; then
  echo "action=$action dir=$direction key=$forward_key pane=$pane" >> /tmp/herdr-nav.log
fi

# No target pane resolved: nothing safe to do.
[ -n "$pane" ] || exit 0

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
