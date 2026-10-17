# Terra MX 3.2 — steering/stability test update

This is the first staged update permitted by the v3.2 request. It preserves v3.1
and refines the input-to-ground-lean response. Suspension oscillation, airborne
whips and their remaining configuration migration are deferred to separate test
updates. Faster roll response raises some force transients; human evaluation of
this stage is needed before combining more changes. This is not a claim that
MX Bikes realism, real suspension setup, or whip handling has been achieved.

## Preserved baseline and scope

New branch: `refinement/v3.2-steering`, based on
`repair/traction-steering-v3` at
`bbcb836f8c01d69bb120f9b8b3649c81f9b27e31`.
The original v3.1 source/Windows archives and branch are intact.
There is one active replacement controller, identified as
`ReducedCoordinateMotorcycle/v3.2-steering`.
`--legacy` still selects v2 and is not a v3.1 comparison switch.

No changes to tire friction/force law, suspension integration, track, rider
model, mass/inertia, crash thresholds, controller mappings, or physics engine.
No chassis attitude/velocity overwrite, extra ground balance torque, or new
unrestricted air-control torque was added.

## Diagnosis and code changes

1. `rider_controller.gd`: the old damping term was `8.32 * actual_roll_rate`.
   It opposed both unexpected roll and intentional movement toward a changing
   lean request. The player waited while the proportional/integral error built.
   The new term is `8.32 * (actual_roll_rate - 0.35 * requested_lean_rate)`.
   Requested rate is computed after the existing 100 degrees/s limiter.
   This supplies a modest, bounded moving-reference contribution through the
   existing front-force inverse and steering actuator. Unexpected roll remains
   damped. P, D, I gains, integral bounds/reset and lean/grip envelope retain
   v3.1 values. The fallback curvature calculation is unchanged.
2. `controls.gd`: new-profile steering smoothing is 0.06 seconds rather than
   0.10. The 1.35 curve is unchanged. The production single exponential filter
   and mapping/deadzone path remain. Saved user response values override defaults;
   no binding/profile migration forces the new smoothing onto existing players.
3. `250f.json`: active rider/steering tuning is in `handling.rider` and
   `handling.steering`; input defaults are `handling.input`. Existing actuator
   stiffness 65 Nm/rad, damping ratio 1, 30 Nm torque cap and finite stops remain.
   Config extraction alone reproduces **all seven baseline scenario summaries
   exactly**, with tracking=0 and smoothing=0.10. See CONFIGURATION.md for
   legacy lookalike fields and deferred configuration work.
4. `motorcycle.gd`: uses those active steering settings and adds telemetry for
   roll/yaw rates, requested lean rate, both slip angles, and suspension velocities.
   Existing F1 diagnostics retain raw mapped input/filtered command, target/actual
   steer and lean, loads, utilization, tire velocities and applied tire forces.
5. `input_response_probe.gd` / `replay_controls.gd`: inject post-deadzone action
   strengths into the real Controls command path. Previous handling tests injected
   already-filtered commands and could not measure input smoothing/curve delay.
   Original direct-command tests remain and keep their original thresholds.
   Version/header and build-smoke expectations identify the new implementation.

The steering actuator velocity feedforward from v3.1 remains unchanged in value.
We did not increase steering speed, torque or grip to hide delay. In normal
reversal replay the front never reaches saturation in either version; delayed
reference tracking is demonstrable without traction exhaustion. This evidence
covers these scenarios, not every reported washout on the track. Baseline load
spikes in the gradual-turn scenario remain a separate suspension investigation.

## Identical-input comparison

Godot 4.6.3, GodotPhysics3D, 240 Hz. Seven six-second cases, identical initial
poses, wheel speeds, drivetrain state and raw post-deadzone action schedules.
Steering and foot-support assists on; no saved-profile dependence in the replay.
10 m/s normal, 4 m/s low speed and 18 m/s fast reversal. Both versions use curve
1.35. v3.1 uses smoothing .10; final uses .06. Trace samples at 30 Hz; aggregate
metrics are computed at 240 Hz (4.17 ms resolution). No physical USB/gamepad or
OS input latency is represented.

| Metric | v3.1 | 3.2 steering test |
|---|---:|---:|
| Normal reversal: first +0.5 degree lean after input | 204 ms | 96 ms |
| Normal reversal: lean crosses zero after opposite input | 654 ms | 367 ms |
| Normal reversal: overshoot past negative lean target | 0.973 degrees | 0.762 degrees |
| Normal reversal: lean error RMS | 5.502 degrees | 4.182 degrees |
| Normal reversal: last time outside +/-1 degree target band | 3.733 s | 3.633 s |
| Fast reversal: zero crossing after opposite input | 658 ms | 338 ms |
| Fast reversal: overshoot | 0.886 degrees | 0.505 degrees |
| Gradual turn: first +0.5 degree lean after ramp starts | 529 ms | 338 ms |
| Gradual turn: lean error RMS | 2.295 degrees | 1.561 degrees |
| Small correction: first +0.5 degree lean | 571 ms | 267 ms |
| Low speed: first +0.5 degree lean | 492 ms | 313 ms |
| Low speed: lean error RMS | 1.366 degrees | 0.920 degrees |
| Straight: lateral travel | 0 m | 0 m |
| Crashed cases | 0 / 7 | 0 / 7 |

