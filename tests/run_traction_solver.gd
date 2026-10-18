extends SceneTree
const Tire=preload("res://src/physics/replacement/contact_tire.gd")
var failures: int=0
var checks: int=0
func check(ok: bool,label: String,details: Variant=null) -> void:
 checks+=1
 print("PASS " if ok else "FAIL ",label," ",details)
 if not ok:failures+=1
func _initialize() -> void:
 var h: float=1.0/240
 for v in [-0.4,0.4]:
  var tire=Tire.new(0.34,0.65)
  tire.load=900
  tire.omega=0
  var force: Vector2=tire.forces(h,v,0,0.98,0,0,1000,Vector2(0.02,0.02))
  # Locked rotation cannot absorb the predicted contact impulse. The force
  # equation must use only the supplied chassis inverse mass in that branch.
  var expected: float=-90000*h*v/(1+90000*h*h*0.02)
  check(absf(force.x-expected)<0.001,"locked-patch force agrees with constrained wheel",[v,force.x,expected])
  tire.spin(h,0,1000)
  check(absf(tire.omega)<0.00001,"brake capacity holds the predicted lock",tire.omega)
 var tire=Tire.new(0.34,0.65)
 tire.load=900
 tire.omega=15
 var initial: float=0.5*100*4*4+0.5*tire.inertia*tire.omega*tire.omega
 var speed: float=4
 for i in range(480):
  var f: Vector2=tire.forces(h,speed,0,0.98,0,0,0,Vector2(0.01,0.01))
  speed+=f.x*h/100
  tire.spin(h,0,0)
 var final: float=0.5*100*speed*speed+0.5*tire.inertia*tire.omega*tire.omega
 check(final<=initial,"unpowered contact does not add kinetic energy",[initial,final])
 check(absf(tire.omega*tire.radius-speed)<0.01,"free wheel regains rolling contact",[speed,tire.omega*tire.radius])
 print("TRACTION_SOLVER_RESULT checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
