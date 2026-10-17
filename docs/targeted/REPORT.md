# Terra MX 0.3.1 — targeted steering repair

This test build keeps the v3 engine, vehicle architecture, tire force law, terrain friction, suspension, rider, track and controls. It repairs the steering-reference path. It is not evidence that human riding feel is realistic.

Preserved baseline: **266751cc59e5d30f3f8c6dbb34a63d0783350d87**, including its unchanged Windows/source ZIPs. Changes are isolated on **repair/traction-steering-v3**. Runtime identity: **ReducedCoordinateMotorcycle/v3.1-targeted**.

## Findings and exact behavior changes

### 1. Steering correction used the wrong lean geometry

`rider_controller.gd` converted a desired ground-heading correction to steering using `cos(lean) / cos(rake)`. For the existing raked steering mechanism, the small-angle ground-heading derivative on flat terrain is `cos(rake) * cos(lean)`. The old conversion therefore delivered approximately `cos(lean)²` of the intended correction: 88.3% at 20° lean and 58.7% at 40° lean.

The repair divides by the actual mechanism's projected heading derivative. `geometry.gd::heading_per_steer()` computes that derivative using chassis orientation, current steering and the contact normal. The existing fork, wheel and fender geometry is unchanged. Six independent finite-difference tests cover lean, steering, yaw, pitch and sloped contact normals.

### 2. The steering actuator lagged its moving reference

The actuator was a bounded position spring with damping against actual steering velocity. It omitted target-velocity feedforward. In the baseline low-speed trace, actual steering was still +15.7° when its target had moved to +10.9°. The following correction overshot in the other direction; the six-second case eventually fell. Normal tire forces were not continuously saturated before that oscillation developed.

`motorcycle.gd` now includes `damping * target_steering_rate` in hand torque. Target rate is estimated from reference motion, bounded to ±6 rad/s and filtered with a 25 ms time constant. Existing stiffness **65 Nm/rad**, computed critical damping **6.84 Nms/rad**, steering inertia **0.18 kgm²**, angle stops and **30 Nm hand-torque limit** remain unchanged. Actual steering still evolves through inertia and torque; there is no angle assignment or chassis rotation command.

### 3. Accumulated roll trim persisted after the error reversed

The trace showed integral correction around +2.3 rad/s² after the bike crossed back through its requested lean. That stale correction continued pushing it into an opposite lean. Faster actuator tracking exposed this clearly in the angled-landing regression.

`rider_controller.gd` now clears accumulated roll trim when the roll error changes sign. Roll-error/rate feedback, integral gain **6**, integral bound **±3**, and steering assistance remain. This is a zero-crossing reset of stale trim, not a change to tire friction or an extra upright torque. The final angled-landing test recovers to about **+0.03°** lean at four seconds; its 29.1° peak still indicates a substantial transient.

These three small changes form one steering-reference tracking repair. No other handling parameters were tuned.

## Tire, load and restriction audit

- Tire forward/right axes and force signs are consistent: right is `forward × normal`, and lateral tread demand opposes contact-point lateral velocity. In the replay's normal riding cases, front lateral shear did not add positive slip power. Brief elastic energy release is present during the brake-slide transient, as expected from stored tread shear.
- Applied tire forces remain within the combined `mu * load` budget; production unloading/friction tests pass. Grounded static loads sum to approximately **1775.6 N**, supporting the unchanged 181 kg total mass.
- The original tire force law and its inverse are unchanged. `contact_tire.gd` only gains diagnostic fields. There is no lateral velocity overwrite, added lateral lock, friction increase or new tire model.
- The `mu * 0.55` requested-lean envelope remains exactly as in v3. It limits the requested lean; actual chassis roll remains physical. Its realism/calibration is unresolved. Keeping it fixed makes the steering repair comparison interpretable.
- Integral/force limits were measured. Normal gradual/reversal cases did not require persistent clipping of front lateral-force requests. The imposed rear-brake slide briefly reaches limits and remains deliberately recoverable.
- Global/body angular damping remains zero in Replace mode; chassis rotation axes remain unlocked. Suspension travel and force calculations are unchanged.
- Several older `250f.json` steering/tire tuning fields are not consumed by the replacement path: v3 uses hardcoded tread stiffness/relaxation and the steering constants above. The file was inspected and left unchanged rather than pretending those old fields tune the active controller.
- The saved input curve/deadzone/smoothing is unchanged (default steering smoothing is 0.10 s). Player input remains a lean/balance request with countersteering at speed, not a direct front-wheel angle. Diagnostics expose raw mapped input, filtered command and actual steering separately.

## Identical-input comparison

[before.json](before.json) records v3 with observation-only instrumentation; [after.json](after.json) records this repair. Both use the same five six-second waveforms in `tests/targeted_probe.gd`, 240 Hz, same spawn and terrain, assists enabled, manual gear, and no player-device input. Straight/gradual/reversal/slide start at 10 m/s in gear 2, 6000 RPM, throttle 0.4. Low speed starts at 4 m/s in gear 1, 4000 RPM, throttle 0.28. Gradual steering ramps to 0.55; reversal switches +0.5 to −0.5; low steering ramps to 0.35. The slide holds 0.25 steering and applies rear brake/clutch from 2.0 to 2.5 seconds before release.

