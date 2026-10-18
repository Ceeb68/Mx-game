extends SceneTree
## Observation only: full-bike sag/drop settling, alongside the force-balance probe.
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 game.controls.set_physics_process(false)
 game.set_process(false)
 var bike=game.bike
 bike.command.clutch=1
 bike.reset_at(Transform3D(Basis.IDENTITY,Vector3(60,0.95,20)))
 for i in range(960):await physics_frame
 var sag: Array=[bike.stations[0].compression,bike.stations[1].compression]
 var idle=bike.telemetry()
 bike.reset_at(Transform3D(Basis.IDENTITY,Vector3(60,1.5,20)))
 var first_contact: float=-1
 var settled: float=-1
 var stable_ticks: int=0
 var previous_vy: float=0
 var peak_accel: float=0
 var peak_load: float=0
 var trace: Array=[]
 var extrema: Array=[[],[]]
 var previous_direction: Array=[0,0]
 var peak_q: Array=[0.,0.]
 for i in range(1440):
  await physics_frame
  var time: float=i/240.0
  if first_contact<0 and bike.contact_mask>0:first_contact=time
  var stable: bool=first_contact>=0 and absf(bike.linear_velocity.y)<0.02
  for j in range(2):
   var station=bike.stations[j]
   stable=stable and absf(station.compression-sag[j])<0.002 and absf(station.velocity)<0.02
   peak_q[j]=maxf(peak_q[j],station.compression)
   var direction: float=signf(station.velocity) if absf(station.velocity)>0.005 else 0
   if first_contact>=0 and direction!=0 and previous_direction[j]!=0 and direction!=previous_direction[j]:extrema[j].append({"time_s":time,"compression_m":station.compression})
   if direction!=0:previous_direction[j]=direction
  stable_ticks=stable_ticks+1 if stable else 0
  if settled<0 and stable_ticks>=60:settled=time-59.0/240-first_contact
  var acceleration: float=(bike.linear_velocity.y-previous_vy)*240
  previous_vy=bike.linear_velocity.y
  peak_accel=maxf(peak_accel,absf(acceleration))
  peak_load=maxf(peak_load,maxf(bike.wheels[0].load,bike.wheels[1].load))
  trace.append({"time_s":time,"height_m":bike.position.y,"vy_m_s":bike.linear_velocity.y,"vertical_acceleration_m_s2":acceleration,"q_m":[bike.stations[0].compression,bike.stations[1].compression],"qdot_m_s":[bike.stations[0].velocity,bike.stations[1].velocity],"load_n":[bike.wheels[0].load,bike.wheels[1].load],"contact_mask":bike.contact_mask,"roll_deg":rad_to_deg(bike.lean_angle),"pitch_deg":rad_to_deg(bike.rotation.x)})
 var result={"static_sag_m":sag,"idle_load_n":[idle.front_load_n,idle.rear_load_n],"first_contact_s":first_contact,"settling_after_contact_s":settled,"peak_compression_m":peak_q,"peak_load_n":peak_load,"peak_vertical_acceleration_m_s2":peak_accel,"extrema":extrema,"crashed":bike.crashed}
 FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify({"results":[result],"trace":trace},"  "))
 print("SUSPENSION_DROP ",JSON.stringify(result))
 quit()
