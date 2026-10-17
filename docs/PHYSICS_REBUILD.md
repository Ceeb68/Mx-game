# Physics replacement prototype — 0.3.0

## Inspection and engine decision

The previous release is commit `94da04347ba8d94f6a5301c2ef0ad83e2fffc26d`, version 0.2.0. It uses Godot 4.6.3 standard, the built-in **Godot Physics** 3D rigid-body solver, and `MotorcycleSimulation/v2`. It is not VehicleBody3D, PhysX, or a third-party motorcycle simulator. Track rendering and collision use the same heightfield triangles. The bike is one RigidBody3D; powertrain, tires, suspension and virtual rider are custom GDScript.

Inspection covered the scene, project/export configuration, all physics modules, track, presentation/rig, controls, settings/UI, diagnostics, and test paths. Only the selected motorcycle's `_integrate_forces` applies riding forces. Controls write requests; rider animation and camera do not apply forces. Pause freezes the body deliberately. Reset sets transform/velocities deliberately. There are no simultaneous competing riding controllers or locked chassis rotation axes. Visual parts and skeletal poses are directly transformed, as expected for rendering; they were not independent physical bodies.

Concrete weaknesses in v2:

- Suspension is a massless ray support: chassis contact speed directly becomes damper force; axle extension is assigned from hit distance. There is no unsprung wheel translation, tire carcass compliance, top-out dynamics, or distinction between suspension force and tire load. Extension could also exceed the stated suspension travel. This is a strong candidate for the rigid terrain response.
- The front fender/number plate are chassis children, front wheel rotates about its own vertical pivot, handlebars rotate separately, and forks stretch between endpoints. These mechanisms visibly disagree; the fork geometry has no common raked steering pivot.
- The tire law uses instantaneous speed-derived stiffness, a tanh friction curve, and filtered output force. It has no static elastic tread state. Slip at low speed, saturation and load changes therefore depend on numerical force filtering. This can contribute to a washed-out contact response; it is not evidence that dirt friction coefficients alone are wrong.
- Steering input crosses the saved input filter, lean rate limit, steering rate limit and steering servo. The total response can feel heavy even with zero local damping. Its default Combine damping mode also leaves Godot’s default world damping in effect. The earlier very small slip measurements did not establish good rider feel.
- Wheel contact did not account for a leaning circular wheel's support radius. Rear visual axle motion was vertical rather than a fixed-length swingarm arc.

These are implementation defects/limitations, not evidence of an incapable rigid-body solver. No physical tire telemetry or rider assessment exists to calibrate a claim of MX Bikes/MX Simulator realism.

| Candidate | Fit to this project | Decision |
|---|---|---|
| Godot Physics + replacement motorcycle | Existing 240 Hz rigid-body, terrain query, force and collision facilities; preserves exports/UI/assets | Selected for controlled architecture comparison |
| Built-in Jolt Physics | Available in installed Godot; suitable bodies, constraints, terrain and custom forces | Real alternative. A separate falling-body probe successfully ran at 240 Hz. No motorcycle-quality or solver superiority benchmark is claimed |
| PhysX | Capable native solver; no existing project binding/build pipeline | Requires native integration and cross-platform packaging; does not supply a dirt motorcycle tire model |
| Bullet | Capable solver; not this project's built-in Godot 4 backend | Would need native integration/GDExtension or different engine version |
| Rapier | Capable Rust solver; no existing native binding in this project | Additional native/plugin/toolchain dependency; no justification for migration before correcting forces |

