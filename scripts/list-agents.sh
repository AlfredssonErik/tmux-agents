#!/usr/bin/env bash
set -u

tmux list-panes -a -F '#{pane_id}' 2>/dev/null |
while IFS= read -r pane; do
    [ -n "$pane" ] || continue
    [ -n "$(tmux show-option -pt "$pane" -qv @tmux_agents_state 2>/dev/null)" ] || continue
    printf '%s\n' "$pane"
done
