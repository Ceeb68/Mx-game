extends Node3D
## Original procedural engineering proxy; no third-party motorcycle assets.
var bike: RigidBody3D
var wheel_nodes: Array[Node3D] = []
var hubs: Array[Node3D] = []
var rider: Node3D
const Geometry = preload("res://src/physics/replacement/geometry.gd")
var steering: Node3D
var upper_forks: Array = []
var lower_forks: Array = []
var shock: MeshInstance3D
var handlebar: Node3D
var limbs: Array[MeshInstance3D] = []
var red: StandardMaterial3D
var black: StandardMaterial3D
var metal: StandardMaterial3D
var white: StandardMaterial3D

func mat(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
 var m := StandardMaterial3D.new()
 m.albedo_color = color
 m.metallic = metallic
 m.roughness = 0.45 if metallic > 0 else 0.8
 return m

func box(size: Vector3, position_: Vector3, material: Material, parent: Node = self) -> MeshInstance3D:
 var mesh := BoxMesh.new()
 mesh.size = size
 return instance(mesh, position_, material, parent)

func instance(mesh: Mesh, position_: Vector3, material: Material, parent: Node = self) -> MeshInstance3D:
 var item := MeshInstance3D.new()
 item.mesh = mesh
 item.material_override = material
 item.position = position_
 parent.add_child(item)
 return item

func rod(a: Vector3, b: Vector3, radius: float, material: Material, parent: Node = self) -> MeshInstance3D:
 var mesh := CylinderMesh.new()
 mesh.top_radius = radius
 mesh.bottom_radius = radius
 mesh.height = 1.0
 var item := instance(mesh, (a + b) * 0.5, material, parent)
 align_rod(item, a, b)
 return item

func align_rod(item: Node3D, a: Vector3, b: Vector3) -> void:
 var direction: Vector3 = b - a
 item.position = (a + b) * 0.5
 item.quaternion = Quaternion(Vector3.UP, direction.normalized())
 item.scale = Vector3(1, direction.length(), 1)

func _ready() -> void:
 bike = get_parent()
 red = mat(Color(0.97, 0.25, 0.055))
 black = mat(Color(0.035, 0.04, 0.045))
 metal = mat(Color(0.58, 0.61, 0.61), 0.8)
 white = mat(Color(0.85, 0.9, 0.87))
 box(Vector3(0.28, 0.13, 0.85), Vector3(0, 0.32, 0.15), black)
 box(Vector3(0.35, 0.28, 0.48), Vector3(0, 0.18, -0.25), red)
 box(Vector3(0.24, 0.30, 0.28), Vector3(0, -0.08, 0), metal)
 box(Vector3(0.22, 0.06, 0.55), Vector3(0, 0.28, 0.70), red)
 steering = Node3D.new()
 steering.name = "SteeringHead"
 steering.position = Geometry.HEAD
 add_child(steering)
 box(Vector3(0.25, 0.05, 0.6), Vector3(0, 0.30, -0.92) - Geometry.HEAD, red, steering).name = "FrontFender"
 box(Vector3(0.23, 0.25, 0.045), Vector3(0, 0.30, -0.66) - Geometry.HEAD, white, steering)
 for y in [0.28,0.40]:
  box(Vector3(0.27,0.035,0.10),Vector3(0,y,Geometry.HEAD.z-(Geometry.HEAD.y-y)*tan(Geometry.RAKE))-Geometry.HEAD,metal,steering)
 for side in [-1.0,1.0]:
  upper_forks.append(rod(Vector3.ZERO,Vector3.UP,0.026,metal,steering))
  lower_forks.append(rod(Vector3.ZERO,Vector3.UP,0.033,black,steering))
 shock = rod(Vector3(0,0.16,0.40),Geometry.REAR_PIVOT,0.045,metal)
 for x in [-0.13, 0.13]:
  rod(Vector3(x, -0.22, 0.3), Vector3(x, 0.32, -0.4), 0.025, metal)
  rod(Vector3(x, -0.22, 0.3), Vector3(x, -0.10, -0.35), 0.025, metal)
 rod(Vector3(0.18, 0.1, 0.48), Vector3(0.18, 0.13, 0.86), 0.065, metal)
 handlebar = Node3D.new()
 handlebar.position = Vector3(0, 0.48, -0.55) - Geometry.HEAD
 steering.add_child(handlebar)
 rod(Vector3(-0.4, 0, 0), Vector3(0.4, 0, 0), 0.025, metal, handlebar)
 for side in [-1.0, 1.0]:
  rod(Vector3(side * 0.11, -0.25, 0.12), Vector3(side * 0.28, -0.25, 0.12), 0.025, metal)
  box(Vector3(0.15, 0.025, 0.065), Vector3(side * 0.19, -0.235, 0.12), black)
 for i in range(2):
  var hub := Node3D.new()
  if i == 0:
   steering.add_child(hub)
  else:
   add_child(hub)
  hubs.append(hub)
  var spin := Node3D.new()
  hub.add_child(spin)
  wheel_nodes.append(spin)
  var tire := TorusMesh.new()
  var radius: float = bike.config.front_radius_m if i == 0 else bike.config.rear_radius_m
  tire.inner_radius = radius - 0.10
  tire.outer_radius = radius
  tire.rings = 24
  tire.ring_segments = 12
  var t := instance(tire, Vector3.ZERO, black, spin)
  t.rotation.z = PI / 2
  var rim := TorusMesh.new()
  rim.inner_radius = radius - 0.13
  rim.outer_radius = radius - 0.115
  var v := instance(rim, Vector3.ZERO, metal, spin)
  v.rotation.z = PI / 2
  for spoke in range(12):
   var angle: float = spoke * TAU / 12
   rod(Vector3.ZERO, Vector3(0, sin(angle), cos(angle)) * (radius - 0.12), 0.006, metal, spin)
  for knob in range(24):
   var angle: float = knob * TAU / 24
   var k := box(Vector3(0.13, 0.04, 0.055), Vector3(0, cos(angle), sin(angle)) * (radius - 0.005), black, spin)
   k.rotation.x = angle
 rider = preload("res://src/presentation/rider_animator.gd").new()
 rider.bike = bike
 add_child(rider)
 # Animated fork/swingarm rods are updated from actual spring extension.
 for i in range(2): limbs.append(rod(Vector3.ZERO, Vector3.UP, 0.022, metal))

func _process(dt: float) -> void:
 steering.basis = Geometry.steering_basis(bike.steer_angle)
 var front: Vector3 = Geometry.hub(0,bike.wheels[0].extension,0)
 hubs[0].position = front - Geometry.HEAD
 hubs[1].position = Geometry.hub(1,bike.wheels[1].extension,0)
 for i in range(2): wheel_nodes[i].rotate_x(-bike.wheels[i].omega * dt)
 for side in range(2):
  var x: float = -0.10 if side == 0 else 0.10
  var top := Vector3(x,0,0)
  var axle: Vector3 = front + Vector3(x,0,0) - Geometry.HEAD
  var direction: Vector3 = (axle-top).normalized()
  align_rod(upper_forks[side],top,top+direction*0.62)
  align_rod(lower_forks[side],axle,axle-direction*0.44)
  align_rod(limbs[side],Geometry.REAR_PIVOT+Vector3(x,0,0),hubs[1].position+Vector3(x,0,0))
 align_rod(shock,Vector3(0,0.16,0.40),Geometry.REAR_PIVOT.lerp(hubs[1].position,0.42))
