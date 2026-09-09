#!/usr/bin/env bash
set -u

platform="$(uname -s)"
if [ "$platform" != Darwin ] && ! command -v notify-send >/dev/null 2>&1; then
    exit 0
fi

usage() {
    printf 'usage: %s [--test] [--kind finished|input] [--pane PANE]\n' "$0" >&2
    exit 2
}

pane=""
test_mode=0
kind="finished"
while [ "$#" -gt 0 ]; do
    case "$1" in
        --test) test_mode=1; shift ;;
        --kind) [ "$#" -ge 2 ] || usage; kind="$2"; shift 2 ;;
        --pane) [ "$#" -ge 2 ] || usage; pane="$2"; shift 2 ;;
        *) usage ;;
    esac
done
case "$kind" in finished|input) ;; *) usage ;; esac

sound="$(tmux show-option -gqv @tmux_agents_notify_sound 2>/dev/null)"
if [ "$test_mode" -eq 1 ]; then
    location="tmux-agents test"
elif [ -n "$pane" ]; then
   path="$(tmux display-message -p -t "$pane" '#{pane_current_path}' 2>/dev/null)" || exit 0
   location="${path##*/}" 
else
    printf 'notify.sh: missing --pane\n' >&2
    exit 2
fi

# Do not interrupt a client currently viewing target pane.
if [ "$test_mode" -eq 0 ] && [ -n "$pane" ]; then
    while IFS= read -r current; do
        if [ "$current" = "$pane" ]; then
            exit 0
        fi
    done <<EOF
$(tmux list-clients -F '#{pane_id}' 2>/dev/null)
EOF
fi

if [ "$kind" = input ]; then
    title='OpenCode needs input'
else
title='OpenCode finished'
fi
message="$location"
if [ "$platform" != Darwin ]; then
    notify-send "$title" "$message"
    exit $?
fi
# Pass untrusted text as argv, never by interpolating it into AppleScript.
osascript_error=0
if [ -n "$sound" ]; then
    if [ "$test_mode" -eq 1 ]; then
        /usr/bin/osascript - "$title" "$message" "$sound" <<'APPLESCRIPT' || osascript_error=$?
on run argv
    display notification (item 2 of argv) with title (item 1 of argv) sound name (item 3 of argv)
end run
APPLESCRIPT
    else
        /usr/bin/osascript - "$title" "$message" "$sound" >/dev/null 2>&1 <<'APPLESCRIPT' || :
on run argv
    display notification (item 2 of argv) with title (item 1 of argv) sound name (item 3 of argv)
end run
APPLESCRIPT
    fi
else
    if [ "$test_mode" -eq 1 ]; then
        /usr/bin/osascript - "$title" "$message" <<'APPLESCRIPT' || osascript_error=$?
on run argv
    display notification (item 2 of argv) with title (item 1 of argv)
end run
APPLESCRIPT
    else
        /usr/bin/osascript - "$title" "$message" >/dev/null 2>&1 <<'APPLESCRIPT' || :
on run argv
    display notification (item 2 of argv) with title (item 1 of argv)
end run
APPLESCRIPT
    fi
fi
[ "$test_mode" -eq 0 ] || exit "$osascript_error"
