# Developing codehive

codehive is usually developed from a Claude session on a server that runs codehive. That session runs inside one of the live install's servers, as the same user, so a test that installs, uninstalls, or drives systemd hits the real install. That has broken it before. This page sets things up so development and testing can't touch the live install, and the live install only changes when you update it from GitHub.

## The workflow

| Stage | Where | What happens |
|---|---|---|
| Develop | A Claude session in this repo, locked (below) | Editing, the sandboxed tests, pushing branches |
| Test | GitHub Actions, on every push | Lint, then both test suites on Ubuntu 24.04 and Debian 13, on x86_64 and ARM64, and a check of the real Claude Code |
| Build | The nightly workflow | CI again on the commit being built, then a prerelease |
| Check | Your server, over SSH | Install the prerelease and try it with real Remote Control, then promote it or roll back |
| Deploy | Your server, over SSH | `codehive update` to the promoted release |

No test or staging machine is signed in to Claude. The automated tests use a fake Claude Code, and the only check with real Remote Control is the one you make on your own server before promoting a build. See [RELEASING.md](RELEASING.md).

## In a development session

- **Run only the sandboxed tests:** `bats test/unit.bats`. They use a throwaway home folder and stand-ins for `systemctl` and Claude Code, so they're safe anywhere.
- **To test anything else, push the branch** and read the result with `gh run watch`. CI is where the installer, real systemd, and the integration tests run.
- **Never run** the installer, the uninstaller, `test/integration.bats`, `systemctl --user`, or any `codehive` command that changes something (`new`, `trust`, `untrust`, `delete`, `sync`, `restart`, `off`, `on`, `update`, `uninstall`). If a change needs one of them tried on the live install, it goes through a release.

[.claude/settings.json](.claude/settings.json) denies those commands in sessions in this repo, so Claude Code refuses them with a clear message. Deny rules match the start of a command, so they're a guardrail, not a lock. The lock is below.

## Locking the development server

A systemd drop-in for the server that runs this repo's sessions makes codehive's files, and everything the live install reacts to, read-only for those sessions, and hides the systemd user manager from them. Other projects, the launcher, and SSH logins are unaffected.

1. Find the server's unit name. For a repo at `~/projects/codehive`:
   ```bash
   echo "claude-rc@$(systemd-escape --path ~/projects/codehive).service"
   # claude-rc@home-<you>-projects-codehive.service
   ```
2. Create `~/.config/systemd/user/<unit name>.d/sandbox.conf`, changing `%h/projects` and `%h/projects/codehive` if your project folder or repo is elsewhere:
   ```ini
   [Service]
   # Sessions developing codehive can't change or control the live install
   ReadOnlyPaths=-%h/.local/share/codehive -%h/.config/codehive -%h/.local/bin
   ReadOnlyPaths=-%h/.local/share/systemd/user -%h/.config/systemd/user
   # ...or what it runs and reacts to: Claude Code and the other projects
   ReadOnlyPaths=-%h/.local/share/claude -%h/projects
   ReadWritePaths=%h/projects/codehive
   InaccessiblePaths=-%t/systemd -%t/bus -%t/codehive-sync.lock
   ```
3. Over SSH, not from a session, since the restart ends every session in this repo:
   ```bash
   systemctl --user daemon-reload
   systemctl --user restart '<unit name>'
   ```

In a new session in this repo, check that it took effect. Each of these should fail:

```bash
touch ~/.local/share/codehive/probe ~/.local/bin/probe ~/projects/probe
systemctl --user is-active claude-rc-launcher.service
```

and these should still work: editing files in the repo, `git push`, `gh`, and `bats test/unit.bats`.

What the lock covers:

| Path | Why |
|---|---|
| `~/.local/share/codehive`, `~/.config/codehive` | The installed scripts, launcher, trusted list, and config |
| `~/.local/bin` | The `codehive` command, and the `claude` link every server runs |
| `~/.local/share/systemd/user`, `~/.config/systemd/user` | The unit files, and this drop-in, so a session can't loosen it |
| `~/.local/share/claude` | The Claude Code versions every server runs. Claude Code can't update itself from these sessions; the other servers still update it. |
| `~/projects`, except this repo | Creating, removing, or excluding a project would make the sync start or stop its server |
| The systemd user manager and the sync lock | Starting, stopping, enabling, or stalling anything |

What stays writable, because Claude Code needs it: this repo, `~/.claude`, `~/.claude.json`, and `/tmp`.

The lock stops accidents, which is what broke the live install before. It doesn't stop a session that sets out to get around it. A session can still:

- **Signal your other servers,** since they run as the same user. A server that's killed restarts within 10 seconds.
- **Edit `~/.claude.json`,** where workspace trust lives. codehive restores dropped trust from its trusted list, which is locked, within a minute.
- **Edit your shell startup files,** such as `~/.bashrc`, which run when you log in.

The drop-in isn't part of the install. Updating or reinstalling codehive leaves it alone, and `codehive uninstall` doesn't remove it.

## Tools

The tests use [bats](https://github.com/bats-core/bats-core) 1.5 or newer, and CI lints with [shellcheck](https://www.shellcheck.net/). See [test/README.md](test/README.md) for what each test file covers.
