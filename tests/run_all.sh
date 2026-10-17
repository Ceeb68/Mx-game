#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
for suite in run_physics run_track run_controls run_bindings profile_restart run_rider; do
 "$project_dir/launch.sh" --headless --fixed-fps 240 --script "res://tests/$suite.gd"
done
"$project_dir/launch.sh" --headless --fixed-fps 240 --script res://tests/handling_probe.gd -- user://handling-phase2.json --assert
