# tmux-agents

OpenCode state in tmux status bar, with native menu navigation and optional
notifications.

## Install

Add plugin to `.tmux.conf`:

```tmux
set -g @plugin 'AlfredssonErik/tmux-agents'
```

Install OpenCode bridge:

```sh
~/.tmux/plugins/tmux-agents/bin/tmux-agents install opencode
```

Add status component and reload tmux:

```tmux
set -g status-right '#{@tmux_agents_status}'
```

If you want local installation.

```tmux
run-shell '/PATH/TO/tmux-agents/tmux-agents.tmux'
```

Install OpenCode bridge:

```sh
/PATH/TO/tmux-agents/bin/tmux-agents install opencode
```

## Configuration

Set options before TPM loads the plugin.

Enable notifications with `@tmux_agents_notify on`. Notifications fire when
OpenCode finishes or needs input, unless target pane is visible. macOS uses
`osascript`; Linux uses `notify-send`.

Enable click navigation with both options:

```tmux
set -g mouse on
set -g @tmux_agents_mouse on
```

Complete list of available configurations:

```tmux
set -g @tmux_agents_mouse off
set -g @tmux_agents_menu_title '󰚩 tmux-agents'
set -g @tmux_agents_menu_style 'bg=#1e1e2e,fg=#cdd6f4'
set -g @tmux_agents_menu_selected_style 'bg=#89b4fa,fg=#1e1e2e,bold'
set -g @tmux_agents_menu_border_style 'fg=#89b4fa'
set -g @tmux_agents_menu_border_lines rounded
set -g @tmux_agents_watchdog_interval 5
set -g @tmux_agents_notify off
set -g @tmux_agents_notify_sound ''
set -g @tmux_agents_status_icon '◆'
set -g @tmux_agents_icon_working '󰔟'
set -g @tmux_agents_icon_waiting '?'
set -g @tmux_agents_icon_idle '✓'
set -g @tmux_agents_icon_error '!'
set -g @tmux_agents_icon_active '●'
set -g @tmux_agents_status_fg '#1e1e2e'
set -g @tmux_agents_color_working yellow
set -g @tmux_agents_color_waiting red
set -g @tmux_agents_color_idle green
set -g @tmux_agents_color_error magenta
set -g @tmux_agents_color_active cyan
```


## Keybinds

`prefix + a` opens native agent menu. Select entry to jump to pane.

Status entries are clickable when mouse navigation is enabled.

Test notifications:

```sh
/PATH/TO/tmux-agents/scripts/notify.sh --test
/PATH/TO/tmux-agents/scripts/notify.sh --test --kind input
```

Check installation:

```sh
~/.tmux/plugins/tmux-agents/bin/tmux-agents doctor
```

MIT licensed.
