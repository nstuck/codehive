# Requirements

- A Claude **Pro, Max, Team, or Enterprise** plan. API keys don't work with Remote Control. On Team or Enterprise plans, an Owner has to turn on Remote Control in the Claude Code admin settings.
- A 64-bit Linux system that uses systemd. See [Supported systems](#supported-systems).
- `curl`, `git`, and `python3` (standard on most distributions).
- At least one client signed in to the same account: the Claude iOS app, a browser at claude.ai/code, or the Claude Desktop app.

## Supported systems

codehive runs on 64-bit Linux systems that Claude Code supports and that use systemd to start and supervise services. Every server is a systemd user service.

| System | Status | Tested |
|---|---|---|
| Debian 13, x86_64 | Works. codehive is developed here, and its automated tests run here on every change. | Tested |
| Debian 13, ARM64 | Expected to work. codehive's automated tests pass here on every change. | Partially tested |
| Ubuntu 24.04, x86_64 and ARM64 | Expected to work. codehive's automated tests pass here on every change. | Partially tested |
| Debian 10+ and other Ubuntu 20.04+ | Expected to work. Claude Code officially supports these. | Unconfirmed |
| Fedora, and RHEL 8+ with its rebuilds (Rocky, AlmaLinux) | Expected to work. Claude Code publishes dnf packages for them. | Unconfirmed |
| Other 64-bit ARM (for example, a Raspberry Pi 4 or 5 with a 64-bit OS) running any of the above | Expected to work. Claude Code ships ARM64 builds. | Unconfirmed |
| Other systemd distributions (Arch, openSUSE, Linux Mint, Pop!_OS, ...) | Likely to work. Claude Code doesn't list them, but its standard Linux build usually runs on them. | Unconfirmed |

*Tested* means codehive has been used there with real Claude Code and Remote Control. *Partially tested* means codehive's automated tests run there on every change: they install codehive and drive real systemd services through every `codehive` command, but with a stand-in for Claude Code, so Remote Control itself isn't covered. See [Releasing](../RELEASING.md#checks-on-every-change).

In detail, the installer and scripts need:

- **systemd with user services.** `systemctl --user` has to work in a login session, and `loginctl enable-linger` has to be available so the servers keep running after you log out. The installer checks this. If it reports no systemd user session, log in over SSH instead of switching users with `su` or `sudo`.
- **bash 4.4 or newer, GNU coreutils, and `flock` from util-linux.** Any systemd distribution from the last several years has these.
- **Enough memory for your projects.** Claude Code recommends at least 4 GB of RAM. Each project runs its own server process, and each open session adds another, so the memory you need grows with the number of projects and sessions you use at once.

If you run codehive on a system marked *Unconfirmed*, please open an issue saying whether it worked, so this table can be updated.
