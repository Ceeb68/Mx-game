# Simulation architecture and force ownership

Coordinates are metres, seconds, kilograms, Newtons and radians. Bike local forward is -Z, right +X and up +Y. Positive wheel angular speed means forward rolling (angular momentum along -axle). Combined bike+rider mass is 181 kg, including a 78 kg rider. The JSON values are prototype estimates, not certified specifications for any manufacturer.

## Active path

`scenes/main.tscn` → `src/main.gd` → **`src/physics/motorcycle.gd::_integrate_forces()`**, Godot physics at **240 Hz**. `MotorcycleSimulation/v1`, the tick count and actual physics step are displayed in the HUD and printed at startup. There is one chassis and no second controller. Tests instantiate the same shipped scene and drive the same command dictionary; they do not replace the motorcycle with a mock.

Rendering, input, UI and camera never set chassis rotation or velocity during normal riding. Only the explicit reset request writes a complete rigidbody pose/velocity inside `_integrate_forces()`. Godot owns gravity and chassis collision resolution; custom code owns wheel contact, drag, wheel momentum accounting and the visible optional foot support. Default Godot damping is disabled for this body.

| Module | Ownership |
| --- | --- |
| `motorcycle.gd` | Contact queries, contact frames, force application, aggregate COM, steering joint, wheel/chassis momentum accounting, crash state, reset and telemetry |
| `tire.gd` | Per-wheel spin, slip, relaxed combined-force brush approximation, friction-circle constraint and brake integration |
| `suspension.gd` | Preload + spring + compression/rebound damper + progressive bottoming load; no force application |
| `powertrain.gd` | Crank angular velocity, interpolated torque curve, limiter, clutch slip/torque, gear ratios and shift interruption |
| `test_track.gd` | One height sampler for both rendered mesh and physical triangle collision; surface coefficients |
| `controls.gd` | Keyboard/gamepad mapping, deadzone/sensitivity/smoothing; writes dimensionless control requests |
| `bike_visual.gd` | Mesh proxies, wheel spin, suspension position and procedural rider limb segments; no physics mutation |
| `main.gd` | Scene composition, presentation, cameras, settings, reset request routing |

## Per-wheel contact

1. Cast from each suspension mount down chassis up, excluding the motorcycle.
2. Determine extension/compression from hit distance minus tire radius.
3. Compute contact point velocity including chassis angular velocity. Compute compression rate from its terrain-normal component.
4. `suspension.gd` returns unilateral normal load: preload + spring rate × compression + selected damping × compression velocity + bottoming term. No negative load (the spring cannot pull the ground).
5. Project wheel forward onto the contact plane; the front direction includes actual steering angle. Calculate longitudinal slip and lateral slip angle with low-speed regularization.
6. Calculate relaxed tire demand; constrain the combined longitudinal/lateral force to μ × current normal load, including immediate unloading limits. Add terrain rolling resistance.
7. The chassis applies the resulting force at the ground contact offset, producing actual weight transfer and roll/pitch/yaw moments.
8. Integrate wheel speed using drivetrain torque, tire reaction and independent braking. Subtract the change of separately stored wheel spin momentum from chassis momentum. Contact moments are already included at step 7 and must not be added twice.

The model lacks measured load sensitivity/camber thrust, a finite contact patch, unsprung translation, carcass dynamics and deformable soil. Friction saturation alone does not establish realistic dirt traction. Initial phase B work should replace approximations incrementally, preserving the command/telemetry interface.

## Steering and assistance

Raw input requests a front steering angle; a finite-inertia torque servo and an approximate trail aligning moment determine the actual angle. With steering assistance enabled above 2.5 m/s, the input requests lean (up to 37°), translated to a feedforward turn angle plus roll-error/rate feedback. That changes front steering torque, causing tire forces to initiate countersteering and subsequent turning. It does not directly rotate the motorcycle. Servo stiffness and damping are in the JSON.

The steering/lean gains are preliminary. Low-speed transition, reversal, full-lock maneuvering and aggressive slides still require human validation. Front wheel steering gyro/precession and fork assembly reaction are not fully modeled; the implemented gyroscopic term accounts approximately for chassis rotation of wheel angular momentum.

Foot support is a separate optional **external** roll torque, maximum 85 Nm, only when grounded and below 3 m/s. It fades out toward 3 m/s, is disabled after a crash, and never acts in flight. This represents a development low-speed rider aid, not an internally generated rider torque or a proven foot/ground contact solver. Its current value is displayed. Disable it in Settings to evaluate unassisted low-speed balance.

## Rider, flight and crash limitations

The rider is included in chassis mass; a filtered body-position command moves the combined COM by the rider mass fraction. This is a kinematic aggregate-mass approximation, not a separate articulated momentum-conserving rider body. Procedural arm/knee segments use approximate targets rather than analytic IK. Posture currently changes rider height and COM, not independently validated anatomical dynamics.

In flight, tire forces become zero; gravity, drag and wheel/chassis angular momentum reactions continue. Rear-brake pitch correction is tested. There are no arbitrary airborne yaw/roll control torques. Advanced airborne body movement, whips and scrubs are deliberately deferred until an articulated rider/control model can justify them.

The crash classifier uses sustained chassis contact or extreme grounded lean with a 0.22 s persistence window. It never crashes based solely on tire slip. Crash state cuts throttle but leaves the rigidbody simulating; reset restores pose, velocities, engine/gear/clutch, wheels, steering and rider COM. Impact severity and recovery classification need more comprehensive development before this meets the full brief.

## Configuration and future boundaries

`data/250f.json` holds mass, inertia, wheel dimensions, spring/damping/preload, steering assembly, torque curve, ratios, brakes and helper limits with units in their names. Some model regularization constants and controller gains remain in source and should move into validated setup resources as tuning matures. JSON currently assumes a valid schema: editor-time validation is a later task.

No networking, racing, progression or replay system is pretending to be complete. Future networking should consume time-stamped command samples and authoritative simulation snapshots; Godot rigidbody physics is **not guaranteed bitwise deterministic across platforms**. A fixed timestep alone is not lockstep networking. Retain one authoritative dynamics path and use validated server state, rather than trusting client transforms.
