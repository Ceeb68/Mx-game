extends SceneTree
var scene: Node3D
var bike: RigidBody3D
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String, evidence: Variant) -> void:
 print("PASS " if ok else "FAIL ", text, " ", JSON.stringify(evidence))
 if not ok: failures += 1
func spawn(p: Vector3, velocity: Vector3) -> void:
 for action in ["throttle", "front_brake", "rear_brake", "steer", "lean", "weight", "clutch"]: bike.command[action] = 0.0
 bike.reset_at(Transform3D(Basis.IDENTITY, p), velocity)
 for i in range(3): await physics_frame
 for wheel in bike.wheels: wheel.omega = -velocity.z / wheel.radius
 bike.engine.automatic = false
 bike.engine.gear = 3
 bike.engine.rpm = 6500
func run() -> void:
 scene = load("res://scenes/main.tscn").instantiate()
 root.add_child(scene)
 await process_frame
 bike = scene.bike
 scene.controls.set_physics_process(false)
 await spawn(Vector3(0, 0.78, -30), Vector3(0, 0, -14))
 bike.command.throttle = 0.35
 bike.command.weight = 0.5
 var max_air: float = 0
 var peak_load: float = 0
 var takeoff: bool = false
 var landed: bool = false
 for i in range(1680):
  await physics_frame
  if bike.airborne_time > 0.08: takeoff = true
  if takeoff and bike.wheels[0].grounded and bike.wheels[1].grounded: landed = true
  max_air = maxf(max_air, bike.airborne_time)
  peak_load = maxf(peak_load, bike.wheels[0].load + bike.wheels[1].load)
 check(takeoff and landed and not bike.crashed, "small tabletop takeoff, landing, continued ride", {"max_air_s": max_air, "peak_load_n": peak_load, "position": bike.position, "telemetry": bike.telemetry()})
 await spawn(Vector3(22, 0.78, -23), Vector3(0,0,-7))
 bike.engine.gear = 2
 bike.command.throttle = 0.35
 var peak_compression: float = 0
 for i in range(1200):
  await physics_frame
  peak_compression = maxf(peak_compression, bike.wheels[0].compression)
 check(not bike.crashed and bike.position.z < -45 and peak_compression > 0.07, "braking bumps exercise suspension without a crash", {"position":bike.position,"peak_compression":peak_compression, "telemetry":bike.telemetry()})
 await spawn(Vector3(-24,0.78,25), Vector3(0.8,0,-9))
 bike.command.throttle = 0.4
 for i in range(480): await physics_frame
 check(not bike.crashed and absf(bike.wheels[0].slip_angle) < 0.08 and absf(bike.wheels[1].slip_angle) < 0.08, "small lateral slide recovers without slip-triggered crash", bike.telemetry())
 print("TRACK_RESULT checks=3 failures=",failures)
 quit(0 if failures == 0 else 1)
