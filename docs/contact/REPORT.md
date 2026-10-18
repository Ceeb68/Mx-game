# Terra MX 3.5 — targeted tire and fallen-contact repair

Built on preserved v3.4 commit `7a1c96ca417bd35fa09f02be3841b2c7a2b00f10`,
branch `refinement/v3.4-ground-contact`. New branch:
`repair/tire-contact-crash-sliding`. The old build and archives remain intact.

This update repairs fallen contact and removes active virtual-rider steering
following a crash. **It does not complete the known berm/bump/whoops repair or
establish MX Bikes-level realism.** Normal riding steering and tire coefficients
are preserved. Actual Windows execution and human/gamepad feel remain unverified.

## What the investigation established

The wheels are not just animations. Each wheel has angular inertia, drive/brake
and tire-reaction torque; the chassis receives the corresponding momentum
reaction. Each suspension station has a separate compliant unsprung coordinate.
Tire forces depend on load, signed patch velocity, wheel spin, deformation and a
shared longitudinal/lateral friction budget. Visual wheels integrate the same
simulated angular velocity. Forward rolling is positive scalar omega, physical
rotation about **negative axle**, and negative visual X rotation; those signs
and the existing chassis reaction are consistent. No momentum-sign change ships.

On smooth ground, measurement does **not** reproduce unlimited gliding. From
8 m/s, six seconds of clutch-in coasting ends at **6.382 m/s**; front/rear wheel
speeds remain coupled through tire forces. Normal acceleration from 6 m/s reaches
**9.713 m/s**, with mean rear longitudinal slip after 1 s around **1.1%**. Hard
braking from 8 m/s stops after **10.434 m**, including the initial 0.5 s coasting
period. Rear lock produces approximately **−1 slip**; releasing the brake
restores rolling. Hardpack and loam corners and the mild brake perturbation
recover without a crash. These results match v3.4 at the reported precision.
They establish distinct physical responses, not subjective grip quality.

Three specific contact problems were found:

1. The 0.28 m-wide central collision box misses the 0.8 m handlebar and 0.56 m
   footpeg support spans visible on the existing bike. A side fall can put those
   visible components through the terrain while the much narrower box supports
   the chassis. Friction was already dissipating energy; blindly raising it
   would not repair the contact locations.
2. The virtual rider remains active after `crashed=true`. In the tipped-fall
   probes it still supplies up to **30 Nm of hand torque**, including moments
   with a tire loaded. That is a balance controller attempting to ride a fallen
   motorcycle, rather than passive post-crash mechanics.
3. The riding tire frame projects chassis/wheel forward onto the road. For a
   pitched or cambered disk, this need not equal the wheel/road plane
   intersection. A single-wheel pure-rolling test produces fictitious lateral
   demand up to about **860 N**, despite zero physical patch velocity. The exact
   disk tangent removes that artifact in the test. Applying it to all riding
   also changes the balance controller's force/steering relationship and
   regresses existing tests, so that broad variant was rejected.

## Exact retained changes

- `src/physics/replacement/crash_contacts.gd`: two native capsule contacts fitted
  to the existing handlebar and footpeg geometry, in addition to the existing
  core box. They belong to the same rigid body and use its unchanged friction
  **0.45**, zero restitution, mass and explicit inertia. They are always present;
  the native solver decides when they touch. No extra custom skid friction or
  contact-count multiplier is applied. Installation preserves the existing
  presentation child ordering verified by rider/input tests.
- `motorcycle.gd`: after a crash, release the virtual rider's steering and
  landing preparation and apply **zero active hand torque**. Passive trail,
  steering damping, wheel spin, gyroscope reactions, suspension and tire forces
  continue. No body pose or velocity is assigned as a crash response.
- `geometry.gd` / `motorcycle.gd`: use the true disk tangent
  `normal.cross(axle)` for **passive fallen-tire contact**. Normal riding retains
  the v3.4 frame and its calibrated steering-heading derivative. The all-riding
  correction needs further coordinated controller work before it can ship.
- `contact_tire.gd`: retain the patch's previous frame and transport stored tread
  deformation when the fallen-contact frame rotates. Projection and an
  anisotropic elastic-energy cap prevent transport from adding stored energy.
  Reset/detach invalidate that frame, preventing stale shear on reattachment.
  During normal riding the frame is recorded without changing existing forces.
- Added raw native collision-point/normal/impulse/velocity/shape diagnostics,
  wheel longitudinal speeds and omega, physical patch velocity and tire-power
  estimates. Existing steering/load/slip/world-force telemetry is retained.

