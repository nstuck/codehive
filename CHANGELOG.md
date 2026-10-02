# Changelog

All notable changes to codehive are listed here. Versions follow [semantic versioning](https://semver.org/): a major version changes what an existing install does or needs from you, a minor version adds something, and a patch fixes something.

Each release is also published on the [releases page](https://github.com/nstuck/codehive/releases), and `codehive status` tells you when a newer one is out.

## [Unreleased]

## [1.0.0] - 2026-10-02

The first release.

### Added

- One installer, `install.sh`, that also works through `curl | bash`, and a `codehive` command to manage everything: `new`, `status`, `logs`, `restart`, `sync`, `trust`, `untrust`, `dirs`, `version`, `update`, and `uninstall`.
- A Remote Control server for every folder in one or more project folders, started, switched between modes, and stopped automatically as folders come and go.
- Git projects run in worktree mode, so each session gets its own worktree. Other folders run in same-dir mode.
- A launcher that creates new projects from any client.
- `AUTO_TRUST` setting for workspace trust, off by default. See [Workspace trust](https://github.com/nstuck/codehive/blob/v1.0.0/docs/workspace-trust.md).
- `codehive untrust` to take trust away from a folder and stop its server.
- A daily check for new releases, shown in `codehive status`, `codehive version`, and at the start of launcher sessions. Turn it off with `UPDATE_CHECK=0` or `--no-update-check`.
- `codehive update` to reinstall from the repo and branch codehive came from.
- Server output is filtered before it reaches the journal, so status redraws don't flood the logs.

[Unreleased]: https://github.com/nstuck/codehive/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/nstuck/codehive/releases/tag/v1.0.0
