# codehive: Claude Code on a Server, from Any Device

codehive turns a Linux server into a home base for Claude Code that you can use from the Claude iOS app, a web browser, or the Claude Desktop app. You can open any project, start new sessions, and create new projects without SSH.

> [!WARNING]
> **codehive puts convenience ahead of security.** It keeps a Claude Code server running at all times for every project, and anyone signed in to your claude.ai account can use them to run commands on your server as your user. Some of these risks come with Claude Code's Remote Control feature itself, and some come from what codehive adds. codehive's guardrails are a reasonable effort, not an audited security boundary (see [About this project](#about-this-project)). Read the [Security model](docs/security.md) and make sure you understand it before you install codehive.

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
| `codehive update` | Update codehive to the newest release |
| `codehive off` / `on` | Stop every server until you turn them back on |

Run `codehive restart`, `update`, and `uninstall` over SSH, not from a Claude session, because they can stop the server that session runs in. See [Daily use](docs/usage.md) for every command.

Projects you clone or copy in yourself don't get a server until you've reviewed them and run `codehive trust`. See [Workspace trust](docs/workspace-trust.md).

## Documentation

All documentation is in [docs/](docs/README.md):

- [Requirements](docs/requirements.md), [Installing codehive](docs/install.md), [Connecting clients](docs/clients.md), and [Manual install](docs/manual-install.md)
- [Daily use](docs/usage.md), [Git and non-git projects](docs/project-modes.md), [Workspace trust](docs/workspace-trust.md), [Configuration](docs/configuration.md), [Updating](docs/updating.md), [Troubleshooting](docs/troubleshooting.md), and [Uninstalling](docs/uninstall.md)
- [How it works](docs/how-it-works.md), [Network and data](docs/network-and-data.md), and [Security model](docs/security.md)

Changes between versions are listed in [CHANGELOG.md](CHANGELOG.md). [DEVELOPING.md](DEVELOPING.md) covers working on codehive itself, and [RELEASING.md](RELEASING.md) covers version numbers, tests, nightly builds, and releases.

## About this project

codehive is my first public project, and it's vibe coded: it was written entirely with Claude Code, and it will keep being made that way. Every build is tried on a real server before it becomes a release.

I'm not a security specialist. I've made every reasonable effort to put guardrails in place wherever they don't get in the way of what codehive is for, and the [Security model](docs/security.md) lists the risks I know about and what codehive does about each. The guardrails haven't been audited, though, and I expect someone with real security expertise could find ways around them. Read the security model before you install, and decide for yourself whether the trade-offs suit your server.

Suggestions and bug reports are welcome as [GitHub issues](https://github.com/nstuck/codehive/issues).

## License

[MIT](LICENSE)
