#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
PROJECT=${1:?Supply Godot project path}
LABEL=${2:-baseline}
export XDG_DATA_HOME="$HERE/runtime/data" XDG_CONFIG_HOME="$HERE/runtime/config" XDG_CACHE_HOME="$HERE/runtime/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
export BENCH_OUTPUT="$HERE/$LABEL.json"
godot --headless --path "$PROJECT" --script "$HERE/bench.gd" | tee "$HERE/$LABEL.log"
sha256sum "$PROJECT/scripts/main.gd" > "$HERE/$LABEL.sha256"
