#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
for suite in run_physics run_track run_controls run_bindings profile_restart run_rider run_rebuild run_steering_geometry; do
 "$project_dir/launch.sh" --headless --fixed-fps 240 --script "res://tests/$suite.gd"
done
"$project_dir/launch.sh" --headless --fixed-fps 240 --script res://tests/handling_probe.gd -- user://handling-v3.json --assert

"$project_dir/launch.sh" --headless --fixed-fps 240 --script res://tests/targeted_probe.gd -- user://targeted-after.json --assert

"$project_dir/launch.sh" --headless --fixed-fps 240 --script res://tests/input_response_probe.gd -- user://input-response-v32.json --assert

"$project_dir/launch.sh" --headless --fixed-fps 240 --script res://tests/run_recovery.gd
"$project_dir/launch.sh" --headless --fixed-fps 240 --script res://tests/landing_probe.gd -- user://landing-v33.json --assert

"$project_dir/launch.sh" --headless --fixed-fps 240 --script res://tests/run_traction_solver.gd

"$project_dir/launch.sh" --headless --fixed-fps 240 --script res://tests/run_tire_inverse.gd

"$project_dir/launch.sh" --headless --fixed-fps 240 --script res://tests/run_contact_geometry.gd
"$project_dir/launch.sh" --headless --fixed-fps 240 --script res://tests/contact_probe.gd -- user://contact-current.json --assert
"$project_dir/launch.sh" --headless --fixed-fps 240 --script res://tests/contact_probe.gd -- user://contact-rear-yaw.json --scenario=rear_slide --rear-yaw --assert
