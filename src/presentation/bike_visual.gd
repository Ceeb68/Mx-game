extends Node3D
## Original procedural engineering proxy; no third-party motorcycle assets.
var bike: RigidBody3D
var wheel_nodes: Array[Node3D] = []
var hubs: Array[Node3D] = []
var torso: Node3D
var head: Node3D
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
 box(Vector3(0.25, 0.05, 0.6), Vector3(0, 0.12, -0.92), red)
 box(Vector3(0.23, 0.25, 0.045), Vector3(0, 0.30, -0.66), white)
 for x in [-0.13, 0.13]:
  rod(Vector3(x, -0.22, 0.3), Vector3(x, 0.32, -0.4), 0.025, metal)
  rod(Vector3(x, -0.22, 0.3), Vector3(x, -0.10, -0.35), 0.025, metal)
 rod(Vector3(0.18, 0.1, 0.48), Vector3(0.18, 0.13, 0.86), 0.065, metal)
 rod(Vector3(-0.4, 0.48, -0.55), Vector3(0.4, 0.48, -0.55), 0.025, metal)
 for i in range(2):
  var hub := Node3D.new()
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
 torso = box(Vector3(0.37, 0.42, 0.21), Vector3(0, 0.84, 0.05), mat(Color(0.14, 0.22, 0.25)))
 var helmet := SphereMesh.new()
 helmet.radius = 0.135
 helmet.height = 0.29
 head = instance(helmet, Vector3(0, 1.16, -0.08), white)
 box(Vector3(0.23, 0.075, 0.07), Vector3(0, 1.17, -0.20), black)
 for i in range(8): limbs.append(rod(Vector3.ZERO, Vector3.UP, 0.045, black if i < 4 else white))
 # Animated fork/swingarm rods are updated from actual spring extension.
 for i in range(4): limbs.append(rod(Vector3.ZERO, Vector3.UP, 0.022, metal))

func _process(_dt: float) -> void:
 for i in range(2):
  hubs[i].position = Vector3(0, -0.02 - bike.wheels[i].extension, -0.74 if i == 0 else 0.74)
  hubs[i].rotation.y = -bike.steer_angle if i == 0 else 0.0
  wheel_nodes[i].rotate_x(-bike.wheels[i].omega * _dt)
 var hip: Vector3 = Vector3(0, 0.62 if bike.command.stand else 0.42, 0.17) + bike.rider_offset
 var shoulder: Vector3 = hip + Vector3(0, 0.38, -0.16)
 torso.position = (hip + shoulder) * 0.5
 torso.rotation.x = -0.25
 head.position = shoulder + Vector3(0, 0.21, -0.08)
 for side in range(2):
  var x: float = -1.0 if side == 0 else 1.0
  var hand: Vector3 = Vector3(x * 0.35, 0.48, -0.55).rotated(Vector3.UP, -bike.steer_angle)
  var elbow: Vector3 = shoulder + Vector3(x * 0.29, -0.06, -0.09)
  align_rod(limbs[side * 2], shoulder + Vector3(x * 0.17, 0, 0), elbow)
  align_rod(limbs[side * 2 + 1], elbow, hand)
  var knee: Vector3 = hip + Vector3(x * 0.18, -0.26, -0.17)
  align_rod(limbs[4 + side * 2], hip + Vector3(x * 0.12, 0, 0), knee)
  align_rod(limbs[5 + side * 2], knee, Vector3(x * 0.20, -0.25, 0.12))
  align_rod(limbs[8 + side], Vector3(x * 0.10, 0.40, -0.50), hubs[0].position + Vector3(x * 0.10, 0, 0))
  align_rod(limbs[10 + side], Vector3(x * 0.11, -0.17, 0.15), hubs[1].position + Vector3(x * 0.11, 0, 0))
