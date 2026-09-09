#!/usr/bin/env bash
set -u

usage() { printf 'usage: %s --action claim|update|clear --pane PANE --owner OWNER --state STATE [--pid PID] [--agent AGENT]\n' "$0" >&2; exit 2; }
pane="${TMUX_PANE:-}"
action=""
state=""
pid=""
owner=""
agent="opencode"
notify_transition=0
notify_kind="finished"
while [ "$#" -gt 0 ]; do
    case "$1" in
        --action) [ "$#" -ge 2 ] || usage; action="$2"; shift 2 ;;
        --pane) [ "$#" -ge 2 ] || usage; pane="$2"; shift 2 ;;
        --state) [ "$#" -ge 2 ] || usage; state="$2"; shift 2 ;;
        --pid) [ "$#" -ge 2 ] || usage; pid="$2"; shift 2 ;;
        --owner) [ "$#" -ge 2 ] || usage; owner="$2"; shift 2 ;;
        --agent) [ "$#" -ge 2 ] || usage; agent="$2"; shift 2 ;;
        *) usage ;;
    esac
done
[ -n "$action" ] && [ -n "$pane" ] && [ -n "$owner" ] || usage
if [ "$action" != clear ]; then
    case "$state" in working|waiting|idle|error|active|off) ;; *) exit 2 ;; esac
fi
case "$action" in claim|update|clear) ;; *) exit 2 ;; esac
case "$pane" in %*) ;; *) exit 2 ;; esac
case "$owner" in *[!A-Za-z0-9._:-]*) exit 2 ;; esac
case "$agent" in *[!A-Za-z0-9._:-]*) exit 2 ;; esac
case "$pid" in ''|*[!0-9]*) [ "$action" = clear ] || exit 2 ;; esac

tmux display-message -p -t "$pane" '#{pane_id}' >/dev/null 2>&1 || exit 0
dir="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

previous_state="$(tmux show-option -pt "$pane" -qv @tmux_agents_state 2>/dev/null)"
previous_owner="$(tmux show-option -pt "$pane" -qv @tmux_agents_owner 2>/dev/null)"
previous_pid="$(tmux show-option -pt "$pane" -qv @tmux_agents_pid 2>/dev/null)"
notifications="$(tmux show-option -gqv @tmux_agents_notify 2>/dev/null)"
if [ "$action" = claim ] && [ -n "$previous_owner" ] && [ -n "$previous_pid" ] &&
   ps -p "$previous_pid" -o command= 2>/dev/null | grep -E '(^|/)(opencode)( |$)' >/dev/null 2>&1; then
    exit 75
fi
if [ "$action" != claim ] && [ "$previous_owner" != "$owner" ]; then
    exit 0
fi
if [ "$previous_state" = working ] && [ "$state" = idle ] && [ "$notifications" = on ]; then
    notify_transition=1
elif [ "$previous_state" != waiting ] && [ "$state" = waiting ] && [ "$notifications" = on ]; then
    notify_transition=1
    notify_kind="input"
fi
if [ "$action" = clear ] || [ "$state" = off ]; then
    tmux set-option -p -t "$pane" -u @tmux_agents_pid \; \
        set-option -p -t "$pane" -u @tmux_agents_state \; \
        set-option -p -t "$pane" -u @tmux_agents_label \; \
        set-option -p -t "$pane" -u @tmux_agents_agent \; \
        set-option -p -t "$pane" -u @tmux_agents_owner \; \
        set-option -p -t "$pane" -u @tmux_agents_updated_at
else
    tmux set-option -p -t "$pane" @tmux_agents_pid "$pid" \; \
        set-option -p -t "$pane" @tmux_agents_state "$state" \; \
        set-option -p -t "$pane" @tmux_agents_label "$agent" \; \
        set-option -p -t "$pane" @tmux_agents_agent "$agent" \; \
        set-option -p -t "$pane" @tmux_agents_owner "$owner" \; \
        set-option -p -t "$pane" @tmux_agents_updated_at "$(date +%s)"
fi
"$dir/scripts/render-status.sh" >/dev/null
tmux refresh-client -S 2>/dev/null || :
if [ "$notify_transition" -eq 1 ]; then
    "$dir/scripts/notify.sh" --kind "$notify_kind" --pane "$pane" &
fi
