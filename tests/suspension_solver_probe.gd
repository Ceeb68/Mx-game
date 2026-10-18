extends SceneTree
const Station=preload("res://src/physics/replacement/wheel_station.gd")
var results: Array=[]
var failures: int=0
var checks: int=0
func check(ok: bool,label: String,detail: Variant=null) -> void:
 checks+=1
 print("PASS " if ok else "FAIL ",label," ",detail)
 if not ok:failures+=1
func _initialize() -> void:
 var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/250f.json"))
 var h: float=1.0/960
 for index in range(2):
  for name in ["rebound_flight","top_out","lift_off"]:
   var station=Station.new(index)
   station.compression=0.0001 if name=="top_out" else (0.05 if name=="lift_off" else 0.04)
   station.velocity=-0.5 if name=="top_out" else (0.0 if name=="lift_off" else -1.2)
   var previous: float=station.velocity
   station.step(h,0.051 if name=="lift_off" else -1.0,-4.0 if name=="lift_off" else 0.0,1,0,config,name=="lift_off")
   var residual: float=station.unsprung_mass*(station.velocity-previous)/h-(station.load-station.spring_force-station.unsprung_mass*9.81)
   check(absf(residual)<0.001,"wheel/chassis momentum balance "+str(index)+"/"+name,residual)
   results.append({"wheel":index,"case":name,"momentum_residual_n":residual,"reaction_n":station.spring_force,"load_n":station.load,"velocity_m_s":station.velocity})
  var station=Station.new(index)
  var road: float=0.07
  var kt: float=config.contact_compliance.carcass_stiffness_n_m[index]
  var k: float=config.spring_n_m[index]
  var preload_force: float=config.preload_n[index]
  var equilibrium: float=(kt*road-preload_force-station.unsprung_mass*9.81)/(kt+k)
  var previous_energy: float=0.5*kt*road*road
  var maximum_gain: float=0
  var peak_load: float=0
  var settled_ticks: int=0
  var settled_time: float=-1
  for i in range(2400):
   station.step(h,road,0,1,0,config,true)
   var q: float=station.compression
   var energy: float=0.5*station.unsprung_mass*station.velocity*station.velocity+0.5*k*q*q+preload_force*q+station.unsprung_mass*9.81*q+0.5*kt*pow(maxf(0,road-q),2)
   maximum_gain=maxf(maximum_gain,energy-previous_energy)
   previous_energy=energy
   peak_load=maxf(peak_load,station.load)
   if absf(q-equilibrium)<0.001 and absf(station.velocity)<0.01:settled_ticks+=1
   else:settled_ticks=0
   if settled_time<0 and settled_ticks>192:settled_time=(i-192)*h
  check(maximum_gain<0.0001,"fixed road/mount cannot create suspension energy "+str(index),maximum_gain)
  check(absf(station.compression-equilibrium)<0.0001 and settled_time>0 and settled_time<1,"finite suspension settles rather than locking "+str(index),[station.compression,equilibrium,settled_time])
  results.append({"wheel":index,"case":"fixed_road_settling","energy_gain_j":maximum_gain,"equilibrium_compression_m":equilibrium,"settling_time_s":settled_time,"peak_load_n":peak_load})
 print("SUSPENSION_SOLVER_RESULT checks=",checks," failures=",failures)
 if not OS.get_cmdline_user_args().is_empty():FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
 quit(0 if failures==0 else 1)
