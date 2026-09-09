#!/usr/bin/env bash
set -u

tmux list-panes -a -F '#{pane_id}' 2>/dev/null |
while IFS= read -r pane; do
    state="$(tmux show-option -pt "$pane" -qv @tmux_agents_state 2>/dev/null)"
    pid="$(tmux show-option -pt "$pane" -qv @tmux_agents_pid 2>/dev/null)"
    [ -n "$state" ] || continue
    if [ -z "$pid" ] || ! ps -p "$pid" -o command= 2>/dev/null | grep -E '(^|/)(opencode)( |$)' >/dev/null 2>&1; then
        tmux set-option -p -t "$pane" -u @tmux_agents_pid \; \
            set-option -p -t "$pane" -u @tmux_agents_state \; \
            set-option -p -t "$pane" -u @tmux_agents_label \; \
            set-option -p -t "$pane" -u @tmux_agents_agent \; \
            set-option -p -t "$pane" -u @tmux_agents_owner \; \
            set-option -p -t "$pane" -u @tmux_agents_updated_at
    fi
done