No tire friction, chassis friction, global damping, suspension constants,
rider asset/animation, track, input bindings, response settings or local reset
logic changed. The fixed capsule envelopes approximate the existing components;
they are not independently articulated handlebar or wheel colliders.

## Identical-input driving and crash comparison

Godot 4.6.3 standard, Godot Physics, 240 Hz. Both versions use the same initial
transforms, velocities, wheel omega, gears, RPM and input schedules in
`tests/contact_probe.gd`. Direct commands bypass the input filter equally;
separate existing input-path tests cover saved bindings and filtering.
Each scenario lasts 6 s. Both models use the same world, default assists and
clutch state. Falls start above ground; both versions have the same release
height and gravitational potential. Different support geometry changes the
subsequent drop height and impact, as it should.

| Fall / direction | v3.4 stopping distance | Candidate stopping distance |
|---|---:|---:|
| fall_left_low | 0.610 m | 0.722 m |
| fall_right_low | 0.608 m | 0.561 m |
| fall_left_fast | 10.200 m | 16.074 m |
| fall_right_fast | 15.877 m | 15.763 m |
| fall_left_across | 0.595 m | 0.734 m |
| fall_right_across | 0.701 m | 0.577 m |
| fall_tip_left | 1.401 m | 0.821 m |
| fall_tip_right | 1.273 m | 0.821 m |

Stopping requires horizontal speed below 0.15 m/s for at least 0.5 s; the value
records the start of the final sustained slow window. Distance is accumulated
horizontal path from release, including airborne travel. First native-contact
distance is also recorded so contact-only travel can be derived.

**Distances do not uniformly decrease.** The left low-speed and across falls
travel slightly farther. The 12 m/s left fall travels farther, while the right
changes little; their left/right distance difference falls from about 5.68 m to
0.31 m. All these falls settle with negligible chassis kinetic energy. A simple
point mass sliding at 12 m/s with mu 0.45 would require about 16.3 m before other
losses; long high-energy slides are not, by themselves, evidence of missing
friction. Native 6-DOF impacts and rotation need not match that simple estimate.
This is one paired replay, not a calibrated statistical crash model.

The tipped-fall distance improves **1.401→0.821 m** on the left and
**1.273→0.821 m** on the right. Active hand torque after the crash falls
**30→0 Nm**. The new baseline checks fail those two old cases specifically for
continued steering; all17 candidate driving/fall checks pass. Fully fallen
low-speed cases stop within 0.74 m, without freezing the body.

The extra rear-yaw probe starts with approximately0.5 m/s rear-only lateral
patch motion, produced by initial lateral velocity and yaw rate rather than
cancelled by a velocity assignment. The candidate peaks at**0.563 m/s** rear
lateral speed and recovers to about **0.0024 longitudinal rear slip**, without a
crash. The deliberate longer/harder rear-brake corner still crashes and is kept
as an aggressive-limit observation, not declared successful riding.

## Energy and force measurements

Full 240 Hz traces contain chassis linear/angular velocity, wheel rotation,
longitudinal/lateral slip, normal loads, applied local/world tire forces,
suspension velocity, physical patch velocity, native collision impulses and
contact locations. Derived native friction force is reported tangential impulse
multiplied by 240; its work estimate uses the solver-reported contact velocity.
All tested falls have negative accumulated reported tangential-contact work.
These are reported solver samples, not an exact closed energy balance.
The patch-velocity diagnostic combines rigid-carrier motion and wheel spin;
it omits relative suspension/steering-contact velocity terms. Those remain
reduced-coordinate contact-model approximations, not measured full wheel-body
velocities. The pure-rolling unit cases have zero relative suspension/steering
rates, so their frame-consistency comparison does not depend on that omission.

`body_kinetic_energy_j` is sprung rigid-body translation plus rotation;
`kinetic_energy_j` adds both wheel-spin energies. They do not include a complete
unsprung translation, engine, gravitational or spring energy budget. Kinetic
energy can rise while the bike drops before impact. Free wheels may retain spin
after the chassis stops; they are not forcibly stopped for appearance.
Post-fall chassis speed and body energy, contact impulses and stopping distance
are checked independently, rather than interpreting total wheel-spin energy as
a still-sliding chassis.

See `comparison.csv/json`, before/after result summaries and full compressed
traces, rear-yaw replays, raw validation output and the build fingerprint file.
All failed and aggressive scenarios remain in the stored data.

## Architecture decision and rejected experiment

The measured smooth-ground rolling, force, braking and lock/recovery behavior
does not justify replacing the engine or installing unconstrained wheel bodies.
The retained reduced-coordinate model supports the existing steering progress.
Its sparse rays still approximate the contact envelope, normals, unsprung
coupling and changing terrain. It cannot be treated as a fully validated wheel
contact manifold on rough, strongly banked terrain.

