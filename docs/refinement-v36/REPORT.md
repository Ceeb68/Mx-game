# Terra MX v3.6 — Stage A traction test; Stage B incomplete

This build fixes a measurable tire/brake constraint mismatch. It does **not**
resolve the requested suspension bounce or general rough-terrain traction goal.
No tested suspension candidate cleared the regression checks, so the playable
build retains v3.5 suspension. The four known ground failures remain visible.
Automated measurements do not establish realistic feel or MX Bikes-level handling.

Preserved baseline: `repair/tire-contact-crash-sliding`,
`cd87a8dbebb6f12201694c77db58fe6b359b6af3`.
Development branch: `refinement/v3.6-traction-suspension`.
Godot 4.6.3 standard, Godot Physics, 240 Hz; identical scripted inputs and settings.
The original v3.5 ZIPs and branch are preserved.

## Stage A: accepted brake constraint repair

The old force predictor always included wheel rotational inverse mass `R²/I`,
even when the subsequent finite brake update actually held rotation at zero.
It also renewed the locked tread using carrier speed. This let the predictor
allocate contact impulse to wheel rotation that the brake prevented.

The new solve first tries a stationary tread/locked rotation branch, with chassis
inverse effective mass and zero rolling renewal. It checks the brake torque
needed after contact impulse against the actual finite capacity. If that lock
cannot be held, it solves the rotating branch using the available brake torque.
The wheel spin update uses the same bearing drag as the predictor. No chassis
velocity is assigned or cancelled; no friction coefficient or force multiplier
was raised. Combined longitudinal/lateral saturation and continuous sliding
softening remain active. Lock is a mechanical constraint, not a riding state
that disables slides or rider input.

An initial experiment also changed rotating tread renewal to wheel circumferential
speed. It passed flat tests but regressed braking bumps and was removed.
The final rotating relaxation retains v3.5 carrier-speed convection and the
matching steering inverse. Small floating-point differences at saturated-force
multiplication can still diverge failed crash trajectories; they are not evidence
of improved handling.

### Numerical results

| Identical scenario / measurement | v3.5 | Retained Stage A |
| --- | ---: | ---: |
| Locked wheel at ±0.4 m/s, 900 N load, brake capacity 1000 Nm: force magnitude | 113.675 N | 145.455 N |
| Analytic constrained solution in that test | 145.455 N | 145.455 N |
| Actual wheel rotation after brake update | 0 rad/s | 0 rad/s |
| Hard-brake front slip-ratio RMS, full 6 s | 0.0522 | 0.0235 |
| Hard-brake stopping distance from scenario start | 10.43375 m | 10.47192 m |
| Hard-brake stop time, sustained <0.15 m/s criterion | 2.1458 s | 2.3917 s |
| Coasting final speed | 6.38211 m/s | 6.38211 m/s |
| Hardpack corner front/rear slip-angle RMS | 0.3662° / 0.3561° | 0.3662° / 0.3561° |
| Loam corner front/rear slip-angle RMS | 0.3352° / 0.3204° | 0.3352° / 0.3204° |
| Mild rear slide front/rear slip-angle RMS | 0.2047° / 0.1987° | 0.2047° / 0.1987° |
| Rear-lock/release rolling mismatch RMS | 2.4071 m/s | 2.4125 m/s |
| Low-speed left/right side-fall stop distance | 0.72194 / 0.56070 m | 0.72194 / 0.56070 m |
| Fast left/right side-fall stop distance | 16.07424 / 15.76271 m | 16.35336 / 15.77609 m |

The old locked-force prediction is about 22% below its constrained solution;
the corrected magnitude is about 28% larger in this specific case. This is not
28% more grip everywhere. Hard braking takes **longer**, not less time, to meet
the sustained stop criterion. Ordinary rolling/cornering is largely unchanged.
High-speed falls are not shorter. Controlled wheelspin, rear lockup/release and
the deliberately aggressive slide still behave distinctly; the aggressive slide
still crashes. A separate unpowered tire/body test loses kinetic energy from
873.125 to 865.637 J and regains rolling within 0.00014 m/s.

## Stage B: investigated, rejected for the playable build

The new station probe found real errors in the current reduced-coordinate solve:

- Rebound reaction is clamped nonnegative although the implicit wheel solve can
  use a negative spring/damper reaction. The resulting wheel/chassis force-balance
  residual is 851.10 N front and 946.49 N rear in the chosen rebound-flight test.
- Top-out projects wheel velocity to zero without transmitting the matching
  travel-stop impulse. Residuals are 3360 / 4320 N in the test case.
