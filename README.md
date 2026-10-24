# claude-reboot-helper

Keeps Claude Desktop on Omarchy from turning hardware acceleration off by
itself every time you reboot, shut down or log out.

## The problem

Claude Desktop has built-in GPU crash protection. If its GPU process dies three
times in one session, it writes `isHardwareAccelerationDisabled: true` to
`~/.config/Claude/claude_desktop_config.json`, and it starts without
acceleration from then on.

On Omarchy, that protection fires during every reboot, shutdown and logout while
Claude is still running in the tray:

- **Reboot/shutdown:** Omarchy closes all windows, but Claude only hides to the
  tray. Two seconds later, systemd sends SIGTERM to every Claude process at
  once. The GPU process dies before the main process has registered that it is
  quitting.
- **Logout:** Claude isn't stopped at all. Its GPU process dies when Hyprland
  goes away.

Either way, Claude then tries to restart the GPU process and fails about 20
times in roughly 100 ms. Each failure (`reason: 'launch-failed'`, exit code
1002) counts as a GPU crash, so acceleration gets turned off. Nothing is wrong
with your GPU, and you never see it happen.

You can confirm it in Claude's own log:

```
[gpu-recovery] 3 GPU process deaths this session — disabling hardware acceleration
[gpu-recovery] 20 GPU process deaths in 106ms — terminal crash loop, action: relaunch
```

Those lines land within a second or two of a boot ending
(`journalctl --list-boots`) or of Hyprland stopping.

## The fix

The fix is to quit Claude cleanly *before* its processes get killed. Sending
SIGTERM to Claude's main process alone makes it quit straight away: it skips its
"quit anyway?" prompt and marks itself as quitting first. GPU deaths after that
point are ignored. As a bonus, open Claude Code sessions get saved instead of
being killed.

There are two user units:

| Unit | When | How |
| --- | --- | --- |
| `claude-desktop-quit-on-shutdown.service` | reboot, shutdown | Holds a logind *delay* inhibitor. On `PrepareForShutdown`, it sends SIGTERM to Claude's main process and waits up to 10 s for it to exit before releasing the lock. |
| `claude-desktop-quit-on-logout.service` | logout | Its `ExecStop` does the same thing. It's ordered after `graphical-session.target`, so systemd runs it before stopping Hyprland. |

Both units use `bin/claude-desktop-quit-on-shutdown`. It reads Claude's main
PID from `~/.config/Claude/SingletonLock` and refuses to signal anything that
isn't Claude's main process.

The helpers cover every way of rebooting, shutting down or logging out: the
Omarchy menu, `systemctl reboot`, the power button and `uwsm stop`.

## Requirements

- Omarchy, which provides a uwsm session (so `graphical-session.target` exists)
  and `InhibitDelayMaxSec=15` from `omarchy-settings`.
- The `claude-desktop` package (`/usr/lib/claude-desktop/claude-desktop`), as
  shipped in the Omarchy repo.
- `gdbus` (glib2) and `systemd-inhibit`, which are already present.

## Install

From this folder:

```bash
./install.sh
```

This copies the script to `~/.local/bin` and the units to
`~/.config/systemd/user`, then enables and starts them. No root access is
needed. It's safe to run again to update.

If hardware acceleration is already off, turn it back on in Claude's settings.

## Check it works

After a reboot or logout:

```bash
./check.sh
```

You should see `Sent SIGTERM to Claude Desktop` followed by `exited after …ms`.
Also check that no `gpu-recovery` event is newer than that, and that all the
acceleration flags are `False`.

## Uninstall

```bash
./uninstall.sh
```

## Caveats

- **Stopping or restarting `claude-desktop-quit-on-logout.service` by hand
  quits Claude Desktop.** That's the unit's job. `install.sh` and
  `uninstall.sh` avoid it.
- Claude quits without asking, even with Claude Code sessions running. That's
  the same thing that happens at shutdown anyway, except that here the sessions
  get saved first.
- This works around a bug in Claude Desktop. The real fix belongs in the app,
  which should ignore GPU-process deaths while the session is ending.

Tested on Omarchy with `claude-desktop` 3.6556.2 (October 2026) on an
NVIDIA GPU, through a real reboot and a real logout.

## License

[CC0 1.0](LICENSE)
