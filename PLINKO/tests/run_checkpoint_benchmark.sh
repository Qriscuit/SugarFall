#!/usr/bin/env bash
# Isolated data/config/cache avoid touching a player's normal game save.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/peg-foundry-checkpoint.XXXXXXXX")"
trap 'rm -rf "$TMP"' EXIT
export XDG_DATA_HOME="$TMP/data"
export XDG_CONFIG_HOME="$TMP/config"
export XDG_CACHE_HOME="$TMP/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
GODOT="${GODOT:-godot}"
"$GODOT" --headless --path "$ROOT" --script res://tests/benchmark_checkpoint.gd
