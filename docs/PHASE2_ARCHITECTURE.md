# Phase 2 simulation and presentation architecture

Coordinates are SI units: metres, seconds, kilograms, Newtons, radians. Bike local forward is -Z, right +X and up +Y. Positive scalar wheel speed corresponds to angular momentum along -axle. Total mass remains 181 kg, including a 78 kg rider. Inertia, bike geometry, powertrain and surface μ values were retained from the first build.

## One active dynamics path

`scenes/main.tscn` → `src/main.gd` → **`src/physics/motorcycle.gd::_integrate_forces()`**, at **240 Hz**. `MotorcycleSimulation/v2`, actual tick/step, requested/actual lean, wheel sample counts, forces and grip utilization identify the running implementation. There is no replacement chassis controller.

| Module | Ownership |
| --- | --- |
| `physics/motorcycle.gd` | One rigidbody; contact queries, world contact frames, force application, steering assembly, wheel/chassis momentum bookkeeping, aggregate rider COM, reset/crash state |
| `physics/tire.gd` | Independent wheel spin, longitudinal/lateral slip, contact-force response, friction budget, progressive sliding and braking integration |
| `physics/suspension.gd` | Preload, spring, compression/rebound damping and bottoming load; never applies forces itself |
| `physics/virtual_rider.gd` | Optional lean-request filtering and speed-dependent steering requests; never rotates or stabilizes the chassis directly |
| `physics/powertrain.gd` | Existing engine curve/inertia, clutch slip/torque, gears, limiter, engine drag and shift interruption |
| `world/test_track.gd` | Shared visual/collision heightfield and dirt/loam/sand friction/rolling resistance |
| `controls.gd` | One keyboard/pad action model, capture/conflicts, response settings, saved profiles, device handling; writes dimensionless commands |
| `ui/controls_panel.gd` | Accessible tabbed Controls/Response/Riding interface; no physical-force calculations |
| `presentation/bike_visual.gd` | Existing procedural motorcycle, rotating handlebar, visible pegs, wheel/suspension-linked visual parts |
| `presentation/rider_animator.gd` | Original skinned rider and analytical IK; visual-only skeleton poses |
| `main.gd` | Scene composition, telemetry, camera, menu/pause, discrete action dispatch |

Only explicit reset writes chassis pose/velocity. Godot owns gravity and chassis collision resolution. Contact force, air drag, wheel momentum exchange and the existing visible foot-support aid are the only custom chassis force/torque sources. Default rigidbody damping remains disabled. No lateral-velocity cancellation, chassis orientation assignment, hidden roll spring or artificial speed change was introduced.

## Tire response and low-speed numerical stability

The first build used normalized lateral stiffness 6 and fixed 25 ms force relaxation. A half-scale steering reversal in the controlled probe reached 16.3° front slip and 33.8° lean. Those observations motivated changes to the actual force path rather than a global friction multiplier.

Phase 2 uses normalized longitudinal stiffness 12 and front/rear lateral stiffness 15/13.5. The surface friction coefficients are unchanged. Stiffness defines the initial force-versus-slip slope; it does not raise the μFz force limit.

For the longitudinal contact solve, predict free wheel speed from drive and dry-brake torque, then account for the change that the unknown tire force would induce in both wheel and contact-point speed. The denominator includes `r² / Iwheel` plus inverse effective chassis contact mass. Lateral response also includes the force-induced contact-point speed change. Effective inverse mass includes chassis translation and the contact arm's rotational inertia contribution. This bounded backward-looking coupling prevents the higher tire stiffness from making a light wheel chatter numerically at low speed.

A combined brush demand is smoothly limited by μFz. High demand progressively approaches a sliding level of 0.87 of that peak; relaxation is a 0.12 m contact distance divided by forward speed, bounded in time near rest. Current load immediately constrains force on unloading. Front/rear wheel angular speed and the clutch/drivetrain remain separately integrated. Ground-contact torque is not added a second time: the chassis receives the negative change in separately stored wheel angular momentum, plus its existing approximate wheel gyroscopic term.

This is a tractable approximate dirt-tire model, not measured motocross tire data. It lacks carcass deformation, calibrated camber thrust/load sensitivity, soil excavation and independent unsprung translation. A μFz cap and good bounded scenarios do not establish real-world tire accuracy.

## Curved footprint sampling and suspension