- An unloading carcass can integrate a negative normal reaction before the output
  clips it to zero. Residuals are −3619.06 / −4044.29 N in the lift-off case.
- Four unsprung substeps are advanced but only their last reaction is transmitted
  over the whole chassis step. Road compression is held during those substeps
  despite a nonzero closing velocity.

A coordinated experiment used a unilateral active-set re-solve, signed reaction
including stop impulse, moving-road implicit stiffness and averaged substep
reactions. It reduced all six force-balance residuals below 0.001 N and passed
fixed-mount passive-energy checks. It nevertheless introduced a braking-bumps
failure. Isolating averaged reactions, unilateral unloading, signed reactions,
and stop impulses did not produce a candidate that preserved all passing ground
cases. Some candidates recovered a larger cross-landing or small bumps while
worsening braking bumps or rough loam. Those tradeoffs were rejected.

Damping was measured rather than increased to its maximum. With unchanged
springs, reducing carcass damping from 1100/1200 to 700/800 Ns/m shortened isolated
fixed-mount wheel settling from 0.0865/0.0906 s to 0.0583/0.0615 s, but worsened
riding results. Increasing compression damping from 1000/1100 to 1300/1400 Ns/m
also introduced a braking-bumps failure. Both tuning trials were rejected.
The approximate compressed-wheel damping ratio is already above critical on
compression before these experiments; this is not simply a lack of damping.
That local linear estimate does not prove a complete coupled bike is overdamped.

`experiments/` contains result summaries and source snapshots for the distinct
mechanism changes. `EXPERIMENTS.md` records composition and rejection reasons.
They are inactive prototypes under an ignored documentation directory.
There is no silent alternative physics mode in the shipped game.

### Retained suspension measurements: no improvement claimed

| Flat static / zero-speed drop measurement | v3.5 | Stage A build |
| --- | ---: | ---: |
| Static front/rear station sag | 43.856 / 41.129 mm | identical |
| Peak drop front/rear compression | 198.103 / 169.686 mm | identical |
| Peak drop tire load | 4317.48 N | identical |
| Peak measured vertical acceleration | 41.635 m/s² | identical |
| Settle after first contact | 0.62083 s | identical |

Drop starts at chassis y=1.5 m over the same flat terrain, zero initial speed,
clutch disengaged. Settle means front/rear compression within 2 mm of measured
static sag, station speeds and chassis vertical speed <0.02 m/s for 0.25 s.
Full extrema and traces are in `drop-before.json` / `drop-after.json`. Front
post-impact compression peaks at 198.05 mm, rebounds to 35.82 mm, then reaches
45.51 mm; the rear has a comparable damped transient. This flat drop does not
represent repeated banked bumps or whoops.

Active suspension values remain: springs 12500/13500 N/m, compression damping
1000/1100 Ns/m, rebound 1400/1500 Ns/m, preload 180/180 N, travel 0.30 m,
carcass stiffness 110000/110000 N/m, carcass damping 1100/1200 Ns/m,
unsprung masses 7/9 kg. Low static sag and the unresolved reaction errors merit
further controlled investigation; changing sag alone was not validated here.

## Geometry and load/traction coupling

The architecture remains one chassis rigidbody, two unsprung translation DOFs,
simulated wheel spin and three curved, weighted ray samples per tire. Ground
forces are applied at the tire point and guide/suspension reactions at the hub;
spin reaction and gyroscopic torque remain active. Wheels are not unconstrained
rigidbodies. Body contact friction and v3.5 handlebar/peg contacts are unchanged.

Riding uses projected forward; passive fallen contact uses the actual wheel/road
plane tangent. Under lean and steering the former is an approximation, as the
previous isolated all-riding experiment demonstrated. It was not reapplied.
Patch velocity includes chassis translation and rotation about the COM, but not
all station and steering motion. Simply inserting these velocities without
reciprocal generalized forces/inverse mass would create another inconsistent
model. The present effective-mass solve also neglects off-diagonal coupling.
These limitations are unresolved, not validated as physically exact contact.

Both load and the `mu*load` combined budget respond immediately to unloading;
detachment clears elastic tread shear. Rapid unloading/recontact can therefore
change available grip abruptly. The force-balance and substep observations above
show a suspension contribution to traction inconsistency. They do not establish
a single cause for every washout. Tire relaxation on a rotating wheel remains an
empirical carrier-speed approximation, and native dirt is still a rigid surface
with location-dependent friction/rolling resistance, not deformable soil.

## Exact accepted code changes

