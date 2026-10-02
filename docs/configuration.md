# Configuration

The config is a bash file at `~/.config/codehive/config`:

```bash
PROJECT_DIRS=(
  "$HOME/projects"
  "$HOME/work"
)
LAUNCHER_DIR="$HOME/.local/share/codehive/launcher"
BIN_DIR="$HOME/.local/bin"
PERMISSION_MODE=""
LAUNCHER_AUTOAPPROVE=0
AUTO_TRUST=0
UPDATE_CHECK=1
```

See [config.example](../config.example) for a commented copy.

- **Add or remove a project folder:** edit `PROJECT_DIRS` and run the installer again. The servers for projects in a removed folder stop, and the folder itself isn't touched.
- **Change the permission mode:** edit `PERMISSION_MODE` and run `codehive restart`.
- **Change automatic trust:** edit `AUTO_TRUST`. It applies on the next sync. See [Workspace trust](workspace-trust.md).
- **Turn update checks off or on:** edit `UPDATE_CHECK`. It applies on the next check. See [Update notices](updating.md#update-notices).
- **Change the launcher or bin folder:** edit the config and run the installer again. Files from the old location are removed.

## Setting up another computer

Copy `~/.config/codehive/config` to the new machine. Paths under your home folder are saved as `$HOME/...`, so the file works under a different user name. Then do steps 1 and 2 of [Installing codehive](install.md), and run the installer.

## The launcher's settings

The installer writes `.claude/settings.json` in the launcher folder. It holds:

- A `SessionStart` hook that runs `~/.local/share/codehive/libexec/claude-rc-update-check --notice` when a launcher session starts. It reads the result of the last update check, without going online, and prints the notice if a newer version is out. That way, the launcher's Claude can tell you (see [Update notices](updating.md#update-notices)).
- With `--launcher-autoapprove`, permission to run `codehive new` without asking: `"permissions": {"allow": ["Bash(/home/you/.local/bin/codehive new:*)"]}`.

If that file already exists and the installer didn't write it, it's left alone and the installer warns you. Add those two things to it yourself if you want them.

## Where things are installed

| What | Where |
|---|---|
| `codehive` command | `~/.local/bin/codehive` (`--bin-dir`) |
| Config | `~/.config/codehive/config` |
| Scripts, launcher, install manifest | `~/.local/share/codehive/` |
| systemd units | `~/.local/share/systemd/user/` |

These follow the XDG base directory spec, and `XDG_CONFIG_HOME` and `XDG_DATA_HOME` are respected. The systemd units go in the folder systemd reserves for units installed by packages, which leaves `~/.config/systemd/user` free for your own overrides.