The all-riding wheel-plane experiment passed the existing normal corner check,
but changed the ground suite from 4 to 5 failures (braking bumps newly failed)
and the landing observations from 3 to 4 failures (rough loam newly failed).
It was removed from riding. A reviewable extension patch is preserved at
`full-riding-plane-experiment.patch`, with rejected measurements and validation
output. Use a separate experimental branch if continuing it; the patch extends
the current passive tangent to all riding and changes the heading derivative.
Historical experiment data precedes the final post-crash release/transport
changes, so it is not a byte-for-byte replay of that extension patch.

Swept disk/convex contact could resolve edges missed by three rays, but needs
careful shape orientation, contact manifold selection, continuous collision,
suspension travel and reciprocal force coupling. Constrained wheel assemblies
would add axle/steering/suspension joints, inertia and self-collision problems,
and require a separate stability comparison. Neither was shown necessary for
this targeted fallen-contact repair, and neither architecture is switched on.
The normal riding frame approximation remains an explicit limitation, not a
claimed solution to every report of loose grip.

## Validation and inherited failures

- **178 supported checks pass:**  146 existing checks, 14 contact/frame checks,
  17 driving/fall checks and 1 independent rear-yaw recovery check.
- **9/13 existing ground cases pass.** The same 4 still fail: bank crawl, bank
  transition, bump correction and whoops. `ground-results.json` retains actual
  lean and first-upset states; a flipped bike fails even if its crash flag is
  absent. The unchanged braking-bump case remains within its loose threshold,
  not proof of composed bump riding.
- **3/4 existing landing observations fail:** harder 14° cross-landing,
  small bumps and whoops. Supported landing assertions pass. No thresholds or
  crash detector were weakened.
- The aggressive rear-brake corner still crashes. It is recorded as an
  observation in both full and rear-yaw runs, not counted twice as new coverage.
- Windows/Linux exports complete; actual Linux release smoke passes support,
  acceleration, braking and the retained rider rig for 1,260 ticks. Windows
  execution, target-PC performance and human/controller feel are unverified.

## Reproduce and open the game

```sh
./launch.sh --headless --editor --import --quit
./tests/run_all.sh
./launch.sh --headless --fixed-fps 240 --script res://tests/ground_probe.gd -- /tmp/ground.json --assert
```

The last command intentionally returns nonzero for the 4 inherited failures.
The full supported runner prints the known landing/aggressive observations.
Contact-only replay:

```sh
./launch.sh --headless --fixed-fps 240 --script res://tests/contact_probe.gd -- /tmp/contact.json --assert
./launch.sh --headless --fixed-fps 240 --script res://tests/contact_probe.gd -- /tmp/rear-yaw.json --scenario=rear_slide --rear-yaw --assert
```

`--scenario=` selects a prefix, so the second command also retains the harder
rear-slide observation. `--check-only` checks an existing replay JSON without
rerunning simulation. For baseline comparison, extract the preserved v3.4 source
into another directory, apply `baseline-instrumentation.patch` with
`git apply --unidiff-zero` (observation only), copy the new contact probe there,
and run identical commands. Baseline's two tipped-fall steering checks fail.
Use `python tools/compare_contact.py BEFORE.json AFTER.json OUTPUT_DIRECTORY`.

**Godot source:** extract `TerraMX-v3.5-contact-test-GODOT-SOURCE.zip`, import its
root **project.godot** in **Godot 4.6.3 standard**, wait for import, press **F5**.
**Windows:** extract `TerraMX-v3.5-contact-test-windows.zip`, run TerraMX.exe.
F1 must identify `ReducedCoordinateMotorcycle/v3.5-contact`. Existing settings and
bindings remain; use the same response/assist profile when comparing. R recovers
locally and F6 selects the next lane. Test low/high-speed side falls on both
sides, coasting, braking, rear lock/release and small turns. Keep v3.4 separately.
Automated checks do not establish realistic or satisfying riding feel.

## Packaged-source verification

The packaged Godot source was extracted into an empty directory. Every source
and runtime file matched the build manifest; Godot 4.6.3 standard imported it
without parse errors, and its actual game launch passed the 1,260-tick smoke.
`source-import.txt` and `source-launch.txt` record those checks. Final archive
fingerprints cover the updated report/logs; runtime files are unchanged from
that clean import. `contact-shapes.json` records actual native collision samples
on the added handlebar and footpeg contacts, not just their presence in the scene.
