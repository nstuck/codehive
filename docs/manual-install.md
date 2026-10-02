# Manual install

> **Unsupported.** `install.sh` is the only supported way to install codehive. This walkthrough does the same things it does, one step at a time, so you can see and control each change to your system. If something goes wrong, or you'd rather not maintain it by hand later, run `./install.sh` from your clone. It picks up your config and turns a manual install into a supported one.

By the end you'll have the same setup the installer creates: the `codehive` command, a Remote Control server for each trusted project, the launcher, and the timers and watches that keep them in sync.

Everything runs as your normal user. Only one step, turning on lingering, needs `sudo`. Use a terminal over SSH or at a console, not a Claude session: sessions on a codehive server have `CODEHIVE_CONFIG` and `CODEHIVE_DATA` set, which would point these steps at the existing install, and later steps restart the server that session runs in. Run every command from your clone's folder, in the same terminal: later steps use shell variables that step 4 sets. If you get disconnected, `cd` back to the clone and run step 4 again before you continue.

## Before you start

Make sure you have:

- A system that meets the [requirements](requirements.md).
- Claude Code installed and signed in with your claude.ai account, with the one-time Remote Control prompt answered. That's steps 1 and 2 of [Installing codehive](install.md).
- Your git name and email set, because `codehive new` makes an initial commit in each new project:

  ```bash
  git config --global user.name "Your Name"
  git config --global user.email "you@example.com"
  ```

## 1. Get the code

Clone the repo somewhere you'll keep it. The clone stays in use after the install, because it's where you update from later:

```bash
git clone https://github.com/nstuck/codehive.git ~/codehive
cd ~/codehive
```

To install a specific release instead of the latest `main`, check out its tag, for example `git checkout v1.0.0`.

## 2. Check your system

codehive needs a handful of standard tools. This prints a line for each one that's missing:

```bash
for cmd in git systemctl systemd-escape journalctl loginctl flock realpath python3 curl; do
  command -v "$cmd" >/dev/null || echo "missing: $cmd"
done
```

No output means you have them all. Install anything missing with your distribution's package manager.

Next, check that you have a systemd user session. Every codehive server is a systemd user service, so this has to work:

```bash
systemctl --user show-environment >/dev/null && echo "user session OK"
```

If it fails with an error about the bus or `XDG_RUNTIME_DIR`, you probably switched to this user with `su` or `sudo`. Log in as the user directly, over SSH or at a console, and start again from step 1.

Some environment variables stop Remote Control from starting. The servers inherit both your shell's environment and the systemd user manager's, so check both:

```bash
for v in ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL CLAUDE_CODE_OAUTH_TOKEN \
         CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC DISABLE_GROWTHBOOK; do
  [ -n "${!v:-}" ] && echo "set in your shell: $v"
  systemctl --user show-environment | grep -q "^$v=" && echo "set in systemd: $v"
done
```

If anything is printed, clear it:

- **Set in your shell:** remove it from wherever it's set, such as `~/.bashrc` or `~/.profile`, then log out and back in.
- **Set in systemd:** run `systemctl --user unset-environment <NAME>`. If it comes back after a reboot, look for it in `~/.config/environment.d/`.

Finally, confirm Claude Code is signed in with a claude.ai account rather than an API key:

```bash
claude auth status
```

The output should include `"authMethod": "claude.ai"`. If it doesn't, run `claude auth login` and choose the claude.ai option.

## 3. Choose your settings

codehive reads its settings from a config file. Start from the example in the repo:

```bash
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/codehive"
cp config.example "${XDG_CONFIG_HOME:-$HOME/.config}/codehive/config"
nano "${XDG_CONFIG_HOME:-$HOME/.config}/codehive/config"
```

The defaults suit most setups. Here's what each setting decides. Write paths as `"$HOME/..."`, not `~/...`, because `~` doesn't expand inside quotes.

**`PROJECT_DIRS`: where your projects live.** Each subfolder of these folders becomes a project with its own server. The default is `~/projects`. List more than one folder to keep, for example, work and personal projects apart. `codehive new` creates projects in the first folder unless you name another. The folders can't be inside each other.

**`LAUNCHER_DIR`: the launcher's workspace.** The launcher is the server you ask for new projects. Its folder holds only its instructions, so the default under `~/.local/share` is fine unless you want it somewhere visible. It can't be inside a project folder.

**`BIN_DIR`: where the `codehive` command goes.** The default, `~/.local/bin`, is already on `PATH` for most distributions, and it's where Claude Code installs itself. Choose another folder only if you have a reason to.

