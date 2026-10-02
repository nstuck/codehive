# codehive: Claude Code on a Server, from Any Device

codehive turns a Linux server into a home base for Claude Code that you can use from the Claude iOS app, a web browser, or the Claude Desktop app. You can open any project, start new sessions, and create new projects without SSH.

Your files and code stay on the server, and the commands Claude runs execute there. As with any Claude Code session, your prompts, the file contents Claude reads, and the conversation go to Anthropic, which runs the model and keeps the transcript in sync across your devices. See [Where your data lives](docs/network-and-data.md#where-your-data-lives).

## How it works

Every folder in your project folders (`~/projects` by default) gets its own Claude Code Remote Control server, running as a systemd user service. Each one shows up by name in the session list of every client signed in to your claude.ai account. A **launcher** server creates new projects when you ask it to from any client. Servers start at boot, restart if they crash, and are added or removed as project folders come and go.

The server only makes outbound HTTPS connections, so no ports have to be opened. See [How it works](docs/how-it-works.md) for the details.

## Requirements

- A Claude Pro, Max, Team, or Enterprise plan. API keys don't work with Remote Control.
- A 64-bit Linux server that uses systemd, such as Debian or Ubuntu. See [Supported systems](docs/requirements.md#supported-systems).

## Install

Sign in to Claude Code on the server first, as described in [Installing codehive](docs/install.md), then run:

```bash
curl -fsSL https://raw.githubusercontent.com/nstuck/codehive/main/install.sh | bash
```

Then open the session list in any client and pick a project, or open **launcher** and ask for a new one. See [Connecting clients](docs/clients.md).

## Everyday commands

| Command | What it does |
|---|---|
| `codehive status` | Show the launcher and every project's server |
| `codehive new <name>` | Create a git project and start its server |
| `codehive trust <path>` | Trust a folder you added yourself, so it gets a server |
| `codehive logs <name>` | Show a server's log |
| `codehive restart [<name>]` | Restart one server, or all of them |
| `codehive update` | Update codehive |

Run `codehive restart`, `update`, and `uninstall` over SSH, not from a Claude session, because they can stop the server that session runs in. See [Daily use](docs/usage.md) for every command.

Projects you clone or copy in yourself don't get a server until you've reviewed them and run `codehive trust`. See [Workspace trust](docs/workspace-trust.md).

## Documentation

All documentation is in [docs/](docs/README.md):

- [Requirements](docs/requirements.md), [Installing codehive](docs/install.md), [Connecting clients](docs/clients.md), and [Manual install](docs/manual-install.md)
- [Daily use](docs/usage.md), [Git and non-git projects](docs/project-modes.md), [Workspace trust](docs/workspace-trust.md), [Configuration](docs/configuration.md), [Updating](docs/updating.md), [Troubleshooting](docs/troubleshooting.md), and [Uninstalling](docs/uninstall.md)
- [How it works](docs/how-it-works.md), [Network and data](docs/network-and-data.md), and [Security model](docs/security.md)

Changes between versions are listed in [CHANGELOG.md](CHANGELOG.md). [RELEASING.md](RELEASING.md) covers versioning and releases.

## License

[MIT](LICENSE)
