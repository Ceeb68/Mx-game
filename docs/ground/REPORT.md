# Ground handling investigation — incomplete v3.4 candidate

**The requested repair is not complete. Do not treat this build as a stable
v3.4 release or approval to start unrelated development.** Four of thirteen new
ground scenarios still fail. v3.3 is preserved at
`b55a020c2c9cbccd35fdea4a6227520461e91ed2` on
`refinement/v3.3-landing-recovery`; this work is isolated on
`refinement/v3.4-ground-contact`.

## Retained changes

`contact_tire.gd` adds a bounded numerical inverse of the existing discrete
lateral tread equation. `rider_controller.gd` uses it at low speeds instead of adding the
old slip-angle estimate to an inverse based on absolute forward speed and a
0.5 m/s floor. That approximation loses reverse direction and asks steering to
create lateral velocity even when nearly stationary. The new inverse rotates
the measured signed longitudinal/lateral velocity into candidate tire headings,
evaluates the same unsaturated force equation, finds reachable roots, and
chooses the smallest heading change. If no root exists within the existing
steering range, it chooses the sampled reachable heading with least force error.
The existing combined friction budget still limits actual applied force.
The repair is fully active through 2.2 m/s, fades continuously to zero at
3 m/s, and retains the established v3.3 inverse above 3 m/s. This deliberately
limits scope to the low-speed inconsistency: applying the new inverse at all
speeds regressed the rough-loam observation from 14.4° to 18.3° final lean.
That unbounded variant was rejected; the faster-speed tests are preserved.

This fixes an inverse-model inconsistency, not the complete motorcycle model.
It does not create grip or additional balance authority at standstill.
At the tested berm climb, peak roll falls from 15.43° to 1.08°.
Braking-bump peak and final lean remain 25.75° and 24.12°, respectively.
This is a limited slow-speed improvement, not composed bump handling.
Berm entry peak remains 5.85°; exit remains 6.14°.
Slow bank transitions remain unacceptable and sometimes worsen.

`motorcycle.gd` adds observation-only force decomposition: per-wheel contact
normal, hit point versus applied point, suspension axis, normal/guide/tangent
roll moments, spring force, mount acceleration, road compression, cached versus
current controller moment, full world angular velocity and chassis basis.
`tests/ground_probe.gd` records these with existing input, actual steering,
requested/actual lean, lateral tire velocity, load, utilization, force, slip and
suspension state every 240 Hz physics step. No runtime physics gains change.

## Identical-input comparison

Godot 4.6.3 standard, Godot Physics, fixed 240 Hz, same initial transforms,
wheel speeds, gears, commands and durations on both versions. Exact schedules
are in `tests/ground_probe.gd`. Steering assistance and existing foot support
are on. The controls filter is bypassed equally for deterministic physical
comparison; existing input-path regressions are run separately.

| Scenario | v3.3 peak roll | Candidate peak roll | Candidate result |
|---|---:|---:|---|
| slow_figure_eight | 4.48° | 4.48° | PASS |
| berm_entry | 5.85° | 5.85° | PASS |
| berm_crawl | 111.09° | 110.04° | **FAIL** |
| berm_transition | 98.76° | 102.18° | **FAIL** |
| berm_hold | 4.68° | 4.68° | PASS |
| berm_climb | 15.43° | 1.08° | PASS |
| berm_descend | 0.02° | 0.02° | PASS |
| berm_exit | 6.14° | 6.14° | PASS |
| bump_correction | 96.87° | 96.87° | **FAIL** |
| braking_bumps | 25.75° | 25.75° | PASS |
| whoops | 93.70° | 93.70° | **FAIL** |
| front_unload | 0.00° | 0.00° | PASS |
| rear_unload | 0.00° | 0.00° | PASS |

Thresholds are unchanged between versions: no crash, peak absolute roll <40°,
absolute final roll <25°, final speed >0.5 m/s; steady berm radius drift <6 m;
front/rear unloading must actually exercise the opposite-only contact state.
An upside-down bike fails regardless of its crash flag. These are finite-window
regression limits, not proof of realistic riding or accurate line holding.
The six-second figure-eight input includes a full left/right cycle, not a
long-duration endurance test. Whoops input covers eight seconds, but the bike
crashes before completing the section; this remains a failure.

Full results are `before-results.json`, `after-results.json`, `comparison.csv`
and `comparison.json`. Full, untrimmed 240 Hz traces are in
`before-trace.json.gz` / `after-trace.json.gz`. Exact first-upset ±50 ms windows
are also plain JSON. First upset means first sampled body-forward roll rate
>1.5 rad/s or absolute gravity lean >40°. Independent finite-difference gravity
lean rate is recorded separately, because these rates differ during pitching.

## Where stability breaks

In the baseline whoops run, the first threshold crossing is at 2.891667 s:
front load **0 N**, rear **13,576 N**, roll **31.79°**, body-forward roll rate
**1.674 rad/s**, and its finite difference **132.1 rad/s²**. The rear normal
contributes **+7,451.6 Nm**, tangent force **−6,733.6 Nm**, and guide reaction
**−238.1 Nm** about body forward. The controller is consuming **2,240.1 Nm**
of previous-step passive moment while current-step recorded passive moment is
**456.0 Nm**. The front cannot deliver the correction because it is unloaded.
Rear lateral force is +11,423 N against −7.24 m/s local lateral velocity: the
force opposes slip; this is not a simple reversed-friction-sign bug.
The bounded candidate reaches the same upset at 2.891667 s; it is unsolved.

