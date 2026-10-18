extends SceneTree
var results: Array=[]
var trace: Array=[]
func _initialize() -> void:
 if "--check-only" in OS.get_cmdline_user_args():
  results=JSON.parse_string(FileAccess.get_file_as_string(OS.get_cmdline_user_args()[0])).results
  quit(verify())
 else:call_deferred("run")
func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 game.controls.set_physics_process(false)
 game.set_process(false)
 var bike=game.bike
 for scenario in ["coast","drive","wheelspin_launch","brake","lock_recover","corner_hardpack","corner_loam","rear_slide","rear_slide_hard","fall_left_low","fall_right_low","fall_left_fast","fall_right_fast","fall_left_across","fall_right_across","fall_tip_left","fall_tip_right","unload"]:
  var selected: String=""
  for arg in OS.get_cmdline_user_args():
   if arg.begins_with("--scenario="):selected=arg.trim_prefix("--scenario=")
  if not selected.is_empty() and not scenario.begins_with(selected):continue
  for key in ["throttle","steer","lean","weight","clutch","front_brake","rear_brake"]:bike.command[key]=0.0
  var speed: float=8
  var position:=Vector3(60,0.8,20)
  var basis:=Basis.IDENTITY
  var velocity:=Vector3(0,0,-speed)
  if scenario in ["drive","wheelspin_launch"]:
   speed=6 if scenario=="drive" else 2
   velocity=Vector3(0,0,-speed)
  if scenario=="corner_loam":position.x=-24
  if scenario=="rear_slide" and "--rear-yaw" in OS.get_cmdline_user_args():velocity.x=0.25
  if scenario.begins_with("fall"):
   speed=12 if scenario.ends_with("fast") else 2
   basis=Basis(Vector3.FORWARD,PI/2 if "right" in scenario else -PI/2)
   position.y=0.50
   if "tip" in scenario:
    basis=Basis(Vector3.FORWARD,deg_to_rad(70 if "right" in scenario else -70))
    position.y=0.65
   velocity=Vector3(speed,0,0) if scenario.ends_with("across") else Vector3(0,0,-speed)
  if scenario=="unload":position.y=2
  bike.reset_at(Transform3D(basis,position),velocity)
  for i in range(3):await physics_frame
  if scenario=="rear_slide" and "--rear-yaw" in OS.get_cmdline_user_args():bike.angular_velocity.y=0.25/0.74
  if "tip" in scenario:bike.crashed=true
  for wheel in bike.wheels:wheel.omega=speed/wheel.radius
  bike.engine.automatic=false
  bike.engine.gear=2
  bike.engine.rpm=5000
  var start: Vector3=bike.position
  var previous: Vector3=start
  var distance: float=0
  var stop_time: float=-1
  var stop_distance: float=-1
  var peak_slip: float=0
  var peak_load: float=0
  var collision_impulse: float=0
  var wheel_contacts: Array=[0,0,0,0]
  var steps: int=1440
  var peak_energy: float=0
  var initial_energy: float=0
  var peak_lateral: float=0
  var slow_ticks: int=0
  var pending_stop_distance: float=0
  var pending_stop_time: float=0
  var first_impact_distance: float=-1
  var friction_work: float=0
  var peak_friction_force: float=0
  var stable_slip_sum: float=0
  var stable_slip_count: int=0
  var final_body_energy: float=0
  var crashed_ticks: int=0
  var max_hands_after_crash: float=0
  for i in range(steps):
   var t: float=i/240.0
   bike.command.clutch=1.0
   if scenario in ["drive","wheelspin_launch"]:
    bike.command.clutch=0.0
    bike.command.throttle=0.35 if scenario=="drive" else 0.65
   if scenario=="brake" and t>0.5:
    bike.command.front_brake=0.7
    bike.command.rear_brake=0.35
   if scenario=="lock_recover":bike.command.rear_brake=1.0 if t>0.5 and t<2 else 0
   if scenario in ["corner_hardpack","corner_loam","rear_slide","rear_slide_hard"]:
    bike.command.steer=0.18 if t>0.5 else 0
    bike.command.clutch=0
    bike.command.throttle=0.2
   if scenario=="rear_slide_hard" and t>1 and t<1.6:bike.command.rear_brake=0.8
   if scenario=="rear_slide":
    bike.command.steer=0.10 if t>0.5 else 0
    bike.command.rear_brake=0.25 if t>1 and t<1.25 else 0
   await physics_frame
   var row=bike.telemetry()
   row.erase("landing_events")
   if bike.crashed:
    crashed_ticks+=1
    if crashed_ticks>2:max_hands_after_crash=maxf(max_hands_after_crash,absf(row.hand_torque_nm))
   row.scenario=scenario
   row.time_s=t
   row.velocity=[bike.linear_velocity.x,bike.linear_velocity.y,bike.linear_velocity.z]
   row.position=[bike.position.x,bike.position.y,bike.position.z]
   row.wheel_omega=[bike.wheels[0].omega,bike.wheels[1].omega]
   var local_omega: Vector3=bike.global_basis.inverse()*bike.angular_velocity
   var energy: float=0.5*bike.mass*bike.linear_velocity.length_squared()+0.5*local_omega.dot(local_omega*bike.inertia)
   final_body_energy=energy
   row.body_kinetic_energy_j=energy
   for wheel in bike.wheels:energy+=0.5*wheel.inertia*wheel.omega*wheel.omega
   row.kinetic_energy_j=energy
   if i==0:initial_energy=energy
   peak_energy=maxf(peak_energy,energy)
   var friction_impulse:=Vector3.ZERO
   for contact in row.collision_trace:
    var impulse:=Vector3(contact.impulse[0],contact.impulse[1],contact.impulse[2])
    var normal:=Vector3(contact.reported_normal[0],contact.reported_normal[1],contact.reported_normal[2])
    var contact_velocity:=Vector3(contact.velocity[0],contact.velocity[1],contact.velocity[2])
    var tangent: Vector3=impulse.slide(normal)
    friction_impulse+=tangent
    friction_work+=tangent.dot(contact_velocity)
   row.collision_friction_force_n=[friction_impulse.x*240,friction_impulse.y*240,friction_impulse.z*240]
   peak_friction_force=maxf(peak_friction_force,friction_impulse.length()*240)
   if t>1:
    stable_slip_sum+=absf(bike.wheels[1].slip)
    stable_slip_count+=1
   trace.append(row)
   distance+=Vector2(bike.position.x-previous.x,bike.position.z-previous.z).length()
   previous=bike.position
   if not row.collision_trace.is_empty() and first_impact_distance<0:first_impact_distance=distance
   if Vector2(bike.linear_velocity.x,bike.linear_velocity.z).length()<0.15:
    if slow_ticks==0:
     pending_stop_distance=distance
     pending_stop_time=t
    slow_ticks+=1
    if slow_ticks>=120:
     stop_time=pending_stop_time
     stop_distance=pending_stop_distance
   else:
    slow_ticks=0
    stop_time=-1
    stop_distance=-1
   peak_lateral=maxf(peak_lateral,absf(bike.wheels[1].lateral_velocity))
   peak_slip=maxf(peak_slip,absf(bike.wheels[1].slip))
   peak_load=maxf(peak_load,maxf(bike.wheels[0].load,bike.wheels[1].load))
   collision_impulse+=bike.chassis_impulse_ns
   wheel_contacts[bike.contact_mask]+=1
  var result={"scenario":scenario,"initial_energy_j":initial_energy,"max_hands_after_crash_nm":max_hands_after_crash,"final_body_energy_j":final_body_energy,"reported_friction_work_j":friction_work,"peak_collision_friction_force_n":peak_friction_force,"first_impact_distance_m":first_impact_distance,"mean_rear_slip_after_1s":stable_slip_sum/maxi(stable_slip_count,1),"final_energy_j":trace[-1].kinetic_energy_j,"peak_energy_j":peak_energy,"final_speed_m_s":bike.linear_velocity.length(),"distance_m":distance,"stop_distance_m":stop_distance,"stop_time_s":stop_time,"peak_rear_lateral_m_s":peak_lateral,"peak_rear_slip":peak_slip,"peak_load_n":peak_load,"collision_impulse_ns":collision_impulse,"contact_ticks":wheel_contacts,"final_lean_deg":rad_to_deg(bike.lean_angle),"final_rear_slip":bike.wheels[1].slip,"crashed":bike.crashed}
  results.append(result)
  print("CONTACT ",JSON.stringify(result))
 FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify({"results":results,"trace":trace}))
 quit(verify() if "--assert" in OS.get_cmdline_user_args() else 0)

