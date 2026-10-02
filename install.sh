#!/usr/bin/env bash
# Install or update codehive. Safe to run again at any time: it re-reads the
# config, rewrites the installed files, and leaves running servers alone.
set -euo pipefail

# Piped from curl, there's no repo next to this script: download one and run
# its installer instead. The whole block is read before it runs, so nothing
# after it is needed from the pipe.
if [ ! -f "$(dirname "${BASH_SOURCE[0]:-/nonexistent/x}")/systemd/claude-rc@.service.in" ]; then
  CODEHIVE_REPO="${CODEHIVE_REPO:-nstuck/codehive}"
  CODEHIVE_REF="${CODEHIVE_REF:-latest}"
  # The installer records these so `codehive update` installs from the same place
  export CODEHIVE_REPO CODEHIVE_REF CODEHIVE_DOWNLOADED=1
  # "latest" means the newest release. `codehive update` passes the tag it
  # already looked up in CODEHIVE_TAG.
  ref="$CODEHIVE_REF"
  if [ "$ref" = latest ]; then
    ref="${CODEHIVE_TAG:-}"
    [ -n "$ref" ] || ref="$(curl -fsSL "https://api.github.com/repos/$CODEHIVE_REPO/releases/latest" \
      | sed -n 's/^ *"tag_name": *"\([^"]*\)".*/\1/p')" || ref=""
    [ -n "$ref" ] || { echo "No release found for $CODEHIVE_REPO; installing main instead."; ref=main; }
  fi
  CODEHIVE_TMP="$(mktemp -d)"
  trap 'rm -rf "$CODEHIVE_TMP"' EXIT
  echo "Downloading codehive ($CODEHIVE_REPO@$ref)..."
  url="https://github.com/$CODEHIVE_REPO/archive/$ref.tar.gz"
  curl -fsSL -o "$CODEHIVE_TMP/src.tar.gz" "$url" \
    || { echo "codehive: couldn't download $url (check CODEHIVE_REPO and CODEHIVE_REF)" >&2; exit 1; }
  tar -xzf "$CODEHIVE_TMP/src.tar.gz" -C "$CODEHIVE_TMP" --strip-components=1
  # stdin is the script itself, so take answers to prompts from the terminal
  if (exec </dev/tty) 2>/dev/null; then
    bash "$CODEHIVE_TMP/install.sh" "$@" </dev/tty
  else
    bash "$CODEHIVE_TMP/install.sh" "$@" </dev/null
  fi
  exit
fi

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$REPO/lib/common.sh"   # defaults, plus the existing config if there is one
UNIT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/systemd/user"
MANIFEST="$CODEHIVE_DATA/manifest"
ASSUME_YES=0

