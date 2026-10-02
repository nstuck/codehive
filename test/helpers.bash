# Shared by the bats tests. See test/README.md.
# shellcheck shell=bash

# shellcheck disable=SC2034  # used by the tests that load this
REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

# Run "$@" once a second until it succeeds, for up to $WAIT seconds
wait_for() {
  local i
  for ((i = 0; i < ${WAIT:-30}; i++)); do
    "$@" >/dev/null 2>&1 && return 0
    sleep 1
  done
  "$@"
}

# Print the arguments the fake Claude Code was last started with in a folder
fake_args() { cat "$HOME/.fake-claude/$(basename "$1").args"; }

# Write a ~/.claude.json and a git identity, like a real account would have
fake_account() {
  [ -e "$HOME/.claude.json" ] || echo '{"projects": {}}' >"$HOME/.claude.json"
  git config --global user.name >/dev/null || git config --global user.name "codehive tests"
  git config --global user.email >/dev/null || git config --global user.email "tests@example.invalid"
}

# Make a git repo with one commit. usage: make_repo <dir>
make_repo() {
  mkdir -p "$1"
  git -C "$1" init -q
  git -C "$1" commit -q --allow-empty -m "Initial commit"
}

# Print "yes" if ~/.claude.json trusts a folder, else "no"
trusted() {
  python3 - "$1" <<'PY'
import json, os, sys
p = json.load(open(os.path.expanduser("~/.claude.json"))).get("projects", {})
print("yes" if p.get(os.path.realpath(sys.argv[1]), {}).get("hasTrustDialogAccepted") else "no")
PY
}
