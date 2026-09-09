# tmux-agents

Event-driven OpenCode status for tmux. See every OpenCode process in your
status bar and jump to any agent from a native tmux menu.

## Requirements

- tmux 3.4+
- Bash 3.2+
- OpenCode

## Install

For local development, load checkout directly:

```tmux
run-shell '/PATH/TO/REPOSITORY/tmux-agents/tmux-agents.tmux'
```

For a published repository, add TPM plugin:

```tmux
set -g @plugin 'AlfredssonErik/tmux-agents'
```

Install the OpenCode bridge separately. For local checkout:

```sh
/PATH/TO/REPOSITORY/tmux-agents/scripts/install-opencode.sh install
```

For TPM installation:

```sh
~/.tmux/plugins/tmux-agents/bin/tmux-agents install opencode
```

Restart OpenCode after installation.

Run `doctor` to validate bridge installation and notification support:

```sh
~/.tmux/plugins/tmux-agents/bin/tmux-agents doctor
```

Add cached status to your existing status bar:

```tmux
set -g status-right '#{@tmux_agents_status} | %H:%M'
```

Reload tmux. Press `prefix + a` to open native agent menu.

With both tmux mouse mode and plugin mouse mode enabled, click an agent entry in status bar to jump
directly to its session, window, and pane:

```tmux
set -g mouse on
set -g @tmux_agents_mouse on
```

## States

`working`, `waiting`, `idle`, and `error` come from OpenCode events. `active`
means bridge initialized before its first session event. Multiple OpenCode sessions in one pane collapse into one row using
priority `waiting > error > working > idle > active`.

## Configuration

Set options before TPM loads plugin:

```tmux
set -g @tmux_agents_key a
set -g @tmux_agents_mouse off
set -g @tmux_agents_menu_title '󰚩 tmux-agents'
set -g @tmux_agents_menu_style 'bg=#1e1e2e,fg=#cdd6f4'
set -g @tmux_agents_menu_selected_style 'bg=#89b4fa,fg=#1e1e2e,bold'
set -g @tmux_agents_menu_border_style 'fg=#89b4fa'
set -g @tmux_agents_menu_border_lines rounded
set -g @tmux_agents_watchdog_interval 5
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
set -g @tmux_agents_notify off
set -g @tmux_agents_notify_sound ''
```

State colors can use Catppuccin values directly:

```tmux
set -g @tmux_agents_color_working '#f9e2af'
set -g @tmux_agents_color_waiting '#fab387'
set -g @tmux_agents_color_idle '#a6e3a1'
set -g @tmux_agents_color_error '#f38ba8'
set -g @tmux_agents_color_active '#89b4fa'
set -g status-right-length 200
```

Pill separators use Nerd Font glyphs. Replace `` and `` in
`scripts/render-status.sh` with plain spaces if terminal font lacks them.

`@tmux_agents_mouse` is off by default to avoid conflicts with other status-bar
plugins.

## Notifications

Completion notifications are opt-in. Enable them with:

```tmux
set -g @tmux_agents_notify on
set -g @tmux_agents_notify_sound ''
```

Notifications fire only for `working -> idle` and transitions into `waiting`
(OpenCode needs input). They are suppressed when a tmux client is currently
viewing the agent pane. Default is silent.

Notifications use macOS `osascript` or Linux `notify-send`. Test delivery with:

```sh
/PATH/TO/REPOSITORY/tmux-agents/scripts/notify.sh --test
```

Test input notification wording with:

```sh
/PATH/TO/REPOSITORY/tmux-agents/scripts/notify.sh --test --kind input
```

If no banner appears, check macOS System Settings > Notifications, Focus mode,
and Scheduled Summary. `osascript` notifications may appear under Script
Editor in macOS notification settings.

OpenCode also has its own attention notification system. Disable one system if
you see duplicate notifications. `osascript` notifications do not support
click actions; use the native agent menu or status-bar entries to jump to panes.

## Popup

`prefix + a` opens native tmux menu. Select agent entry to jump to its pane.

## Manual integration

Without TPM, run the entrypoint above and install bridge directly:

```sh
/PATH/TO/REPOSITORY/tmux-agents/scripts/install-opencode.sh install
```

## Diagnostics

```sh
tmux show -gqv @tmux_agents_status
```

Check installation:

```sh
~/.tmux/plugins/tmux-agents/bin/tmux-agents doctor
```

Uninstall bridge:

```sh
~/.tmux/plugins/tmux-agents/scripts/install-opencode.sh uninstall
```

MIT licensed.
