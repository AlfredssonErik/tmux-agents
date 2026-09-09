#!/usr/bin/env bash
set -u

pane="${1:-}"
client="${2:-}"

if [[ ! "$pane" =~ ^%[0-9]+$ ]]; then
    exit 2
fi
case "$client" in
    /dev/*|[A-Za-z0-9._-]*)
        ;;
    *)
        exit 2
        ;;
esac

if ! tmux display-message -p -t "$pane" '#{pane_id}' >/dev/null 2>&1; then
    tmux display-message 'tmux-agents: agent pane no longer exists'
    exit 0
fi

if ! tmux switch-client -c "$client" -t "$pane"; then
    tmux display-message 'tmux-agents: unable to switch to agent pane'
    exit 1
fi