Settling-band timestamps are relative to scenario start; reversal starts at 2.5s.
The last-outside metric describes the finite observation window, not proof of
asymptotic settling. Small-correction peak lean increases 0.742→0.857 degrees.

**Tradeoffs:** normal-reversal front-force tracking RMS rises 5.40→19.53 N;
fast reversal rises 5.50→25.62 N; low-speed rises 1.69→3.06 N. Normal-reversal
peak roll rate rises .429→.768 rad/s and peak yaw rate .262→.439 rad/s. The bike
moves earlier and faster, with less reversal lean overshoot, but not every force
metric improves. A rear-brake slide still reaches locked-wheel slip=1 and
recovers to about .020 final slip; no adhesion guarantee or universal recovery
claim follows from that scripted case. Peak load/grip/slip and force traces are
in comparison.json and the replay files.

## Isolated experiments

- `baseline.json`: untouched v3.1 copied from the preserved Git commit.
- `config_only.json`: final controller with tracking=0 and smoothing=.10;
  all seven scenario summary dictionaries exactly match baseline.
- `rider_only.json`: tracking=.35, smoothing=.10, five original cases.
  Reversal lean RMS 5.502→4.073 degrees; force RMS 5.40→16.61 N.
- `stronger_rejected.json`: tracking=.60, smoothing=.10. Reversal lean RMS
  improves to 3.603 but force RMS increases to 26.68 N; not shipped.
- `combined.json`: tracking=.35 and smoothing=.06, seven cases.
  Faster reversal than rider-only, with slightly greater lean error RMS
  (4.182 vs 4.073) and force RMS (19.53 vs 16.61 N).

Experiment files captured before release identity stamping may identify the
runtime as v3.1-targeted; the names/parameters above describe the actual candidate.
BUILD.json identifies the exact shipped sources and final validation.

## Reproduction

From the source project's root, Godot 4.6.3 standard:

```sh
./launch.sh --headless --editor --import --quit
./tests/run_all.sh
./launch.sh --headless --fixed-fps 240 --script res://tests/input_response_probe.gd -- /tmp/combined.json --assert
./launch.sh --headless --fixed-fps 240 --script res://tests/input_response_probe.gd -- /tmp/config-only.json --tracking=0 --smoothing=0.10
./launch.sh --headless --fixed-fps 240 --script res://tests/input_response_probe.gd -- /tmp/rider-only.json --smoothing=0.10
```

For the original baseline, extract `git archive bbcb836f...` into a separate
scratch directory, copy only the two replay test scripts into its tests folder,
import it, and run the input probe without `--assert` or tuning overrides. This
is a source copy, not a second Git worktree. The baseline fails the new <.5s
reversal latency requirement; original thresholds have not been weakened.

## Manual riding comparison

1. Keep v3.1 and the new build extracted into separate folders. Run the new
   `TerraMX.exe`; verify F1 shows `v3.2-steering` and the header says 3.2.
2. Preserve your bindings. Enable Steering assist and Foot support in Settings.
   To isolate the controller change, use curve=1.35 and smoothing=.10 in both
   versions. The same saved profile is shared by the two executables.
3. On flat hardpack, ride straight, make a small brief correction, hold a gradual
   corner, then alternate left/right at modest speed. Note input delay, remaining
   roll after release, overshoot and front/rear slip. Reset before each repeat.
4. In the new version only, set smoothing=.06 and repeat. Existing profiles will
   otherwise retain .10. Leave sensitivity/curve/assists unchanged. Restore .10
   before running v3.1 again for a matched-settings comparison.
5. Try low-speed figure eights and a short rear-brake slide with recovery. Work
   up to faster reversals. Report speed/gear, lane/surface, input amount, response
   settings and whether front or rear loses grip; F1 exposes the relevant values.
6. Check ordinary jumping, pitch braking, rider movement and landing still work.
   Treat current bouncing and unsatisfying whips as known pending work; this
   update does not claim to fix them.

For Godot, download the **source ZIP**, extract it, import `project.godot` using
Godot **4.6.3 standard**, then press F5. The Windows runtime ZIP has a standalone
executable and cannot be imported as a Godot project. No Blender install is
required to load the baked rider asset.

Automated passes establish repeatable behavior and regressions covered here.
They cannot establish subjective handling realism, real-world calibration,
Windows execution, gamepad feel, or satisfying whips. Those require human riding
feedback on the target machine.

## Release validation

Final source suite: **116 passed, 0 failed** (109 existing checks plus seven
input-path replays). Both Windows and Linux release exports succeeded. The
actual Linux exported executable passed its 1,260-tick acceleration, braking,
support and original-rider smoke check. Windows execution and human/gamepad
feel are unverified. BUILD.json records source/export fingerprints and unchanged
subsystems; validation.log contains the final suite and exported-runtime output.
