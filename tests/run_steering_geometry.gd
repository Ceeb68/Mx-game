extends SceneTree
const G = preload("res://src/physics/replacement/geometry.gd")
func _initialize() -> void:
 var failures: int=0
 var cases: Array=[[0,0,0],[20,0,0],[40,0,0],[-35,0.25,0],[30,-0.30,0.12],[-20,0.4,-0.1]]
 for c in cases:
  var basis:=Basis(Vector3.UP,0.6)*Basis(Vector3.RIGHT,0.08)*Basis(Vector3.FORWARD,deg_to_rad(c[0]))
  var normal: Vector3=Vector3(0,1,c[2]).normalized()
  var h: float=0.001
  var a: Vector3=(basis*(G.steering_basis(c[1]-h)*Vector3.FORWARD)).slide(normal).normalized()
  var b: Vector3=(basis*(G.steering_basis(c[1]+h)*Vector3.FORWARD)).slide(normal).normalized()
  var measured: float=-a.signed_angle_to(b,normal)/(2*h)
  var calculated: float=G.heading_per_steer(basis,normal,c[1])
  var ok: bool=calculated>0.2 and absf(calculated-measured)<0.0002
  print("PASS " if ok else "FAIL ","ground steering derivative ",c," analytic=",calculated," measured=",measured)
  if not ok:failures+=1
 print("STEERING_GEOMETRY_RESULT checks=",cases.size()," failures=",failures)
 quit(0 if failures==0 else 1)
