# Installing codehive

Check the [requirements](requirements.md) first. `install.sh` does most of the setup. The steps you do by hand are the ones that need a browser sign-in or a one-time interactive prompt.

`install.sh` is the only supported way to install codehive. [Manual install](manual-install.md) lists every step it takes, for reference.

Do everything as your normal user, not as root. Claude Code and every service run under your own account. The installer only uses `sudo` once, to turn on lingering.

## 1. Install Claude Code

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

The native installer doesn't need root. It puts the `claude` binary at `~/.local/bin/claude` and keeps itself updated in the background. If `claude` isn't found afterwards, add `~/.local/bin` to your `PATH`:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

If you skip this step, the codehive installer offers to install Claude Code for you.

**Alternative (Debian/Ubuntu package):** Anthropic also publishes an apt repository. See https://code.claude.com/docs/en/install. In that case, update with `sudo apt upgrade claude-code`.

---

## 2. Sign in and answer the one-time prompts

```bash
# Sign in with your claude.ai account (choose the claude.ai option)
claude auth login

# Git identity is needed for the initial commit of new projects
git config --global user.name "Your Name"
git config --global user.email "you@example.com"

# Answer "y" to "Enable Remote Control?", then press Ctrl+C
claude remote-control
```

**Signing in over SSH:** the server has no browser, so `claude auth login` prints a URL. Open it on your phone or another computer, sign in, and paste the code back into the terminal.

The servers inherit your environment, so make sure nothing in it blocks Remote Control. The installer checks both your shell and the systemd user manager for these:

- `ANTHROPIC_API_KEY`, `ANTHROPIC_AUTH_TOKEN`, and `ANTHROPIC_BASE_URL` must **not** be set.
- `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` and `DISABLE_GROWTHBOOK` must **not** be set.
- Don't use tokens from `claude setup-token` or `CLAUDE_CODE_OAUTH_TOKEN`, because they can't start Remote Control sessions.

---

## 3. Run the installer

```bash
curl -fsSL https://raw.githubusercontent.com/nstuck/codehive/main/install.sh | bash
```

This downloads the repo to a temporary folder, runs its installer, and deletes the temporary folder afterwards. Questions are asked on your terminal as usual.

To read the code before running it, clone the repo instead:

```bash
git clone https://github.com/nstuck/codehive.git ~/codehive
cd ~/codehive
./install.sh
```

Both ways take the same options. With curl, put them after `bash -s --`. With no options, projects live in `~/projects`. To choose your own folders, pass `--project-dir` once for each folder. The first one is where new projects are created:

```bash
curl -fsSL https://raw.githubusercontent.com/nstuck/codehive/main/install.sh | bash -s -- --project-dir ~/projects --project-dir ~/work
# or, from a clone:
./install.sh --project-dir ~/projects --project-dir ~/work
```

To install a specific release instead of the latest `main`, set `CODEHIVE_REF` to a tag from the [releases page](https://github.com/nstuck/codehive/releases) or a branch:

```bash
curl -fsSL https://raw.githubusercontent.com/nstuck/codehive/main/install.sh | CODEHIVE_REF=v2026.10.02 bash
```

`CODEHIVE_REPO` installs from a fork (default `nstuck/codehive`).

| Option | Default | What it does |
|---|---|---|
| `--project-dir <dir>` | `~/projects` | A folder whose subfolders are projects. Repeat for several. Replaces the saved list when given. |
| `--launcher-dir <dir>` | `~/.local/share/codehive/launcher` | The launcher's workspace |
| `--bin-dir <dir>` | `~/.local/bin` | Where the `codehive` command goes. Should be on your `PATH`. |
| `--permission-mode <mode>` | Claude Code's default | Permission mode for every session (`acceptEdits`, `auto`, ...) |
| `--accept-edits` | | Same as `--permission-mode acceptEdits` |
| `--launcher-autoapprove` | off | Let the launcher run `codehive new` without asking each time |
| `--auto-trust` | off | Trust every project folder automatically. Read [Workspace trust](workspace-trust.md) first. |
| `--no-update-check` | checks on | Don't check GitHub for new codehive releases (see [Update notices](updating.md#update-notices)) |
| `-y`, `--yes` | | Don't ask for confirmation |

Your choices are saved to `~/.config/codehive/config` and reused the next time you run the installer, so you only pass them once. Project folders can't be inside each other or contain the launcher folder.

The installer:

1. Checks the requirements, your sign-in, and the environment variables above, and offers to install Claude Code if it's missing.
2. Copies the scripts and fills in the systemd unit files with the path to `claude` and your current `PATH`. Without your `PATH`, sessions would only see systemd's minimal default, and tools installed through nvm, `~/.local/bin`, and so on wouldn't be found.
3. Writes the launcher's `CLAUDE.md`, which tells the launcher's Claude how to create projects, and its `.claude/settings.json` (see [The launcher's settings](configuration.md#the-launchers-settings)).
4. Marks the launcher folder as trusted (see [Workspace trust](workspace-trust.md)).
5. Turns on lingering (`sudo loginctl enable-linger`), so the services keep running when you're logged out and start at boot.
6. Starts the launcher, the sync timer, the daily update check, and a watch on each project folder, then starts a server for every trusted project.
7. Prints `codehive status`.

The installer can be run again at any time. It rewrites the installed files from the repo and the config, and leaves running servers alone. If the service files changed, it tells you to run `codehive restart`.

## 4. Verify

```bash
codehive status
```

This lists the launcher, the sync timer, and every project folder with its server's state and mode (`worktree` for git projects, `same-dir` for the rest). Folders that were already in a project folder show *not trusted* until you run `codehive trust` on them, unless you'd trusted them in Claude Code before (see [Workspace trust](workspace-trust.md)).

Open the session list in any client (see [Connecting clients](clients.md)). **launcher** and each project should be listed, each with a green dot when it's online.

Then test the full flow from a client:

1. Open **launcher** and type: *"New project called rc-test."*
2. Within a few seconds, **rc-test** appears in the session list.
3. Open it and start a session.
4. Afterwards, delete the folder with `rm -rf ~/projects/rc-test`. Its server stops right away.

Next, [connect your clients](clients.md).