usage() {
  cat <<EOF
usage: ./install.sh [options]
   or: curl -fsSL https://raw.githubusercontent.com/nstuck/codehive/main/install.sh | bash -s -- [options]

  --project-dir <dir>        a folder whose subfolders are projects; repeat for several
                             (default: ~/projects; replaces the configured list when given)
  --launcher-dir <dir>       the launcher's workspace (default: ~/.local/share/codehive/launcher)
  --bin-dir <dir>            where the codehive command goes (default: ~/.local/bin)
  --permission-mode <mode>   permission mode for sessions (acceptEdits, auto, default, ...)
  --accept-edits             same as --permission-mode acceptEdits
  --launcher-autoapprove     let the launcher run \`codehive new\` without asking
  --no-launcher-autoapprove  ask before the launcher runs \`codehive new\` (default)
  --auto-trust               trust every project folder automatically (see docs/workspace-trust.md)
  --no-auto-trust            only serve folders you've trusted (default)
  --no-update-check          don't check GitHub for new codehive releases
  --update-check             check GitHub once a day for new releases (default)
  --harden                   stop sessions from gaining privileges, such as through sudo
                             (see docs/security.md)
  --no-harden                let sessions use sudo and setuid programs (default)
  -y, --yes                  don't ask for confirmation
  -h, --help                 show this help

Settings are saved to $CODEHIVE_CONFIG and reused on the next run.
Through curl, CODEHIVE_REF picks the tag or branch to install (default: latest,
the newest release)
and CODEHIVE_REPO the GitHub repo (default: nstuck/codehive).
EOF
}

dirs_from_flags=()
while [ $# -gt 0 ]; do
  case "$1" in
    --project-dir)            dirs_from_flags+=("${2:?--project-dir needs a folder}"); shift 2 ;;
    --launcher-dir)           LAUNCHER_DIR="${2:?--launcher-dir needs a folder}"; shift 2 ;;
    --bin-dir)                BIN_DIR="${2:?--bin-dir needs a folder}"; shift 2 ;;
    --permission-mode)        PERMISSION_MODE="${2:?--permission-mode needs a mode}"; shift 2 ;;
    --accept-edits)           PERMISSION_MODE=acceptEdits; shift ;;
    --launcher-autoapprove)   LAUNCHER_AUTOAPPROVE=1; shift ;;
    --no-launcher-autoapprove) LAUNCHER_AUTOAPPROVE=0; shift ;;
    --auto-trust)             AUTO_TRUST=1; shift ;;
    --no-auto-trust)          AUTO_TRUST=0; shift ;;
    --update-check)           UPDATE_CHECK=1; shift ;;
    --no-update-check)        UPDATE_CHECK=0; shift ;;
    --harden)                 HARDEN=1; shift ;;
    --no-harden)              HARDEN=0; shift ;;
    -y|--yes)                 ASSUME_YES=1; shift ;;
    -h|--help)                usage; exit 0 ;;
    *)                        usage >&2; exit 1 ;;
  esac
done
[ ${#dirs_from_flags[@]} -gt 0 ] && PROJECT_DIRS=("${dirs_from_flags[@]}")

# Expand a leading ~ (from quoted flags) and normalize
expand() { local p="$1"; [[ "$p" == "~"* ]] && p="$HOME${p:1}"; normpath "$p"; }
roots=()
for d in "${PROJECT_DIRS[@]}"; do
  d="$(expand "$d")"
  [[ " ${roots[*]-} " == *" $d "* ]] || roots+=("$d")
done
PROJECT_DIRS=("${roots[@]}")
LAUNCHER_DIR="$(expand "$LAUNCHER_DIR")"
BIN_DIR="$(expand "$BIN_DIR")"

confirm() {
  [ "$ASSUME_YES" = 1 ] && return 0
  [ -t 0 ] || die "$1 Pass --yes to accept."
  local reply
  read -r -p "$1 [Y/n] " reply
  [[ -z "$reply" || "$reply" =~ ^[Yy] ]]
}

# ---------------------------------------------------------------- preflight

problems=0
problem() { echo "  ✗ $*" >&2; problems=$((problems + 1)); }

echo "Checking requirements..."
for cmd in git systemctl systemd-escape journalctl loginctl flock realpath python3 curl; do
  command -v "$cmd" >/dev/null || problem "missing command: $cmd"
done
systemctl --user show-environment >/dev/null 2>&1 \
  || problem "no systemd user session (try logging in over SSH instead of su/sudo)"

# These block Remote Control. The user manager's environment matters too,
# because services inherit it.
blocked=(ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL CLAUDE_CODE_OAUTH_TOKEN
         CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC DISABLE_GROWTHBOOK)
manager_env="$(systemctl --user show-environment 2>/dev/null || true)"
for v in "${blocked[@]}"; do
  [ -n "${!v:-}" ] && problem "$v is set in your shell; unset it (Remote Control won't start with it)"
  grep -q "^$v=" <<<"$manager_env" && problem "$v is set in the systemd user manager; run: systemctl --user unset-environment $v"
done

for p in "${PROJECT_DIRS[@]}" "$LAUNCHER_DIR" "$BIN_DIR" "$CODEHIVE_CONFIG" "$CODEHIVE_DATA" "$UNIT_DIR"; do
  [[ "$p" =~ [\"\$\`\\%] ]] && problem "unsupported character in path: $p"
done
for a in "${PROJECT_DIRS[@]}"; do
  for b in "${PROJECT_DIRS[@]}" "$LAUNCHER_DIR"; do
    [ "$a" = "$b" ] && continue
    [[ "$b/" == "$a/"* || "$a/" == "$b/"* ]] && problem "folders can't be inside each other: $a and $b"
  done
done

CLAUDE_BIN="$(command -v claude || true)"
[ -z "$CLAUDE_BIN" ] && [ -x "$HOME/.local/bin/claude" ] && CLAUDE_BIN="$HOME/.local/bin/claude"
if [ -z "$CLAUDE_BIN" ] && [ "$problems" = 0 ]; then
  if confirm "Claude Code isn't installed. Install it now with the official installer?"; then
    curl -fsSL https://claude.ai/install.sh | bash
    CLAUDE_BIN="$HOME/.local/bin/claude"
    [ -x "$CLAUDE_BIN" ] || problem "Claude Code install failed"
  else
    problem "Claude Code isn't installed: https://code.claude.com/docs/en/install"
  fi
fi

[ "$problems" = 0 ] || die "fix the problems above and run ./install.sh again"

if ! "$CLAUDE_BIN" auth status 2>/dev/null | grep -q '"authMethod": *"claude.ai"'; then
  warn "not signed in with a claude.ai account; run \`claude auth login\` before using Remote Control"
fi
if ! git config user.name >/dev/null || ! git config user.email >/dev/null; then
  warn "git user.name/user.email aren't set; \`codehive new\` needs them for the initial commit"
fi

# ---------------------------------------------------------------- install

echo "Installing..."
old_manifest=()
[ -r "$MANIFEST" ] && mapfile -t old_manifest <"$MANIFEST"
new_manifest=()
units_changed=0

# Lets the launcher run `codehive new` without asking
LAUNCHER_ALLOW=""
[ "$LAUNCHER_AUTOAPPROVE" = 1 ] && LAUNCHER_ALLOW="\"Bash($BIN_DIR/codehive new:*)\""

# Commands the launcher must leave to you over SSH, in each way it might write them
deny_cmds=(codehive "$BIN_DIR/codehive")
# shellcheck disable=SC2088  # a literal ~, the way a session might type it
[[ "$BIN_DIR" == "$HOME/"* ]] && deny_cmds+=("~/${BIN_DIR#"$HOME"/}/codehive")
deny=()
for c in "${deny_cmds[@]}"; do
  for sub in trust untrust update restart uninstall; do deny+=("\"Bash($c $sub:*)\""); done
done
deny+=("\"Bash($CODEHIVE_DATA/libexec/claude-trust:*)\"")
LAUNCHER_DENY="$(printf '%s,\n      ' "${deny[@]}")"
LAUNCHER_DENY="${LAUNCHER_DENY%,*}"

# Settings for the server units: sessions can't gain privileges, so sudo,
# su, and other setuid programs don't work in them
HARDEN_LINES=""
[ "$HARDEN" = 1 ] && HARDEN_LINES=$'NoNewPrivileges=yes\nRestrictSUIDSGID=yes'

# Replace @KEY@ placeholders. Values are inserted literally.
render() {
  local src="$1" content
  content="$(<"$src")"
  content="${content//@CLAUDE_BIN@/"$CLAUDE_BIN"}"
  content="${content//@PATH@/"$UNIT_PATH"}"
  content="${content//@LIBEXEC@/"$CODEHIVE_DATA/libexec"}"
  content="${content//@LAUNCHER_DIR@/"$LAUNCHER_DIR"}"
  content="${content//@BIN_DIR@/"$BIN_DIR"}"
  content="${content//@CODEHIVE_CONFIG@/"$CODEHIVE_CONFIG"}"
  content="${content//@CODEHIVE_DATA@/"$CODEHIVE_DATA"}"
  content="${content//@LAUNCHER_ALLOW@/"$LAUNCHER_ALLOW"}"
  content="${content//@LAUNCHER_DENY@/"$LAUNCHER_DENY"}"
  content="${content//@HARDEN@/"$HARDEN_LINES"}"
  content="${content//@PROJECT_DIRS_LIST@/"$(printf -- '- %s\n' "${PROJECT_DIRS[@]}")"}"
  printf '%s\n' "$content"
}

# put <mode> <dest> <src> [render]: install a file, recording it in the manifest
put() {
  local mode="$1" dest="$2" src="$3" tmp
  tmp="$(mktemp)"
  if [ "${4:-}" = render ]; then render "$src" >"$tmp"; else cat "$src" >"$tmp"; fi
  if [ "$dest" != "${dest#"$UNIT_DIR"/}" ] && ! cmp -s "$tmp" "$dest"; then units_changed=1; fi
  mkdir -p "$(dirname "$dest")"
  install -m "$mode" "$tmp" "$dest"
  rm -f "$tmp"
  new_manifest+=("$dest")
}

# PATH goes into unit files, where % is special
UNIT_PATH="${PATH//%/%%}"

put 644 "$CODEHIVE_DATA/lib/common.sh"         "$REPO/lib/common.sh"
put 755 "$CODEHIVE_DATA/libexec/claude-rc-sync" "$REPO/libexec/claude-rc-sync"
put 755 "$CODEHIVE_DATA/libexec/claude-rc-run"  "$REPO/libexec/claude-rc-run"
put 755 "$CODEHIVE_DATA/libexec/claude-rc-logfilter" "$REPO/libexec/claude-rc-logfilter"
put 755 "$CODEHIVE_DATA/libexec/claude-trust"   "$REPO/libexec/claude-trust"
put 755 "$CODEHIVE_DATA/libexec/claude-rc-update-check" "$REPO/libexec/claude-rc-update-check"
put 644 "$CODEHIVE_DATA/VERSION"               "$REPO/VERSION"
put 755 "$CODEHIVE_DATA/uninstall.sh"          "$REPO/uninstall.sh"
put 755 "$BIN_DIR/codehive"                    "$REPO/bin/codehive.in" render

for f in claude-rc@.service claude-rc-plain@.service claude-rc-launcher.service claude-rc-sync.service \
         claude-rc-update-check.service; do
  put 644 "$UNIT_DIR/$f" "$REPO/systemd/$f.in" render
done
put 644 "$UNIT_DIR/claude-rc-sync.timer"  "$REPO/systemd/claude-rc-sync.timer"
put 644 "$UNIT_DIR/claude-rc-update-check.timer" "$REPO/systemd/claude-rc-update-check.timer"
put 644 "$UNIT_DIR/claude-rc-watch@.path" "$REPO/systemd/claude-rc-watch@.path"

put 644 "$LAUNCHER_DIR/CLAUDE.md" "$REPO/launcher/CLAUDE.md.in" render
# The launcher's settings: the update notice hook, plus the permission above
settings="$LAUNCHER_DIR/.claude/settings.json"
was_ours=0
for f in "${old_manifest[@]}"; do [ "$f" = "$settings" ] && was_ours=1; done
if [ -e "$settings" ] && [ "$was_ours" = 0 ]; then
  warn "$settings already exists; not replacing it. See \"The launcher's settings\" in docs/configuration.md for what to add."
else
  put 644 "$settings" "$REPO/launcher/settings.json.in" render
fi

for root in "${PROJECT_DIRS[@]}"; do mkdir -p "$root"; done

# Where this install came from, for `codehive update`
source_file="$CODEHIVE_DATA/source"
{
  echo "# Where codehive was installed from; \`codehive update\` installs from here again"
  if [ "${CODEHIVE_DOWNLOADED:-}" = 1 ]; then
    printf 'CODEHIVE_REPO=%q\nCODEHIVE_REF=%q\n' "$CODEHIVE_REPO" "$CODEHIVE_REF"
  else
    printf 'CODEHIVE_CHECKOUT=%q\n' "$REPO"
  fi
} >"$source_file"
new_manifest+=("$source_file")

# Remove files from the previous install that aren't part of this one
# (for example after changing --bin-dir or --launcher-dir)
for f in "${old_manifest[@]}"; do
  [[ " ${new_manifest[*]} " == *" $f "* ]] || rm -f "$f"
done
printf '%s\n' "${new_manifest[@]}" >"$MANIFEST"

# Write the config with $HOME kept symbolic, so it can be copied to another machine
q() { local p="$1"; [[ "$p" == "$HOME/"* ]] && p="\$HOME/${p#"$HOME"/}"; printf '"%s"' "$p"; }
mkdir -p "$(dirname "$CODEHIVE_CONFIG")"
{
  echo "# codehive config (bash syntax). Run the installer again after changing it;"
  echo "# PERMISSION_MODE only needs \`codehive restart\`, and AUTO_TRUST applies on the next sync."
  echo
  echo "# Folders whose subfolders are projects. \`codehive new\` uses the first one."
  echo "PROJECT_DIRS=("
  for d in "${PROJECT_DIRS[@]}"; do echo "  $(q "$d")"; done
  echo ")"
  echo
  echo "# The launcher's workspace, where you ask for new projects from any client"
  echo "LAUNCHER_DIR=$(q "$LAUNCHER_DIR")"
  echo
  echo "# Where the codehive command is installed; should be on your PATH"
  echo "BIN_DIR=$(q "$BIN_DIR")"
  echo
  echo "# Permission mode for sessions (acceptEdits, auto, default, ...); empty means Claude Code's default"
  echo "PERMISSION_MODE=\"$PERMISSION_MODE\""
  echo
  echo "# 1 lets the launcher run \`codehive new\` without asking"
  echo "LAUNCHER_AUTOAPPROVE=$LAUNCHER_AUTOAPPROVE"
  echo
  echo "# 1 trusts every project folder automatically, so a server starts for anything"
  echo "# that lands in one. 0 only serves folders you've trusted. See docs/workspace-trust.md."
  echo "AUTO_TRUST=$AUTO_TRUST"
  echo
  echo "# 1 checks GitHub once a day for a newer codehive release and mentions it in"
  echo "# \`codehive status\` and at the start of launcher sessions"
  echo "UPDATE_CHECK=$UPDATE_CHECK"
  echo
  echo "# 1 stops sessions from gaining privileges: sudo, su, and other setuid programs"
  echo "# don't work in them. Needs \`codehive restart\`. See docs/security.md."
  echo "HARDEN=$HARDEN"
} >"$CODEHIVE_CONFIG"

# ---------------------------------------------------------------- start

if [ "$(loginctl show-user "$USER" --property=Linger --value 2>/dev/null)" != yes ]; then
  echo "Enabling lingering so the servers run while you're logged out and start at boot (needs sudo)..."
  sudo loginctl enable-linger "$USER"
fi

# The launcher's server can't answer the trust dialog either
"$CODEHIVE_DATA/libexec/claude-trust" "$LAUNCHER_DIR" \
  || warn "couldn't trust $LAUNCHER_DIR; run \`claude\` there once and accept the dialog"

systemctl --user daemon-reload
systemctl --user enable --now --quiet claude-rc-update-check.timer

if is_off; then
  echo "codehive is off, so no servers were started. Run \`codehive on\` to start them."
else
  systemctl --user enable --now --quiet claude-rc-launcher.service claude-rc-sync.timer

  wanted_watches=()
  for root in "${PROJECT_DIRS[@]}"; do
    unit="claude-rc-watch@$(systemd-escape --path "$root").path"
    wanted_watches+=("$unit")
    systemctl --user enable --now --quiet "$unit"
  done
  list_instances 'claude-rc-watch@*' | while IFS= read -r unit; do
    [[ " ${wanted_watches[*]} " == *" $unit "* ]] || systemctl --user disable --now --quiet "$unit"
  done

  systemctl --user start claude-rc-sync.service
fi
# A notice from before this install may be out of date; check again in the background
rm -f "$CODEHIVE_DATA/update-available"
systemctl --user start --no-block claude-rc-update-check.service

echo
"$BIN_DIR/codehive" status
echo
echo "Installed. Config: $CODEHIVE_CONFIG"
if [ "$units_changed" = 1 ] && [ -n "$(list_instance_units)" ]; then
  echo "Service files changed; running servers keep the old settings until \`codehive restart\`."
fi
case ":$PATH:" in *":$BIN_DIR:"*) ;; *) echo "Add $BIN_DIR to your PATH to use the codehive command." ;; esac
