#!/bin/bash
# Install the Claude Desktop quit helpers for the current user.
# Safe to run again to update: it never stops the logout unit, since stopping
# that unit quits Claude Desktop.

set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
bin=$HOME/.local/bin
units=${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user

for cmd in gdbus systemd-inhibit systemctl; do
  command -v "$cmd" >/dev/null || { echo "Missing $cmd" >&2; exit 1; }
done
if [[ ! -x /usr/lib/claude-desktop/claude-desktop ]]; then
  echo "Warning: Claude Desktop not found at /usr/lib/claude-desktop/claude-desktop;" >&2
  echo "the helpers only recognise that binary." >&2
fi
if ! systemctl --user is-active --quiet graphical-session.target; then
  echo "Warning: graphical-session.target is not active (not a uwsm session?);" >&2
  echo "the helpers won't start at login." >&2
fi

install -Dm755 "$repo/bin/claude-desktop-quit-on-shutdown" "$bin/claude-desktop-quit-on-shutdown"
install -Dm644 -t "$units" "$repo"/systemd/*.service

systemctl --user daemon-reload
systemctl --user enable claude-desktop-quit-on-shutdown.service claude-desktop-quit-on-logout.service
# Restarting the shutdown helper is harmless and picks up a new script.
# The logout unit is only started: a no-op when it's already active.
systemctl --user restart claude-desktop-quit-on-shutdown.service
systemctl --user start claude-desktop-quit-on-logout.service

sleep 1
if systemd-inhibit --list --no-pager | grep -q '^Claude Desktop'; then
  echo "Installed. Shutdown delay lock is held; the logout unit is active."
else
  echo "Installed, but the shutdown delay lock is missing. Check:" >&2
  echo "  systemctl --user status claude-desktop-quit-on-shutdown" >&2
  exit 1
fi
