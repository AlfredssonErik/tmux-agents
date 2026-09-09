#!/usr/bin/env bash
set -u

root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
fail=0
check() {
    name="$1"
    shift
    if "$@"; then printf 'ok - %s\n' "$name"; else printf 'not ok - %s\n' "$name"; fail=1; fi
}

check 'shell syntax' bash -n "$root/tmux-agents.tmux"
check 'clickable status range' grep -q 'range=user' "$root/scripts/render-status.sh"
check 'user status range' grep -q 'range=user' "$root/scripts/render-status.sh"
check 'click helper syntax' bash -n "$root/scripts/click-agent.sh"
check 'notification syntax' bash -n "$root/scripts/notify.sh"
check 'osascript notification backend' grep -q '/usr/bin/osascript -' "$root/scripts/notify.sh"
check 'input notification title' grep -q "OpenCode needs input" "$root/scripts/notify.sh"
check 'input notification trigger' grep -q 'state" = waiting' "$root/scripts/update-state.sh"
check 'owner validation' grep -q 'previous_owner.*owner' "$root/scripts/update-state.sh"
check 'live owner protection' grep -q 'previous_pid' "$root/scripts/update-state.sh"
check 'claim contention status' grep -q 'exit 75' "$root/scripts/update-state.sh"
check 'native menu' grep -q 'display-menu' "$root/scripts/menu.sh"
check 'menu styling' grep -q '@tmux_agents_menu_style' "$root/scripts/menu.sh"
if grep -R -q 'fzf' "$root" --exclude-dir=.git --exclude=run.sh; then
    printf 'not ok - no fzf dependency\n'
    fail=1
else
    printf 'ok - no fzf dependency\n'
fi
if grep -R -n 'terminal-notifier' "$root" --exclude-dir=.git --exclude=run.sh; then
    printf 'not ok - removed terminal-notifier references\n'
    fail=1
else
    printf 'ok - removed terminal-notifier references\n'
fi
for script in "$root"/scripts/*.sh; do
    check "syntax $(basename "$script")" bash -n "$script"
done
if command -v node >/dev/null 2>&1; then
    check 'bridge syntax' node --check "$root/integrations/opencode-tmux-agents.js"
fi
if grep -n 'wait-for -[LU] tmux-agents-state' "$root/scripts/update-state.sh"; then
    printf 'not ok - updater has stranded global lock\n'
    fail=1
else
    printf 'ok - updater has no stranded global lock\n'
fi

exit "$fail"
