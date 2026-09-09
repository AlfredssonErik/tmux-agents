#!/usr/bin/env bash
set -u

menu=()
index=1
title="$(tmux show-option -gqv @tmux_agents_menu_title)"
style="$(tmux show-option -gqv @tmux_agents_menu_style)"
selected_style="$(tmux show-option -gqv @tmux_agents_menu_selected_style)"
border_style="$(tmux show-option -gqv @tmux_agents_menu_border_style)"
border_lines="$(tmux show-option -gqv @tmux_agents_menu_border_lines)"
[ -n "$title" ] || title=' 󰚩 tmux-agents '
[ -n "$style" ] || style='bg=#1e1e2e,fg=#cdd6f4'
[ -n "$selected_style" ] || selected_style='bg=#89b4fa,fg=#1e1e2e,bold'
[ -n "$border_style" ] || border_style='fg=#89b4fa'
[ -n "$border_lines" ] || border_lines=rounded
while IFS= read -r pane; do
    [ -n "$pane" ] || continue
    path="$(tmux display-message -p -t "$pane" '#{pane_current_path}' 2>/dev/null)" || continue
    state="$(tmux show-option -pt "$pane" -qv @tmux_agents_state 2>/dev/null)"
    [ -n "$state" ] || continue
    name="${path##*/}"
    name="${name//$'\n'/ }"
    name="${name//$'\r'/ }"
    name="${name//$'\t'/ }"
    name="${name//[^[:print:]]/ }"
    name="${name//\#/##}"
    menu+=("[$state] $name" "" "switch-client -t $pane")
    index=$((index + 1))
done < <("$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/list-agents.sh")

if [ "$index" -eq 1 ]; then
    tmux display-message 'tmux-agents: no active agents'
    exit 0
fi
tmux display-menu -T "$title" -s "$style" -H "$selected_style" \
    -S "$border_style" -b "$border_lines" -x C -y C "${menu[@]}"
