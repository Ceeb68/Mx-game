# Phase 2 validation — 2026-10-17

**Result:** 74 assertions passed, zero failed, plus an exported Linux functional self-test. The game renders with the original skinned rider and the control editor. This establishes bounded engineering improvements and a runnable build; subjective handling still requires your riding feedback. Windows runtime, physical gamepads, vibration and target-PC performance remain unverified here.

## Before/after handling evidence

Baseline: published first-build source commit `8ea3b308cfcc901f1eb8966b79c95e2036eb4f32`. Both runs use the same shipped track and command probe at 240 Hz; the controls node is disabled so the identical command sequence reaches the authoritative chassis directly. Initial moving cases use 10 m/s, second gear, engine 6000 RPM, throttle 0.4, and four simulated seconds. Low speed begins at 4 m/s. Raw records are [handling-before.json](handling-before.json) and [handling-after.json](handling-after.json).

| Scenario and metric | First build | Phase 2 |
| --- | ---: | ---: |
| Held corner: peak front slip | 7.98° | 1.81° |
| Held corner: integrated absolute body-lateral velocity | 1.53 m | 0.31 m |
| Left/right reversal: peak front slip | 16.33° | 2.08° |
| Left/right reversal: peak lean | 33.85° | 18.04° |
| Left/right reversal: peak roll rate | 2.03 rad/s | 0.76 rad/s |
| Low-speed corner: peak front slip | 4.64° | 2.71° |
| Braking corner: peak front slip | 5.16° | 1.83° |
| Straight: lateral travel / peak lean | 0 / 0 | 0 / 0 |

These are defined scenarios, not claims that all riding feels fixed. The lower lateral travel comes with actual turning: the held-corner heading changes and final speed remains ~10.26 m/s, versus ~9.86 before. Not every metric improves: the defined lateral-disturbance case initially reaches a slightly higher peak roll rate (~1.25 versus ~1.16 rad/s), though integrated lateral travel falls (~0.29 versus ~0.58 m) and it recovers without a crash. All raw outcomes are retained rather than reporting only favorable cases.

The initial new low-speed controller still failed an expanded true-idle first-gear start-and-turn test. A diagnostic trace showed raw steering leaning the chassis the wrong way before feedback became effective. After the earlier blend and speed-scaled feedback correction, the same start remains upright: ~3.34 m/s after four seconds, ~4.51° peak lean and ~2.12° peak front slip. No new chassis stabilizing force was added. Faster cases beginning at 18 m/s also pass: front slip stays under 2°, with ~22° peak lean in the held corner and ~19.4° in the reversal.

## Executed suite

`./tests/run_all.sh` runs the real game scene/controller, not a substitute physics mock. The final camera-specific rider assertion was rerun in the rider suite after that integration fix. [validation.log](validation.log) contains the latest outcome for each suite, and [physics-results.json](physics-results.json) retains the core records.

| Suite | Passed | Coverage |
| --- | ---: | --- |
| Core physics | 22 | 240 Hz, static support, no idle propulsion, acceleration, gears, independent brakes/load transfer, deliberate rear lock, both turns, gravity/air contact, airborne brake pitch, level landing, crash/reset, gear boundaries, combined grip/unloading and surfaces |
| Physical track | 3 | Small tabletop flight/landing/continuation, braking bumps, minor slide recovery |
| Existing input/UI | 9 | Actual key press/release, steering response, pause/freeze/resume, manual shift, camera, reset and deadzone |
| Binding editor | 16 | Live key rebind, old-key removal, neutral gating, conflict warning/swap/replace, axis noise rejection, signed axis capture, progressive analog polling, button/D-pad capture, cancel/disconnect and disk save |
| Separate process | 1 | Keyboard/controller mappings, cleared conflicts, sensitivity/deadzone/inversion/vibration settings reload from disk in a fresh Godot process |
| Skinned rider/camera | 10 | Active 17-bone skin, sit/stand separation, smooth movement, fixed segment lengths, actual wrist/ankle targets, directional body shifts, no physics mutation, rider/chase visibility masks |
| Expanded handling | 13 | Straight, correction, held/reversed turns, low-speed turn, braking turn, disturbance recovery, large input, real standing start, two angled landings, faster corner and reversal |
| **Total** | **74** | **Zero failures in final recorded outcomes** |

