extends RigidBody3D
const Suspension = preload("res://src/physics/suspension.gd")
const Tire = preload("res://src/physics/tire.gd")
const Powertrain = preload("res://src/physics/powertrain.gd")
var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/250f.json"))
var wheels: Array = []
var engine: RefCounted
var command := {"throttle": 0.0, "front_brake": 0.0, "rear_brake": 0.0, "steer": 0.0, "lean": 0.0, "weight": 0.0, "clutch": 0.0, "stand": true}
var steering_assist: bool = true
var foot_support: bool = true
var steer_angle: float = 0.0
var steer_rate: float = 0.0
var lean_angle: float = 0.0
var last_crash: String = "none"
var crashed: bool = false
var crash_time: float = 0.0
var simulation_ticks: int = 0
var airborne_time: float = 0.0
var last_dt: float = 0.0
var support_torque: float = 0.0
var steering_torque: float = 0.0
var force_total: Vector3 = Vector3.ZERO
var reset_requested: bool = false
var reset_pose: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0, 1.0, 15))
var spawn_velocity: Vector3 = Vector3.ZERO
var track: Node3D
var rider_offset: Vector3 = Vector3.ZERO

func _ready() -> void:
 name = "MotorcycleSimulation"
 mass = config.mass_kg
 inertia = Vector3(config.inertia_kg_m2[0], config.inertia_kg_m2[1], config.inertia_kg_m2[2])
 center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
 linear_damp = 0.0
 angular_damp = 0.0
 can_sleep = false
 continuous_cd = true
 contact_monitor = true
 max_contacts_reported = 8
 physics_material_override = PhysicsMaterial.new()
 physics_material_override.friction = 0.45
 physics_material_override.bounce = 0.0
 var collider := CollisionShape3D.new()
 var shape := BoxShape3D.new()
 shape.size = Vector3(0.28, 0.36, 1.20)
 collider.shape = shape
 add_child(collider)
 wheels = [Tire.new(config.front_radius_m, config.wheel_inertia_kg_m2[0]), Tire.new(config.rear_radius_m, config.wheel_inertia_kg_m2[1])]
 engine = Powertrain.new(config)

