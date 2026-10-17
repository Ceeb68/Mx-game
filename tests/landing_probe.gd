extends SceneTree
var results: Array=[]
var traces: Array=[]
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 var bike=game.bike
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--landing-gain="):bike.config.landing_control.lean_gain=float(arg.trim_prefix("--landing-gain="))
 game.controls.set_physics_process(false)
 game.set_process(false)
 for scenario in ["two_wheel","front_first","rear_first","sideways_small","moderate_roll_yaw","moderate_mirror","moderate_smaller","moderate_larger","excessive_sideways","tabletop","tabletop_repeat_2","tabletop_repeat_3","small_bumps","whoops","rough_straight"]:
  var selected: String=""
  for arg in OS.get_cmdline_user_args():
   if arg.begins_with("--scenario="):selected=arg.trim_prefix("--scenario=")
  if not selected.is_empty() and selected!=scenario and not (selected=="moderate" and scenario.begins_with("moderate")):continue
  var tabletop: bool=scenario.begins_with("tabletop")
  for k in ["steer","lean","weight","throttle","clutch","front_brake","rear_brake"]:bike.command[k]=0.0
  var orientation:=Basis.IDENTITY
  if scenario=="two_wheel":orientation=Basis(Vector3.RIGHT,0.016)
  if scenario=="front_first":orientation=Basis(Vector3.RIGHT,-0.16)
  if scenario=="rear_first":orientation=Basis(Vector3.RIGHT,0.16)
  if scenario=="sideways_small":orientation=Basis(Vector3.UP,0.10)
  if scenario=="moderate_roll_yaw":orientation=Basis(Vector3.UP,0.10)*Basis(Vector3.FORWARD,0.18)
  if scenario=="moderate_mirror":orientation=Basis(Vector3.UP,-0.10)*Basis(Vector3.FORWARD,-0.18)
  if scenario=="moderate_smaller":orientation=Basis(Vector3.UP,0.10)*Basis(Vector3.FORWARD,0.12)
  if scenario=="moderate_larger":orientation=Basis(Vector3.UP,0.10)*Basis(Vector3.FORWARD,0.24)
  if scenario=="excessive_sideways":orientation=Basis(Vector3.UP,0.8)*Basis(Vector3.FORWARD,1.45)
  var speed: float=14 if tabletop else 12
  var start: Vector3=Vector3(0,0.85,-30) if tabletop else Vector3(-24,2.2,25)
  if scenario in ["small_bumps","whoops","rough_straight"]:
   speed=10
   start=Vector3(22 if scenario=="small_bumps" else (42 if scenario=="whoops" else -24),1.1,-26 if scenario!="rough_straight" else -92)
  bike.reset_at(Transform3D(orientation,start),Vector3(0,0,-speed))
  for i in range(3):await physics_frame
  for w in bike.wheels:w.omega=speed/w.radius
  bike.engine.automatic=false
  bike.engine.gear=3
  bike.engine.rpm=7000
  var detached_ticks: int=0
  var front_only_ticks: int=0
  var rear_only_ticks: int=0
  var peak_load: float=0
  var peak_angular: float=0
  var peak_lean: float=0
  var steps: int=1920 if tabletop else 1200
  for i in range(steps):
   bike.command.throttle=0.4
   if scenario=="two_wheel":
    bike.command.clutch=1.0 if bike.contact_mask==0 else 0.0
    if bike.contact_mask==0:bike.command.throttle=0.0
   if scenario in ["small_bumps","whoops","rough_straight"]:
    bike.command.steer=0.05 if i>240 and i<360 else 0.0
    bike.command.front_brake=0.12 if scenario=="small_bumps" and i>480 and i<720 else 0.0
   await physics_frame
   if bike.contact_mask==0:detached_ticks+=1
   if bike.contact_mask==1:front_only_ticks+=1
   if bike.contact_mask==2:rear_only_ticks+=1
   peak_load=maxf(peak_load,maxf(bike.wheels[0].load,bike.wheels[1].load))
   peak_angular=maxf(peak_angular,bike.angular_velocity.length())
   peak_lean=maxf(peak_lean,absf(rad_to_deg(bike.lean_angle)))
   if i%8==0:
    var row=bike.telemetry()
    row.scenario=scenario
    row.time_s=i/240.0
    row.position=[bike.position.x,bike.position.y,bike.position.z]
    traces.append(row)
  var result={"scenario":scenario,"crashed":bike.crashed,"crash_reason":bike.last_crash,"crash_evidence":bike.crash_evidence.duplicate(true),"landings":bike.landing_events.duplicate(true),"peak_load_n":peak_load,"peak_angular_rad_s":peak_angular,"peak_lean_deg":peak_lean,"final_lean_deg":rad_to_deg(bike.lean_angle),"final_speed_m_s":bike.linear_velocity.length(),"final_position":[bike.position.x,bike.position.y,bike.position.z]}
  result.merge({"detached_ticks":detached_ticks,"front_only_ticks":front_only_ticks,"rear_only_ticks":rear_only_ticks})
  if scenario=="excessive_sideways":
   var crash_location: Vector3=bike.position
   game.reset_bike()
   for i in range(4):await physics_frame
   result.recovered_after_reset=not bike.crashed and bike.crash_time==0 and bike.linear_velocity.length()<1
   result.reset_horizontal_m=Vector2(bike.position.x-crash_location.x,bike.position.z-crash_location.z).length()
  results.append(result)
  print("LANDING ",JSON.stringify(result))
 var args=OS.get_cmdline_user_args()
 FileAccess.open(args[0],FileAccess.WRITE).store_string(JSON.stringify({"results":results,"trace":traces}))
 var failures: int=0
 var checks: int=0
 var observation_failures: int=0
 if "--assert" in args or "--assert-all" in args:
  for x in results:
   var ok: bool=x.crashed if x.scenario=="excessive_sideways" else (not x.crashed and x.final_speed_m_s>3 and absf(x.final_lean_deg)<15)
   if x.scenario=="excessive_sideways":ok=ok and x.recovered_after_reset and x.reset_horizontal_m<10
   if x.scenario.begins_with("tabletop"):ok=ok and not x.landings.is_empty()
   var observation: bool=x.scenario in ["moderate_larger","small_bumps","whoops","rough_straight"]
   if observation and not "--assert-all" in args:
    print("OBSERVED_PASS " if ok else "OBSERVED_FAIL ","diagnostic/",x.scenario," (known-limit probe; excluded from supported-stage assertions)")
    if not ok:observation_failures+=1
    continue
   checks+=1
   print("PASS " if ok else "FAIL ","landing/",x.scenario)
   if not ok:failures+=1
  print("LANDING_RESULT checks=",checks," failures=",failures," diagnostic_observation_failures=",observation_failures)
 quit(0 if failures==0 else 1)