| Measurement | v3 | Repair |
|---|---:|---:|
| Straight, integrated absolute chassis lateral travel | 0.000 m | 0.000 m |
| Gradual turn, lateral travel | 0.300 m | 0.252 m |
| Gradual turn, lean-error RMS | 2.89° | 2.80° |
| Gradual turn, front lateral-force error RMS | 6.58 N | 9.19 N |
| Reversal, first steering movement after command | 79 ms | 46 ms |
| Reversal, front lateral-force error RMS | 20.65 N | 7.33 N |
| Reversal, lean-error RMS | 8.20° | 7.12° |
| Reversal, lateral travel | 0.707 m | 0.607 m |
| Six-second low-speed case | Fell | Upright, 9.47° peak lean |
| Low-speed first steering movement | 133 ms | 83 ms |
| Rear-brake slide/recovery, lateral travel | 0.923 m | 0.469 m |
| Rear-brake slide/recovery, lean-error RMS | 4.01° | 2.09° |
| Deliberate rear lock, peak slip ratio magnitude | 1.00 | 1.00 |
| Rear slip ratio magnitude at end | 0.015 | 0.020 |

The gradual turn's force-error RMS is worse. Resetting accumulated trim changes the force reference during recovery; the resulting heading/lean metrics are not uniformly improved by every measure. Report this tradeoff rather than selecting only favorable numbers. The low-speed baseline's post-crash RMS values are not comparable as normal riding metrics.

Timing measures command-to-first-steering movement above 0.002 rad, using direct simulation commands. It excludes controller hardware latency and the saved input filter. Lateral travel integrates absolute velocity along the chassis right axis; it is not a measured racing-line error. Controller changes can produce different speeds/paths/surface exposure despite identical initial conditions and commands. Traces are recorded at 30 Hz; summaries accumulate at 240 Hz.

## Validation and files

`./tests/run_all.sh` completed with **109 passing assertions, zero failures**: the original 98 checks, six geometry checks and five focused replay assertions. The expanded handling suite retains its full-input, small-correction, turn/reversal, low-speed, slide and landing bounds. [Full log](regression.log.txt), [handling results](handling-after.json), [component results](components-after.json).

Windows and Linux release exports completed without script/export errors. The actual exported Linux executable completed its 1260-tick support/acceleration/braking/rider/controller self-test with the new identity: [runtime log](exported-runtime.log.txt). [BUILD.json](BUILD.json) records source/executable hashes, test counts and unchanged subsystem hashes. ZIP checksums accompany the downloads. Windows execution and physical gamepad/vibration have not been tested here.

Modified production files:

- `src/physics/replacement/motorcycle.gd`: reference-velocity feedforward, heading derivative input, reset state and force telemetry.
- `src/physics/replacement/rider_controller.gd`: corrected heading conversion, zero-crossing trim reset and request-limit diagnostics.
- `src/physics/replacement/geometry.gd`: derivative query only; existing mechanism functions remain unchanged.
- `src/physics/replacement/contact_tire.gd`: observation/reset fields only; force/spin calculations unchanged.
- `src/main.gd`: requested diagnostics and build identity text.
- `src/diagnostics/build_smoke.gd` and `project.godot`: expected identity/version.

Tests add `run_steering_geometry.gd` and `targeted_probe.gd`; existing identity assertions and test runner are updated. `tools/package_targeted.py` produces uniquely named test ZIPs. Tire parameters, suspension module, track, controls implementation, rider animation, motorcycle visual and rider asset are byte-for-byte equal to v3; the build manifest checks this.

For baseline reproduction, use a clean v3 source copy at commit `266751c`, apply [baseline-instrumentation.patch](baseline-instrumentation.patch) with `git apply --unidiff-zero`, and copy the current `tests/targeted_probe.gd` into its tests folder. Import with `./launch.sh --headless --editor --import --quit`, then run the probe without `--assert` to record its known failure. Instrumentation only reads or records state and does not change forces, commands or integration. In this repair checkout run `./tests/run_all.sh` for the passing candidate.

## Your playable comparison

Extract the new ZIP into a separate folder and run `TerraMX.exe`. Keep v3 in its own folder. Use the same saved settings with steering assistance enabled for the virtual-rider comparison. F1 shows input, steering target/actual, lean target/actual, contact lateral velocities, loads, grip utilization, local tire forces and applied world forces. [Rendered diagnostic inspection](diagnostics.png) uses injected commands, so raw device input is zero in that image.

Start in the flat loam lane, try a gradual turn, a reversal, a sustained slow turn, then a brief rear-brake slide and release. Test with your normal device and report the input/assist settings alongside any problem. This completes the requested targeted test build. Further development or calibration should wait for your evaluation; automated results do not establish MX Bikes-style realism.