func reset_at(pose: Transform3D, velocity: Vector3 = Vector3.ZERO) -> void:
 reset_pose = pose
 spawn_velocity = velocity
 reset_requested = true

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
 var dt: float = state.step
 last_dt = dt
 simulation_ticks += 1
 if reset_requested:
  state.transform = reset_pose
  state.linear_velocity = spawn_velocity
  state.angular_velocity = Vector3.ZERO
  for wheel in wheels: wheel.reset()
  engine.reset()
  steer_angle = 0.0
  steer_rate = 0.0
  rider_offset = Vector3.ZERO
  center_of_mass = Vector3.ZERO
  airborne_time = 0.0
  crash_time = 0.0
  crashed = false
  last_crash = "none"
  reset_requested = false
  return
 var basis: Basis = state.transform.basis
 var forward: Vector3 = -basis.z
 var up: Vector3 = basis.y
 var speed: float = state.linear_velocity.dot(forward)
 # Lean measured about heading, including corners with arbitrary world yaw.
 lean_angle = atan2(basis.x.dot(Vector3.DOWN), up.dot(Vector3.UP))
 var roll_rate: float = state.angular_velocity.dot(forward)
 var desired_steer: float = command.steer * deg_to_rad(32)
 if steering_assist and absf(speed) > 2.5:
  var target_lean: float = command.steer * deg_to_rad(37) + command.lean * deg_to_rad(8)
  var feedforward: float = atan(9.81 * tan(target_lean) * config.wheelbase_m / maxf(speed * speed, 9))
  desired_steer = feedforward + 0.85 * (lean_angle - target_lean) + 0.22 * roll_rate
 desired_steer = clampf(desired_steer, -0.56, 0.56)
 # Explicit steering inertia/servo + trail aligning moment; never sets chassis rotation.
 var trail_torque: float = -wheels[0].force.y * config.trail_m * cos(deg_to_rad(config.rake_deg))
 steering_torque = clampf((desired_steer - steer_angle) * config.steer_servo_nm_rad - steer_rate * config.steer_damping_nm_s + trail_torque * 0.12, -22, 22)
 steer_rate += steering_torque / config.steer_inertia_kg_m2 * dt
 steer_angle = clampf(steer_angle + steer_rate * dt, -0.58, 0.58)
 if absf(steer_angle) >= 0.58: steer_rate = 0.0
 # A finite rider mass shifts combined COM. No artificial airborne attitude torque.
 var target_offset := Vector3(command.lean * 0.18, 0.06 if command.stand else -0.04, -command.weight * 0.22)
 rider_offset = rider_offset.lerp(target_offset, 1 - exp(-dt * 7))
 center_of_mass = rider_offset * (config.rider_mass_kg / mass)
 var drive: float = engine.step(dt, command.throttle if not crashed else 0.0, command.clutch, wheels[1].omega)
 force_total = Vector3.ZERO
 var contacts: int = 0
 for i in range(2):
  var wheel = wheels[i]
  var mount := Vector3(0, -0.02, -config.wheelbase_m * 0.5 if i == 0 else config.wheelbase_m * 0.5)
  var origin: Vector3 = state.transform * mount
  var query := PhysicsRayQueryParameters3D.create(origin, origin - up * (config.suspension_rest_m + wheel.radius), 1, [get_rid()])
  var hit: Dictionary = state.get_space_state().intersect_ray(query)
  wheel.grounded = not hit.is_empty() and up.dot(hit.get("normal", Vector3.UP)) > 0.2
  wheel.load = 0.0
  if wheel.grounded:
   contacts += 1
   var normal: Vector3 = hit.normal
   wheel.point = hit.position
   var offset: Vector3 = hit.position - state.transform.origin
   var velocity: Vector3 = state.linear_velocity + state.angular_velocity.cross(offset - basis * center_of_mass)
   wheel.extension = clampf(origin.distance_to(hit.position) - wheel.radius, 0, config.suspension_rest_m)
   wheel.compression = config.suspension_rest_m - wheel.extension
   var compression_speed: float = -velocity.dot(normal) / maxf(up.dot(normal), 0.3)
   wheel.load = Suspension.normal_load(config, i, wheel.compression, compression_speed)
   var tire_forward: Vector3 = forward.rotated(up, -steer_angle if i == 0 else 0.0)
   tire_forward = tire_forward.slide(normal).normalized()
   var right: Vector3 = tire_forward.cross(normal).normalized()
   var surface: Dictionary = track.surface_at(hit.position) if track else {"name": "hardpack", "mu": 0.95, "rolling": 0.018}
   wheel.surface = surface.name
   var tire_force: Vector2 = wheel.forces(dt, velocity.dot(tire_forward), velocity.dot(right), surface.mu, config.tire_relaxation_s)
   var rolling: float = -tanh(velocity.dot(tire_forward) * 2.0) * wheel.load * surface.rolling
   var applied: Vector3 = normal * wheel.load + tire_forward * (tire_force.x + rolling) + right * tire_force.y
   state.apply_force(applied, offset)
   force_total += applied
  else:
   wheel.extension = config.suspension_rest_m
   wheel.compression = 0.0
   wheel.force = Vector2.ZERO
   wheel.slip = 0.0
   wheel.slip_angle = 0.0
   wheel.surface = "air"
  var brake: float = command.front_brake * config.brake_nm[0] if i == 0 else command.rear_brake * config.brake_nm[1]
  var torque: float = drive if i == 1 else 0.0
  var previous_omega: float = wheel.omega
  wheel.spin(dt, torque, brake)
  # Ground force is applied at contact, so it already contains the contact
  # moment of the whole assembly. Subtract ONLY the change in separately stored
  # wheel angular momentum; adding drive torque alone would double-count Fx*r.
  var axle: Vector3 = basis.x.rotated(up, -steer_angle if i == 0 else 0.0)
  state.apply_torque(axle * wheel.inertia * (wheel.omega - previous_omega) / dt)
  state.apply_torque(state.angular_velocity.cross(axle * wheel.omega * wheel.inertia))
 airborne_time = airborne_time + dt if contacts == 0 else 0.0
 # Visible optional foot-down support, grounded and low speed only. No airborne stabilizer.
 support_torque = 0.0
 if foot_support and contacts > 0 and absf(speed) < 3.0 and not crashed:
  support_torque = clampf(-lean_angle * 700 - roll_rate * 85, -config.foot_support_max_nm, config.foot_support_max_nm) * clampf((3.0 - absf(speed)) / 1.0, 0, 1)
  state.apply_torque(forward * support_torque)
 var airflow: Vector3 = state.linear_velocity
 state.apply_central_force(-airflow * airflow.length() * 0.34)
 # Persistent chassis contact / prolonged unrecoverable lean, never tire-slip threshold.
 var severe: bool = (up.dot(Vector3.UP) < 0.24 and contacts > 0) or (state.get_contact_count() > 0 and (up.dot(Vector3.UP) < 0.45 or state.linear_velocity.length() > 3))
 crash_time = crash_time + dt if severe else maxf(0, crash_time - dt * 2)
 if crash_time > 0.22 and not crashed:
  crashed = true
  last_crash = "persistent chassis impact" if state.get_contact_count() > 0 else "grounded lean beyond recovery"
 if state.transform.origin.y < -20:
  crashed = true
  last_crash = "outside test terrain; press R"

func telemetry() -> Dictionary:
 return {"controller": "MotorcycleSimulation/v1", "ticks": simulation_ticks, "speed_m_s": linear_velocity.length(), "rpm": engine.rpm, "gear": engine.gear, "lean_deg": rad_to_deg(lean_angle), "steer_deg": rad_to_deg(steer_angle), "front_load_n": wheels[0].load, "rear_load_n": wheels[1].load, "front_slip": wheels[0].slip, "rear_slip": wheels[1].slip, "front_compression_m": wheels[0].compression, "rear_compression_m": wheels[1].compression, "crashed": crashed, "last_crash": last_crash}
