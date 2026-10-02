# Troubleshooting

**A project doesn't appear in the session list.** Run `codehive status`. If it says *not trusted*, review the project and run `codehive trust <path>` (or `codehive sync` with `AUTO_TRUST=1`). If it still says that, Claude Code may have changed how it stores trust, so run `claude` in that folder once to accept the dialog by hand, then `codehive restart <name>`. Otherwise, check `codehive logs <name>`.

**"Remote Control requires a claude.ai subscription" or "...full-scope login token".** You're signed in with an API key or a limited token. Run `claude auth login` again with your claude.ai account, and remove any `ANTHROPIC_*` variables from your environment and settings files.

**"Remote Control is disabled by your organization's policy".** On Team or Enterprise plans, an Owner needs to turn on Remote Control in the Claude Code admin settings.

**Sessions can't find tools like `node` or `python`.** The `PATH` saved in the service files is missing something. Fix `PATH` in your shell, run the installer again, then run `codehive restart`.

**A session shows as active but nothing responds.** On iPhone, the app's connection can drop after it's been in the background, so close and reopen the app. In a browser or Claude Desktop, reload the page or reopen the session. If that doesn't help, run `codehive restart <name>`.

**Two projects show with folder prefixes, like `projects/app` and `work/app`.** Two of your project folders have a project with the same name. Rename one to get plain names back. Names are worked out when a server starts, so run `codehive restart <name>` after renaming.

**Run diagnostics:** `claude doctor`

## Known limitations

- **Reconnect flakiness.** The iOS app can lose its connection after being in the background. Reopening the app or restarting the project's service fixes it.
- **Claude Desktop can also run sessions locally.** A new session started in a folder on your workstation runs on the workstation, not the server. Open server projects from the session list so sessions run on the server.
- **Old servers stay in the session list.** Each project folder registers its own entry, called an environment, in every client's session list. Stopping a server, even cleanly, doesn't remove its entry: Remote Control keeps it so that restarting `claude remote-control` in the same folder reconnects its existing sessions. When you delete a project or move the launcher, its entry stays in the list as an offline server. Neither the server nor any client can remove it. You can archive its sessions by hand in claude.ai/code or the app, and archived sessions still appear in the Archived view. Renaming or moving a project folder leaves its old entry behind too, because the new folder registers a new one. Stop servers with `systemctl` or `codehive`, never `kill -9`, so their sessions can be reconnected later.
- **Manage servers from a terminal.** A Claude session's commands run inside its server, so `codehive restart`, `update`, `uninstall`, or the installer run from a session can stop the server they run in and be cut off partway. Run them over SSH or on a console.
- **Trust relies on an internal file.** `codehive trust` writes to Claude Code's `~/.claude.json`, which isn't a documented interface. A future Claude Code update could change it, and then projects would need to be trusted by running `claude` in them and accepting the dialog.
- **Project names.** `codehive new` only accepts letters, numbers, `.`, `_`, and `-`. Folders you create yourself can have any name. If two project folders contain a project with the same name, both show with their parent folder's name in front, like `work/app`.
- **`codehive new` makes existing folders git repos.** Run on a folder that already exists, it runs `git init` there and makes an empty commit, which moves the project to worktree mode.
- **First commit delay.** A project switches to worktree mode within a minute of its first commit, not instantly.
- **Some commands only work in a terminal.** Commands like `/plugin` and `/resume` only run in a local terminal session. Most text-based commands, plus `/model`, `/effort`, `/config`, and `/mcp`, work from any client.
- **No new projects while the server is offline.** Sessions run on your server, so if it's off or unreachable, no projects or sessions are available. Use Claude Code's cloud sessions for work that shouldn't depend on your server.
