# How it works

This page explains the services codehive runs and how they keep the servers matched to your project folders. For how traffic moves and where your data goes, see [Network and data](network-and-data.md).

## The big picture

```
┌────────────────────────── Your server ──────────────────────────┐
│                                                                 │
│  systemd (user)                                                 │
│   ├── claude-rc-launcher ──► Remote Control server              │
│   │                          (creates new projects)             │
│   │                                                             │
│   ├── claude-rc@…-app-one ─► Remote Control server              │
│   ├── claude-rc@…-app-two ─► Remote Control server              │
│   ├── claude-rc-plain@…-notes ► Remote Control server           │
│   │                          one per folder in each project dir │
│   │                                                             │
│   ├── claude-rc-watch@….path ─┐ a project dir changes           │
│   └── claude-rc-sync.timer ───┴► claude-rc-sync                 │
│                                  matches servers to the folders │
└─────────────────────────────────────────────────────────────────┘
```

Projects live in one or more project folders: `~/projects` by default, or any list you set in `~/.config/codehive/config`. Each project inside them has its own long-running `claude remote-control` process. Each process appears as one entry in every client's session list and can run many sessions at once. The launcher is the same kind of process, but it lives outside the project folders. Its only job is to create new projects.

Everything is managed with one command, `codehive` (`new`, `status`, `logs`, `restart`, `sync`, `trust`, `untrust`, `dirs`, `off`, `on`, `version`, `update`, `uninstall`). Changes between versions are listed in [CHANGELOG.md](../CHANGELOG.md).

---

## Components

**Remote Control servers.** A `claude remote-control` process in server mode doesn't hold a single conversation. It waits for a client to ask for a session and then starts one. This is what lets you begin new work from your phone, a browser, or Claude Desktop instead of only continuing work you started in a terminal.

**Two service templates.** Each server's unit is named after its project's full path, escaped the systemd way (`~/work/app` becomes `claude-rc@home-you-work-app`), so projects with the same name in different project folders don't collide. Git projects run with `--spawn worktree`, which gives each session its own git worktree, so parallel sessions can't overwrite each other's files. Folders that aren't git repos can't use worktrees, so they run with `--spawn same-dir`, and all their sessions share the folder. See [Git and non-git projects](project-modes.md) for what each mode means day to day.

**The sync script, watches, and timer.** The layout of the project folders is the configuration. The sync script compares the folders there with the running services and fixes any difference:

| Situation | Result |
|---|---|
| New trusted folder | A server starts for it |
| New folder you haven't trusted | Nothing, until you run `codehive trust` (or right away with `AUTO_TRUST=1`) |
| Folder becomes a git repo with a commit | It switches from the plain service to the worktree service |
| Folder stops being a git repo (its `.git` is deleted) | It switches back to the plain service |
| Folder deleted, moved, or marked with `.no-rc` | Its server stops and is disabled |
| Project folder removed from the config | Servers for all its projects stop |

A systemd path unit watches each project folder, so adding, removing, or renaming a project runs the sync right away, however the change was made: `git clone` over SSH, the launcher, a file manager, or a sync tool. The watch only sees the top level of each folder. A timer also runs the sync every minute to catch the one change it can't see: a project's first commit, which happens inside the project.

**The launcher.** This is a Remote Control server whose working folder holds only a `CLAUDE.md` file with instructions. When you ask it for a new project, Claude runs `codehive new`. That creates the folder in the first project folder (or another one you name), sets it up as a git repo with an initial commit, trusts it, and runs the sync. The launcher is kept outside the project folders so that it isn't served as a project itself and its sessions don't treat every project as part of their own workspace.

**The update check.** A timer asks GitHub once a day whether there's a newer codehive release. If there is, `codehive status` says so, and so does the launcher the next time you open it. Nothing updates on its own. See [Update notices](updating.md#update-notices).

**systemd user services.** These keep everything running without a terminal open. Lingering lets the services run while you're logged out and start at boot. `Restart=always` brings a server back if it crashes or exits. That matters because a server gives up and exits after about 10 minutes without network access.

---

## What happens when…

**The server boots.** systemd starts the launcher, the folder watches, and the sync timer. Thirty seconds later, the first sync run starts a server for every trusted project. Each server registers with Anthropic, and your projects show up as online in every client.

**You start a session from a client.** The client asks that project's server for a new session. The server starts a Claude Code session on your server, inside a new worktree for git projects. Your messages go into that session, and the output streams back to the client.

**You create a project from a client.** You ask the launcher and Claude runs `codehive new`. The new project appears in the session list a few seconds later as its own entry.

**You switch devices.** Every client is a view of the same sessions. You can start a task in a browser at your desk and continue it from your phone, because the conversation stays in sync across connected clients.

**You close a client or lose signal.** Nothing stops on the server. Sessions keep running, and you can reconnect later from the same client or a different one. If a client shows a stale session, reopening it usually fixes that.

**The server loses its internet connection.** Servers exit after about 10 minutes offline. systemd keeps restarting them, and they come back online once the connection returns.
