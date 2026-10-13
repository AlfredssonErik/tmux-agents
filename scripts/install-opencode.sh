#!/usr/bin/env bash
set -u

action="${1:-status}"
dir="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
config="${XDG_CONFIG_HOME:-$HOME/.config}"
plugins="$config/opencode/plugins"
target="$plugins/tmux-agents"
legacy="$plugins/tmux-agents.js"
source="$dir/integrations/opencode-tmux-agents"
legacy_source="$dir/integrations/opencode-tmux-agents.js"

if [ "$action" = install ] && [ ! -f "$source/index.js" ] && [ ! -f "$source/tui.js" ]; then
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
    if [ ! -f "$source/index.js" ] || [ ! -f "$source/tui.js" ]; then
        printf 'plugin source: missing\n'
        doctor_fail=1
    fi
    if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
        printf 'opencode plugin: installed\n'
    else
        printf 'opencode plugin: not installed\n'
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
        mkdir -p "$plugins" || exit 1
        if [ -L "$legacy" ] && [ "$(readlink "$legacy")" = "$legacy_source" ]; then
            rm -f "$legacy"
        elif [ -e "$legacy" ] || [ -L "$legacy" ]; then
            printf 'Refusing to replace unrelated file: %s\n' "$legacy" >&2
            exit 1
        fi
        if [ -e "$target" ] || [ -L "$target" ]; then
            if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
                printf 'Already installed: %s\nRestart OpenCode to load it.\n' "$target"
                exit 0
            fi
            printf 'Refusing to replace existing file: %s\n' "$target" >&2
            exit 1
        fi
        ln -s "$source" "$target"
        printf 'Installed %s\nRestart OpenCode CLI to load it.\n' "$target"
        ;;
    uninstall)
        removed=0
        if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
            rm -f "$target"
            removed=1
        elif [ -e "$target" ] || [ -L "$target" ]; then
            printf 'Refusing to remove unrelated file: %s\n' "$target" >&2
            exit 1
        fi
        if [ -L "$legacy" ] && [ "$(readlink "$legacy")" = "$legacy_source" ]; then
            rm -f "$legacy"
            removed=1
        elif [ -e "$legacy" ] || [ -L "$legacy" ]; then
            printf 'Refusing to remove unrelated file: %s\n' "$legacy" >&2
            exit 1
        fi
        if [ "$removed" -eq 1 ]; then
            printf 'Removed OpenCode plugin links\n'
        else
            printf 'Not installed\n'
        fi
        ;;
    status)
        if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
            printf 'Installed: %s\n' "$target"
        elif [ -L "$legacy" ] && [ "$(readlink "$legacy")" = "$legacy_source" ]; then
            printf 'Legacy server-only install: %s\nRun install to enable per-instance TUI tracking.\n' "$legacy"
        else
            printf 'Not installed: %s\n' "$target"
            exit 1
        fi
        ;;
    *) printf 'usage: %s {install|uninstall|status|doctor}\n' "$0" >&2; exit 2 ;;
esac
