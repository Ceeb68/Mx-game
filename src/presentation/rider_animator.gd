extends Node3D
## Original glTF skin, driven through Skeleton3D with analytical two-bone IK.
## Presentation-only: no forces, mass changes, or chassis transforms are written here.
var bike: RigidBody3D
var skeleton: Skeleton3D
var model: Node3D
var bone_ids: Dictionary = {}
var rest: Dictionary = {}
var segment_lengths: Dictionary = {}
var hand_targets: Dictionary = {}
var foot_targets: Dictionary = {}
var joint_positions: Dictionary = {}
var posture: float = 1.0
var weight: float = 0.0
var lateral: float = 0.0
var compression: float = 0.0
var acceleration: float = 0.0
var limb_error: float = 0.0
var pose_ticks: int = 0

func _ready() -> void:
 model = load("res://assets/rider/terra_rider.glb").instantiate()
 add_child(model)
 for mesh in model.find_children("*", "MeshInstance3D", true, false): mesh.layers = 2
 skeleton = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
 for i in range(skeleton.get_bone_count()):
  var bone_name: String = skeleton.get_bone_name(i)
  bone_ids[bone_name] = i
  rest[bone_name] = skeleton.get_bone_global_rest(i)
 for suffix in ["L", "R"]:
  segment_lengths["arm_" + suffix] = Vector2(rest["upper_arm." + suffix].origin.distance_to(rest["forearm." + suffix].origin), rest["forearm." + suffix].origin.distance_to(rest["hand." + suffix].origin))
  segment_lengths["leg_" + suffix] = Vector2(rest["thigh." + suffix].origin.distance_to(rest["shin." + suffix].origin), rest["shin." + suffix].origin.distance_to(rest["foot." + suffix].origin))
 print("RIDER_RUNTIME original_skinned_gltf bones=", skeleton.get_bone_count(), " arm_lengths=", segment_lengths.arm_L, " leg_lengths=", segment_lengths.leg_L)

static func solve_two_bone(root: Vector3, target: Vector3, pole: Vector3, lengths: Vector2) -> Vector3:
 var direction: Vector3 = target - root
 var distance: float = clampf(direction.length(), absf(lengths.x - lengths.y) + 0.0001, lengths.x + lengths.y - 0.0001)
 direction = direction.normalized()
 var along: float = (lengths.x * lengths.x - lengths.y * lengths.y + distance * distance) / (2 * distance)
 var perpendicular: Vector3 = (pole - root).slide(direction).normalized()
 if perpendicular.length() < 0.1: perpendicular = direction.cross(Vector3.RIGHT).normalized()
 var height: float = sqrt(maxf(0, lengths.x * lengths.x - along * along))
 return root + direction * along + perpendicular * height

func set_bone(bone_name: String, origin: Vector3, end: Vector3) -> void:
 var local_origin: Vector3 = skeleton.to_local(bike.to_global(origin))
 var local_end: Vector3 = skeleton.to_local(bike.to_global(end))
 var reference: Transform3D = rest[bone_name]
 var rotation := Basis(Quaternion(reference.basis.y.normalized(), (local_end - local_origin).normalized()))
 skeleton.set_bone_global_pose(bone_ids[bone_name], Transform3D(rotation * reference.basis, local_origin))
 joint_positions[bone_name] = origin

func _process(dt: float) -> void:
 if not skeleton or not is_instance_valid(bike): return
 update_pose(dt)

