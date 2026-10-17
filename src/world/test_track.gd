extends Node3D
## One sampled heightfield supplies both visible triangles and physical collision.
var material: StandardMaterial3D

func surface_at(p: Vector3) -> Dictionary:
 if p.x < -40: return {"name": "sand", "mu": 0.65, "rolling": 0.065}
 if p.x < -12: return {"name": "loam", "mu": 0.85, "rolling": 0.035}
 return {"name": "hardpack", "mu": 0.98, "rolling": 0.018}

func ramp(z: float, start: float, rise: float, deck: float, fall: float, height: float) -> float:
 var distance: float = -z - start
 if distance < 0 or distance > rise + deck + fall: return 0
 if distance < rise:
  var t: float = distance / rise
  return height * t * t * (3 - 2 * t)
 if distance < rise + deck: return height
 var t: float = (distance - rise - deck) / fall
 return height * (1 - t * t * (3 - 2 * t))

func height_at(x: float, z: float) -> float:
 var height: float = 0
 var lane: float = 1 - smoothstep(6, 10, absf(x))
 height += lane * (ramp(z, 40, 8, 7, 11, 1.5) + ramp(z, 95, 12, 10, 16, 3.2))
 if x > 15 and x < 30 and z < -30 and z > -90:
  var fade: float = smoothstep(-30, -37, z) * smoothstep(-90, -83, z)
  height += fade * (0.16 + 0.16 * cos(z * TAU / 4))
 if x > 35 and x < 49 and z < -30 and z > -100:
  height += smoothstep(-30, -36, z) * smoothstep(-100, -94, z) * (0.38 + 0.38 * cos(z * TAU / 7))
 if x < -12 and x > -34 and z < -90:
  height += smoothstep(-90, -100, z) * (sin(x * 1.2 + z * 0.8) * 0.08 + sin(z * 2) * 0.05)
 var radial: float = Vector2(x - 78, z + 65).length()
 if radial > 22 and radial < 38:
  height += smoothstep(26, 36, radial) * (1 - smoothstep(36, 38, radial)) * 2.0
 return height

func _ready() -> void:
 name = "DevelopmentTrack"
 var vertices := PackedVector3Array()
 var colors := PackedColorArray()
 var normals := PackedVector3Array()
 var step: float = 1.5
 for ix in range(147):
  var x: float = -90 + ix * step
  for iz in range(187):
   var z: float = -220 + iz * step
   var a := Vector3(x, height_at(x, z), z)
   var b := Vector3(x + step, height_at(x + step, z), z)
   var c := Vector3(x, height_at(x, z + step), z + step)
   var d := Vector3(x + step, height_at(x + step, z + step), z + step)
   for tri in [[a, b, c], [b, d, c]]:
    var n: Vector3 = (tri[2] - tri[0]).cross(tri[1] - tri[0]).normalized()
    for p in tri:
     vertices.append(p)
     normals.append(n)
     var shade: float = 0.94 + 0.06 * sin(p.x * 4.1 + p.z * 7.3)
     var base := Color(0.36, 0.23, 0.13)
     if p.x < -40: base = Color(0.66, 0.52, 0.32)
     elif p.x < -12: base = Color(0.27, 0.18, 0.11)
     if absf(p.x) < 6: base = Color(0.46, 0.31, 0.18)
     colors.append(base * Color(shade, shade, shade))
 var arrays := []
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX] = vertices
 arrays[Mesh.ARRAY_NORMAL] = normals
 arrays[Mesh.ARRAY_COLOR] = colors
 var mesh := ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
 material = StandardMaterial3D.new()
 material.vertex_color_use_as_albedo = true
 material.roughness = 0.98
 mesh.surface_set_material(0, material)
 var visual := MeshInstance3D.new()
 visual.mesh = mesh
 add_child(visual)
 var ground := StaticBody3D.new()
 var collider := CollisionShape3D.new()
 var physical_faces := PackedVector3Array()
 for index in range(0, vertices.size(), 3):
  physical_faces.append(vertices[index])
  physical_faces.append(vertices[index + 1])
  physical_faces.append(vertices[index + 2])
 var terrain_shape := ConcavePolygonShape3D.new()
 terrain_shape.set_faces(physical_faces)
 terrain_shape.backface_collision = false
 collider.shape = terrain_shape
 ground.add_child(collider)
 add_child(ground)
 for z in range(20, -190, -10):
  marker(Vector3(-7, height_at(-7, z), z), Color(0.96, 0.43, 0.12))
  marker(Vector3(7, height_at(7, z), z), Color(0.96, 0.43, 0.12))
 for z in range(20, -190, -20):
  marker(Vector3(-36, 0, z), Color(0.8, 0.74, 0.52))
 sign_at("01  /  TABLETOPS", Vector3(0, 2.8, 5))
 sign_at("02  /  FLAT · LOAM", Vector3(-24, 2.8, 5))
 sign_at("03  /  BRAKING BUMPS", Vector3(22, 2.8, -20))
 sign_at("04  /  WHOOPS", Vector3(42, 2.8, -20))
 sign_at("05  /  SAND", Vector3(-53, 2.8, 5))
 sign_at("06  /  BERM", Vector3(77, 3.5, -25))
 sign_at("FLAT CORNERS / FREE PRACTICE", Vector3(40, 3.0, 30))

func marker(p: Vector3, color: Color) -> void:
 var visual := MeshInstance3D.new()
 var cone := CylinderMesh.new()
 cone.top_radius = 0.035
 cone.bottom_radius = 0.18
 cone.height = 0.55
 visual.mesh = cone
 var mat := StandardMaterial3D.new()
 mat.albedo_color = color
 visual.material_override = mat
 visual.position = p + Vector3.UP * 0.275
 add_child(visual)

func sign_at(text: String, p: Vector3) -> void:
 var label := Label3D.new()
 label.text = text
 label.font_size = 48
 label.pixel_size = 0.014
 label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
 label.modulate = Color(1.0, 0.87, 0.63)
 label.outline_modulate = Color(0.09, 0.08, 0.07)
 label.position = p
 add_child(label)
