#!/usr/bin/env bats
# Tests that run anywhere, including on a machine with codehive installed:
# each test gets its own HOME, and systemctl, loginctl, sudo, and Claude Code
# are stand-ins, so nothing here touches a real install or real servers.

bats_require_minimum_version 1.5.0

setup() {
  load helpers
  # The shell running the tests may be inside a real install's server, with
  # these pointing at it
  unset CODEHIVE_CONFIG CODEHIVE_DATA XDG_CONFIG_HOME XDG_DATA_HOME GIT_CONFIG_GLOBAL
  unset ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL CLAUDE_CODE_OAUTH_TOKEN \
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC DISABLE_GROWTHBOOK
  export HOME="$BATS_TEST_TMPDIR/home" XDG_RUNTIME_DIR="$BATS_TEST_TMPDIR/run"
  STUB="$BATS_TEST_TMPDIR/stub"
  export STUB_LOG="$BATS_TEST_TMPDIR/systemctl.log" STUB_UNITS="$BATS_TEST_TMPDIR/units"
  mkdir -p "$HOME" "$XDG_RUNTIME_DIR" "$STUB"
  : >"$STUB_LOG"
  : >"$STUB_UNITS"

  # systemctl logs every call. Nothing is ever active; the units it "knows
  # about" are the ones listed in $STUB_UNITS.
  cat >"$STUB/systemctl" <<'EOF'
#!/usr/bin/env bash
echo "$*" >>"$STUB_LOG"
[ "$1" = --user ] && shift
case "$1" in
  is-active) echo inactive; exit 3 ;;
  is-enabled) exit 1 ;;
  show-environment) echo "PATH=$PATH" ;;
  list-units|list-unit-files) cat "$STUB_UNITS" ;;
