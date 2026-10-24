#!/bin/bash
# Remove the Claude Desktop quit helpers without quitting Claude Desktop.

set -uo pipefail

bin=$HOME/.local/bin
units=${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user
names=(claude-desktop-quit-on-shutdown.service claude-desktop-quit-on-logout.service)

systemctl --user disable "${names[@]}" 2>/dev/null
# Remove the script first: stopping the logout unit runs it, which would
# quit Claude Desktop. With it gone, that ExecStop just fails.
rm -f "$bin/claude-desktop-quit-on-shutdown"
systemctl --user stop "${names[@]}" 2>/dev/null
systemctl --user reset-failed "${names[@]}" 2>/dev/null
rm -f "$units/${names[0]}" "$units/${names[1]}"
systemctl --user daemon-reload

echo "Removed."
