extends SceneTree
const Tire=preload("res://src/physics/replacement/contact_tire.gd")
var failures: int=0
func check(ok: bool, label: String) -> void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures+=1
func _initialize() -> void:
 var tire=Tire.new(0.34,0.65)
 tire.load=900
 var dt: float=1.0/240
 for velocity in [Vector2(4,0.3),Vector2(-4,0.3),Vector2(0.2,-0.05),Vector2(-0.2,-0.05)]:
  tire.tread=Vector2(0,0.0002)
  var desired: float=tire.lateral_force_at_heading(dt,0.12,velocity.x,velocity.y,0.04)
  var angle: float=tire.heading_for_force(dt,desired,velocity.x,velocity.y,0.04,-0.4,0.4)
  var actual: float=tire.lateral_force_at_heading(dt,angle,velocity.x,velocity.y,0.04)
  check(absf(actual-desired)<0.1,"reachable signed-velocity inverse "+str(velocity))
 tire.tread=Vector2.ZERO
 check(absf(tire.lateral_force_at_heading(dt,0.4,0,0,0.04))<0.0001,"steering at rest cannot invent tire force")
 var bounded: float=tire.heading_for_force(dt,10000,2,0,0.04,-0.25,0.25)
 check(bounded>=-0.25 and bounded<=0.25,"unreachable force respects steering bounds")
 # Compare prediction with the real unsaturated force integrator, rather than
 # merely checking the inverse against itself.
 var angle: float=0.08
 var longitudinal: float=4*cos(angle)+0.2*sin(angle)
 var lateral: float=0.2*cos(angle)-4*sin(angle)
 tire.omega=longitudinal/tire.radius
 var prediction: float=tire.lateral_force_at_heading(dt,angle,4,0.2,0.04)
 var force: Vector2=tire.forces(dt,longitudinal,lateral,0.95,0,0,0,Vector2(0.04,0.04))
 check(absf(prediction-force.y)<0.001,"prediction agrees with active tread integrator")
 print("TIRE_INVERSE_RESULT checks=7 failures=",failures)
 quit(0 if failures==0 else 1)
