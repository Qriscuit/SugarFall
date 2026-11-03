#!/usr/bin/env bash
# Reset/migration fixtures write and remove saves. Always use isolated user data.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/sugarfall-reset-tests.XXXXXXXX")"
trap 'rm -rf "$TMP"' EXIT
export XDG_DATA_HOME="$TMP/data"
export XDG_CONFIG_HOME="$TMP/config"
export XDG_CACHE_HOME="$TMP/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
GODOT="${GODOT:-godot}"
status=0
"$GODOT" --headless --path "$ROOT" --script res://tests/reset_progress_qa.gd -- --reset-qa-isolated >"$TMP/reset.log" 2>&1 || status=$?
cat "$TMP/reset.log"
if grep -Eq 'SCRIPT ERROR:|^ERROR:' "$TMP/reset.log"; then
  exit 1
fi
exit "$status"
