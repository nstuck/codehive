# Updating

> **Run these from a terminal, not from a Claude session.** Use a console or SSH session for `codehive update`, `codehive restart`, `codehive uninstall`, the installer, and anything else that stops or restarts servers. A command run from a Claude session runs inside that session's server. When the server stops, systemd stops everything inside it, so the command is cut off partway and the session drops. The installer can also ask for confirmation or your `sudo` password, and only a terminal can answer.

**Claude Code** updates itself in the background, but updates take effect the next time Claude Code starts. The servers keep running the old version until they restart:

```bash
codehive restart
```

**codehive** itself:

```bash
codehive update
```

This downloads the installer from the same repo and branch you installed from and runs it again. Your saved settings are reused, so no options are needed, though any installer option can be passed (for example `codehive update --yes`). `--ref <branch or tag>` installs a different version, and `--repo <owner/name>` installs from a fork. Both are remembered for the next update. Running servers keep going; if the service files changed, the installer tells you to run `codehive restart`.

If you installed from a clone, update there instead:

```bash
cd ~/codehive && git pull && ./install.sh
```

If you moved or reinstalled Claude Code, run the installer again so the services use the new path.

## Update notices

codehive checks GitHub once a day for a newer release of the repo you installed from. For an install from a clone, that's the clone's `origin`, if it's on GitHub. When there's a newer release, you see it in three places:

- At the end of `codehive status`.
- In `codehive version`, which also checks again right away.
- When you open a new launcher session from any client. The launcher's Claude mentions it at the start of its first reply, with the release notes link and the command to run.

The notice gives the command that fits your install: `codehive update`, `codehive update --ref <new tag>` if you installed a specific release, or `git pull && ./install.sh` for a clone. Nothing updates on its own.

codehive is built nightly, whenever something changed. Each build is a release named after the UTC date it was made, with tags like `v2026.10.03`, and lists its changes on the [releases page](https://github.com/nstuck/codehive/releases) and in [CHANGELOG.md](../CHANGELOG.md). Read them before updating, especially lines that start with **Action needed:**, which change how an existing install behaves or need something from you. If you skipped several releases, read each one since your version.

The check is a single request to `api.github.com`, made around midnight plus up to four hours, or at the next boot if the server was off. It sends nothing about you or your projects. If the check fails, it tries again the next day. To see its results, run `journalctl --user -u claude-rc-update-check`. To turn it off, set `UPDATE_CHECK=0` in the config, or run the installer with `--no-update-check`.

An install that follows `main`, the default, reports the version of the last nightly build, even if it includes changes made since then. The next nightly build brings a notice, and `codehive update` gets you everything up to it.
