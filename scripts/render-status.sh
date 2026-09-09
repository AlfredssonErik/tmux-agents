#!/usr/bin/env bash
set -u

dir="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
"$dir/scripts/prune.sh" >/dev/null 2>&1 || :
umask 077
tmp="$(mktemp "${TMPDIR:-/tmp}/tmux-agents-status.XXXXXX")" || exit 1
trap 'rm -f "$tmp"' EXIT HUP INT TERM

"$dir/scripts/list-agents.sh" | while IFS= read -r pane; do
    path="$(tmux display-message -p -t "$pane" '#{pane_current_path}' 2>/dev/null)" || continue
    state="$(tmux show-option -pt "$pane" -qv @tmux_agents_state 2>/dev/null)"
    [ -n "$state" ] || continue
    icon="$(tmux show-option -gqv @tmux_agents_status_icon)"
    color="$(tmux show-option -gqv "@tmux_agents_color_$state")"
    state_icon="$(tmux show-option -gqv "@tmux_agents_icon_$state")"
    foreground="$(tmux show-option -gqv @tmux_agents_status_fg)"
    [ -n "$color" ] || color=default
    [ -n "$state_icon" ] || state_icon="$icon"
    [ -n "$foreground" ] || foreground=black
    folder="${path##*/}"
    folder="${folder//$'\n'/ }"
    folder="${folder//$'\r'/ }"
    folder="${folder//$'\t'/ }"
    folder="${folder//[^[:print:]]/ }"
    folder="${folder//\#/##}"
    printf '#[range=user|%s]#[fg=%s]#[fg=%s,bg=%s,bold]%s %s#[fg=%s,bg=default]#[default]#[norange] ' \
        "$pane" "$color" "$foreground" "$color" "$folder" "$state_icon" "$color"
done >"$tmp"

status="$(tr '\n' ' ' <"$tmp")"
status="${status% }"
tmux set-option -g @tmux_agents_status "$status"
printf '%s' "$status"
