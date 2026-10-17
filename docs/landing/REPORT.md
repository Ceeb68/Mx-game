# Terra MX 3.3 — landing and local recovery stage

This is the first staged update allowed by the v3.3 request, based on v3.2
commit `d924b4d2c015814a70bf0fcd60f0c01dcb638d82`. The preserved branch is
`refinement/v3.2-steering`; development is on `refinement/v3.3-landing-recovery`.
Older Windows/source archives are retained. Active identity is
`ReducedCoordinateMotorcycle/v3.3-landing`.

**This does not complete the full v3.3 wish list.** The harder 14-degree
cross-landing remains a known failure. Whoops and some rough riding still need
work. Whip authority has not been redesigned. These limitations are measured,
not hidden by disabling crash detection or by treating every non-crash as a pass.
The build is intended for human evaluation of landing/recovery changes first.

## Diagnosed defects and changes

### A ray hit was being treated as tire contact

`wheel_station.gd` previously enabled the carcass spring/damper whenever the
terrain ray was in reach. A separated tire could therefore receive a negative
carcass spring term, even though the reported unilateral normal load was clamped
to zero. That term changed the unsprung velocity, spring reaction and subsequent
landing state without a real tire contact.

The isolated same-state probe uses 0.1m suspension compression, -0.1m/s velocity,
road-compression coordinate -0.2m, closing speed 1m/s, and a 1/960s substep:

| State after one substep | v3.2 | New |
|---|---:|---:|
| No ray: suspension velocity | -0.25845 m/s | -0.25845 m/s |
| Separated tire, ray in reach: suspension velocity | -3.87205 m/s | -0.25845 m/s |
| Normal load in both cases | 0 N | 0 N |

The repair engages the carcass only at physical overlap or a predicted crossing
within the current unsprung substep, using relative closing velocity. Suspension
spring/damper motion still runs in air. Tire forces remain unilateral; no extra
stabilizing torque or velocity/attitude assignment is introduced.

Carcass stiffness remains 110,000 N/m. Carcass damping moves from the hardcoded
650 Ns/m to configurable front/rear 1,100/1,200 Ns/m in `contact_compliance`.
The isolated unsprung damping ratios are approximately .63/.60 instead of
.37/.33 (ignoring guide projection and chassis coupling). These are estimates,
not measured race-bike calibration. Springs, compression/rebound dampers,
preload, travel and unsprung masses retain v3.2 values. Tire grip is unchanged.

An experiment extrapolating road penetration through the four substeps and
averaging their forces increased several landing peaks and did not rescue the
leaned landing. It was rejected. The original four-substep structure is retained;
this update does not claim to resolve every integration/contact approximation.

### The finite steering assembly was unprepared at touchdown

The baseline's 7–10 degree rolled, 6 degree yawed drops rebounded and rolled over.
The crash snapshot occurred later, with the chassis already sideways. Merely
relaxing the crash flag would not restore riding. More tire damping reduced load
peaks but did not rescue this case either.

The new configurable `landing_control` prepares the existing steering assembly
for a leaned touchdown. After at least .15s airborne, an approach exceeding 3
degrees roll arms preparation for that flight. A physical terrain ray predicts
front-wheel arrival. Over a .65s preview window, the front target blends toward
travel-direction alignment plus a bounded lean-error correction (gain 1.2).
The request is capped at .48rad and is disabled above 45 degrees lean, below
3m/s forward speed, without a descending approach, or with steering assist off.
The existing 30Nm actuator, target-rate bounds/filter, inertia, damping and
steering stops still apply. Ground contact clears the flight latch.

This is explicit **virtual-rider touchdown assistance**, not calibrated human
motor control. It acts through finite steering and the existing wheel/assembly
momentum reactions. It does not rotate the chassis to a target or create free
yaw/roll torque. Ordinary near-upright flight does not arm it. Disabling
`landing_control.enabled` disables preparation; disabling steering assist does
so too. The legacy air steering and wheel acceleration/rear-brake pitch paths
are otherwise unchanged. No new whip model is claimed.

Early broad alignment assistance caused a sideways-landing regression and was
rejected. Later/shorter preview candidates rescued only a narrow range. Mirrored
and different initial roll angles were added to expose that limitation. The
harder 14-degree case still fails with the shipped bounded preparation; it must
not be described as physically unrecoverable merely because this controller
fails to recover it.

