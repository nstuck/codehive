# Security model

**Your claude.ai account is the key.** Anyone signed in to your claude.ai account can see these sessions and send commands to your server. Those commands run with your server user's full permissions. Protecting this setup mostly comes down to protecting that account.

## Optional hardening

- **Trusted Devices (beta).** This requires each device to be enrolled, plus a recent sign-in or biometric check, before it can view or control Remote Control sessions. On Pro and Max plans, you turn it on yourself under **Require trusted devices** in your account settings. On Team and Enterprise plans, an Owner turns it on for the organization.
- **Permission mode.** By default, Claude asks before running commands and editing files, and you approve each request from whichever client you're using. Loosening this, for example with `acceptEdits`, is more convenient but gives a session more freedom to act without asking.
- **A dedicated user account.** For stronger isolation, run the whole setup under a separate Linux user that can only access `~/projects`.

**Projects need to be trusted before they're served.** The workspace trust dialog exists because a project's own settings, such as hooks in its `.claude/` folder, can run commands as soon as a session starts. The services can't answer that dialog, so codehive accepts it for folders you've trusted with `codehive trust` and for new projects made with `codehive new`. Anything else you put in a project folder waits for you to review it. The `AUTO_TRUST=1` setting trusts every project folder automatically instead, which means anything that can write to a project folder can get commands run as you. See [Workspace trust](workspace-trust.md) before turning it on.

**What the launcher can do.** The launcher runs `codehive new`, which runs `systemctl --user` commands as your user. This doesn't give it any power that a normal Claude Code session on the server lacks, but it does mean a launcher session can start and stop your project servers.
