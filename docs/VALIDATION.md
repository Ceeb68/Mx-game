# Validation — 2026-10-17

Status: **runnable Phase A candidate with initial Phase B systems; human riding acceptance pending**. This is not a claim of calibrated realism or completion of the full initial milestone.

## Executed checks

Godot 4.6.3 standard on Linux, 240 Hz live rigidbody simulation. **34 assertions passed, zero failed**: 22 core physics, 3 track scenarios and 9 input/UI checks. The core suite was rerun after its final brake-lock regression was added; the complete track/control suites passed with the same final gameplay code. See [validation.log](validation.log) and [physics-results.json](physics-results.json) for recorded evidence.

| Check | Observed result |
| --- | --- |
| Static equilibrium | Combined tire load ~1775.6 N, matching 181 kg × 9.81; idle speed ~0.0014 m/s |
| Full-throttle straight | ~20.37 m/s (73.3 km/h) after 8 simulated seconds; no crash |
| Engine/gearbox | RPM rises, automatic gearbox reaches gear 5; manual shift input reaches transmission |
| Brake response | Speed ~20.37 → 12.70 m/s in 1.5 s; front peak ~1346 N, rear minimum ~425 N |
| Deliberate rear brake lock | Rear slip -1.0 at ~6.18 m/s; no automatic crash |
| Both turn directions | Opposite headings, lean about ±10.08°, upright and uncrashed in the specified moderate-input scenario |
| Airborne motion | Both tires detach; gravity accelerates the chassis downward |
| Airborne rear brake | Pitch angular rate changes approximately -0.005 → -0.559 rad/s |
| Modest level drop | Suspension absorbs landing and both contacts recover; no crash |
| Small tabletop | Physical takeoff, ~0.396 s continuous flight, landing and continued travel; peak combined tire load ~5906 N |
| Braking bumps | Traversal to z≈-59.4 m without crash; front compression reaches ~0.172 m |
| Small initial lateral slide | Slip angles recover below 0.08 rad without crash |
| Severe fallen chassis | Persistent chassis impact produces crash state; reset clears it |
| Tire law | Combined force respects μFz; unloading immediately reduces force limit |
| Surface coefficients | Sand has lower grip and higher rolling resistance than hardpack |
| Input/UI | Actual injected key press/release, steering smoothing, pause/freeze, Resume signal, manual shift, camera and reset work; signed gamepad deadzone transform passes |
| Gear boundaries | Invalid shifts beyond first/top do not open clutch or start shift interruption |

These tests establish bounded scenarios, not handling quality over arbitrary terrain or player input. The tabletop scenario spawns already moving at 14 m/s, matches wheel speed, selects third gear, uses throttle 0.35 and forward body 0.5. It does not demonstrate that every jump speed or landing attitude is safe. Steering scenarios begin at 9 m/s with modest ±0.24 steering command. The lateral-slide test begins with 0.8 m/s lateral velocity. Physical gamepad devices and aggressive tight corners have not been tested.

## Build and presentation evidence

- Project import completed successfully after assigning writable XDG directories.
- Actual graphical game launched using Xorg's dummy display and Mesa llvmpipe OpenGL 4.5. Screenshots [prototype.png](prototype.png) and [settings.png](settings.png) were captured from the running viewport and inspected. A driver warning says VSync mode changes are unsupported by this software display; no application script errors were observed.
- Matching official export templates were SHA-512 verified before extraction.
- Windows x86-64 release export succeeded. The resulting embedded-pack executable is a PE32+ x86-64 GUI executable. **It has not been executed on Windows.**
- Linux x86-64 release export succeeded and its actual exported executable started headlessly, printed the expected active controller/track/240 Hz identity, and exited with status 0. Full functional scenarios ran from source using the same scene/controller; packaged startup is a separate smoke check.
- No human riding evaluation, physical gamepad test, Windows runtime test, GPU performance benchmark, or cross-platform determinism claim is made. Source startup steps are saved in the cloud draft; publication is separate.

## Important fixes validated during development

- Terrain triangles initially faced away from the wheel rays. Reordered both visible/physical triangles to Godot's winding convention; static support and contact tests now pass on the same geometry.
- Initial steering servo stiffness was insufficient against the model's aligning moment. Increased steering servo stiffness/damping; moderate turn scenarios now settle rather than falling over. This is a bounded automatic test result, not subjective riding feedback.
- Adding drivetrain reaction in addition to a ground-contact moment double-counted part of wheel torque and caused unrealistic backflips. The chassis now receives the negative change of the separately stored wheel angular momentum. Acceleration and airborne brake-pitch checks pass on this path.
- Automatic shifts at a gear boundary used to trigger clutch interruption even without a gear change. Gear changes now require a different valid target; both boundary regressions pass.

## Manual acceptance checklist

Use README's first-ride instructions. Record lane, assist settings, speed, gear, and inputs for failures. Do not mark a row accepted from code presence alone.

| Brief requirement | Current evidence / next riding test |
| --- | --- |
| Spawn on test track | Rendered and automated; confirm on your PC |
| Smooth standstill acceleration | Automatic straight scenario passes; evaluate controller modulation and launch feel |
| Believable braking weight transfer | Measured loads respond; evaluate braking distance and pitch |
| Working manual gears | Keyboard input and auto shifts tested; evaluate manual clutch/shift timing |
| Turns both ways | Moderate scenarios pass; assess response, countersteer and reversal |
| Flat corner without random washout | Bounded turn/slide cases pass; ride sustained sweepers |
| Tight turn with rider control | **Unverified**; test decreasing-radius turns and low-speed assist transition |
| Bumps without excessive instability | Defined braking-bump scenario passes; test whoops and rough loam at varied speeds |
| Small tabletop | Defined takeoff/landing scenario passes; reproduce under player control |
| Air pitch adjustment | Rear-brake angular momentum response tested; evaluate throttle/brake modulation |
| Land and continue | Level drop and tabletop pass; angled and large landings remain unverified |
| Deliberately exceed grip | Rear lock tested; combined cornering/throttle breakaway needs riding review |
| Recover minor slides | Defined lateral disturbance recovers; test steering/throttle recovery |
| Crash on unrecoverable event | Fallen chassis case tested; classifier is provisional, not impact-severity calibrated |
| Observe active systems | Live tick, controller identity, forces, tire states, load, slip, RPM and steering displayed |

Next development should follow this feedback: calibrate the tire/load and suspension/geometry model, improve low-speed/control transitions and rider momentum, and expand scenario coverage for tight turns and angled landings. Professional assets, advanced whips/scrubs and content systems remain later work.
