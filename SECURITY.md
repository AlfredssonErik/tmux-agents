# Security

tmux-agents runs local shell scripts and an OpenCode plugin under the current
user account. It does not provide isolation or elevate privileges.

Report security issues privately to the repository maintainers before public
disclosure through the repository owner's GitHub security contact. Include
reproduction steps, platform, tmux version, and affected configuration.

The plugin treats pane IDs, process IDs, states, owners, and agent names as
validated values. Project paths and display names are escaped before being
placed in tmux status formats. Do not install the plugin from an untrusted
repository or grant write access to its directory to other users.
