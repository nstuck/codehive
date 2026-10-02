#!/usr/bin/env bash
# Stop every codehive server and remove the installed files.
# Project folders are never touched. --purge also removes the config and the
# launcher folder.
set -euo pipefail

here="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
# shellcheck source=lib/common.sh
. "$here/lib/common.sh"
MANIFEST="$CODEHIVE_DATA/manifest"

purge=0
case "${1:-}" in
  --purge) purge=1 ;;
  "") ;;
  *) echo "usage: uninstall.sh [--purge]" >&2; exit 1 ;;
esac

echo "Stopping servers..."
systemctl --user disable --now --quiet claude-rc-sync.timer claude-rc-update-check.timer \
  claude-rc-launcher.service 2>/dev/null || true
list_instances 'claude-rc@*' 'claude-rc-plain@*' 'claude-rc-watch@*' | while IFS= read -r unit; do
  systemctl --user disable --now --quiet "$unit"
done

echo "Removing files..."
if [ -r "$MANIFEST" ]; then
  while IFS= read -r f; do
    rm -f "$f"
  done <"$MANIFEST"
  rm -f "$MANIFEST" "$CODEHIVE_DATA/update-available"
  for d in "$LAUNCHER_DIR/.claude" "$LAUNCHER_DIR" "$CODEHIVE_DATA/libexec" "$CODEHIVE_DATA/lib" "$CODEHIVE_DATA"; do
    rmdir "$d" 2>/dev/null || true
  done
else
  echo "No install manifest at $MANIFEST; nothing to remove." >&2
fi
systemctl --user daemon-reload

if [ "$purge" = 1 ]; then
  rm -f "$CODEHIVE_CONFIG"
  rmdir --ignore-fail-on-non-empty "$(dirname "$CODEHIVE_CONFIG")" 2>/dev/null || true
  rm -rf "$LAUNCHER_DIR" "$CODEHIVE_DATA"
fi

echo "codehive is uninstalled. Your project folders were not touched."
[ "$purge" = 1 ] || echo "Config kept at $CODEHIVE_CONFIG (use --purge to remove it)."