The chassis forward vertical component is about +0.852 at that frame, so the
bike is pitched roughly 58°. Its rear normal is
(−0.524, 0.732, 0.436), with a substantial transverse component. The track's
whoops lane also intersects the outer taper of the circular berm around
(x=42,z=−54); this is not purely a flat lane of longitudinal bumps. The 1.5 m
physical triangle grid and three-ray weighted patch do not provide a resolved
round-wheel contact manifold on this steep, combined surface. Increasing mesh
resolution alone did not repair it. No visual-only smoothing was used.

In the baseline slow crawl, the first upset occurs at 4.166667 s, after forward
speed decays and the bike stalls/rolls back. The front unloads; rear load is
818 N. The second low-speed bank transition crosses at 2.8125 s with both tires
loaded. Steering alone has insufficient force authority near zero travel and
existing finite foot support does not recover the banked stall. The new inverse
correctly retains signed reverse travel but does not solve that authority gap.
The smooth 0.4–2.2 m/s blend and 2–3 m/s foot fade are continuous; changing
thresholds alone did not resolve these failures.

World-relative lean remains referenced to gravity. Replacing it with the road
normal would hide the required force balance on a bank. Measurements show
body-axis roll rate and gravity lean rate diverge during pitch; matching the
rate and force-acceleration frame was tested, but did not solve the ground suite.
Front detach already clears forces/load/slip; a stale normal can remain, but
zero front grip prevents that data from supplying actual front force authority.
The one-step-old passive moment is a remaining control limitation on abrupt
contact transitions. No claim is made that a single root cause explains all
remaining failures.

## Rejected experiments

These were measured and removed from the shipped candidate, not accumulated as
unverified tuning:

- 0.5 m physical triangles: some bank measurements improve, rough probes still
  flip; no mesh change retained.
- Circle-envelope sampling, contact-point closing velocity, signed rebound,
  suspension-stop impulse averaging and current-contact moment prediction:
  no consistent recovery across the ground cases.
- Lower blend thresholds and automatic finite rider-carriage banking:
  banked stalls still fail. No rider feature retained.
- Wheel/road plane frame and gravity-consistent roll-rate/torque mapping:
  individually plausible corrections, still failing rough contact tests.
- Front precession resolved into the steering DOF: bump peak roll around 1.7°
  and 1.6°, but the existing six-second flat corner exceeds its unchanged 5°
  front-slip threshold (5.58° in the combined run). Removed to preserve baseline
  flat behavior. Sign changes to wheel momentum reactions also worsened tests.

The remaining difficult failures require further focused physics work. This
candidate does not justify describing berm stability, whoops, or the requested
MX Bikes-style feel as fixed.

## Reproduce

Run from this project:

```sh
./launch.sh --headless --editor --import --quit
./tests/run_all.sh
./launch.sh --headless --fixed-fps 240 --script res://tests/ground_probe.gd -- /tmp/ground-after.json --assert
```

The ground command intentionally returns nonzero for its four failures.
`--scenario=whoops` or `--scenario=low` isolates a failing case.
To repeat the baseline without changing this branch, use a separate extracted
copy of v3.3 at the preserved commit, apply
`git apply --unidiff-zero docs/ground/baseline-instrumentation.patch` with this
candidate's patch path, and copy `tests/ground_probe.gd` into its tests folder.
The patch only adds telemetry. Run the same command and compare with:

```sh
python tools/compare_ground.py /tmp/ground-before.json /tmp/ground-after.json /tmp/ground-comparison
```

## Open and test manually

Use **TerraMX-v3.4-ground-EXPERIMENTAL-GODOT-SOURCE.zip**. Extract it fully,
import its root `project.godot` in **Godot 4.6.3 standard**, let import finish,
then press **F5**. This source ZIP is distinct from the Windows executable ZIP.
F1 must identify `v3.4-ground-experimental`. Keep v3.3 in a separate folder.
Use the same saved controller response and assist settings for comparison.
R recovers locally; F6 selects the next lane. Test the same slow turns, banking
entries/holds/exits, braking bumps and whoops with cautious short inputs.

Automated checks do not establish realistic riding feel. Windows execution,
physical gamepad behavior and subjective riding remain unverified here.

## Validation outcome

- Existing supported-stage/regression assertions: **139 passed, 0 failed**.
- New tire-inverse checks: **7 passed, 0 failed**, including signed forward/reverse,
  low-speed reachable forces, zero-speed authority, bounds, and comparison with
  the actual unsaturated tread integrator.
- New ground assertions: **9 passed, 4 failed** (bank crawl, bank transition,
  bump correction, whoops). Both original and candidate fail those same cases.
- Existing landing observations: **3 failed of 4**, unchanged: 14° cross-landing,
  small bumps and whoops. Rough-loam final lean remains about 14.4°, within the
  existing loose diagnostic threshold. Supported landing assertions all pass.
- Windows and Linux exports completed without script errors. The actual Linux
  release passed its 1,260-tick support/acceleration/braking/rider-rig smoke test.
  A first Linux launch without writable XDG directories failed; rerunning with
  the documented writable XDG paths succeeded. Use launch.sh for source runs.
- Fresh extracted source imported with Godot 4.6.3 standard without parse errors.
  Source launch validation and archive fingerprints are recorded alongside this
  report. Windows execution and human riding remain untested.

These passing regressions do not turn the four ground failures into a passed
v3.4 handling update. The requested stable grounded riding outcome is unfinished.