**`PERMISSION_MODE`: how much sessions can do without asking.** Empty means Claude Code's default: Claude asks before running commands or editing files, and you approve each request from your client. `acceptEdits` lets it edit files without asking, which is more convenient on a phone but gives sessions more room. See [Optional hardening](security.md#optional-hardening).

**`LAUNCHER_AUTOAPPROVE`: whether the launcher asks before creating a project.** With `0`, the default, you approve each `codehive new` from your client. `1` skips that prompt. Creating a project only makes an empty git repo, so the risk is low either way.

**`AUTO_TRUST`: whether every project folder is trusted automatically.** Leave this at `0` unless you've read [Workspace trust](workspace-trust.md). With `0`, a folder you clone or copy in yourself gets no server until you review it and run `codehive trust`. With `1`, anything that lands in a project folder is trusted within a minute, and its settings can run commands as you.

**`UPDATE_CHECK`: whether to check for new releases.** With `1`, codehive asks GitHub once a day whether there's a newer release, and tells you in `codehive status` and in the launcher. It sends nothing about you or your projects. Set it to `0` if the server shouldn't contact GitHub. See [Update notices](updating.md#update-notices).

Save the file and exit (in nano, Ctrl+O, Enter, Ctrl+X).

## 4. Load your settings into the shell

The rest of the steps use your settings and a few derived values. This block loads them the same way codehive's own scripts do. Run it now, and again if you open a new terminal partway through:

```bash
cd ~/codehive     # or wherever you cloned it
. lib/common.sh    # reads your config, and sets CODEHIVE_CONFIG and CODEHIVE_DATA
BIN_DIR="$(normpath "$BIN_DIR")"
UNIT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/systemd/user"
CLAUDE_BIN="$(command -v claude || echo "$HOME/.local/bin/claude")"
UNIT_PATH="${PATH//%/%%}"    # % has a special meaning in unit files
LAUNCHER_ALLOW=""
[ "$LAUNCHER_AUTOAPPROVE" = 1 ] && LAUNCHER_ALLOW="\"Bash($BIN_DIR/codehive new:*)\""

# Fills in the @PLACEHOLDERS@ in the templates under bin/, systemd/, and launcher/
render() {
  local content
  content="$(<"$1")"
  content="${content//@CLAUDE_BIN@/"$CLAUDE_BIN"}"
  content="${content//@PATH@/"$UNIT_PATH"}"
  content="${content//@LIBEXEC@/"$CODEHIVE_DATA/libexec"}"
  content="${content//@LAUNCHER_DIR@/"$LAUNCHER_DIR"}"
  content="${content//@BIN_DIR@/"$BIN_DIR"}"
  content="${content//@CODEHIVE_CONFIG@/"$CODEHIVE_CONFIG"}"
  content="${content//@CODEHIVE_DATA@/"$CODEHIVE_DATA"}"
  content="${content//@LAUNCHER_ALLOW@/"$LAUNCHER_ALLOW"}"
  content="${content//@PROJECT_DIRS_LIST@/"$(printf -- '- %s\n' "${PROJECT_DIRS[@]}")"}"
  printf '%s\n' "$content"
}
```

Check that the values look right:

```bash
printf 'projects: %s\n' "${PROJECT_DIRS[@]}"
echo "launcher: $LAUNCHER_DIR"
echo "command:  $BIN_DIR/codehive"
echo "claude:   $CLAUDE_BIN"
"$CLAUDE_BIN" --version
```

The last line should print a Claude Code version. If it doesn't, `claude` isn't on your `PATH`. Fix that and run this step again.

None of these paths can contain `"`, `$`, `` ` ``, `\`, or `%`, because they're written into unit files and scripts. This prints any that do:

```bash
for p in "${PROJECT_DIRS[@]}" "$LAUNCHER_DIR" "$BIN_DIR" "$CODEHIVE_CONFIG" "$CODEHIVE_DATA" "$UNIT_DIR"; do
  [[ "$p" =~ [\"\$\`\\%] ]] && echo "unsupported character in: $p"
done
```

Also check your `PATH` itself. It gets copied into every service, and that's the only `PATH` your sessions will have. If you load tools like `node` through nvm, pyenv, or similar, make sure they're on `PATH` in this shell now. Otherwise sessions won't find them.

## 5. Install the scripts

codehive's helper scripts live in `~/.local/share/codehive`. They aren't templates, so they're copied as they are:

```bash
mkdir -p "$CODEHIVE_DATA/lib" "$CODEHIVE_DATA/libexec"
install -m 644 lib/common.sh "$CODEHIVE_DATA/lib/common.sh"
for f in claude-rc-sync claude-rc-run claude-rc-logfilter claude-trust claude-rc-update-check; do
  install -m 755 "libexec/$f" "$CODEHIVE_DATA/libexec/$f"
done
install -m 644 VERSION "$CODEHIVE_DATA/VERSION"
install -m 755 uninstall.sh "$CODEHIVE_DATA/uninstall.sh"
```

They are:

- `claude-rc-sync`: matches running servers to your project folders.
- `claude-rc-run`: starts one Remote Control server.
- `claude-rc-logfilter`: keeps the server's status display from flooding the journal.
- `claude-trust`: records workspace trust.
- `claude-rc-update-check`: the daily release check.

`VERSION` and `uninstall.sh` are used by `codehive version` and `codehive uninstall`.

## 6. Install the `codehive` command

The command is a template, because it needs to know where your config and scripts are:

```bash
mkdir -p "$BIN_DIR"
render bin/codehive.in >"$BIN_DIR/codehive"
chmod 755 "$BIN_DIR/codehive"
```

Check that your shell finds it:

```bash
command -v codehive || echo "$BIN_DIR isn't on your PATH"
```

If it isn't on your `PATH`, add `export PATH="$BIN_DIR:$PATH"` to `~/.bashrc`, using the real folder name, and open a new terminal. You can keep going in the meantime by typing `"$BIN_DIR/codehive"` instead of `codehive`.

## 7. Install the systemd units

These unit files define the services. They're templates too: each one gets the path to `claude`, your `PATH`, and the codehive locations filled in.

```bash
mkdir -p "$UNIT_DIR"
for f in claude-rc@.service claude-rc-plain@.service claude-rc-launcher.service \
         claude-rc-sync.service claude-rc-update-check.service; do
  render "systemd/$f.in" >"$UNIT_DIR/$f"
  chmod 644 "$UNIT_DIR/$f"
done
for f in claude-rc-sync.timer claude-rc-update-check.timer claude-rc-watch@.path; do
  install -m 644 "systemd/$f" "$UNIT_DIR/$f"
done
```

They go in `~/.local/share/systemd/user`, the folder systemd reads for user units installed by packages. That leaves `~/.config/systemd/user` free for your own overrides. [How it works](how-it-works.md) explains what each unit does.

## 8. Set up the launcher

The launcher's folder holds two files. `CLAUDE.md` tells the launcher's Claude how to create projects. `.claude/settings.json` holds the hook that shows update notices in launcher sessions, plus the `codehive new` permission if you set `LAUNCHER_AUTOAPPROVE=1`.

First check whether there's a settings file there that codehive didn't write:

```bash
if [ -e "$LAUNCHER_DIR/.claude/settings.json" ] &&
   ! grep -qxF "$LAUNCHER_DIR/.claude/settings.json" "$CODEHIVE_DATA/manifest" 2>/dev/null; then
  echo "you have your own settings file"
else
  echo "no settings file of your own"
fi
```

If it prints *no settings file of your own*, write both files. This also replaces a settings file from an earlier run of this walkthrough:

```bash
mkdir -p "$LAUNCHER_DIR/.claude"
render launcher/CLAUDE.md.in >"$LAUNCHER_DIR/CLAUDE.md"
render launcher/settings.json.in >"$LAUNCHER_DIR/.claude/settings.json"
chmod 644 "$LAUNCHER_DIR/CLAUDE.md" "$LAUNCHER_DIR/.claude/settings.json"
OWN_SETTINGS=0
```

If it prints *you have your own settings file*, the installer wouldn't replace it either. Write only `CLAUDE.md`, and add the hook and permission to your file by hand. [The launcher's settings](configuration.md#the-launchers-settings) shows what to add.

```bash
render launcher/CLAUDE.md.in >"$LAUNCHER_DIR/CLAUDE.md"
chmod 644 "$LAUNCHER_DIR/CLAUDE.md"
OWN_SETTINGS=1
```

Then create your project folders, if they don't exist yet:

```bash
for root in "${PROJECT_DIRS[@]}"; do mkdir -p "$root"; done
```

## 9. Record the install

Two small files let codehive maintain itself. `source` tells `codehive update` where you installed from: this clone. The manifest lists every file that was installed, and `codehive uninstall` removes exactly those files and nothing else.

```bash
{
  echo "# Where codehive was installed from; \`codehive update\` installs from here again"
  printf 'CODEHIVE_CHECKOUT=%q\n' "$PWD"
} >"$CODEHIVE_DATA/source"

{
  printf '%s\n' "$CODEHIVE_DATA/lib/common.sh"
  for f in claude-rc-sync claude-rc-run claude-rc-logfilter claude-trust claude-rc-update-check; do
    printf '%s\n' "$CODEHIVE_DATA/libexec/$f"
  done
  printf '%s\n' "$CODEHIVE_DATA/VERSION" "$CODEHIVE_DATA/uninstall.sh" "$BIN_DIR/codehive"
  for f in claude-rc@.service claude-rc-plain@.service claude-rc-launcher.service claude-rc-sync.service \
           claude-rc-update-check.service claude-rc-sync.timer claude-rc-update-check.timer claude-rc-watch@.path; do
    printf '%s\n' "$UNIT_DIR/$f"
  done
  printf '%s\n' "$LAUNCHER_DIR/CLAUDE.md"
  [ "$OWN_SETTINGS" = 1 ] || printf '%s\n' "$LAUNCHER_DIR/.claude/settings.json"
  printf '%s\n' "$CODEHIVE_DATA/source"
} >"$CODEHIVE_DATA/manifest"
```

If you kept your own launcher settings in step 8, they're left out of the manifest, so uninstalling won't delete them. If you opened a new terminal since step 8, set `OWN_SETTINGS` to the same value again before you run this.

## 10. Turn on lingering

Normally systemd stops a user's services when they log out. Lingering keeps them running, and starts them at boot before anyone logs in. That's what makes the server available from your phone at any time. It's the one step that needs `sudo`:

```bash
loginctl show-user "$USER" --property=Linger --value
```

If that prints `yes`, lingering is already on. Otherwise turn it on:

```bash
sudo loginctl enable-linger "$USER"
```

If you can't use `sudo`, ask an administrator to run that command for your user. Without it, everything still works while you're logged in, but the servers stop when your last session ends.

## 11. Trust the launcher's folder

Claude Code won't start a server in a folder until its workspace trust dialog has been accepted, and a service can't answer a dialog. codehive wrote everything in the launcher's folder itself, so it's safe to trust:

```bash
"$CODEHIVE_DATA/libexec/claude-trust" "$LAUNCHER_DIR"
```

If this fails because `~/.claude.json` doesn't exist yet, run `claude` once in any folder, exit, and try again. Or run `claude` in the launcher folder and accept the dialog yourself.

## 12. Start everything

Tell systemd about the new units, then start the launcher, the sync timer, and the daily update check:

```bash
systemctl --user daemon-reload
systemctl --user enable --now claude-rc-launcher.service claude-rc-sync.timer claude-rc-update-check.timer
```

Start a watch on each project folder, so adding or removing a project starts or stops its server right away:

```bash
for root in "${PROJECT_DIRS[@]}"; do
  systemctl --user enable --now "claude-rc-watch@$(systemd-escape --path "$root").path"
done
```

Run the first sync, which starts a server for every trusted project. Then run the first update check in the background:

```bash
systemctl --user start claude-rc-sync.service
rm -f "$CODEHIVE_DATA/update-available"
systemctl --user start --no-block claude-rc-update-check.service
```

The update check runs even with `UPDATE_CHECK=0`. In that case it only clears any old notice.

## 13. Check that it works

```bash
codehive status
```

The launcher and the sync timer should show `active`, and each project folder should show its watch as `active`. Projects that were already in a project folder show *not trusted*, unless you'd trusted them in Claude Code before or set `AUTO_TRUST=1`. Review each one, then trust it to start its server:

```bash
codehive trust ~/projects/some-project
```

Then open a client and test the whole flow, as described in [4. Verify](install.md#4-verify). Next, [connect your clients](clients.md).

If the launcher isn't `active`, `codehive logs launcher` shows why. [Troubleshooting](troubleshooting.md) covers the common problems.

## After installing

**Changing settings.** Edit the config, then run steps 4 to 12 again. Some settings need less:

- A new `PERMISSION_MODE` only needs `codehive restart`.
- A new `AUTO_TRUST` or `UPDATE_CHECK` applies on its own at the next sync or check.

If you remove a project folder from `PROJECT_DIRS`, also stop its watch:

```bash
systemctl --user disable --now "claude-rc-watch@$(systemd-escape --path /the/old/folder).path"
```

If you change `BIN_DIR` or `LAUNCHER_DIR`, delete the files from the old location yourself.

**Updating.** Run `git pull` in your clone, then steps 4 to 12 again. If the unit files changed, run `codehive restart` afterwards, from a terminal rather than a Claude session. The simpler path is `git pull && ./install.sh`, which does all of that and moves you to a supported install. See [Updating](updating.md).

**Uninstalling.** `codehive uninstall` works the same as for an installer-made install, because it uses the manifest from step 9. See [Uninstalling](uninstall.md).
