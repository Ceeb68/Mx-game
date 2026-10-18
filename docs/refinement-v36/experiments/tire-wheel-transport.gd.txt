extends "res://src/physics/tire.gd"
## Stateful elastic tread (bristle) contact, backward-Euler relative velocity solve.
## Static adhesion transitions to sliding; both directions share one friction budget.
var tread := Vector2.ZERO
var tread_stiffness:=Vector2(90000,110000)
var reference_load: float=900
var tread_length: float=0.16
var sliding_drop: float=0.12
var bearing_drag: float=0.015
var brake_locked: bool=false
var contact_forward:=Vector3.FORWARD
var contact_right:=Vector3.RIGHT
var has_contact_frame: bool=false
var sliding: bool = false
var longitudinal_velocity: float = 0
var lateral_velocity: float = 0
var applied_force := Vector3.ZERO
func reset() -> void:
 super.reset()
 has_contact_frame=false
 brake_locked=false
 longitudinal_velocity = 0
 lateral_velocity = 0
 applied_force = Vector3.ZERO
 tread = Vector2.ZERO
 sliding = false
func stiffness_at_load() -> Vector2:
 return tread_stiffness*clampf(load/reference_load,0.08,2.5)

func configure(data: Dictionary, index: int) -> void:
 super.configure(data,index)
 var tuning: Dictionary=data.get("active_tire",{})
 var rates: Array=tuning.get("tread_stiffness_n_m",[90000.0,110000.0])
 tread_stiffness=Vector2(rates[0],rates[1])
 reference_load=tuning.get("reference_load_n",900.0)
 tread_length=tuning.get("tread_transport_length_m",0.16)
 sliding_drop=tuning.get("sliding_drop_fraction",0.12)
 bearing_drag=tuning.get("bearing_drag_nm_s",0.015)

func limited_trial(dt: float, relative: Vector2, stiffness: Vector2, convection: float, inverse_mass: Vector2, limit: float) -> Vector2:
 var demand:=Vector2.ZERO
 for j in range(2):
  demand[j]=stiffness[j]*(tread[j]+dt*relative[j])/(1+dt*convection+stiffness[j]*dt*dt*inverse_mass[j])
 sliding=demand.length()>limit
 if sliding:
  var excess: float=demand.length()/maxf(limit,0.001)-1
  demand=demand.normalized()*limit*(1-sliding_drop*(1-exp(-excess)))
 return demand

func forces(dt: float, longitudinal: float, lateral: float, mu: float, _legacy: float, drive: float = 0, brake: float = 0, inverse_effective_mass: Vector2 = Vector2(0.01,0.01)) -> Vector2:
 longitudinal_velocity=longitudinal
 lateral_velocity=lateral
 slip=(omega*radius-longitudinal)/maxf(absf(longitudinal),1)
 slip_angle=atan2(lateral,maxf(absf(longitudinal),0.5))
 var stiffness: Vector2=stiffness_at_load()
 var limit: float=maxf(0,mu*load)
 var free: float=omega+(drive-omega*bearing_drag)*dt/inertia
 var brake_direction: float=signf(free)
 brake_locked=false
 var demand:=Vector2.ZERO
 if brake>0:
  # First solve the constrained (zero rotation) branch. A locked wheel has
  # no rotational inverse mass and no rolling renewal of its tread patch.
  demand=limited_trial(dt,Vector2(-longitudinal,-lateral),stiffness,0,inverse_effective_mass,limit)
  var required: float=drive-omega*bearing_drag-demand.x*radius+omega*inertia/dt
  brake_locked=absf(required)<=brake
  brake_direction=signf(required)
 if not brake_locked:
  free-=brake_direction*brake*dt/inertia
  var relative:=Vector2(free*radius-longitudinal,-lateral)
  # Tread enters/leaves the patch with wheel rotation, not chassis travel.
  var convection: float=absf(free*radius)/tread_length
  demand=limited_trial(dt,relative,stiffness,convection,inverse_effective_mass+Vector2(radius*radius/inertia,0),limit)
 tread=Vector2(demand.x/stiffness.x,demand.y/stiffness.y)
 force=demand
 utilization=force.length()/maxf(limit,0.001)
 return force

