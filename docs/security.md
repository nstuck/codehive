# Security model

**Your claude.ai account is the key.** Anyone signed in to your claude.ai account can see your Remote Control sessions and send commands to your server. Those commands run with your server user's full permissions. Protecting this setup mostly comes down to protecting that account.

**codehive puts convenience ahead of security.** Its purpose is to make every project on your server reachable from any device at any time, and that's also what makes it risky. Read this page before you install it.

codehive is a layer over Claude Code's Remote Control feature. Each server it runs is a plain `claude remote-control`, the same one you'd start by hand in a terminal. Some of the risks below come with Remote Control itself, no matter how you run it. Others exist because of what codehive adds: servers that are always running, a launcher, and accepting workspace trust for you. This page keeps the two apart, so you can tell which risks you take on by using Remote Control at all and which come from choosing codehive.

## Risks that come with Remote Control

These apply to any Remote Control server, including one you start by hand in a terminal. codehive doesn't add them, and it can't remove them.

- **Account access means server access.** Anyone signed in to your claude.ai account, on any device, can open a session on any of your servers. A stolen password, a leaked session, or a device you forgot to sign out of is enough.
- **Approving a request works from anywhere.** By default, Claude asks before it runs a command or edits a file, but anyone who can open the session can approve the request. Permission prompts protect you from Claude doing something you didn't ask for. They don't protect you from someone else who has your account.
- **Sessions aren't limited to their project.** A session runs commands as your Linux user. It can read and change any file that user can, including other projects, `~/.ssh`, `~/.claude.json`, and your shell startup files. If that user can use `sudo` without a password, or is in the `docker`, `lxd`, or `incus` group, a session can get root.
- **Claude can be misled by what it reads.** Files, web pages, issues, and command output can contain instructions written to steer Claude. This is true of any Claude Code session. Remote Control makes it more likely you'll approve a request on a small phone screen without reading it closely.
- **Your conversations pass through Anthropic.** Transcripts, and any file contents Claude reads, are sent to Anthropic. See [Network and data](network-and-data.md).
- **A project's own settings can run code.** A project's `.claude/settings.json` can define hooks and turn on MCP servers, which run as you when a session starts. Claude Code's workspace trust dialog exists to make you review that first.

## Risks codehive adds or makes bigger

These come from what codehive does on top of Remote Control. Each one says what codehive does to limit it, and which settings change it.

- **Servers are always running.** A server you start by hand exists only while its terminal is open. codehive runs a server for every trusted project, starts them at boot, keeps them running while you're logged out, and restarts them if they crash. Someone who gets into your account can reach your server at any time, not only while you happen to have a server open. `codehive off` stops them all until you run `codehive on`.
- **There are more ways in.** Every trusted project, plus the launcher, shows up in the session list. Each one is a separate place to open a session.
- **codehive accepts the trust dialog for you.** The services can't answer the dialog, so codehive accepts it for folders you've trusted with `codehive trust` and for new projects made with `codehive new`. With the default `AUTO_TRUST=0`, a folder you clone or copy in waits for you to review it. With `AUTO_TRUST=1`, anything that can write to a project folder can get commands run as you. codehive also restores trust entries that Claude Code drops from `~/.claude.json`, so taking trust away has to be done with `codehive untrust`. See [Workspace trust](workspace-trust.md).
- **The launcher can make projects and start servers.** The launcher runs `codehive new`, which creates a folder, makes it a git repo, trusts it, and starts its server. It can also run `systemctl --user` commands like any session can, so it can start and stop your project servers. A normal Claude Code session on the server could do all of this too, but the launcher is built for it. With `LAUNCHER_AUTOAPPROVE=1`, it runs `codehive new` without asking. The launcher's settings deny `codehive trust`, `untrust`, `update`, `restart`, and `uninstall`, and Claude Code enforces that even in a permission mode that skips prompts. Deny rules match the start of a command, though, so a session that reaches the same thing another way, for example through `bash -c` or by editing `~/.claude.json`, isn't stopped. Sessions in your projects have no such rules.
- **One permission mode applies to every server.** `PERMISSION_MODE` sets the mode for every project and the launcher at once. `acceptEdits` lets every session edit files without asking, `auto` lets a classifier approve most actions without asking you, and `bypassPermissions` skips every prompt. (`dontAsk` and `plan` go the other way: they let sessions do less.)
- **Installing and updating run code from GitHub.** The installer, `curl | bash`, and `codehive update` download codehive from GitHub and run it as you. You're trusting the repo you install from, and anyone who can push to it. By default, both install the newest release, and `codehive update` shows what changed in each release since yours and asks before installing. `--ref main` follows every commit instead. The `curl | bash` one-liner runs the copy of `install.sh` on `main` first, which then downloads the release. To read everything before it runs, install from a clone. If Claude Code isn't installed, the installer offers to run Claude Code's official installer the same way.
- **Server output goes to your journal.** Each server's output, including session names and links, is logged to your user's systemd journal. You can read it, and so can members of the `systemd-journal` and `adm` groups.

