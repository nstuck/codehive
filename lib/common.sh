# Shared settings and helpers for codehive. Source this file; don't run it.
# shellcheck shell=bash disable=SC2034  # settings are used by the scripts that source this

CODEHIVE_CONFIG="${CODEHIVE_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/codehive/config}"
CODEHIVE_DATA="${CODEHIVE_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/codehive}"

# Defaults, overridden by the config file
PROJECT_DIRS=("$HOME/projects")
LAUNCHER_DIR="$CODEHIVE_DATA/launcher"
BIN_DIR="$HOME/.local/bin"
PERMISSION_MODE=""
LAUNCHER_AUTOAPPROVE=0
AUTO_TRUST=0
UPDATE_CHECK=1

# shellcheck source=/dev/null
[ -r "$CODEHIVE_CONFIG" ] && . "$CODEHIVE_CONFIG"

# Normalize a path (absolute, no trailing slash, no ..) without resolving symlinks
normpath() { realpath -ms -- "$1"; }

_roots=()
for _r in "${PROJECT_DIRS[@]}"; do _roots+=("$(normpath "$_r")"); done
PROJECT_DIRS=("${_roots[@]}")
unset _roots _r
LAUNCHER_DIR="$(normpath "$LAUNCHER_DIR")"

# Names that `codehive new` accepts
valid_name() { [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; }

# Print the template unit a project folder should run under
unit_for() {
  local dir="$1" esc
  esc="$(systemd-escape --path "$dir")"
  if git -C "$dir" rev-parse --verify HEAD >/dev/null 2>&1; then
    echo "claude-rc@$esc.service"
  else
    echo "claude-rc-plain@$esc.service"
  fi
}

# Print the project folder a claude-rc@ / claude-rc-plain@ unit runs in
dir_for_unit() {
  local inst="${1#*@}"
  systemd-escape --unescape --path "${inst%.service}"
}

# Print every project folder under the configured roots, one per line
list_projects() {
  local root dir
  for root in "${PROJECT_DIRS[@]}"; do
    for dir in "$root"/*/; do
      [ -d "$dir" ] || continue
      dir="${dir%/}"
      [ -e "$dir/.no-rc" ] && continue
      printf '%s\n' "$dir"
    done
  done
}

# Print every instance of the given templates that systemd knows about,
# loaded or just enabled. usage: list_instances 'claude-rc@*' ...
list_instances() {
  {
    systemctl --user list-units --all --plain --no-legend "$@"
    systemctl --user list-unit-files --plain --no-legend "$@" || true  # exits 1 when empty
  } | awk '$1 ~ /@.+\.(service|path)$/ {print $1}' | sort -u
}

# Print every project server unit systemd knows about
list_instance_units() { list_instances 'claude-rc@*' 'claude-rc-plain@*'; }

# Print "yes" if Claude Code has recorded workspace trust for a folder, else "no".
# Read-only; this looks at Claude Code's internal ~/.claude.json format.
is_trusted() {
  python3 - "$1" <<'EOF' 2>/dev/null || echo unknown
import json, os, sys
with open(os.path.expanduser("~/.claude.json")) as f:
    projects = json.load(f).get("projects", {})
entry = projects.get(os.path.realpath(sys.argv[1]), {})
print("yes" if entry.get("hasTrustDialogAccepted") else "no")
EOF
}

# Print the installed codehive version, or "unknown" if the VERSION file is missing
installed_version() { cat "$CODEHIVE_DATA/VERSION" 2>/dev/null || echo unknown; }

# Succeed if version $1 is newer than version $2
version_gt() { [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n1)" = "$1" ]; }

# Print the command that updates this install to version $1
update_command() {
  local CODEHIVE_REPO="" CODEHIVE_REF=main CODEHIVE_CHECKOUT=""
  # shellcheck source=/dev/null
  [ -r "$CODEHIVE_DATA/source" ] && . "$CODEHIVE_DATA/source"
  if [ -n "$CODEHIVE_CHECKOUT" ]; then
    echo "cd $CODEHIVE_CHECKOUT && git pull && ./install.sh"
  elif [[ "$CODEHIVE_REF" =~ ^v[0-9] ]]; then
    echo "codehive update --ref v$1"
  else
    echo "codehive update"
  fi
}

# Print a notice if the last update check found a newer release
update_notice() {
  local f="$CODEHIVE_DATA/update-available" latest="" url="" installed
  [ "$UPDATE_CHECK" = 1 ] && [ -r "$f" ] || return 0
  { read -r latest; read -r url; } <"$f"
  installed="$(installed_version)"
  [ "$installed" = unknown ] || version_gt "$latest" "$installed" || return 0
  echo "codehive $latest is available (installed: $installed). Release notes: $url"
  echo "To update, run this over SSH, not from a Claude session: $(update_command "$latest")"
}

die()  { echo "codehive: $*" >&2; exit 1; }
warn() { echo "codehive: $*" >&2; }
