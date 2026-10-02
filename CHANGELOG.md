# Changelog

All notable changes to codehive are listed here. codehive is built every night that something changed. Versions are the UTC date of the build, such as `2026.10.03`, with `.1`, `.2` added for any extra builds on the same day. Changes that need something from you after updating start with **Action needed:**.

Each build is also published on the [releases page](https://github.com/nstuck/codehive/releases), and `codehive status` tells you when a newer one is out.

## [Unreleased]

### Added

- `codehive off` stops every server, including the launcher, and keeps them stopped across reboots until `codehive on`. The launcher can run `codehive off` when you ask it to.
- `codehive status` ends with security notes about settings and account details that let sessions do more without asking, such as `AUTO_TRUST=1` or passwordless `sudo`.
- `HARDEN` setting (`--harden`), off by default, that stops sessions from gaining privileges, so `sudo`, `su`, and other setuid programs don't work in them.
- A security model that separates the risks that come with Remote Control from the ones codehive adds. See [Security model](https://github.com/nstuck/codehive/blob/main/docs/security.md).

### Changed

- **Action needed:** `codehive update` and the `curl | bash` install now install the newest release instead of the latest commit on `main`, and `update` shows the release notes of every release since yours and asks before installing. Installs made before this keep following `main`. To follow releases, run `codehive update --ref latest` once.
- The launcher's settings deny `codehive trust`, `untrust`, `update`, `restart`, and `uninstall`. The launcher now gives you the command to run over SSH instead.

## [2026.10.02] - 2026-10-02

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

[Unreleased]: https://github.com/nstuck/codehive/compare/v2026.10.02...HEAD
[2026.10.02]: https://github.com/nstuck/codehive/releases/tag/v2026.10.02