- `src/physics/replacement/contact_tire.gd`: finite-brake locked/rotating solve,
  common force limiter, matching configured drag in spin/prediction, lock state.
- `data/250f.json`: `active_tire` exposes the previously hardcoded stiffness,
  reference load, relaxation length, sliding drop and bearing drag. Defaults
  retain 90000/110000 N/m, 900 N, 0.16 m, 0.12 and 0.015 Nm·s. No terrain mu increase.
- `motorcycle.gd`: observation-only lock/tread telemetry and build identity.
- New six-check `run_traction_solver.gd`; inverse test sets the simulated wheel
  state before predicting it, keeping its original tolerance. New suspension
  force-balance and sag/drop probes; measurement and packaging scripts.
- Project version and existing build-selection checks stamp Stage A explicitly.

`wheel_station.gd`, `geometry.gd`, `rider_controller.gd`, track, rider, steering
and suspension tuning, controls, local recovery, camera and presentation are
unchanged from v3.5 in the retained build. Only the diagnostic/prototype files
contain proposed suspension changes.

## Verification and visible failures

`tests/run_all.sh`: **184 supported checks pass**, zero supported failures.
This is the prior 178 checks plus six tire constraint/rolling-energy checks.
Both main and isolated Stage A contact scenario summaries match exactly.
There are separate failures, not included in that supported count:

- Ground: 9/13 pass. `berm_crawl`, `berm_transition`, `bump_correction`, `whoops`
  still fail. No threshold was relaxed. Peak roll, final lean and crash flag are
  all checked, so an overturned bike is not accepted for avoiding a crash flag.
- Landing observations: `moderate_larger`, `small_bumps`, `whoops` fail;
  `rough_straight` passes its limited end-window criterion. 11 supported landing
  assertions pass; that does not make the entire landing suite successful.
- `rear_slide_hard` still crashes, also repeated in the rear-yaw subset.
- New suspension force-balance/settling diagnostic: 10 checks, **6 fail** with the
  retained suspension. These newly exposed defects are deliberately visible.

Exports completed for Windows and Linux. Actual Linux release and freshly
extracted Godot source pass the 1260-tick support/accelerate/brake/rider smoke.
Clean source import succeeds without a preexisting `.godot` cache. Runtime
fingerprints in `BUILD.json` match the imported source and packaged source.
Actual Windows execution, physical controller behavior and riding feel remain
unverified. No claim of MX Bikes realism or complete traction/bounce repair.

Metrics include front/rear slip ratios/angles, forces, grip use, spin/carrier
mismatch, loads, contact interruptions, compression/velocity, pitch, roll and
position-derived vertical acceleration. `*-metrics.json` preserves whole-run
and identical first-second windows, including falls rather than censoring them.
Ground/contact traces are 240 Hz; landing traces are 30 Hz. Finite-difference
acceleration is sample-dependent. Kinetic and native friction-work diagnostics
are not a closed energy budget for an engine-powered, controlled bike. Only the
isolated unpowered/fixed-mount probes make their stated passivity checks.

## Reproduce and test the download

From the extracted source, import root `project.godot` in **Godot 4.6.3 standard**
and press F5. For CLI use `bash launch.sh` (some ZIP extractors drop executable
bits). The Windows ZIP is a separate standalone game and cannot be imported.

```sh
./tests/run_all.sh
./launch.sh --headless --fixed-fps 240 --script res://tests/ground_probe.gd -- /tmp/ground.json --assert
./launch.sh --headless --fixed-fps 240 --script res://tests/suspension_solver_probe.gd -- /tmp/station.json
./launch.sh --headless --fixed-fps 240 --script res://tests/suspension_drop_probe.gd -- /tmp/drop.json
```

Ground and station diagnostic commands intentionally return nonzero for the
recorded defects. Replay commands and measurement definitions are in the test
scripts and `tools/measure_refinement.py`. To compare the baseline, use its
preserved branch, copy only the new diagnostic probe into that isolated copy,
and use the same fixed timestep and input scripts. Bulk compressed traces remain
in Git; they are omitted from both downloads to reduce size. All project source,
assets, configuration and tests are present in the source ZIP.

For human comparison keep v3.5 in a separate folder and use the same saved assists,
response curves and bindings. First check slow braking/lockup and release, then
normal turns and a small rear slide on flat hardpack/loam. Treat banked crawls,
rough corrections and whoops as known failures. This deliverable is a limited
Stage A repair and a documented unsuccessful Stage B investigation, not completion
of the requested suspension refinement.
