#!/usr/bin/env bash
set -u

action="${1:-status}"
dir="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
config="${XDG_CONFIG_HOME:-$HOME/.config}"
target="$config/opencode/plugins/tmux-agents.js"
source="$dir/integrations/opencode-tmux-agents.js"

if [ "$action" = install ] && [ ! -e "$source" ]; then
    printf 'Bridge source missing: %s\n' "$source" >&2
    exit 1
fi

if [ "$action" = doctor ]; then
    doctor_fail=0
    printf 'tmux: '
    if ! tmux -V 2>/dev/null; then
        printf 'unavailable\n'
        doctor_fail=1
    fi
    printf 'plugin: %s\n' "$dir"
    if [ ! -f "$source" ]; then
        printf 'plugin source: missing\n'
        doctor_fail=1
    fi
    if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
        printf 'opencode bridge: installed\n'
    else
        printf 'opencode bridge: not installed\n'
        doctor_fail=1
    fi
    if [ "$(uname -s)" = Darwin ] || command -v notify-send >/dev/null 2>&1; then
        printf 'notifications: available\n'
    else
        printf 'notifications: unavailable\n'
    fi
    exit "$doctor_fail"
fi

case "$action" in
    install)
        mkdir -p "$(dirname -- "$target")" || exit 1
        if [ -e "$target" ] || [ -L "$target" ]; then
            if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
                printf 'Already installed: %s\nRestart OpenCode to load it.\n' "$target"
                exit 0
            fi
            if [ -L "$target" ] && [ ! -e "$target" ]; then
                rm -f "$target"
                ln -s "$source" "$target"
                printf 'Repaired %s\nRestart OpenCode to load it.\n' "$target"
                exit 0
            fi
            printf 'Refusing to replace existing file: %s\n' "$target" >&2
            exit 1
        fi
        ln -s "$source" "$target"
        printf 'Installed %s\nRestart OpenCode to load it.\n' "$target"
        ;;
    uninstall)
        if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
            rm -f "$target"
            printf 'Removed %s\n' "$target"
        elif [ -L "$target" ] && [ ! -e "$target" ]; then
            rm -f "$target"
            printf 'Removed dangling bridge: %s\n' "$target"
        elif [ -e "$target" ]; then
            printf 'Refusing to remove unrelated file: %s\n' "$target" >&2
            exit 1
        else
            printf 'Not installed\n'
        fi
        ;;
    status)
        if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
            printf 'Installed: %s\n' "$target"
        else
            printf 'Not installed: %s\n' "$target"
            exit 1
        fi
        ;;
    *) printf 'usage: %s {install|uninstall|status|doctor}\n' "$0" >&2; exit 2 ;;
esac
