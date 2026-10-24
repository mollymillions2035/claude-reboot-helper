#!/bin/bash
# Show whether the helpers are running, what they did last, and whether
# Claude Desktop has turned hardware acceleration off since.

config=${XDG_CONFIG_HOME:-$HOME/.config}/Claude

echo "== Units"
systemctl --user is-active claude-desktop-quit-on-shutdown.service claude-desktop-quit-on-logout.service |
  paste -d' ' <(printf '%s\n' shutdown: logout:) -
systemd-inhibit --list --no-pager | grep -q '^Claude Desktop' &&
  echo "shutdown delay lock: held" || echo "shutdown delay lock: MISSING"

echo "== Last helper actions (all boots)"
journalctl --user -o short-iso --no-pager \
  -u claude-desktop-quit-on-shutdown.service -u claude-desktop-quit-on-logout.service \
  -g 'Sent SIGTERM|exited after|still running|not running' | tail -6

echo "== Last gpu-recovery events in Claude's logs"
grep -h 'gpu-recovery' "$config"/logs/main*.log 2>/dev/null | sort | tail -4 | cut -c1-160 | grep . || echo none

echo "== Hardware acceleration flags"
python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); [print(k, v) for k, v in d.items() if "HardwareAcceleration" in k]' \
  "$config/claude_desktop_config.json" 2>/dev/null || echo "no Claude Desktop config"
[[ -e $config/gpu-crash-streak ]] && echo "crash marker: $(cat "$config/gpu-crash-streak")" || echo "crash marker: none"