The original acceleration/braking/airborne regression tests still pass. The tabletop remains a physical takeoff/flight/landing scenario, not an animation. Rear-wheel lock still produces slip -1 without a slip-triggered crash. Contact force stays constrained by the combined current μFz budget; dirt/sand μ values were not raised.

## Rider and graphical inspection

The original Blender-authored glTF imports as one skinned mesh with 17 bones and gear material groups. Approximate human segment lengths are ~0.333/0.274 m upper/lower arm and ~0.440/0.420 m upper/lower leg. The rig test exercises standing, sitting, forward/backward and lateral body inputs with steering. In those poses, endpoint/bone-length errors are below 0.002 m, and pelvis motion stays below 0.035 m per 60 Hz animation update.

Actual software-OpenGL views were captured and inspected: [standing](phase2-standing.png), [front/helmet details](phase2-front.png), [seated](phase2-seated.png), [binding editor](phase2-controls.png), [response settings](phase2-response.png), and [rider-camera view](phase2-helmet.png). Inspection led to seated pelvis/seat clearance, neck coverage and camera self-occlusion corrections. This is a recognizable original stylized motocross rider, not a production photorealistic character or a complete cloth/ragdoll system. Bone endpoint tests do not prove that mesh clipping is impossible under every pose.

No physical gamepad was attached. Binding/capture/analog tests inject actual Godot keyboard/joypad events and use the production mapping functions; they do not establish hardware driver compatibility or vibration feel. A disconnect callback path is tested, but a real unplug/replug still needs the short manual procedure below.

## Exported application evidence

- Godot 4.6.3 standard project import and both Windows/Linux release exports succeeded.
- The runtime pack includes the imported glTF scene and new input/IK/diagnostic scripts. Export templates were verified against the official SHA-512 manifest before their original installation.
- The actual Linux release executable ran `--headless --fixed-fps 240 -- --self-test`, loaded the 17-bone rider and v2 chassis, settled on both tires, accelerated to ~4.16 m/s, braked to ~1.87 m/s, and exited 0 after 1260 ticks. This tests exported resource inclusion and active physics, beyond process startup.
- Windows is exported as an x86-64 executable but has not been run on Windows here. [PHASE2_BUILD.json](PHASE2_BUILD.json) records source/executable fingerprints and unverified capabilities.
- Rendering used Xorg dummy display and Mesa llvmpipe OpenGL. Its unsupported VSync-mode warning is expected for that display. No application script errors were observed in the final test/capture/export logs. No 60 FPS or target-GPU performance claim is made.

## Your next hands-on pass

1. Start on the straight with default assists. Accelerate, make small corrections, then progressive corners/reversals at 25–40 km/h. Try a slow turn while accelerating from rest. Compare with the retained first-build ZIP.
2. Brake straight and lightly in a corner; deliberately lock/release the rear. Apply aggressive throttle on dirt and sand. Grip should remain finite and slides should be recoverable where physical loading allows.
3. Repeat the small tabletop, brief airborne rear-brake pitch correction, and a modest landing. Report unexplained yaw/roll with the approach speed and inputs.
4. Sit/stand, shift body position and steer through both directions. Check hands at grips, boots on pegs, seat/neck clearance, elbow/knee bends and transitions during braking and landings.
5. In Controls, bind a trigger, stick direction, D-pad and key; resolve a conflict; change Response settings; quit/relaunch. Unplug/replug the controller and release inputs to resume. Test vibration if your device supports it.

Include lane, speed, gear, controller model, assist/response settings and exact inputs with feedback. This update is ready for that round of testing; calibration and acceptance of riding feel remain open.
