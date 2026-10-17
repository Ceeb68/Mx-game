extends SceneTree
## Runs the shipped scene and the same live rigidbody path as interactive riding.
var game: Node3D
var bike: RigidBody3D
var failures: int = 0
var checks: int = 0
var records: Array = []

func _initialize() -> void:
 call_deferred("run")

func verify(condition: bool, description: String, evidence: Variant = null) -> void:
 checks += 1
 var result := {"check": description, "passed": condition, "evidence": evidence}
 records.append(result)
 print("PASS " if condition else "FAIL ", description, " ", JSON.stringify(evidence))
 if not condition: failures += 1

func ticks(count: int) -> void:
 for i in range(count): await physics_frame

func reset(position_: Vector3 = Vector3(-24, 1.0, 25), velocity: Vector3 = Vector3.ZERO, basis: Basis = Basis.IDENTITY) -> void:
 for action in ["throttle", "front_brake", "rear_brake", "steer", "lean", "weight", "clutch"]: bike.command[action] = 0.0
 bike.engine.automatic = true
 bike.steering_assist = true
 bike.foot_support = true
 bike.reset_at(Transform3D(basis, position_), velocity)
 await ticks(3)

func run() -> void:
 game = load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 bike = game.bike
 game.controls.set_physics_process(false)
 verify(Engine.physics_ticks_per_second == 240, "fixed physics is 240 Hz")
 await reset()
 await ticks(720)
 verify(bike.wheels[0].grounded and bike.wheels[1].grounded and not bike.crashed, "settles upright on two suspension contacts", bike.telemetry())
 var load: float = bike.wheels[0].load + bike.wheels[1].load
 verify(absf(load - bike.config.mass_kg * 9.81) < bike.config.mass_kg * 9.81 * 0.12, "static tire loads support total mass", load)
 verify(bike.linear_velocity.length() < 0.1, "idle does not propel motorcycle", bike.linear_velocity.length())
 bike.command.throttle = 1.0
 var maximum_speed: float = 0
 var maximum_rpm: float = 0
 var maximum_gear: int = 1
 for i in range(1920):
  await physics_frame
  maximum_speed = maxf(maximum_speed, bike.linear_velocity.length())
  maximum_rpm = maxf(maximum_rpm, bike.engine.rpm)
  maximum_gear = maxi(maximum_gear, bike.engine.gear)
 verify(maximum_speed > 8 and not bike.crashed, "engine torque accelerates the live chassis", {"speed": maximum_speed, "telemetry": bike.telemetry()})
 verify(maximum_rpm > 4500 and maximum_gear > 1, "engine revs and automatic gearbox shifts", {"rpm": maximum_rpm, "gear": maximum_gear})
 # Independent flat-ground brake scenario: acceleration speed no longer depends on world damping.
 await reset(Vector3(-24,0.78,25),Vector3(0,0,-12))
 for wheel in bike.wheels: wheel.omega=12/wheel.radius
 bike.command.clutch=1
 await ticks(60)
 var before_braking: float = bike.linear_velocity.length()
 var front_peak: float = 0
 var rear_min: float = 99999
 bike.command.throttle = 0
 bike.command.front_brake = 0.6
 bike.command.rear_brake = 0.25
 for i in range(360):
  await physics_frame
  front_peak = maxf(front_peak, bike.wheels[0].load)
  rear_min = minf(rear_min, bike.wheels[1].load)
 verify(bike.linear_velocity.length() < before_braking * 0.7, "independent brakes slow chassis", {"before": before_braking, "after": bike.linear_velocity.length()})
 verify(front_peak > bike.config.mass_kg * 9.81 * 0.55 and rear_min < bike.config.mass_kg * 9.81 * 0.45, "braking transfers load to front", {"front_peak": front_peak, "rear_min": rear_min})
 await reset(Vector3(-24, 0.78, 25), Vector3(0, 0, -9))
 for wheel in bike.wheels: wheel.omega = 9 / wheel.radius
 bike.command.clutch = 1.0
 bike.command.rear_brake = 1.0
 await ticks(180)
 verify(bike.wheels[1].slip < -0.4 and bike.linear_velocity.length() > 4 and not bike.crashed, "deliberate rear-brake traction loss remains recoverable", {"slip": bike.wheels[1].slip, "speed": bike.linear_velocity.length(), "crashed": bike.crashed})
 for direction in [-1.0, 1.0]:
  await reset(Vector3(-24, 0.84, 25), Vector3(0, 0, -9))
  for wheel in bike.wheels: wheel.omega = 9 / wheel.radius
  bike.command.throttle = 0.22
  await ticks(60)
  bike.command.steer = direction * 0.24
  await ticks(480)
  verify(not bike.crashed and bike.global_basis.y.y > 0.65 and -bike.global_basis.z.x * direction > 0.08, "controlled turn direction %+.0f" % direction, {"heading_x": -bike.global_basis.z.x, "lean": rad_to_deg(bike.lean_angle), "telemetry": bike.telemetry()})
 await reset(Vector3(-24, 6, 20), Vector3(0, 0, -10))
 bike.foot_support = false
 bike.command.clutch = 1
 for wheel in bike.wheels: wheel.omega = 25
 await ticks(60)
 verify(not bike.wheels[0].grounded and not bike.wheels[1].grounded, "wheel contact disengages in air")
 verify(bike.linear_velocity.y < -2 and absf(bike.linear_velocity.x) < 0.05, "airborne motion follows gravity without upright snapping", bike.linear_velocity)
 var pitch_before: float = bike.angular_velocity.x
 bike.command.rear_brake = 1
 await ticks(30)
 verify(bike.angular_velocity.x < pitch_before - 0.08, "airborne rear brake transfers wheel angular momentum to pitch", {"before": pitch_before, "after": bike.angular_velocity.x})
 await reset(Vector3(-24, 1.7, 20), Vector3(0, 0, -4))
 for wheel in bike.wheels: wheel.omega = 4 / wheel.radius
 await ticks(480)
 verify(not bike.crashed and bike.wheels[0].grounded and bike.wheels[1].grounded, "modest level landing is absorbed and rideable", bike.telemetry())
 await reset(Vector3(-24, 0.5, 20), Vector3(0, 0, -5), Basis(Vector3.FORWARD, 1.45))
 bike.foot_support = false
 await ticks(480)
 verify(bike.crashed, "persistent severe chassis collision produces crash", bike.last_crash)
 await reset()
 await ticks(360)
 verify(not bike.crashed and bike.last_crash == "none" and absf(bike.steer_angle) < 0.01 and bike.airborne_time == 0, "reset clears crash, steering, engine and wheel state", bike.telemetry())
 bike.engine.gear = bike.config.gears.size()
 bike.engine.shift_cooldown = 0
 bike.engine.shift(1)
 verify(bike.engine.shift_cooldown == 0, "top-gear shift request does not disengage clutch")
 bike.engine.gear = 1
 bike.engine.shift(-1)
 verify(bike.engine.shift_cooldown == 0, "first-gear downshift does not interrupt torque")
 # Test the exact production tire law under combined loading / unloading.
 var tire = load("res://src/physics/replacement/contact_tire.gd").new(0.335, 0.85)
 tire.load = 800
 tire.omega = 80
 var force: Vector2
 for i in range(100): force = tire.forces(1.0 / 240, 10, 5, 0.8, 0.025)
 verify(force.x > 0 and force.y < 0 and force.length() <= 640.001, "combined tire demand stays within friction circle", force)
 tire.load = 100
 force = tire.forces(1.0 / 240, 10, 5, 0.8, 0.025)
 verify(force.length() <= 80.001, "unloading immediately reduces traction limit", force)
 var hard: Dictionary = game.bike.track.surface_at(Vector3(0, 0, 0))
 var sand: Dictionary = game.bike.track.surface_at(Vector3(-50, 0, 0))
 verify(sand.mu < hard.mu and sand.rolling > hard.rolling, "sand changes physical grip and rolling resistance")
 var output := FileAccess.open("user://physics-results.json", FileAccess.WRITE)
 output.store_string(JSON.stringify({"checks": checks, "failures": failures, "results": records}, "  "))
 print("PHYSICS_RESULT checks=", checks, " failures=", failures, " output=", ProjectSettings.globalize_path("user://physics-results.json"))
 quit(0 if failures == 0 else 1)