Each wheel samples three longitudinal rays across ±0.085 m, accounting for the circular tire's height at the offset samples. Contact position, normal and extension are weighted with twice the weight on the center sample. All rays query the same physical heightfield used for rendering. This reduces single-triangle/single-ray contact discontinuities while preserving actual terrain collision.

The suspension still computes normal load from preload, compression, compression/rebound velocity and progressive bottoming, then the chassis applies the combined contact force at the contact point. Patch sample count, current load, compression, slip, grip utilization and forces are observable. This is not a full finite tire volume or a fork/linkage multibody solver.

## Virtual-rider control and the standing-start fix

Player steering requests a lean, bounded by available steering geometry and a conservative surface-grip envelope. Lean requests slew at 48°/s; steering requests have their own rate limit. A feedforward steer angle plus roll-error/rate feedback is sent to the same finite-inertia front steering servo used in the original build. Real tire contact forces initiate lean and turning.

An expanded true-idle first-gear start test caught a defect missed by moving-start probes: low-speed raw steering could lean the bike the wrong way before sufficient correction authority became active. The final controller blends from parking steering into feedback between 0.3 and 1.8 m/s. Feedback gain compensates for approximately v²-dependent steering-to-roll authority, bounded at low/high speed. Tests cover both this transition and faster corners/reversals. This is an input controller, not a new physical stabilizer.

The existing optional foot support remains capped at 85 Nm, grounded only, and fades below 3 m/s. Its actual torque is shown. It represents a development foot-down aid, not a solved foot/ground contact model. Raw steering and foot support can be disabled separately in Riding settings; expert unassisted handling remains uncalibrated. There is no airborne self-leveling torque.

## Input ownership and persistence

Every action has independent keyboard and controller mappings. A controller mapping can be a button (including D-pad) or a signed analog axis half. Polling preserves analog values, applies the appropriate deadzone, and then steering/lean response shaping. Axis capture requires a neutral sample below 0.25 before a deliberate movement above 0.65. Conflicting assignments remain pending until Swap/Replace/Cancel; old mappings are not silently overwritten.

`controls_v2.cfg` stores mappings, response, assists and camera settings under Godot's user data directory. Writes use a temporary file and atomic replacement. Valid first-build keyboard/controller mappings migrate from the old file, which is preserved. Device IDs are not persisted, so reconnecting retains the layout. Resume/reconnect requires neutral riding inputs; capture/disconnection clears transient commands. Escape is a reserved cancel/recovery shortcut even after Pause is remapped. Synthetic controller event tests cover code paths; a physical device still needs validation.

Discrete commands pass through one action signal to `main.gd`; continuous commands pass through one dictionary to the chassis. Rebinding does not create a competing controller. UI navigation uses Godot's standard mouse/keyboard/gamepad focus behavior.

## Original skinned rider

`assets/rider/terra_rider.glb` contains a 17-bone rig and one skinned mesh with gear material groups. `tools/build_rider.py` reproduces the original mesh, skeleton, helmet/goggles, jersey/pants, gloves and boots in Blender. No downloaded character assets or proprietary game materials are used. The asset is stylized and needs further art/cloth/skin polish before a production-realistic character claim.

Procedural Skeleton3D poses blend sitting/standing, forward/backward/lateral rider input, acceleration and suspension loading. Two-bone IK retains fixed arm/leg segment lengths, uses anatomical elbow/knee pole directions, and targets rotating bar grips and visible footpegs. A reach-constrained torso and pelvis avoid stretching; seated pelvis height accounts for the existing seat. Neck coverage bridges the helmet/collar gap. The rider camera follows the head pose and excludes the self-occluding skin layer; chase rendering restores the full character.

The visual rig never changes rigidbody velocities, inertia or forces. The pre-existing aggregate rider COM shift remains the physical body-position approximation. There is no fully articulated dynamic rider, ragdoll, cloth simulation, knee collision solver or airborne body-momentum system yet. Jump/landing reaction comes from filtered spring/acceleration posture, not added stabilizing torque.

## Development boundaries

The initial engine, gears, independent brakes, contact-force weight transfer, flight and wheel-brake pitch correction, reset, collision/crash state, track lanes and cameras are retained. Dynamic terrain, advanced airborne whips/scrubs, audio, racing, replay, career and networking remain deferred. Godot rigidbody simulation is not guaranteed bitwise deterministic across platforms; fixed stepping alone is not a lockstep networking guarantee.

Use the tests and telemetry to verify actual active changes, then collect rider feedback. Do not equate headless metrics, mesh creation or compilation with subjective handling, physical controller operation or Windows runtime acceptance.
