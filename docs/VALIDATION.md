# Validation — replacement prototype 0.3.0

## Executed checks

Godot 4.6.3 standard on Linux. `./tests/run_all.sh` completed with exit status 0 on the final physics code: **98 assertions passed, zero failed**. Full output is in [validation.log](validation.log).

| Suite | Passed |
|---|---:|
| Live chassis, powertrain, braking, flight, crash/reset and production tire law | 22 |
| Tabletop takeoff/landing, braking bumps and lateral recovery | 3 |
| Keyboard/menu/gamepad response | 9 |
| Live binding capture, conflict handling, analog noise and persistence | 16 |
| Separate-process saved-profile reload | 1 |
| Imported skin, 17-bone IK, grip/peg attachments and camera visibility | 10 |
| Replacement identity, mechanism, unsprung/tread dynamics, airborne reactions and sustained corner | 24 |
| Expanded handling scenarios | 13 |
| **Total** | **98** |

The handling cases cover straight travel, a small correction, held/reversed steering, low speed, braking in a corner, imposed lateral slide, 100% steering, a true-idle standing start, both signs of an angled landing, and faster corner/reversal inputs. All complete without a crash. The full-input case now sends **1.0**, replacing the inherited 0.90 request, and additionally checks peak lean below 40° and front slip below 6°. The virtual rider reserves transient grip by limiting its requested steady lateral acceleration to 0.55 μg; chassis roll itself remains unconstrained. These are bounded scenario assertions, not proof of universally stable or realistic handling. The brake test now independently starts on flat terrain at 12 m/s; it retains the original stopping/weight-transfer assertions. It no longer inherits the different acceleration run's speed and rough-terrain position after removal of world damping.

The added mechanism tests verify the actual main-scene script and controller identity, sprung+unsprung mass, load separation, wheel response to a road step versus the old instantaneous spring, tread memory and yield, unloading, transient tire inverse, shared steering parentage, fixed-length telescoping tubes, exact rendered axle coordinates, swingarm radius, and no unexplained freefall rotation. A six-second corner remains rideable with peak front slip **0.80°**, peak lean **12.92°**, and final speed **14.65 m/s**; initial steering is **-0.66°** before right lean develops. Freefall pitch rate is **0.0071 rad/s**, and an airborne body shift changes pitch through the stored rider momentum reaction. See [rebuild-results.json](rebuild-results.json).

## Old/new comparison

The preserved **v2** implementation was rerun through the same 13 handling command sequences and passed its own assertions. Its log is [legacy-comparison.txt](legacy-comparison.txt). Raw results: [v2](handling-v2.json), [v3](handling-v3.json).

| Scenario / metric | v2 | Replacement v3 |
|---|---:|---:|
| Held corner, peak front slip | 1.81° | 1.11° |
| Reversal, peak front slip | 2.08° | 1.16° |
| Full input, peak front slip | 5.35° | 2.33° |
| Fast corner, peak front slip | 1.87° | 1.03° |
| Reversal, integrated absolute chassis lateral travel | 0.66 m | 0.63 m |
| Low-speed case, peak lean | 12.61° | 17.04° |
| Right-lean/yaw-mismatched landing, peak lean | 9.34° | 33.22° |
| Same landing, final lean after four seconds | 0.00° | -4.79° |

**The landing transient is a material remaining weakness.** It recovers within this test, but has substantially more roll excursion than v2. Low-speed lean and lateral recovery are also not uniformly better. Similar input commands are compared; the new controller's grip reserve/lean mapping and absence of inherited world damping change the resulting lean targets, speeds and paths. Lower slip figures alone cannot establish better grip or better human riding feel. There is no measured tire-data or commercial-simulator reference comparison.

The architecture difference is independently demonstrable: different active motorcycle script; unsprung state and separated loads; stored tread shear and its inverse; shared raked mechanism; force-based roll request; momentum reactions. This is not a new name on the original force loop. The original physics files, isolated legacy modules and old downloadable build remain preserved.

## Exported runtime and rendering

Both Windows x64 and Linux x64 release exports completed without script/export errors using checksum-verified official 4.6.3 templates. The **actual exported Linux executable** ran twice with `--headless --fixed-fps 240 -- --self-test`, once normally and once with `--legacy`. Both exited 0 and verified settled tire support, acceleration, braking, skinned rider and the selected controller over 1,260 ticks. Replacement speed went from **4.58 to 2.52 m/s** under the requested brake sequence; the legacy mode reports its separate v2 identity.

[REBUILD_BUILD.json](REBUILD_BUILD.json) records the active path, source fingerprints, executable SHA-256 values, test counts and runtime results. The packaging helper writes ZIP checksums, checks archive integrity, and includes a legacy comparison launcher. The published Windows ZIP is downloaded again and checked against its local SHA-256 and embedded executable fingerprint before delivery.

Three Xorg/Mesa llvmpipe views were rendered and inspected: [extended fork](rebuild-fork-extended.png), [compressed fork](rebuild-fork-compressed.png), [opposite steering](rebuild-steering-opposite.png). These are explicitly frozen articulation poses, not evidence of human riding or an animation recorded during a jump. The high fender stays fixed relative to the triple clamps while the axle moves beneath it; the complete assembly turns together.

The installed built-in Jolt backend also passed a separate 240 Hz falling-body availability check: [output](jolt-availability.txt), [probe](jolt-probe.gd.txt), [temporary project settings](jolt-probe-project.txt). It was not selected for this release; no motorcycle benchmark between solvers was performed.

## What remains unverified

- Windows execution, target-PC frame rate, physical gamepad/vibration and human riding feel.
- Measured motocross tire/mass/inertia calibration, deformable dirt, full articulated multibody accuracy, production-quality whips/scrubs and severe landing coverage.
- Broad raw-steering/manual-assist-off handling and every possible rider input combination.
- Fresh-task restoration of the cloud snapshot after user publication.

Read [the full design and limitations](PHYSICS_REBUILD.md) and use the README's hands-on comparison steps. The next assessment should specifically include sustained low-speed steering and the yaw-mismatched landing, as well as normal cornering, rather than treating a passing aggregate as a riding-quality verdict.
