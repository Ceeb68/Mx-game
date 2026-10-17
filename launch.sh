#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$project_dir/.godot/runtime/data}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$project_dir/.godot/runtime/config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$project_dir/.godot/runtime/cache}"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
exec godot --path "$project_dir" "$@"