### Crash conditions and evidence

The original `speed > 3m/s` condition made upright chassis contact alone severe.
Forward speed is no longer sufficient. The detector retains the .22s persistent
condition timer and its decay, evaluates grounded excessive lean, tilted chassis
contact, and rapidly tumbling tilted chassis contact. Limits are configurable in
`crash_detection`. Excessively sideways impacts still crash in the actual replay.

Every latched crash records tick, reason, orientation, angular speed, speed,
chassis contacts/impulse, tire contact mask, loads and accumulated duration.
Falling outside terrain also records its reason/location. Touchdowns record
first contacting wheel(s), airborne duration, approach closing speed, orientation,
angular velocity, peak tire load and normal impulse integrated over .25s. This
impulse includes support during that interval; it is not an isolated collision
impulse or a real-world impact measurement. Raw engine chassis impulses can be
zero on reported contacts and are diagnostic rather than the sole crash test.
Telemetry also exposes physical penetration, carcass activation, preparation
state, steering assist state, loads, suspension velocities, roll/yaw rates and
existing traction/input diagnostics. F1 shows crash conditions, touchdown summary
and reset source.

### Local recovery

`local_recovery.gd` validates physical terrain with five footprint rays and a
chassis clearance shape. It rejects terrain edges, steep/uneven patches and
obstructed placements. R first searches the current area, then nearby positions
within 8m, then the most recent validated checkpoint, finally the lane start.
It preserves horizontal heading and places the upright bike above the highest
sampled terrain under its footprint.

A checkpoint is refreshed every .25s only with both tires supporting the bike,
reasonable upright alignment, no crash/accumulating crash condition and validated
terrain. Recovery uses the existing physics-step reset path to clear velocities,
engine, steering, tire tread/spin/contact, suspension, rider momentum, timers and
new landing state. F6 explicitly clears the old checkpoint and selects the next
lane's designated start. Bindings and controller settings are preserved.

In the paired half-track reset probe, v3.2 moves the bike about 78.73m back to its
lane start; local recovery moves it less than 0.01m horizontally. The actual
excessively-sideways crash case also tests recovery after the crash latches.

## Preservation and validation boundaries

The ground virtual-rider source, input/response source, tire friction/force law,
geometry, track, rider asset/animation, powertrain and camera behavior remain
unchanged. `handling` configuration is identical to v3.2. Contact physics changes
can still slightly alter riding; unchanged source is not proof of identical feel.
Existing regression thresholds are retained. The reset-key test now checks local
recovery instead of the intentionally replaced lane-start behavior.

All numerical runs use Godot 4.6.3 standard, GodotPhysics3D and fixed 240Hz steps.
Trace rows are sampled at 30Hz; extrema are computed at 240Hz. Drop cases start
around 2.2m chassis height and 12m/s forward speed. The nominal two-wheel case
starts nearly level with the clutch open during flight; actual first-contact
ordering is recorded rather than assumed simultaneous. Other cases deliberately
start front/rear pitched, yawed or rolled. Tabletop cases traverse the existing
first and second jumps at identical initial inputs, repeated three times.

Rough probes start at 10m/s on the existing braking-bump, whoop and rough-loam
lanes, with a brief .05 steering correction; the braking-bump probe also applies
.12 front brake briefly. The baseline and candidate use identical schedules.
An unlatched crash flag with a flipped bike is counted as an unsuccessful ride.

`--assert` validates the supported landing/recovery stage. The harder 14-degree
cross-landing and the three rough scenarios are **diagnostic observations**, not
silently passed assertions. `--assert-all` applies the riding criteria to all
15 scenarios and is expected to expose remaining failures. See BUILD.json and
the numerical comparison below for exact passing and failing outcomes.

## Reproduction

```sh
./launch.sh --headless --editor --import --quit
./tests/run_all.sh
./launch.sh --headless --fixed-fps 240 --script res://tests/landing_probe.gd -- /tmp/landings.json --assert-all
./launch.sh --headless --fixed-fps 240 --script res://tests/reset_probe.gd -- /tmp/reset.json
./launch.sh --headless --script res://tests/contact_gap_probe.gd -- /tmp/gap.json
```