## Optional hardening

`codehive status` ends with security notes when a setting, or your user account, lets sessions do more without asking: a looser `PERMISSION_MODE`, `AUTO_TRUST=1`, `LAUNCHER_AUTOAPPROVE=1`, passwordless `sudo`, or membership in the `docker`, `lxd`, or `incus` group. The installer shows the same notes when it finishes.

- **Trusted Devices (beta).** This requires each device to be enrolled, plus a recent sign-in or biometric check, before it can view or control Remote Control sessions. On Pro and Max plans, you turn it on yourself under **Require trusted devices** in your account settings. On Team and Enterprise plans, an Owner turns it on for the organization. This is the strongest protection against someone using your account from another device.
- **Keep the defaults for codehive's own settings.** `AUTO_TRUST=0`, `LAUNCHER_AUTOAPPROVE=0`, and an empty `PERMISSION_MODE` each keep a step where you review or approve something. Turn one on only once you've read what it skips.
- **Permission mode.** By default, Claude asks before running commands and editing files, and you approve each request from whichever client you're using. Loosening this, for example with `acceptEdits`, is more convenient but gives a session more freedom to act without asking. Avoid `bypassPermissions` on a server that's always reachable.
- **`HARDEN=1`.** Install with `--harden`, or set `HARDEN=1` in the config, run the installer again, and run `codehive restart`. Sessions then run with systemd's `NoNewPrivileges` and `RestrictSUIDSGID`, so nothing in them can gain privileges: `sudo`, `su`, and other setuid programs fail, and so do programs that need file capabilities, such as `ping`. It doesn't stop a session from using the `docker` group or anything else your user can already do.
- **A dedicated user account.** For stronger isolation, run the whole setup under a separate Linux user that can only access `~/projects`. Don't give that user passwordless `sudo` or put it in the `docker` group, and keep your SSH keys and other credentials out of its home folder.
- **Fewer projects.** Every trusted project is another server that's always reachable. Mark projects you're not working on with `.no-rc`, or `codehive untrust` them.

## If your account may be compromised

1. Cut the server off. From the launcher on any client, ask it to turn codehive off, or over SSH, run `codehive off`. Every server stops and stays stopped, even after a reboot. If you can't trust codehive's own files anymore, also run `claude auth logout` over SSH, so nothing on the server can connect to your account.
2. Secure the account in claude.ai: change your password, sign out other sessions, and turn on Trusted Devices.
3. Look at what happened. Session transcripts are in `~/.claude/projects/`. In worktree mode, each session's changes are on its own branch (`git worktree list`, `git branch`). `codehive logs <name>` shows when servers and sessions started. Check your shell startup files, `crontab -l`, `~/.config/systemd/user/`, `~/.ssh/authorized_keys`, and each project's `.claude/` folder for anything you didn't put there.
4. When you're done, run `claude auth login` if you signed out, and then `codehive on`.
