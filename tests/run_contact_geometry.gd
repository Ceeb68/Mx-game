extends SceneTree
const G=preload("res://src/physics/replacement/geometry.gd")
const Tire=preload("res://src/physics/replacement/contact_tire.gd")
var failures: int=0
var checks: int=0
func check(ok: bool,label: String) -> void:
 checks+=1
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures+=1
func _initialize() -> void:
 for lean in [-0.45,0.0,0.45]:
  for pitch in [-0.3,0.3]:
   var basis:=Basis(Vector3.UP,0.4)*Basis(Vector3.RIGHT,pitch)*Basis(Vector3.FORWARD,lean)
   var normal:=Vector3(-0.2,1,0.1).normalized()
   var axle: Vector3=basis*G.steering_basis(0.2)*Vector3.RIGHT
   var radial: Vector3=(-normal).slide(axle).normalized()*0.34
   var forward: Vector3=G.rolling_direction(normal,axle)
   var spin_velocity: Vector3=(-axle*(8/0.34)).cross(radial)
   var carrier: Vector3=-spin_velocity
   check((carrier+spin_velocity).length()<0.00001,"cambered/pitched pure rolling has zero patch velocity "+str([lean,pitch]))
   var tire=Tire.new(0.34,0.65)
   tire.load=900
   tire.omega=8/0.34
   var force: Vector2=tire.forces(1.0/240,carrier.dot(forward),carrier.dot(forward.cross(normal)),0.98,0)
   var old_forward: Vector3=(basis*G.steering_basis(0.2)*Vector3.FORWARD).slide(normal).normalized()
   var legacy=Tire.new(0.34,0.65)
   legacy.load=900
   legacy.omega=8/0.34
   var old_force: Vector2=legacy.forces(1.0/240,carrier.dot(old_forward),carrier.dot(old_forward.cross(normal)),0.98,0)
   print("PURE_ROLLING_FORCE old_lateral_n=",old_force.y," repaired_lateral_n=",force.y)
   check(absf(force.y)<0.001,"pure rolling creates no fictitious lateral force "+str([lean,pitch]))
 var tire=Tire.new(0.34,0.65)
 tire.update_contact_frame(Vector3.FORWARD,Vector3.RIGHT,false)
 tire.tread=Vector2(0.002,0)
 var old_energy: float=90000*tire.tread.x*tire.tread.x+110000*tire.tread.y*tire.tread.y
 var rotation:=Basis(Vector3.UP,0.4)
 tire.update_contact_frame(rotation*Vector3.FORWARD,rotation*Vector3.RIGHT,true)
 var new_energy: float=90000*tire.tread.x*tire.tread.x+110000*tire.tread.y*tire.tread.y
 check(new_energy<=old_energy+0.000001,"passive contact-frame transport cannot add elastic energy")
 tire.detach()
 tire.update_contact_frame(Vector3.FORWARD,Vector3.RIGHT,true)
 check(tire.tread==Vector2.ZERO,"reattachment cannot resurrect the previous patch deformation")
 print("CONTACT_GEOMETRY_RESULT checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
