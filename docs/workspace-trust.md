# Workspace trust

Claude Code asks you to trust a folder the first time it runs there, because a project's own settings can run commands on your server as soon as a session starts, before you've typed anything. A Remote Control server can't start in a folder until that's been accepted, and the services can't answer the dialog. So codehive accepts it for them, writing the same entry to `~/.claude.json` that Claude Code writes when you accept the dialog by hand.

The `AUTO_TRUST` setting decides which project folders that happens for.

| `AUTO_TRUST` | Installer flag | Which projects get a server |
|---|---|---|
| `0` (default) | `--no-auto-trust` | Only folders you've trusted. Anything else is left alone, and `codehive status` shows it as *not trusted*. |
| `1` | `--auto-trust` | Every folder in a project folder. Each sync trusts any it finds. |

With `AUTO_TRUST=0`, a folder counts as trusted when any of these is true:

- You ran `codehive trust <path>` on it.
- `codehive new` created it, either over SSH or from the launcher. A folder that didn't exist before holds nothing but an empty git repo, so it's trusted straight away. If the folder already existed, `codehive new` doesn't trust it, and tells you to review it and run `codehive trust`.
- You ran `claude` in it and accepted the trust dialog.

So a project you `git clone` or copy into a project folder doesn't start until you've looked at it and run `codehive trust`. The installer always trusts the launcher folder, since codehive writes everything in it.

**What an untrusted project can't do.** An untrusted project has no server, so for the clients it doesn't exist:

- It isn't in the session list on your phone, in a browser, or in Claude Desktop, so you can't start or continue a session in it from any of them. If it had a server before, its old entry stays in the list as offline (see [Known limitations](troubleshooting.md#known-limitations)).
- The launcher can't open it for you either. Asking the launcher for a project with an existing folder's name runs `git init` and the initial commit there if needed, but no server starts.

Nothing else changes. The folder isn't moved or modified, `codehive status` still lists it, and the sync starts its server within a minute once you trust it. Over SSH, you can still work in it with `claude` in a terminal. That shows the trust dialog, and accepting it trusts the folder for codehive too. Being untrusted doesn't protect the folder, though. Sessions in other projects, and the launcher, can still read and change its files.

`codehive untrust <path>` takes trust away again and stops the project's server. Any session open in it is cut off right away, the same as when a server stops for any other reason. In worktree mode, its worktrees and branches stay in the repo. With `AUTO_TRUST=1`, the next sync would trust it again, so mark the project with `.no-rc` instead.

To change the setting, edit `AUTO_TRUST` in the config, or run the installer again with `--auto-trust` or `--no-auto-trust`. It applies on the next sync, within a minute. Turning it off doesn't take trust away from folders that already have it, including every project that `AUTO_TRUST=1` trusted. Run `codehive untrust` on any you want to review again.

**What turning `AUTO_TRUST` on means for security.** Trusting a folder lets the files in it run commands on your server, as your user, without asking. A project's `.claude/settings.json` can define hooks, which are shell commands Claude Code runs when a session starts, when a tool runs, and at other points. It can also turn on the project's MCP servers, which are programs Claude Code starts, and allow tools so they run without a prompt. None of this goes through the permission mode, and none of it needs a session to do anything wrong. Opening the project from a client is enough. With `AUTO_TRUST=1`:

- **Whatever lands in a project folder is trusted within a minute, without your review.** A repo you clone to look at, a folder a sync tool copies in, or an archive you unpack all get a server, and their settings take effect the first time anyone opens a session in them.
- **Anything that can write to a project folder can run code as you.** That includes other users or services with write access to the folder, a sync tool and whoever else can write to what it syncs, and a Claude session in another project that's persuaded to create a folder there. Each of these could otherwise only write files. With auto-trust, they can get commands run, though still only when a session starts in that project.
- **Trust isn't per change.** Pulling new commits into a trusted project can add or change hooks, and nothing asks you again. This is true with either setting, but with `AUTO_TRUST=1` there was never a first review either.

Turn it on only if every way into your project folders is something you control and you review code before it gets there. A folder you can't vouch for belongs somewhere outside the project folders until you've read it, especially its `.claude/` folder, `.mcp.json`, and `CLAUDE.md`.

With `AUTO_TRUST=0`, the trust step is a review point, not a sandbox. A trusted project's hooks still run as you, and a session in any project can edit `~/.claude.json` or run `codehive trust` itself, subject to the permission mode. Only the launcher's settings block `codehive trust`. For stronger separation, see the hardening options in the [security model](security.md#optional-hardening).

**Keeping trust in place.** A Claude Code process can drop entries when it rewrites `~/.claude.json`. codehive keeps its own list of trusted folders in `~/.local/share/codehive/trusted`, and every sync puts back any entry missing from `~/.claude.json`. Folders you trusted through Claude Code's dialog are added to that list the first time a sync sees them. Folders marked with `.no-rc` are never trusted by the sync.

This depends on an internal Claude Code file format, not a documented interface, so a future update could change it. If trusted projects start getting stuck, `codehive status` shows *not trusted* next to them. In that case, run `claude` once in the folder to accept the dialog by hand.
