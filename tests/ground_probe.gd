extends SceneTree
var results: Array=[]
var traces: Array=[]
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 var bike=game.bike
 game.controls.set_physics_process(false)
 game.set_process(false)
 for scenario in ["slow_figure_eight","berm_entry","berm_crawl","berm_transition","berm_hold","berm_climb","berm_descend","berm_exit","bump_correction","braking_bumps","whoops","front_unload","rear_unload"]:
  var args=OS.get_cmdline_user_args()
  var selected: String=""
  for arg in args:
   if arg.begins_with("--scenario="):selected=arg.trim_prefix("--scenario=")
  if not selected.is_empty() and selected!=scenario and not (selected=="low" and scenario in ["berm_crawl","berm_transition"]):continue
  for key in ["throttle","steer","lean","weight","clutch","front_brake","rear_brake"]:bike.command[key]=0.0
  var location:=Vector3(-24,0.95,20)
  var direction:=Vector3.FORWARD
  var speed: float=3.0
  var roll: float=0
  var steps: int=1440
  match scenario:
   "berm_entry":
    location=Vector3(102,0,-65)
    direction=Vector3(0.3,0,-1).normalized()
    speed=3
   "berm_crawl":
    location=Vector3(109,0,-65)
    speed=1.2
   "berm_transition":
    location=Vector3(107,0,-65)
    direction=Vector3(0.5,0,-1).normalized()
    speed=1.8
   "berm_hold","berm_exit":
    location=Vector3(109,0,-65)
    speed=4
    roll=-atan(speed*speed/(31*9.81))
   "berm_climb":
    location=Vector3(105.5,0,-65)
    direction=Vector3.RIGHT
    speed=2.0
    steps=720
   "berm_descend":
    location=Vector3(110,0,-65)
    direction=Vector3.LEFT
    speed=2.0
    steps=720
   "bump_correction","braking_bumps":
    location=Vector3(22,0,-26)
    speed=10
   "whoops":
    location=Vector3(42,0,-26)
    speed=10
    steps=1920
   "front_unload","rear_unload":
    location=Vector3(-24,1.4,20)
    speed=5
  if scenario.begins_with("berm") or scenario in ["bump_correction","braking_bumps","whoops"]:location.y=bike.track.height_at(location.x,location.z)+0.95
  var orientation: Basis=Basis.looking_at(direction,Vector3.UP)*Basis(Vector3.FORWARD,roll)
  if scenario=="front_unload":orientation=orientation*Basis(Vector3.RIGHT,0.16)
  if scenario=="rear_unload":orientation=orientation*Basis(Vector3.RIGHT,-0.16)
  bike.reset_at(Transform3D(orientation,location),direction*speed)
  for i in range(3):await physics_frame
  for wheel in bike.wheels:wheel.omega=speed/wheel.radius
  bike.engine.automatic=false
  bike.engine.gear=1 if speed<=5 else 2
  bike.engine.rpm=3800 if speed<=5 else 6500
  var peak_roll: float=0
  var peak_rate: float=0
  var peak_load: float=0
  var contact_counts: Array=[0,0,0,0]
  var peak_radius_error: float=0
  var first_upset: Dictionary={}
  var previous_rate: float=0
  var previous_lean: float=bike.lean_angle
  for i in range(steps):
   var t: float=i/240.0
   bike.command.throttle=0.16 if speed<=5 else 0.4
   if scenario=="slow_figure_eight":bike.command.steer=0.22*sin(maxf(0,t-0.5)*TAU/5.0)
   if scenario in ["berm_entry","berm_hold"]:bike.command.steer=-0.16 if t>0.3 else 0
   if scenario in ["berm_crawl","berm_transition"]:
    bike.command.steer=-0.07 if t>0.3 else 0
    bike.command.throttle=0.12
   if scenario=="berm_exit":
    bike.command.steer=-0.2 if t>0.3 else 0
    bike.command.throttle=0.4 if t>2 else 0.16
   if scenario in ["berm_climb","berm_descend"]:bike.command.throttle=0.1
   if scenario in ["bump_correction","braking_bumps","whoops"]:bike.command.steer=0.05 if t>1 and t<1.5 else 0
   if scenario=="braking_bumps":bike.command.front_brake=0.12 if t>2 and t<3 else 0
   await physics_frame
   var rate: float=bike.angular_velocity.dot(-bike.global_basis.z)
   var row=bike.telemetry()
   row.erase("landing_events")
   row.measured_lean_rate_rad_s=wrapf(bike.lean_angle-previous_lean,-PI,PI)*240
   previous_lean=bike.lean_angle
   row.scenario=scenario
   row.time_s=t
   row.position=[bike.position.x,bike.position.y,bike.position.z]
   row.roll_acceleration_rad_s2=(rate-previous_rate)*240
   previous_rate=rate
   traces.append(row)
   if first_upset.is_empty() and (absf(rate)>1.5 or absf(row.lean_deg)>40):first_upset=row.duplicate(true)
   peak_roll=maxf(peak_roll,absf(row.lean_deg))
   peak_rate=maxf(peak_rate,absf(rate))
   peak_load=maxf(peak_load,maxf(bike.wheels[0].load,bike.wheels[1].load))
   contact_counts[bike.contact_mask]+=1
   if scenario=="berm_hold":peak_radius_error=maxf(peak_radius_error,absf(Vector2(bike.position.x-78,bike.position.z+65).length()-31))
  var result={"scenario":scenario,"crashed":bike.crashed,"peak_roll_deg":peak_roll,"peak_roll_rate_rad_s":peak_rate,"peak_load_n":peak_load,"final_lean_deg":rad_to_deg(bike.lean_angle),"final_speed_m_s":bike.linear_velocity.length(),"contact_ticks":contact_counts,"berm_radius_error_m":peak_radius_error,"first_upset":first_upset,"final_position":[bike.position.x,bike.position.y,bike.position.z]}
  results.append(result)
  print("GROUND ",JSON.stringify(result))
 var failures: int=0
 if "--assert" in OS.get_cmdline_user_args():
  for record in results:
   var ok: bool=not record.crashed and record.peak_roll_deg<40 and absf(record.final_lean_deg)<25 and record.final_speed_m_s>0.5
   if record.scenario=="berm_hold":ok=ok and record.berm_radius_error_m<6
   if record.scenario=="front_unload":ok=ok and record.contact_ticks[2]>0
   if record.scenario=="rear_unload":ok=ok and record.contact_ticks[1]>0
   print("PASS " if ok else "FAIL ","ground/",record.scenario)
   if not ok:failures+=1
  print("GROUND_RESULT checks=",results.size()," failures=",failures)
 FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify({"results":results,"trace":traces}))
 quit(0 if failures==0 else 1)
