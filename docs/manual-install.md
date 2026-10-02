# Manual install

> **Unsupported.** `install.sh` is the only supported way to install codehive. This page lists every step it takes, in the same order, so you can see exactly what it does to your system or reproduce it by hand. If you install this way and something goes wrong, run `install.sh` over the top of it to get back to a supported install.

The commands below use the installer's defaults: projects in `~/projects`, no permission mode, the launcher asking before it runs `codehive new`, `AUTO_TRUST=0`, and update checks on. Where an [installer option](install.md#3-run-the-installer) would change something, it's noted.

Do steps 1 and 2 of [Installing codehive](install.md) first. Then run everything below in one shell, from a clone of the repo, as your normal user:

```bash
git clone https://github.com/nstuck/codehive.git ~/codehive
cd ~/codehive
```

## 1. Set the variables

```bash
REPO="$PWD"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/codehive/config"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}/codehive"
UNITS="${XDG_DATA_HOME:-$HOME/.local/share}/systemd/user"
PROJECT_DIRS=("$HOME/projects")          # --project-dir, once per folder
LAUNCHER_DIR="$DATA/launcher"            # --launcher-dir
BIN_DIR="$HOME/.local/bin"               # --bin-dir
PERMISSION_MODE=""                       # --permission-mode
LAUNCHER_AUTOAPPROVE=0                   # --launcher-autoapprove
AUTO_TRUST=0                             # --auto-trust
UPDATE_CHECK=1                           # --no-update-check
CLAUDE_BIN="$(command -v claude || echo "$HOME/.local/bin/claude")"
```

Project folders can't be inside each other or contain the launcher folder, and none of these paths can contain `"`, `$`, `` ` ``, `\`, or `%`.

## 2. Check the requirements

The installer stops if any of these fail:

```bash
for cmd in git systemctl systemd-escape journalctl loginctl flock realpath python3 curl; do
  command -v "$cmd" >/dev/null || echo "missing command: $cmd"
done
systemctl --user show-environment >/dev/null || echo "no systemd user session"

# None of these may be set in your shell or in the systemd user manager
for v in ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL CLAUDE_CODE_OAUTH_TOKEN \
         CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC DISABLE_GROWTHBOOK; do
  [ -n "${!v:-}" ] && echo "$v is set in your shell"
  systemctl --user show-environment | grep -q "^$v=" && echo "$v is set in the systemd user manager"
done

[ -x "$CLAUDE_BIN" ] || echo "Claude Code isn't installed"
```

It only warns about these:

```bash
"$CLAUDE_BIN" auth status | grep -q '"authMethod": *"claude.ai"' || echo "not signed in with a claude.ai account"
git config user.name >/dev/null && git config user.email >/dev/null || echo "git user.name/user.email aren't set"
```

## 3. Install the files

Some files are templates with `@KEY@` placeholders. The installer fills them in literally with this function:

```bash
LAUNCHER_ALLOW=""
[ "$LAUNCHER_AUTOAPPROVE" = 1 ] && LAUNCHER_ALLOW="\"Bash($BIN_DIR/codehive new:*)\""
UNIT_PATH="${PATH//%/%%}"   # % is special in unit files

render() {
  local content
  content="$(<"$1")"
  content="${content//@CLAUDE_BIN@/"$CLAUDE_BIN"}"
  content="${content//@PATH@/"$UNIT_PATH"}"
  content="${content//@LIBEXEC@/"$DATA/libexec"}"
  content="${content//@LAUNCHER_DIR@/"$LAUNCHER_DIR"}"
  content="${content//@BIN_DIR@/"$BIN_DIR"}"
  content="${content//@CODEHIVE_CONFIG@/"$CONFIG"}"
  content="${content//@CODEHIVE_DATA@/"$DATA"}"
  content="${content//@LAUNCHER_ALLOW@/"$LAUNCHER_ALLOW"}"
  content="${content//@PROJECT_DIRS_LIST@/"$(printf -- '- %s\n' "${PROJECT_DIRS[@]}")"}"
  printf '%s\n' "$content"
}
```

Your current `PATH` goes into every unit file, so sessions find the same tools you do.

Copy the scripts:

```bash
mkdir -p "$DATA/lib" "$DATA/libexec" "$BIN_DIR" "$UNITS" "$LAUNCHER_DIR/.claude"
install -m 644 lib/common.sh "$DATA/lib/common.sh"
for f in claude-rc-sync claude-rc-run claude-rc-logfilter claude-trust claude-rc-update-check; do
  install -m 755 "libexec/$f" "$DATA/libexec/$f"
done
install -m 644 VERSION "$DATA/VERSION"
install -m 755 uninstall.sh "$DATA/uninstall.sh"
render bin/codehive.in >"$BIN_DIR/codehive" && chmod 755 "$BIN_DIR/codehive"
```

Install the systemd units:

