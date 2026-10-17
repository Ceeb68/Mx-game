extends SceneTree
const Geometry = preload("res://src/physics/replacement/geometry.gd")
var results: Array = []
var traces: Array = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 var bike=game.bike
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--tracking="):
   bike.config.handling.rider.target_rate_tracking=float(arg.trim_prefix("--tracking="))
 var replay=load("res://tests/replay_controls.gd").new()
 replay.bike=bike
 replay.defaults()
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--smoothing="):replay.options.smoothing_s=float(arg.trim_prefix("--smoothing="))
  if arg.begins_with("--curve="):replay.options.steering_curve=float(arg.trim_prefix("--curve="))
 game.controls.set_physics_process(false)
 game.set_process(false)
 var visual=bike.get_child(1)
 visual.set_process(false)
 visual.rider.set_process(false)
 bike.steering_assist=true
 bike.foot_support=true
 for scenario in ["straight","gradual_turn","reversal","low_speed","rear_slide","small_correction","fast_reversal"]:
  for key in ["throttle","steer","lean","weight","clutch","front_brake","rear_brake"]:bike.command[key]=0.0
  replay.steer=0
  var speed: float=4 if scenario=="low_speed" else 10
  if scenario=="fast_reversal":speed=18
  bike.reset_at(Transform3D(Basis.IDENTITY,Vector3(-24,0.78,25)),Vector3(0,0,-speed))
  for i in range(3):await physics_frame
  for wheel in bike.wheels:wheel.omega=speed/wheel.radius
  bike.engine.automatic=false
  bike.engine.gear=2 if speed==10 else 1
  bike.engine.rpm=6000 if speed==10 else 4000
  if scenario=="fast_reversal":
   bike.engine.gear=4
   bike.engine.rpm=8500
  var force_error2: float=0
  var lean_error2: float=0
  var lateral_travel: float=0
  var peak_front_lateral: float=0
  var peak_rear_lateral: float=0
  var peak_lean: float=0
  var positive_power: int=0
  var saturated: int=0
  var limited: int=0
  var peak_integral: float=0
  var peak_rear_slip: float=0
  var response_time: float=-1
  var initiation: float=-1
  var reversal: float=-1
  var peak_overshoot: float=0
  var peak_roll_rate: float=0
  var peak_yaw_rate: float=0
  var peak_load: float=0
  var peak_utilization: float=0
  var last_outside: float=0
  for i in range(1440):
   var t: float=i/240.0
   bike.command.throttle=0.28 if speed==4 else 0.4
   bike.command.steer=0
   match scenario:
    "gradual_turn":bike.command.steer=0.55*clampf((t-0.5)/1.0,0,1)
    "reversal":bike.command.steer=0.5 if t>0.5 and t<2.5 else (-0.5 if t>=2.5 else 0)
    "low_speed":bike.command.steer=0.35*clampf((t-0.5)/0.5,0,1)
    "small_correction":bike.command.steer=0.1 if t>0.5 and t<1.2 else 0
    "fast_reversal":bike.command.steer=0.5 if t>0.5 and t<2.5 else (-0.5 if t>=2.5 else 0)
    "rear_slide":
     bike.command.steer=0.25 if t>0.5 else 0
     bike.command.rear_brake=1.0 if t>2 and t<2.5 else 0
     bike.command.clutch=1.0 if t>2 and t<2.5 else 0
   replay.injected={"right":maxf(0,bike.command.steer),"left":maxf(0,-bike.command.steer),"throttle":bike.command.throttle,"rear_brake":bike.command.rear_brake,"clutch":bike.command.clutch}
   var raw: float=bike.command.steer
   replay._physics_process(1.0/240.0)
   await physics_frame
   if response_time<0 and t>0.5 and absf(bike.steer_angle)>0.002:response_time=t-0.5
   var lean_deg: float=rad_to_deg(bike.lean_angle)
   var target_deg: float=rad_to_deg(bike.virtual_rider.lean_request)
   if initiation<0 and t>0.5 and lean_deg>0.5:initiation=t-0.5
   if scenario in ["reversal","fast_reversal"] and t>=2.5:
    if reversal<0 and lean_deg<0:reversal=t-2.5
    if target_deg<-5 and lean_deg<target_deg:peak_overshoot=maxf(peak_overshoot,target_deg-lean_deg)
    if absf(lean_deg-target_deg)>1:last_outside=t
   if scenario=="small_correction" and t>=1.2 and absf(lean_deg)>0.25:last_outside=t
   peak_roll_rate=maxf(peak_roll_rate,absf(bike.angular_velocity.dot(-bike.global_basis.z)))
   peak_yaw_rate=maxf(peak_yaw_rate,absf(bike.angular_velocity.y))
   peak_load=maxf(peak_load,maxf(bike.wheels[0].load,bike.wheels[1].load))
   peak_utilization=maxf(peak_utilization,maxf(bike.wheels[0].utilization,bike.wheels[1].utilization))
   peak_lean=maxf(peak_lean,absf(rad_to_deg(bike.lean_angle)))
   peak_front_lateral=maxf(peak_front_lateral,absf(bike.wheels[0].lateral_velocity))
   peak_rear_lateral=maxf(peak_rear_lateral,absf(bike.wheels[1].lateral_velocity))
   lateral_travel+=absf(bike.linear_velocity.dot(bike.global_basis.x))/240
   peak_rear_slip=maxf(peak_rear_slip,absf(bike.wheels[1].slip))
   if t>=0.5:
    force_error2+=pow(bike.wheels[0].force.y-bike.virtual_rider.desired_front_force,2)
    lean_error2+=pow(rad_to_deg(bike.lean_angle-bike.virtual_rider.lean_request),2)
    if bike.wheels[0].force.y*bike.wheels[0].lateral_velocity>0.1:positive_power+=1
    if bike.wheels[0].utilization>0.98:saturated+=1
    if bike.virtual_rider.force_limited:limited+=1
    peak_integral=maxf(peak_integral,absf(bike.virtual_rider.roll_integral))
   if i%8==0:
    var row: Dictionary=bike.telemetry()
    row.raw_input=raw
    row.roll_rate_rad_s=bike.angular_velocity.dot(-bike.global_basis.z)
    row.yaw_rate_rad_s=bike.angular_velocity.y
    row.scenario=scenario
    row.time_s=t
    traces.append(row)
  var r={"scenario":scenario,"crashed":bike.crashed,"force_tracking_rms_n":sqrt(force_error2/1320),"lean_tracking_rms_deg":sqrt(lean_error2/1320),"peak_lean_deg":peak_lean,"peak_front_lateral_m_s":peak_front_lateral,"peak_rear_lateral_m_s":peak_rear_lateral,"lateral_travel_m":lateral_travel,"front_positive_shear_power_fraction":positive_power/1320.0,"front_saturated_fraction":saturated/1320.0,"force_limited_fraction":limited/1320.0,"peak_integral":peak_integral,"response_s":response_time,"final_speed":bike.linear_velocity.length(),"final_lean_deg":rad_to_deg(bike.lean_angle),"rear_peak_slip":peak_rear_slip,"final_rear_slip":bike.wheels[1].slip}
  r.merge({"lean_initiation_s":initiation,"lean_reversal_s":reversal,"reversal_overshoot_deg":peak_overshoot,"last_outside_band_s":last_outside,"peak_roll_rate_rad_s":peak_roll_rate,"peak_yaw_rate_rad_s":peak_yaw_rate,"peak_tire_load_n":peak_load,"peak_grip_use":peak_utilization})
  results.append(r)
  print("TARGETED ",JSON.stringify(r))
 var geometric: Array=[]
 for lean in [0,20,40]:
  var b:=Basis(Vector3.FORWARD,deg_to_rad(lean))
  var lo: Vector3=(b*(Geometry.steering_basis(-0.0005)*Vector3.FORWARD)).slide(Vector3.UP).normalized()
  var hi: Vector3=(b*(Geometry.steering_basis(0.0005)*Vector3.FORWARD)).slide(Vector3.UP).normalized()
  var measured: float=-lo.signed_angle_to(hi,Vector3.UP)/0.001
  var old_inverse: float=cos(deg_to_rad(lean))/cos(Geometry.RAKE)
  geometric.append({"lean_deg":lean,"heading_per_steer":measured,"v3_response_fraction":measured*old_inverse})
 var failures: int=0
 if "--assert" in OS.get_cmdline_user_args():
  for record in results:
   var ok: bool=not record.crashed and record.final_speed>2 and record.peak_lean_deg<35
   if record.scenario=="straight":ok=ok and record.lateral_travel_m<0.02
   if record.scenario=="low_speed":ok=ok and record.peak_lean_deg<15 and record.lean_tracking_rms_deg<5
   if record.scenario=="reversal":ok=ok and record.lean_reversal_s>0 and record.lean_reversal_s<0.5 and record.reversal_overshoot_deg<1
   if record.scenario=="small_correction":ok=ok and absf(record.final_lean_deg)<0.5 and record.peak_lean_deg<5
   if record.scenario=="rear_slide":ok=ok and record.rear_peak_slip>0.9 and absf(record.final_rear_slip)<0.25
   print("PASS " if ok else "FAIL ","targeted/",record.scenario)
   if not ok:failures+=1
  print("TARGETED_RESULT checks=",results.size()," failures=",failures)
 var path: String=OS.get_cmdline_user_args()[0]
 var f=FileAccess.open(path,FileAccess.WRITE)
 f.store_string(JSON.stringify({"controller":bike.SIMULATION_VERSION,"results":results,"geometry":geometric,"trace":traces},"  "))
 print("TARGETED_GEOMETRY ",JSON.stringify(geometric))
 replay.free()
 quit(0 if failures==0 else 1)