func verify() -> int:
 var checks: int=0
 var failures: int=0
 for row in results:
  if row.scenario=="rear_slide_hard":
   print("OBSERVATION aggressive rear-brake corner: crashed=",row.crashed," final lean=",row.final_lean_deg)
   continue
  var ok: bool=is_finite(row.final_energy_j) and row.final_energy_j>=0
  if row.scenario.begins_with("fall"):
   ok=ok and row.max_hands_after_crash_nm<0.001 and row.crashed and row.final_speed_m_s<0.15 and row.final_body_energy_j<1 and row.stop_time_s>=0 and row.collision_impulse_ns>0 and row.reported_friction_work_j<0
   ok=ok and row.stop_distance_m>0.1 and row.stop_distance_m<(25 if row.scenario.ends_with("fast") else 2.5)
  else:
   ok=ok and not row.crashed and absf(row.final_lean_deg)<30 and row.contact_ticks[3]>500
   match row.scenario:
    "coast":ok=ok and row.final_speed_m_s>3 and row.final_speed_m_s<8 and row.final_energy_j<row.initial_energy_j and row.mean_rear_slip_after_1s<0.05
    "drive":ok=ok and row.final_speed_m_s>8 and row.mean_rear_slip_after_1s<0.1
    "wheelspin_launch":ok=ok and row.peak_rear_slip>0.5 and row.final_speed_m_s>8
    "brake":ok=ok and row.final_speed_m_s<0.15 and row.stop_distance_m>1 and row.stop_distance_m<15
    "lock_recover":ok=ok and row.peak_rear_slip>0.9 and row.final_speed_m_s>1
    "corner_hardpack","corner_loam":ok=ok and absf(row.final_lean_deg)>1 and row.final_speed_m_s>3
    "rear_slide":
     ok=ok and row.final_speed_m_s>4
     if "--rear-yaw" in OS.get_cmdline_user_args():ok=ok and row.peak_rear_lateral_m_s>0.3
    "unload":ok=ok and row.contact_ticks[0]>30 and row.contact_ticks[3]>500 and row.final_speed_m_s>3
  checks+=1
  print("PASS " if ok else "FAIL ","contact/",row.scenario)
  if not ok:failures+=1
 print("CONTACT_RESULT checks=",checks," failures=",failures," observations=",results.size()-checks)
 return 0 if failures==0 else 1