```bash
for f in claude-rc@.service claude-rc-plain@.service claude-rc-launcher.service \
         claude-rc-sync.service claude-rc-update-check.service; do
  render "systemd/$f.in" >"$UNITS/$f" && chmod 644 "$UNITS/$f"
done
for f in claude-rc-sync.timer claude-rc-update-check.timer claude-rc-watch@.path; do
  install -m 644 "systemd/$f" "$UNITS/$f"
done
```

Set up the launcher's workspace. If `.claude/settings.json` is already there and the installer didn't write it, the installer leaves it alone instead (see [The launcher's settings](configuration.md#the-launchers-settings)):

```bash
render launcher/CLAUDE.md.in >"$LAUNCHER_DIR/CLAUDE.md" && chmod 644 "$LAUNCHER_DIR/CLAUDE.md"
render launcher/settings.json.in >"$LAUNCHER_DIR/.claude/settings.json" && chmod 644 "$LAUNCHER_DIR/.claude/settings.json"
for root in "${PROJECT_DIRS[@]}"; do mkdir -p "$root"; done
```

## 4. Record the install

`codehive update` reads where codehive came from, and `codehive uninstall` removes exactly the files in the manifest:

```bash
{
  echo "# Where codehive was installed from; \`codehive update\` installs from here again"
  printf 'CODEHIVE_CHECKOUT=%q\n' "$REPO"
} >"$DATA/source"

cat >"$DATA/manifest" <<EOF
$DATA/lib/common.sh
$DATA/libexec/claude-rc-sync
$DATA/libexec/claude-rc-run
$DATA/libexec/claude-rc-logfilter
$DATA/libexec/claude-trust
$DATA/libexec/claude-rc-update-check
$DATA/VERSION
$DATA/uninstall.sh
$BIN_DIR/codehive
$UNITS/claude-rc@.service
$UNITS/claude-rc-plain@.service
$UNITS/claude-rc-launcher.service
$UNITS/claude-rc-sync.service
$UNITS/claude-rc-update-check.service
$UNITS/claude-rc-sync.timer
$UNITS/claude-rc-update-check.timer
$UNITS/claude-rc-watch@.path
$LAUNCHER_DIR/CLAUDE.md
$LAUNCHER_DIR/.claude/settings.json
$DATA/source
EOF
```

## 5. Write the config

The installer writes your choices to the config, with paths under your home folder kept as `$HOME/...`. With the defaults, it's:

```bash
mkdir -p "$(dirname "$CONFIG")"
cat >"$CONFIG" <<'EOF'
# codehive config (bash syntax). Run the installer again after changing it;
# PERMISSION_MODE only needs `codehive restart`, and AUTO_TRUST applies on the next sync.

# Folders whose subfolders are projects. `codehive new` uses the first one.
PROJECT_DIRS=(
  "$HOME/projects"
)

# The launcher's workspace, where you ask for new projects from any client
LAUNCHER_DIR="$HOME/.local/share/codehive/launcher"

# Where the codehive command is installed; should be on your PATH
BIN_DIR="$HOME/.local/bin"

# Permission mode for sessions (acceptEdits, auto, default, ...); empty means Claude Code's default
PERMISSION_MODE=""

# 1 lets the launcher run `codehive new` without asking
LAUNCHER_AUTOAPPROVE=0

# 1 trusts every project folder automatically, so a server starts for anything
# that lands in one. 0 only serves folders you've trusted. See docs/workspace-trust.md.
AUTO_TRUST=0

# 1 checks GitHub once a day for a newer codehive release and mentions it in
# `codehive status` and at the start of launcher sessions
UPDATE_CHECK=1
EOF
```

## 6. Turn on lingering

So the services run while you're logged out and start at boot:

```bash
[ "$(loginctl show-user "$USER" --property=Linger --value)" = yes ] || sudo loginctl enable-linger "$USER"
```

## 7. Trust the launcher

The launcher's server can't answer the trust dialog either:

```bash
"$DATA/libexec/claude-trust" "$LAUNCHER_DIR"
```

## 8. Start everything

```bash
systemctl --user daemon-reload
systemctl --user enable --now claude-rc-launcher.service claude-rc-sync.timer claude-rc-update-check.timer
for root in "${PROJECT_DIRS[@]}"; do
  systemctl --user enable --now "claude-rc-watch@$(systemd-escape --path "$root").path"
done
systemctl --user start claude-rc-sync.service
rm -f "$DATA/update-available"
systemctl --user start --no-block claude-rc-update-check.service
"$BIN_DIR/codehive" status
```

The sync starts a server for every trusted project. Continue with [4. Verify](install.md#4-verify).

## What the installer does differently on later runs

Running `install.sh` again repeats all of this, with three differences:

- It deletes files listed in the old manifest that aren't part of the new install, for example after you change `--bin-dir` or `--launcher-dir`.
- It stops and disables watches on folders that are no longer in `PROJECT_DIRS`.
- If any unit file changed and servers are running, it tells you to run `codehive restart`.
