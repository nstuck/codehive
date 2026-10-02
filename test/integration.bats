#!/usr/bin/env bats
# End-to-end tests against a real systemd user manager, with a stand-in for
# Claude Code. They install codehive for the current user, start and stop real
# services, and uninstall it at the end, so they only run on a throwaway
# machine: in CI, or with CODEHIVE_INTEGRATION=1. They refuse to run where
# codehive or Claude Code is already installed.
# Tests run in order and build on each other.

setup_file() {
  load helpers
  if [ "${GITHUB_ACTIONS:-}" != true ] && [ "${CODEHIVE_INTEGRATION:-}" != 1 ]; then
    echo "integration tests only run in CI or with CODEHIVE_INTEGRATION=1 (see test/README.md)" >&2
    return 1
  fi
  # Inside a codehive server, or on a machine with an install, these would
  # replace the real one
  if [ -n "${CODEHIVE_CONFIG:-}${CODEHIVE_DATA:-}" ] || [ -e "$HOME/.local/share/codehive" ] \
      || [ -e "$HOME/.config/codehive" ]; then
    echo "codehive is installed here; run the integration tests on a throwaway machine" >&2
    return 1
  fi
  if command -v claude >/dev/null || [ -e "$HOME/.local/bin/claude" ]; then
    echo "Claude Code is installed here; run the integration tests on a throwaway machine" >&2
    return 1
  fi
  mkdir -p "$HOME/.local/bin"
  cp "$REPO/test/fake-claude" "$HOME/.local/bin/claude"
  fake_account
  "$REPO/install.sh" --yes --no-update-check
  # bats runs teardown_file even when setup_file fails, so it may only undo
  # an install made here
  touch "$BATS_FILE_TMPDIR/installed-by-tests"
}

teardown_file() {
  [ -e "$BATS_FILE_TMPDIR/installed-by-tests" ] || return 0
  if [ -x "$HOME/.local/bin/codehive" ]; then
    "$HOME/.local/bin/codehive" uninstall --purge >/dev/null 2>&1 || true
  fi
  rm -f "$HOME/.local/bin/claude"
}

setup() {
  load helpers
  PATH="$HOME/.local/bin:$PATH"
  PROJECTS="$HOME/projects"
}

active() { systemctl --user is-active --quiet "$1"; }
inactive() { ! systemctl --user is-active --quiet "$1"; }
unit() { echo "claude-rc@$(systemd-escape --path "$PROJECTS/$1").service"; }
plain_unit() { echo "claude-rc-plain@$(systemd-escape --path "$PROJECTS/$1").service"; }

@test "the installer starts the launcher, the sync timer, and the folder watch" {
  wait_for active claude-rc-launcher.service
  active claude-rc-sync.timer
  active "claude-rc-watch@$(systemd-escape --path "$PROJECTS").path"
  run fake_args "$HOME/.local/share/codehive/launcher"
  [[ "$output" == *$'remote-control\n--name\nlauncher\n--spawn\nsame-dir'* ]]
}

@test "codehive new starts a worktree-mode server" {
  codehive new demo
  wait_for active "$(unit demo)"
  run fake_args "$PROJECTS/demo"
  [ "${lines[0]}" = "$PROJECTS/demo" ]
  [[ "$output" == *$'--name\ndemo\n--spawn\nworktree'* ]]
}

@test "an untrusted folder gets no server until it's trusted" {
  make_repo "$PROJECTS/cloned"
  codehive sync
  sleep 2
  inactive "$(unit cloned)"
  run codehive status
  [[ "$output" == *"cloned"*"not trusted"* ]]
  codehive trust "$PROJECTS/cloned"
  wait_for active "$(unit cloned)"
}

@test "a folder without git runs in same-dir mode" {
  mkdir -p "$PROJECTS/plain"
  codehive trust "$PROJECTS/plain"
  wait_for active "$(plain_unit plain)"
  run fake_args "$PROJECTS/plain"
  [[ "$output" == *$'--spawn\nsame-dir'* ]]
}

@test "the first commit switches a project to worktree mode" {
  git -C "$PROJECTS/plain" init -q
  git -C "$PROJECTS/plain" commit -q --allow-empty -m "Initial commit"
  codehive sync
  wait_for active "$(unit plain)"
  wait_for inactive "$(plain_unit plain)"
}

@test ".no-rc stops a server" {
  touch "$PROJECTS/cloned/.no-rc"
  codehive sync
  wait_for inactive "$(unit cloned)"
  run codehive status
  [[ "$output" == *"cloned"*"excluded (.no-rc)"* ]]
}

@test "untrust stops a server" {
  codehive untrust "$PROJECTS/plain"
  wait_for inactive "$(unit plain)"
  [ "$(trusted "$PROJECTS/plain")" = no ]
}

@test "deleting a folder stops its server through the folder watch" {
  codehive new gone
  wait_for active "$(unit gone)"
  rm -rf "$PROJECTS/gone"
  # The watch should notice right away; the timer would take up to a minute
  WAIT=20 wait_for inactive "$(unit gone)"
}

@test "delete stops a server and deletes its folder" {
  codehive new doomed
  wait_for active "$(unit doomed)"
  codehive delete doomed --yes
  inactive "$(unit doomed)"
  [ ! -e "$PROJECTS/doomed" ]
  run codehive status
  [[ "$output" != *doomed* ]]
}

@test "restart starts a server again" {
  before="$(systemctl --user show -p MainPID --value "$(unit demo)")"
  codehive restart demo
  wait_for active "$(unit demo)"
  after="$(systemctl --user show -p MainPID --value "$(unit demo)")"
  [ "$before" != "$after" ]
}

@test "off stops everything and keeps it stopped until on" {
  codehive off
  wait_for inactive claude-rc-launcher.service
  wait_for inactive "$(unit demo)"
  inactive claude-rc-sync.timer
  codehive sync
  sleep 2
  inactive "$(unit demo)"
  codehive on
  wait_for active claude-rc-launcher.service
  wait_for active "$(unit demo)"
}

@test "running the installer again leaves running servers alone" {
  before="$(systemctl --user show -p MainPID --value "$(unit demo)")"
  "$REPO/install.sh" --yes
  active "$(unit demo)"
  [ "$(systemctl --user show -p MainPID --value "$(unit demo)")" = "$before" ]
}

@test "uninstall stops every server and keeps the project folders" {
  codehive uninstall --purge
  wait_for inactive claude-rc-launcher.service
  wait_for inactive "$(unit demo)"
  [ -z "$(systemctl --user list-units --state=active --plain --no-legend 'claude-rc*')" ]
  [ ! -e "$HOME/.local/bin/codehive" ]
  [ -d "$PROJECTS/demo/.git" ]
}