esac
exit 0
EOF
  printf '#!/bin/sh\necho yes\n' >"$STUB/loginctl"
  printf '#!/bin/sh\nexit 1\n' >"$STUB/sudo"
  printf '#!/bin/sh\nexit 0\n' >"$STUB/journalctl"
  cp "$REPO/test/fake-claude" "$STUB/claude"
  chmod +x "$STUB"/*
  export PATH="$STUB:$PATH"
  fake_account

  DATA="$HOME/.local/share/codehive"
  CONFIG="$HOME/.config/codehive/config"
  PROJECTS="$HOME/projects"
}

install_codehive() { "$REPO/install.sh" --yes --no-update-check "$@"; }
codehive() { "$HOME/.local/bin/codehive" "$@"; }

# ---------------------------------------------------------------- installer

@test "the installer installs every file it records, and the launcher's settings" {
  run install_codehive
  [ "$status" -eq 0 ]
  [ -s "$DATA/manifest" ]
  while IFS= read -r f; do
    [ -e "$f" ] || { echo "missing: $f"; return 1; }
  done <"$DATA/manifest"
  [ -x "$HOME/.local/bin/codehive" ]
  [ -d "$PROJECTS" ]
  [ "$(trusted "$DATA/launcher")" = yes ]
  grep -q "^\--user enable --now --quiet claude-rc-launcher.service claude-rc-sync.timer" "$STUB_LOG"
}

@test "the launcher's settings are valid JSON and deny the commands it must leave to you" {
  install_codehive
  run python3 - "$DATA/launcher/.claude/settings.json" "$HOME" <<'PY'
import json, sys
deny = json.load(open(sys.argv[1]))["permissions"]["deny"]
home = sys.argv[2]
for c in ("codehive", f"{home}/.local/bin/codehive", "~/.local/bin/codehive"):
    for sub in ("trust", "untrust", "delete", "update", "restart", "uninstall"):
        rule = f"Bash({c} {sub}:*)"
        assert rule in deny, rule
print("ok")
PY
  [ "$status" -eq 0 ]
  [ "$output" = ok ]
}

@test "the installer stops when a variable that blocks Remote Control is set" {
  ANTHROPIC_API_KEY=x run install_codehive
  [ "$status" -ne 0 ]
  [[ "$output" == *"ANTHROPIC_API_KEY is set"* ]]
  [ ! -e "$DATA/manifest" ]
}

@test "running the installer again keeps the saved settings" {
  install_codehive --accept-edits --project-dir "$HOME/a" --project-dir "$HOME/b"
  run install_codehive
  [ "$status" -eq 0 ]
  grep -qx 'PERMISSION_MODE="acceptEdits"' "$CONFIG"
  [ "$(codehive dirs)" = "$HOME/a"$'\n'"$HOME/b" ]
}

@test "--harden stops sessions from gaining privileges, and --no-harden undoes it" {
  install_codehive --harden
  grep -qx 'NoNewPrivileges=yes' "$HOME/.local/share/systemd/user/claude-rc@.service"
  install_codehive --no-harden
  run ! grep -q 'NoNewPrivileges' "$HOME/.local/share/systemd/user/claude-rc@.service"
}

@test "uninstall --purge removes everything but the project folders" {
  install_codehive
  make_repo "$PROJECTS/keep"
  mapfile -t files <"$DATA/manifest"
  run codehive uninstall --purge
  [ "$status" -eq 0 ]
  for f in "${files[@]}"; do
    [ ! -e "$f" ] || { echo "left behind: $f"; return 1; }
  done
  [ ! -e "$DATA" ]
  [ ! -e "$CONFIG" ]
  [ -d "$PROJECTS/keep/.git" ]
}

# ---------------------------------------------------------------- codehive new

@test "new makes a trusted git project with a commit and starts a sync" {
  install_codehive
  : >"$STUB_LOG"
  run codehive new demo
  [ "$status" -eq 0 ]
  git -C "$PROJECTS/demo" rev-parse --verify HEAD
  [ "$(trusted "$PROJECTS/demo")" = yes ]
  grep -qx -- "--user start claude-rc-sync.service" "$STUB_LOG"
}

@test "new rejects names that aren't plain folder names" {
  install_codehive
  for name in ../x .hidden "a b" -x; do
    run codehive new "$name"
    [ "$status" -ne 0 ] || { echo "accepted: $name"; return 1; }
  done
}

@test "new doesn't trust a folder that already existed" {
  install_codehive
  mkdir -p "$PROJECTS/cloned"
  run codehive new cloned
  [ "$status" -eq 0 ]
  [[ "$output" == *"isn't trusted"* ]]
  [ "$(trusted "$PROJECTS/cloned")" = no ]
}

@test "new --in uses another project folder, by name or path" {
  install_codehive --project-dir "$HOME/projects" --project-dir "$HOME/work"
  codehive new one --in work
  codehive new two --in "$HOME/work"
  [ -d "$HOME/work/one/.git" ]
  [ -d "$HOME/work/two/.git" ]
  run codehive new three --in elsewhere
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------- codehive delete

@test "delete stops the server, forgets trust, and deletes the folder" {
  install_codehive
  codehive new doomed
  grep -qx "$PROJECTS/doomed" "$DATA/trusted"
  : >"$STUB_LOG"
  run codehive delete doomed --yes
  [ "$status" -eq 0 ]
  [ ! -e "$PROJECTS/doomed" ]
  [ "$(trusted "$PROJECTS/doomed")" = no ]
  run ! grep -qx "$PROJECTS/doomed" "$DATA/trusted"
  grep -qxF -- "--user disable --now --quiet claude-rc@$(systemd-escape --path "$PROJECTS/doomed").service" "$STUB_LOG"
}

@test "delete shows what would be lost and asks, unless --yes is given" {
  install_codehive
  codehive new keep
  touch "$PROJECTS/keep/draft"
  run codehive delete keep </dev/null
  [ "$status" -ne 0 ]
  [[ "$output" == *"files with uncommitted changes: 1"* ]]
  [[ "$output" == *"no remote"* ]]
  [[ "$output" == *"pass --yes"* ]]
  [ -e "$PROJECTS/keep/draft" ]
}

@test "delete only deletes a folder directly inside a project folder" {
  install_codehive
  mkdir -p "$HOME/outside"
  for arg in . .. "$PROJECTS" "$HOME/outside" "$DATA/launcher" launcher /; do
    run codehive delete "$arg" --yes
    [ "$status" -ne 0 ] || { echo "deleted: $arg"; return 1; }
  done
  [ -d "$PROJECTS" ] && [ -d "$HOME/outside" ] && [ -d "$DATA/launcher" ]
}

@test "delete removes only the link for a linked project" {
  install_codehive
  mkdir -p "$HOME/real"
  touch "$HOME/real/file"
  ln -s "$HOME/real" "$PROJECTS/linked"
  run codehive delete linked --yes
  [ "$status" -eq 0 ]
  [ ! -L "$PROJECTS/linked" ]
  [ -e "$HOME/real/file" ]
}

# ---------------------------------------------------------------- trust

@test "claude-trust restores entries Claude Code drops, and --remove forgets them" {
  install_codehive
  trust="$DATA/libexec/claude-trust"
  mkdir -p "$PROJECTS/p" "$PROJECTS/q"
  "$trust" "$PROJECTS/p"
  echo '{"projects": {}}' >"$HOME/.claude.json"   # dropped by a rewrite
  run "$trust" --check "$PROJECTS/p" "$PROJECTS/q"
  [ "$output" = "$PROJECTS/p" ]
  [ "$(trusted "$PROJECTS/p")" = yes ]
  "$trust" --remove "$PROJECTS/p"
  [ "$(trusted "$PROJECTS/p")" = no ]
  run "$trust" --check "$PROJECTS/p"
  [ -z "$output" ]
}

@test "claude-trust --check keeps trust you accepted in Claude Code's dialog" {
  install_codehive
  mkdir -p "$PROJECTS/p"
  python3 - "$PROJECTS/p" <<'PY'
import json, os, sys
f = os.path.expanduser("~/.claude.json")
d = json.load(open(f))
d["projects"][sys.argv[1]] = {"hasTrustDialogAccepted": True}
json.dump(d, open(f, "w"))
PY
  "$DATA/libexec/claude-trust" --check "$PROJECTS/p"
  grep -qx "$PROJECTS/p" "$DATA/trusted"
}

# ---------------------------------------------------------------- sync

@test "sync starts servers for trusted projects only, in the right mode" {
  install_codehive
  make_repo "$PROJECTS/git"
  mkdir -p "$PROJECTS/plain" "$PROJECTS/untrusted" "$PROJECTS/excluded"
  touch "$PROJECTS/excluded/.no-rc"
  "$DATA/libexec/claude-trust" "$PROJECTS/git" "$PROJECTS/plain" "$PROJECTS/excluded"
  : >"$STUB_LOG"
  run "$DATA/libexec/claude-rc-sync"
  [ "$status" -eq 0 ]
  git_unit="claude-rc@$(systemd-escape --path "$PROJECTS/git").service"
  plain_unit="claude-rc-plain@$(systemd-escape --path "$PROJECTS/plain").service"
  grep -qxF -- "--user start --no-block $git_unit" "$STUB_LOG"
  grep -qxF -- "--user start --no-block $plain_unit" "$STUB_LOG"
  run ! grep -q untrusted "$STUB_LOG"
  run ! grep -q excluded "$STUB_LOG"
}

@test "sync stops servers whose folder is gone" {
  install_codehive
  stale="claude-rc@$(systemd-escape --path "$PROJECTS/gone").service"
  echo "$stale loaded active running" >"$STUB_UNITS"
  : >"$STUB_LOG"
  "$DATA/libexec/claude-rc-sync"
  grep -qxF -- "--user disable --now --quiet $stale" "$STUB_LOG"
}

@test "with AUTO_TRUST=1, sync trusts every project" {
  install_codehive --auto-trust
  mkdir -p "$PROJECTS/anything"
  "$DATA/libexec/claude-rc-sync"
  [ "$(trusted "$PROJECTS/anything")" = yes ]
}

@test "off keeps sync from starting anything until on" {
  install_codehive
  make_repo "$PROJECTS/p"
  "$DATA/libexec/claude-trust" "$PROJECTS/p"
  codehive off
  [ -e "$DATA/off" ]
  : >"$STUB_LOG"
  run "$DATA/libexec/claude-rc-sync"
  [[ "$output" == *"codehive is off"* ]]
  run ! grep -q -- "start" "$STUB_LOG"
  codehive on
  [ ! -e "$DATA/off" ]
  grep -qx -- "--user start claude-rc-sync.service" "$STUB_LOG"
}

# ---------------------------------------------------------------- helpers

@test "version_gt orders date versions and same-day builds" {
  . "$REPO/lib/common.sh"
  version_gt 2026.10.03 2026.10.02.1
  version_gt 2026.10.02.1 2026.10.02
  version_gt 2026.10.10 2026.10.9
  run ! version_gt 2026.10.02 2026.10.02
  run ! version_gt 2026.10.02 2026.10.03
}

@test "update_notice only mentions a newer release" {
  install_codehive
  . "$DATA/lib/common.sh"
  # shellcheck disable=SC2034  # read by update_notice
  UPDATE_CHECK=1
  printf '2099.01.01\nhttps://example.invalid/r\n' >"$DATA/update-available"
  [[ "$(update_notice)" == *"codehive 2099.01.01 is available"* ]]
  printf '2000.01.01\nhttps://example.invalid/r\n' >"$DATA/update-available"
  [ -z "$(update_notice)" ]
}

@test "the log filter strips escape codes and drops repeated lines" {
  run bash -c "printf '\e[1mready\e[0m\r\nready\nready\nconnected\n' | '$REPO/libexec/claude-rc-logfilter'"
  [ "$status" -eq 0 ]
  [ "$output" = $'ready\nconnected' ]
}
