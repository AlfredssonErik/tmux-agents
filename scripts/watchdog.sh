#!/usr/bin/env bash
set -u

dir="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
interval="$(tmux show-option -gqv @tmux_agents_watchdog_interval 2>/dev/null)"
[ -n "$interval" ] || interval=5
while tmux list-sessions >/dev/null 2>&1; do
    "$dir/scripts/prune.sh" >/dev/null 2>&1 || :
    "$dir/scripts/render-status.sh" >/dev/null 2>&1 || :
    sleep "$interval"
done