Sources for engine integration context: [Godot 3D physics settings](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#class-projectsettings-property-physics-3d-physics-engine), [Godot Jolt documentation](https://docs.godotengine.org/en/stable/tutorials/physics/using_jolt_physics.html). These references describe capabilities; the local availability probe is the evidence for this installed Jolt build.

## What actually changed

The default scene now instantiates `src/physics/replacement/motorcycle.gd`, identity **ReducedCoordinateMotorcycle/v3**. It does not extend the old motorcycle controller. The old implementation remains at `src/physics/legacy/`, and the original `src/physics/motorcycle.gd` also remains unchanged. Only one implementation is instantiated at launch.

1. **Wheel translation:** `wheel_station.gd` integrates independent front/rear unsprung travel and velocity (7/9 kg). Springs act on a 165 kg sprung body; total nominal mass remains 181 kg. Four implicit suspension/carcass substeps run inside each 240 Hz chassis step. `m q'' = N·axis − spring − projected gravity − mount acceleration`. Contact load follows carcass deflection/damping, separately from spring force. Travel and stops are explicit. Guide reactions include transverse gravity and mount inertia so a raked fork cannot propel an idling bike. Full-extension reaction avoids an artificial upward preload in flight.
2. **Traction:** `contact_tire.gd` replaces the force calculation with elastic tread displacement. A backward-Euler relative-velocity solve couples wheel spin and contact effective mass. Convective tread release depends on distance travelled. Trial elastic force shares one combined friction budget and yields continuously into sliding. Unloading immediately limits force; airborne contact clears tread memory. No lateral velocity overwrite, traction lock or increase to terrain friction coefficients is used. Existing independent rotational wheel inertia and powertrain calculations are retained.
3. **Mechanism:** `geometry.gd` supplies raked steering transforms, fork travel, a fixed-length rear swingarm arc and grip targets to physics, rendering and rider IK. Ground support radius accounts for wheel lean. Normal contact force acts at the tire contact; axial spring/guide corrections act at the wheel station. Fork tubes retain fixed lengths and telescope rather than stretch. High front fender, clamps, plate and bars share the steering parent. Rear fender remains on the chassis. The rear shock endpoints follow the swingarm.
4. **Balance:** `rider_controller.gd` derives a required front lateral force from roll-error/roll-rate feedback, the actual normal/rear/gyroscopic roll moments and front contact lever. It inverts the discrete tread calculation, including stored shear and effective mass, to obtain a steering request. This replaces steady turn-radius feedforward on the ground; bounded integral correction and grip reserve remain. Lean requests have a finite 100°/s rate; steering no longer has a second request slew filter. A compliant finite steering DOF uses hand torque bounded to 30 Nm, critical damping and estimated trail load compensation. Steering and wheel gyroscopic momentum reactions return to the chassis. The replacement explicitly uses Replace damping mode with zero global/body damping; aerodynamic drag and component damping remain physical force/torque terms. No riding transform or rotation assignment exists.
5. **Rider/air:** rider carriage motion has bounded acceleration and stores relative angular momentum; its change applies an equal-and-opposite chassis torque. Throttle/brake alter wheel angular momentum and pitch. Grounded low-speed foot support remains an explicitly switchable development aid; it never runs in flight. There is no airborne upright correction. This provides physical control mechanisms, not an authored whip/scrub animation system.

### Files to review

Created: `src/physics/replacement/motorcycle.gd`, `wheel_station.gd`, `contact_tire.gd`, `rider_controller.gd`, `geometry.gd`; independent preserved copies under `src/physics/legacy/`; `tests/run_rebuild.gd`, `tests/capture_rebuild.gd`; packaging helper `tools/package_build.py`.

Modified: `src/main.gd` (single-controller selection, identity and telemetry); `src/presentation/bike_visual.gd` (component hierarchy); `src/presentation/rider_animator.gd` (shared grip geometry with legacy fallback); `src/diagnostics/build_smoke.gd` (packaged-controller verification); `project.godot` (0.3.0 and explicit backend); `tests/run_physics.gd` (active tire law, total mass, independent fixed-speed flat brake case); `tests/handling_probe.gd` (single-case/trace support); `tests/run_all.sh` (replacement suite). Documentation and validation artifacts record the investigation and results. The original bike data, powertrain and rider asset remain unchanged.

### Scope and fidelity

This is a reduced-coordinate prototype, not a full articulated multibody engine. Fork travel and swingarm angle are numerical DOFs, not separate Godot rigid bodies joined by solver constraints. Chassis inertia uses the existing estimated aggregate values; unsprung mass coupling uses local three-dimensional wheel-station acceleration and omits the full multibody mass matrix. The rear travel solve linearizes the swingarm tangent each chassis step. Steering inertia/trail, tire stiffness, dirt coefficients and rider reactions are development estimates. Carcass contact still uses three terrain rays; it is not a swept wheel collision shape, deformable dirt, or measured motocross tire data. Hard bottoming/extension stops are reduced-coordinate limits, not detailed bump-stop elastomers. Rider animation remains a separate skinned presentation following requests and physical suspension state.

Do not interpret this build as completed realistic whips/scrubs, a validated race simulator, or a proven improvement in human riding feel. These require further physical calibration and hands-on assessment. The architecture change and the automated behaviors can be verified now.

## Launch and compare

Extract the Windows archive; run `TerraMX.exe`. The header says **REBUILD PROTOTYPE** and debug display identifies **Godot Physics • ReducedCoordinateMotorcycle/v3**. F1 toggles diagnostics. Existing keyboard/gamepad binding editor, profile, rider, camera, track and settings remain connected.

For the preserved controller, run `TerraMX.exe -- --legacy` from a terminal, or use the supplied `Compare-legacy.bat`. Its debug identity is **MotorcycleSimulation/v2** and it uses the preserved old visual hierarchy. The previous Phase 2 ZIP remains downloadable unchanged. Comparison does not run both controllers on the same body.

From source:

```sh
./launch.sh
./launch.sh -- --legacy
./tests/run_all.sh
./launch.sh --headless --fixed-fps 240 --script res://tests/handling_probe.gd -- user://old.json --legacy --assert
./launch.sh --headless --fixed-fps 240 --script res://tests/handling_probe.gd -- user://new.json --assert
```

`tests/run_rebuild.gd` checks the actual selected script, backend setting, separated masses/load, no idle creep, unsprung transient response versus the old algebraic spring, tread memory/yield/unloading, steering/fender parentage, fork travel and tube lengths, swingarm radius, and rider airborne momentum transfer. `tests/capture_rebuild.gd` produces explicitly frozen articulation views, not riding screenshots.

For hands-on comparison, start in the flat loam lane (F6), accelerate gently, hold a small steering input, reverse it, brake in a turn, then use the bump and tabletop lanes. Test raw steering with virtual rider assistance disabled separately. Inspect that the high front fender turns with the bars while the axle telescopes beneath it. Try seated/standing and body shifts in flight. Existing saved response curves and smoothing remain active; adjust them in Settings → Response if desired. Check traction release under rear brake and aggressive throttle rather than expecting unlimited grip.

Results and package fingerprints accompany this build. Linux automated runtime and rendered inspection are possible here; physical gamepad feel and Windows execution are not verified in this environment.
