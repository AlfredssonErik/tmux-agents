#!/usr/bin/env bash

TMUX_AGENTS_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

tmux_version="$(tmux -V | awk '{print $2}')"
tmux_major="${tmux_version%%.*}"
tmux_minor="${tmux_version#*.}"
tmux_minor="${tmux_minor%%[^0-9]*}"
if [ "${tmux_major:-0}" -lt 3 ] || { [ "${tmux_major:-0}" -eq 3 ] && [ "${tmux_minor:-0}" -lt 4 ]; }; then
    tmux display-message 'tmux-agents: tmux 3.4+ required'
    exit 0
fi

set_default() {
    option="$1"
    value="$2"
    if [ -z "$(tmux show-option -gqv "$option")" ]; then
        tmux set-option -g "$option" "$value"
    fi
}
set_default @tmux_agents_key a
set_default @tmux_agents_mouse off
set_default @tmux_agents_watchdog_interval 5
set_default @tmux_agents_menu_title '󰚩 tmux-agents'
set_default @tmux_agents_menu_style 'bg=#1e1e2e,fg=#cdd6f4'
set_default @tmux_agents_menu_selected_style 'bg=#89b4fa,fg=#1e1e2e,bold'
set_default @tmux_agents_menu_border_style 'fg=#89b4fa'
set_default @tmux_agents_menu_border_lines rounded
set_default @tmux_agents_status_icon '◆'
set_default @tmux_agents_icon_working '󰔟'
set_default @tmux_agents_icon_waiting '?'
set_default @tmux_agents_icon_idle '✓'
set_default @tmux_agents_icon_error '!'
set_default @tmux_agents_icon_active '●'
set_default @tmux_agents_status_fg '#1e1e2e'
set_default @tmux_agents_color_working yellow
set_default @tmux_agents_color_waiting red
set_default @tmux_agents_color_idle green
set_default @tmux_agents_color_error magenta
set_default @tmux_agents_color_active cyan
set_default @tmux_agents_notify off
set_default @tmux_agents_notify_sound ''

key="$(tmux show-option -gqv @tmux_agents_key)"
tmux bind-key "$key" run-shell -b "\"$TMUX_AGENTS_DIR/scripts/menu.sh\""
"$TMUX_AGENTS_DIR/scripts/render-status.sh" >/dev/null

watchdog_pid="$(tmux show-environment -g TMUX_AGENTS_WATCHDOG_PID 2>/dev/null | cut -d= -f2)"
if [ -z "$watchdog_pid" ] || ! kill -0 "$watchdog_pid" 2>/dev/null; then
    "$TMUX_AGENTS_DIR/scripts/watchdog.sh" >/dev/null 2>&1 &
    tmux set-environment -g TMUX_AGENTS_WATCHDOG_PID "$!"
fi

if [ "$(tmux show-option -gqv @tmux_agents_mouse)" = on ]; then
    tmux bind-key -T root MouseDown1Status if-shell -F \
        '#{m/r:^%[0-9]+$,#{mouse_status_range}}' \
        "run-shell -b '$TMUX_AGENTS_DIR/scripts/click-agent.sh \"#{mouse_status_range}\" \"#{client_tty}\"'" \
        'switch-client -t ='
fi
