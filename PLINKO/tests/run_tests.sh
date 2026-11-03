#!/usr/bin/env bash
# Linux test runner: isolated user data prevents modifying a normal game save.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/peg-foundry-tests.XXXXXXXX")"
trap 'rm -rf "$TMP"' EXIT
export XDG_DATA_HOME="$TMP/data"
export XDG_CONFIG_HOME="$TMP/config"
export XDG_CACHE_HOME="$TMP/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
GODOT="${GODOT:-godot}"
"$GODOT" --headless --path "$ROOT" -- --self-test
"$GODOT" --headless --path "$ROOT" --script res://tests/independent_qa.gd
"$GODOT" --headless --path "$ROOT" --script res://tests/countdown_feedback_qa.gd

"$GODOT" --headless --path "$ROOT" --script res://tests/resume_qa.gd
"$GODOT" --headless --path "$ROOT" --script res://tests/run_comparison_qa.gd -- --comparison-qa-isolated
"$GODOT" --headless --path "$ROOT" --script res://tests/reset_progress_qa.gd -- --reset-qa-isolated
"$GODOT" --headless --path "$ROOT" --script res://tests/monetization_qa.gd -- --monetization-qa-isolated
