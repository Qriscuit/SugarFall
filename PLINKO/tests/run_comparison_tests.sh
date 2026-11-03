#!/usr/bin/env bash
# Run-comparison save/load fixtures must use isolated user data.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/sugarfall-comparison-tests.XXXXXXXX")"
trap 'rm -rf "$TMP"' EXIT
export XDG_DATA_HOME="$TMP/data"
export XDG_CONFIG_HOME="$TMP/config"
export XDG_CACHE_HOME="$TMP/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
GODOT="${GODOT:-godot}"
status=0
"$GODOT" --headless --path "$ROOT" --script res://tests/run_comparison_qa.gd -- --comparison-qa-isolated >"$TMP/comparison.log" 2>&1 || status=$?
cat "$TMP/comparison.log"
if grep -Eq 'SCRIPT ERROR:|^ERROR:|^FAIL:' "$TMP/comparison.log"; then
  exit 1
fi
exit "$status"
