# Changelog

All notable changes to codehive are listed here. codehive is built every night that something changed. Versions are the UTC date of the build, such as `2026.10.03`, with `.1`, `.2` added for any extra builds on the same day. Changes that need something from you after updating start with **Action needed:**.

Each build is also published on the [releases page](https://github.com/nstuck/codehive/releases), and `codehive status` tells you when a newer one is out.

## [Unreleased]

The first release.

### Added

- One installer, `install.sh`, that also works through `curl | bash`, and a `codehive` command to manage everything: `new`, `status`, `logs`, `restart`, `sync`, `trust`, `untrust`, `dirs`, `version`, `update`, and `uninstall`.
- A Remote Control server for every folder in one or more project folders, started, switched between modes, and stopped automatically as folders come and go.
- Git projects run in worktree mode, so each session gets its own worktree. Other folders run in same-dir mode.
- A launcher that creates new projects from any client.
- `AUTO_TRUST` setting for workspace trust, off by default. See [Workspace trust](https://github.com/nstuck/codehive/blob/v2026.10.02/docs/workspace-trust.md).
- `codehive untrust` to take trust away from a folder and stop its server.
- A daily check for new releases, shown in `codehive status`, `codehive version`, and at the start of launcher sessions. Turn it off with `UPDATE_CHECK=0` or `--no-update-check`.
- `codehive update` to reinstall from the repo and branch codehive came from.
- Server output is filtered before it reaches the journal, so status redraws don't flood the logs.

[Unreleased]: https://github.com/nstuck/codehive/commits/main
