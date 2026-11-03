#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export XDG_DATA_HOME="$PWD/tests/v04_runtime/data"
export XDG_CONFIG_HOME="$PWD/tests/v04_runtime/config"
export XDG_CACHE_HOME="$PWD/tests/v04_runtime/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
godot --headless --path . --script res://tests/v04_qa.gd