func spin(dt: float, drive_torque: float, brake_torque: float) -> void:
 var next: float=omega+(drive_torque-force.x*radius-omega*bearing_drag)*dt/inertia
 omega=move_toward(next,0,brake_torque*dt/inertia)

func detach() -> void:
 has_contact_frame=false
 brake_locked=false
 tread = Vector2.ZERO
 force = Vector2.ZERO
 load = 0
 grounded = false
 longitudinal_velocity = 0
 lateral_velocity = 0
 applied_force = Vector3.ZERO
 slip = 0
 slip_angle = 0
 utilization = 0
func lateral_angle_for_force(dt: float, desired: float, longitudinal: float, inverse_mass: float) -> float:
 var stiffness: float = stiffness_at_load().y
 var denominator: float = 1 + dt * absf((omega-omega*bearing_drag*dt/inertia)*radius) / tread_length + stiffness * dt * dt * inverse_mass
 var relative: float = (desired * denominator / stiffness - tread.y) / dt
 return atan2(-relative,maxf(absf(longitudinal),0.5))

# Evaluate the same unsaturated discrete tread equation used by forces(),
# after rotating the measured velocity into a candidate tire heading.
func lateral_force_at_heading(dt: float, angle: float, longitudinal: float, lateral: float, inverse_mass: float) -> float:
 var along: float=longitudinal*cos(angle)+lateral*sin(angle)
 var across: float=lateral*cos(angle)-longitudinal*sin(angle)
 var stiffness: float=stiffness_at_load().y
 return stiffness*(tread.y-dt*across)/(1+dt*absf((omega-omega*bearing_drag*dt/inertia)*radius)/tread_length+stiffness*dt*dt*inverse_mass)

func heading_for_force(dt: float, desired: float, longitudinal: float, lateral: float, inverse_mass: float, low: float, high: float) -> float:
 # Reverse travel is signed. At standstill steering cannot invent lateral
 # velocity: choose the least-error reachable heading, rather than a speed floor.
 var best: float=clampf(0,low,high)
 var best_error: float=absf(lateral_force_at_heading(dt,best,longitudinal,lateral,inverse_mass)-desired)
 var root_found: bool=false
 var previous: float=low
 var previous_error: float=lateral_force_at_heading(dt,previous,longitudinal,lateral,inverse_mass)-desired
 for sample in range(17):
  var candidate: float=lerpf(low,high,sample/16.0)
  var error: float=lateral_force_at_heading(dt,candidate,longitudinal,lateral,inverse_mass)-desired
  if not root_found and absf(error)<best_error:
   best=candidate
   best_error=absf(error)
  if error*previous_error<=0:
   var a: float=previous
   var b: float=candidate
   var ea: float=previous_error
   for iteration in range(12):
    var middle: float=(a+b)*0.5
    var em: float=lateral_force_at_heading(dt,middle,longitudinal,lateral,inverse_mass)-desired
    if ea*em<=0:b=middle
    else:
     a=middle
     ea=em
   var solution: float=(a+b)*0.5
   if not root_found or absf(solution)<absf(best):best=solution
   root_found=true
  previous=candidate
  previous_error=error
 return best

func update_contact_frame(forward: Vector3, right: Vector3, passive: bool) -> void:
 if passive and has_contact_frame:
  # Re-express existing patch deformation, rather than treating its old
  # components as if the tire frame had not rotated during the fall.
  var deformation: Vector3=contact_forward*tread.x+contact_right*tread.y
  var old_energy: float=tread_stiffness.x*tread.x*tread.x+tread_stiffness.y*tread.y*tread.y
  tread=Vector2(deformation.dot(forward),deformation.dot(right))
  var new_energy: float=tread_stiffness.x*tread.x*tread.x+tread_stiffness.y*tread.y*tread.y
  # Coordinate transport must not create unaccounted elastic energy.
  if new_energy>old_energy and new_energy>0:tread*=sqrt(old_energy/new_energy)
 contact_forward=forward
 contact_right=right
 has_contact_frame=true
