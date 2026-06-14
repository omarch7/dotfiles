#!/usr/bin/env bash
# Reflect this Claude Code session's state on its tmux pane + window.
#
# Usage: claude-tmux-state.sh <attention|running|idle>
#   attention -> Claude needs a DECISION (permission prompt)      -> red
#   running   -> Claude is actively working                       -> yellow
#   idle      -> Claude is done / session start / waiting         -> no color
#
# The Notification event (mapped to `attention`) fires for BOTH permission
# prompts AND idle "waiting for your input" nudges. Only a permission prompt is
# a real decision, so for `attention` we read notification_type from the hook
# payload on stdin and downgrade anything that isn't a permission_prompt to
# idle — otherwise an idle session wrongly turns red.
#
# Pane state is stored in @claude_state; the window aggregates its panes into
# @claude_win (attention > running > idle), so a window's number colors by the
# highest-priority pane it contains.
#
# Guard: tmux's `set-option -p` SILENTLY falls back to the globally-active pane
# when $TMUX_PANE is empty/unset or points to another tmux server (background
# tasks, agent teammates, detached worktrees). We only act when $TMUX_PANE
# round-trips to itself, proving it's a real pane in THIS server. Without this,
# state from other sessions pollutes whatever pane you're looking at.

STATE="$1"

# A Notification only counts as attention if it's a permission prompt. Read the
# payload from stdin (skip when stdin is a TTY, e.g. manual runs, to avoid
# blocking). Any non-permission notification (idle_prompt, etc.) -> idle.
if [ "$STATE" = "attention" ]; then
  ntype=''
  [ -t 0 ] || ntype=$(jq -r '.notification_type // empty' 2>/dev/null)
  [ "$ntype" = "permission_prompt" ] || STATE='idle'
fi

PANE="${TMUX_PANE}"
[ -n "$PANE" ] || exit 0
[ "$(tmux display-message -p -t "$PANE" '#{pane_id}' 2>/dev/null)" = "$PANE" ] || exit 0

case "$STATE" in
  attention|running) NEW="$STATE" ;;
  *)                 NEW='' ;;
esac

# Early exit if nothing changed — keeps the per-tool PostToolUse hook cheap.
CUR=$(tmux display-message -p -t "$PANE" '#{@claude_state}' 2>/dev/null)
[ "$CUR" = "$NEW" ] && exit 0

tmux set-option -p -t "$PANE" @claude_state "$NEW" 2>/dev/null

# Recompute the window aggregate from all its panes.
WINDOW=$(tmux display-message -p -t "$PANE" '#{window_id}' 2>/dev/null)
[ -n "$WINDOW" ] || exit 0

STATES=$(tmux list-panes -t "$WINDOW" -F '#{@claude_state}' 2>/dev/null)
if printf '%s\n' "$STATES" | grep -q '^attention$'; then
  WIN='attention'
elif printf '%s\n' "$STATES" | grep -q '^running$'; then
  WIN='running'
else
  WIN=''
fi
tmux set-option -w -t "$WINDOW" @claude_win "$WIN" 2>/dev/null