For a baseline, extract `git archive d924b4d2c015814a70bf0fcd60f0c01dcb638d82`
into a separate scratch directory; apply baseline-instrumentation.patch using
`git apply --unidiff-zero /path/to/baseline-instrumentation.patch` and copy
landing_probe.gd, reset_probe.gd and contact_gap_probe.gd into its tests directory.
Import it, then run those probes without assertions or candidate tuning overrides.
The instrumentation adds observations only. No extra Git worktree is required.
Candidate experiment JSONs are retained for diagnosis; release BUILD.json and
final after.json identify the shipped code/results.

## Manual riding test

1. Keep v3.2 and this build in separate folders. Verify the new F1 identity ends
   in `v3.3-landing`. Keep the same saved response, assist, bike and input settings.
2. Repeat the flat-loam straight, gradual corners, small corrections and reversals.
   Report any loss of the steering feel you liked; this update is meant to preserve it.
3. On the tabletop lane, build speed gradually, release extreme steering before
   touchdown, land reasonably straight, then continue accelerating. Repeat with
   gentle front/rear-first landings and a small amount of lean/yaw. Observe F1's
   touchdown, peak load, contact and crash-condition information.
4. Try R while upright halfway along a lane, after a genuine crash, and near a
   tabletop. Check local position, upright clearance and heading. F6 should still
   take you to the next lane start. A fall outside valid terrain should reuse the
   safe checkpoint rather than an invalid placement.
5. Bumps/whoops and harder sideways landings are known limits. Report speed, lane,
   posture, steering/body input and whether the upset starts at the front or rear.
   Local R recovery makes repeated practice possible; the rough-track failures
   have not been hidden by an automatic respawn or pose clamp.
6. Check ordinary throttle/rear-brake pitch adjustment, controls/menu, rider and
   camera. Existing whips remain a pending improvement, not a completed feature.

For Godot, extract **TerraMX-v3.3-landing-source.zip**, import `project.godot` in
**Godot 4.6.3 standard**, then F5. For Windows, extract the runtime ZIP and run
`TerraMX.exe`. Windows execution, physical gamepad feel and subjective realism
still require riding feedback on the target machine. Automated repeatability is
not proof of MX Bikes-level realism.

## Final measured comparison

| Scenario / metric | v3.2 | Shipped landing stage |
|---|---:|---:|
| 10-degree roll, 6-degree yaw drop | crash; peak roll 110.09° | recovers; peak roll 14.19° |
| Mirrored 10-degree drop | crash; peak roll 115.96° | recovers; peak roll 14.19° |
| 7-degree roll, 6-degree yaw drop | crash; peak roll 100.46° | recovers; peak roll 7.40° |
| Small sideways landing peak roll | 14.07° | 12.11° |
| Front-first landing peak tire load | 6,774 N | 6,321 N |
| Rear-first landing peak tire load | 6,910 N | 6,343 N |
| Tabletop traversal peak tire load | 6,863 N | 5,981 N |
| Three repeated tabletop traversals | all survive | all survive |
| Flat-ground normal lean reversal | 366.7 ms | 366.7 ms |
| Flat-ground reversal lean error RMS | 4.1816° | 4.1798° |
| Half-track local reset distance | 78.73 m | <0.01 m |

These drop cases use identical initial conditions and commands. The three
moderate cases end within 0.01° upright and around 15.5m/s after five seconds.
Straight/tabletop riding already survived the baseline replay; its survival is
not presented as a newly fixed baseline failure. Tabletop load peaks fall about
13%, while some other contact/trajectory measures change.

**Known failures, explicitly retained:** the 14-degree cross-landing still crashes
(peak roll 95.79°). The braking-bump run avoids a latched crash but ends at 39.95°
roll, so it fails the riding criterion. The whoop run also avoids a latched flag
but flips (peak 179.84°) and ends at 74.45° roll/2.05m/s; it fails. The rough-loam
run meets the finite-window criterion at 14.40° final roll, with a 17.10° peak;
this is not proof of composed or sustained rough riding. Full results and raw
traces are in before.json, after.json and comparison.json.

Final validation: **139 supported-stage/regression assertions passed, 0 failed;
3 of 4 additional diagnostic observations failed.** This is not an all-green
claim for the complete v3.3 request. No existing handling thresholds were lowered.
Windows and Linux release exports succeeded. The actual Linux executable passed
its 1,260-tick support/acceleration/braking/rider smoke test. Source/executable
fingerprints and preserved subsystem hashes are in BUILD.json. Windows execution
and human riding/gamepad feel remain unverified.