func update_pose(dt: float) -> void:
 pose_ticks += 1
 var blend: float = 1 - exp(-dt * 6)
 posture = lerpf(posture, 1.0 if bike.command.stand else 0.0, blend)
 weight = lerpf(weight, bike.command.weight, blend)
 lateral = lerpf(lateral, bike.command.lean, blend)
 compression = lerpf(compression, clampf((bike.wheels[0].compression + bike.wheels[1].compression - 0.11) * 0.35, -0.025, 0.055), blend)
 acceleration = lerpf(acceleration, clampf(bike.longitudinal_acceleration / 9.81, -1, 1), blend)
 # Absorb load with knees and elbows; gradually change stance, not bone snapping.
 var hip := Vector3(lateral * 0.10, lerpf(0.44, 0.65, posture) - compression * posture, 0.20 - weight * 0.11 + acceleration * 0.025)
 # Keep the pelvis above the seat and within leg reach at combined input extremes.
 for suffix in ["L", "R"]:
  var side: float = -1 if suffix == "L" else 1
  var lengths: Vector2 = segment_lengths["leg_" + suffix]
  var horizontal := Vector2(side * 0.19 - hip.x - side * 0.105, 0.12 - hip.z)
  hip.y = minf(hip.y, sqrt(maxf(0.01, pow((lengths.x + lengths.y) * 0.985, 2) - horizontal.length_squared())) - 0.15)
 var angle: float = lerpf(0.48, 0.74, posture) + weight * 0.12 - acceleration * 0.05
 # Fit the torso within arm reach while retaining fixed human segment lengths.
 for i in range(36):
  var axis := Vector3(0, cos(angle), -sin(angle))
  var reachable: bool = true
  for suffix in ["L", "R"]:
   var side: float = -1 if suffix == "L" else 1
   var shoulder: Vector3 = hip + axis * 0.49 + Vector3(side * 0.20, 0, 0)
   var grip: Vector3 = grip_target(side) + Vector3(0, 0.025, 0.02)
   var lengths: Vector2 = segment_lengths["arm_" + suffix]
   if shoulder.distance_to(grip) > (lengths.x + lengths.y) * 0.965: reachable = false
  if reachable or angle >= 1.35: break
  angle += 0.025
 var torso_axis := Vector3(0, cos(angle), -sin(angle))
 set_bone("pelvis", hip, hip + torso_axis * 0.12)
 set_bone("spine", hip + torso_axis * 0.12, hip + torso_axis * 0.34)
 set_bone("chest", hip + torso_axis * 0.34, hip + torso_axis * 0.52)
 var neck: Vector3 = hip + torso_axis * 0.52
 set_bone("neck", neck, neck + Vector3(0, 0.09, -0.01))
 set_bone("head", neck + Vector3(0, 0.09, -0.01), neck + Vector3(lateral * 0.01, 0.29, -0.035))
 limb_error = 0
 for suffix in ["L", "R"]:
  var side: float = -1 if suffix == "L" else 1
  var shoulder: Vector3 = hip + torso_axis * 0.49 + Vector3(side * 0.20, 0, 0)
  var wrist: Vector3 = grip_target(side) + Vector3(0, 0.025, 0.02)
  hand_targets[suffix] = wrist
  var arm: Vector2 = segment_lengths["arm_" + suffix]
  var elbow: Vector3 = solve_two_bone(shoulder, wrist, shoulder + Vector3(side * 0.45, -0.10, 0.05), arm)
  set_bone("upper_arm." + suffix, shoulder, elbow)
  set_bone("forearm." + suffix, elbow, wrist)
  set_bone("hand." + suffix, wrist, wrist + Vector3(0, -0.06, -0.085))
  var hip_joint: Vector3 = hip + Vector3(side * 0.105, 0, 0)
  var ankle := Vector3(side * 0.19, -0.15, 0.12)
  foot_targets[suffix] = ankle
  var leg: Vector2 = segment_lengths["leg_" + suffix]
  var knee: Vector3 = solve_two_bone(hip_joint, ankle, hip_joint + Vector3(side * 0.25, -0.22, -0.45), leg)
  set_bone("thigh." + suffix, hip_joint, knee)
  set_bone("shin." + suffix, knee, ankle)
  set_bone("foot." + suffix, ankle, ankle + Vector3(0, -0.055, -0.18))
  limb_error = maxf(limb_error, absf(elbow.distance_to(wrist) - arm.y))
  limb_error = maxf(limb_error, absf(knee.distance_to(ankle) - leg.y))

func grip_target(side: float) -> Vector3:
 if bike.SIMULATION_VERSION == "MotorcycleSimulation/v2":
  return Vector3(0, 0.48, -0.55) + Vector3(side * 0.35, 0, 0).rotated(Vector3.UP, -bike.steer_angle)
 return preload("res://src/physics/replacement/geometry.gd").grip(side, bike.steer_angle)
