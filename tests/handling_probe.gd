extends SceneTree
var game: Node3D
var bike: RigidBody3D
var results: Array = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
 game = load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 bike = game.bike
 game.controls.set_physics_process(false)
 for scenario in ["straight", "small_correction", "held_corner", "reversal", "low_speed", "corner_brake", "slide", "full_input", "standing_start", "landing_left", "landing_right", "fast_corner", "fast_reversal"]:
  var selected: String = ""
  for argument in OS.get_cmdline_user_args():
   if argument.begins_with("--scenario="): selected=argument.trim_prefix("--scenario=")
  if not selected.is_empty() and scenario != selected: continue
  for action in ["throttle", "front_brake", "rear_brake", "steer", "lean", "weight", "clutch"]: bike.command[action] = 0.0
  var speed: float = 4 if scenario == "low_speed" else (0 if scenario == "standing_start" else 10)
  if scenario.begins_with("fast_"): speed = 18
  var initial_basis := Basis.IDENTITY
  var height: float = 0.78
  if scenario.begins_with("landing"):
   initial_basis = Basis(Vector3.UP, 0.06) * Basis(Vector3.FORWARD, 0.14 if scenario == "landing_right" else -0.14)
   height = 1.6
  bike.reset_at(Transform3D(initial_basis,Vector3(-24,height,25)),Vector3(1.2 if scenario=="slide" else 0,0,-speed))
  for i in range(3): await physics_frame
  for wheel in bike.wheels: wheel.omega = speed / wheel.radius
  bike.engine.gear = 1 if scenario == "standing_start" else 2
  bike.engine.automatic = scenario == "standing_start"
  bike.engine.rpm = bike.config.idle_rpm if scenario == "standing_start" else 6000
  if scenario.begins_with("fast_"):
   bike.engine.gear = 4
   bike.engine.rpm = 8500
  var peak_lean: float = 0
  var peak_slip: float = 0
  var peak_roll: float = 0
  var lateral_integral: float = 0
  var lost_contact: int = 0
  var steps: int = 960
  for i in range(steps):
   var t: float = i / 240.0
   bike.command.throttle = 0.28 if scenario == "low_speed" else 0.4
   if scenario == "fast_corner": bike.command.steer = 0.55 if t > 0.5 else 0
   if scenario == "fast_reversal": bike.command.steer = 0.5 if t > 0.5 and t < 2 else (-0.5 if t >= 2 else 0)
   if scenario=="full_input": bike.command.steer=1.0 if t>0.5 else 0
   if scenario=="standing_start":
    bike.command.throttle=0.55
    bike.command.steer=0.25 if t>1.5 else 0
   if scenario=="small_correction": bike.command.steer=0.1 if t>0.5 and t<1.2 else 0
   if scenario=="held_corner": bike.command.steer=0.55 if t>0.5 else 0
   if scenario=="reversal": bike.command.steer=0.5 if t>0.5 and t<2 else (-0.5 if t>=2 else 0)
   if scenario=="low_speed": bike.command.steer=0.35 if t>0.5 else 0
   if scenario=="corner_brake":
    bike.command.steer=0.4 if t>0.5 else 0
    bike.command.front_brake=0.25 if t>2 else 0
    if t>2: bike.command.throttle=0
   await physics_frame
   peak_lean=maxf(peak_lean,absf(rad_to_deg(bike.lean_angle)))
   peak_slip=maxf(peak_slip,absf(rad_to_deg(bike.wheels[0].slip_angle)))
   peak_roll=maxf(peak_roll,absf(bike.angular_velocity.dot(-bike.global_basis.z)))
   if "--trace" in OS.get_cmdline_user_args() and i % 60 == 0: print("TRACE ",t," roll ",rad_to_deg(bike.lean_angle)," target ",rad_to_deg(bike.virtual_rider.lean_request)," steer ",rad_to_deg(bike.steer_angle)," requested ",rad_to_deg(bike.virtual_rider.steering_request)," hand ",bike.steering_torque," load ",bike.wheels[0].load," slip ",rad_to_deg(bike.wheels[0].slip_angle)," force ",bike.wheels[0].force," rear ",bike.wheels[1].force," loads ",bike.wheels[1].load," speed ",bike.linear_velocity.length()," angular ",bike.angular_velocity," moment ",bike.passive_roll_moment," desired_fy ",bike.virtual_rider.desired_front_force," arm ",bike.front_roll_arm," integral ",bike.telemetry().get("roll_integral",0)," limited ",bike.telemetry().get("front_force_limited",false))
   lateral_integral+=absf(bike.linear_velocity.dot(bike.global_basis.x))/240
   if not bike.wheels[0].grounded and not bike.wheels[1].grounded: lost_contact+=1
  var result={"scenario":scenario,"crashed":bike.crashed,"peak_lean_deg":peak_lean,"peak_front_slip_deg":peak_slip,"peak_roll_rad_s":peak_roll,"lateral_travel_m":lateral_integral,"both_detached_ticks":lost_contact,"final_speed":bike.linear_velocity.length(),"final_lean_deg":rad_to_deg(bike.lean_angle),"heading_x":-bike.global_basis.z.x}
  results.append(result)
  print("HANDLING ",JSON.stringify(result))
 var path: String = "user://handling.json"
 var args := OS.get_cmdline_user_args()
 for arg in args:
  if not arg.begins_with("--"): path = arg
 var file=FileAccess.open(path,FileAccess.WRITE)
 file.store_string(JSON.stringify(results,"  "))
 var failures: int = 0
 if "--assert" in args:
  for record in results:
   var ok: bool = not record.crashed and record.final_speed > 1 and record.peak_roll_rad_s < 2.2
   if record.scenario == "full_input": ok = ok and record.peak_lean_deg < 40 and record.peak_front_slip_deg < 6
   if record.scenario == "straight": ok = ok and record.lateral_travel_m < 0.02 and record.peak_lean_deg < 0.5
   if record.scenario == "small_correction": ok = ok and record.peak_lean_deg < 5 and record.peak_front_slip_deg < 2
   if record.scenario in ["held_corner", "reversal", "fast_corner", "fast_reversal"]: ok = ok and record.peak_lean_deg < 28 and record.peak_front_slip_deg < 5
   if record.scenario in ["held_corner", "fast_corner"]: ok = ok and absf(record.heading_x) > 0.3
   if record.scenario in ["low_speed", "corner_brake", "standing_start"]: ok = ok and record.peak_lean_deg < 28
   if record.scenario.begins_with("landing"): ok = ok and absf(record.final_lean_deg) < 5
   print("PASS " if ok else "FAIL ","handling/",record.scenario)
   if not ok: failures += 1
  print("HANDLING_RESULT checks=",results.size()," failures=",failures)
 quit(0 if failures == 0 else 1)
