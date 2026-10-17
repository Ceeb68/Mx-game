extends RigidBody3D
const SIMULATION_VERSION := "ReducedCoordinateMotorcycle/v3.2-steering"
const Rider = preload("res://src/physics/replacement/rider_controller.gd")
const Geometry = preload("res://src/physics/replacement/geometry.gd")
const Station = preload("res://src/physics/replacement/wheel_station.gd")
var stations: Array = [Station.new(0), Station.new(1)]
var previous_mount_velocity: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
const Tire = preload("res://src/physics/replacement/contact_tire.gd")
const Powertrain = preload("res://src/physics/powertrain.gd")
var virtual_rider = Rider.new()
var longitudinal_acceleration: float = 0.0
var previous_velocity: Vector3 = Vector3.ZERO
var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/250f.json"))
var wheels: Array = []
var engine: RefCounted
var command := {"throttle": 0.0, "front_brake": 0.0, "rear_brake": 0.0, "steer": 0.0, "lean": 0.0, "weight": 0.0, "clutch": 0.0, "stand": true}
var steering_assist: bool = true
var foot_support: bool = true
var steer_angle: float = 0.0
var steer_rate: float = 0.0
var steering_target: float = 0
var previous_steering_target: float = 0
var steering_target_rate: float = 0
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
var passive_roll_moment: float = 0
var front_roll_arm: float = -0.7
var reset_requested: bool = false
var reset_pose: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0, 1.0, 15))
var spawn_velocity: Vector3 = Vector3.ZERO
var track: Node3D
var rider_offset: Vector3 = Vector3.ZERO
var rider_velocity := Vector3.ZERO
var rider_momentum := Vector3.ZERO
var rider_reaction := Vector3.ZERO

func _ready() -> void:
 name = "ReducedCoordinateMotorcycle"
 mass = config.mass_kg - 16.0
 inertia = Vector3(config.inertia_kg_m2[0], config.inertia_kg_m2[1], config.inertia_kg_m2[2])
 center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
 linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
 angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
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
 for i in range(2): wheels[i].configure(config, i)
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
  for station in stations: station.reset()
  previous_mount_velocity = [spawn_velocity, spawn_velocity]
  engine.reset()
  virtual_rider.reset()
  previous_velocity = spawn_velocity
  longitudinal_acceleration = 0
  steer_angle = 0.0
  steer_rate = 0.0
  steering_target = 0
  previous_steering_target = 0
  steering_target_rate = 0
  rider_offset = Vector3.ZERO
  rider_velocity = Vector3.ZERO
  rider_momentum = Vector3.ZERO
  rider_reaction = Vector3.ZERO
  passive_roll_moment = 0
  front_roll_arm = -0.7
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
 virtual_rider.grounded = wheels[0].grounded or wheels[1].grounded
 virtual_rider.passive_roll_moment = passive_roll_moment
 virtual_rider.front_roll_arm = front_roll_arm
 virtual_rider.front_tire = wheels[0]
 virtual_rider.front_slip_angle = wheels[0].slip_angle
 var front_mu: float = track.surface_at(wheels[0].point).mu if track else 0.95
 virtual_rider.front_grip = sqrt(maxf(0,pow(front_mu*wheels[0].load,2)-pow(wheels[0].force.x,2)))
 virtual_rider.actual_steer = steer_angle
 virtual_rider.front_heading_gain = Geometry.heading_per_steer(basis, wheels[0].normal, steer_angle)
 if steering_assist:
  var surface_mu: float = track.surface_at(state.transform.origin).mu if track else 0.95
  desired_steer = virtual_rider.step(dt, command.steer, command.lean, speed, lean_angle, roll_rate, surface_mu, config)
 longitudinal_acceleration = lerpf(longitudinal_acceleration, (state.linear_velocity - previous_velocity).dot(forward) / dt, 1 - exp(-dt * 6))
 previous_velocity = state.linear_velocity
 desired_steer = clampf(desired_steer, -config.handling.rider.max_steer_rad, config.handling.rider.max_steer_rad)
 steering_target = desired_steer
 # Finite steering DOF: passive trail plus bounded rider torque, implicit damping.
 var actuator: Dictionary = config.handling.steering
 var trail_torque: float = -wheels[0].force.y * config.trail_m * actuator.trail_gain
 # Velocity feedforward makes the existing damped actuator track moving targets.
 # Bound/filter the derivative estimate; hand torque remains limited to 30 Nm.
 var target_rate: float = clampf((desired_steer - previous_steering_target) / dt, -actuator.target_rate_limit_rad_s, actuator.target_rate_limit_rad_s)
 steering_target_rate = lerpf(steering_target_rate, target_rate, 1-exp(-actuator.target_rate_filter_per_s*dt))
 previous_steering_target = desired_steer
 var old_steer_rate: float = steer_rate
 var stiffness: float = actuator.stiffness_nm_rad
 var damping: float = 2.0 * actuator.damping_ratio * sqrt(stiffness * config.steer_inertia_kg_m2)
 steering_torque = clampf((desired_steer - steer_angle) * stiffness + damping * steering_target_rate - trail_torque, -actuator.max_torque_nm, actuator.max_torque_nm)
 steer_rate = (steer_rate + dt * (steering_torque + trail_torque) / config.steer_inertia_kg_m2) / (1 + dt * damping / config.steer_inertia_kg_m2)
 var old_steer: float = steer_angle
 steer_angle = clampf(steer_angle + steer_rate * dt, -actuator.stop_rad, actuator.stop_rad)
 if absf(steer_angle) >= actuator.stop_rad: steer_rate = 0
 # Internal steering angular momentum reaction, including wheel gyro precession.
 var steering_axis: Vector3 = basis * Geometry.axis(0, steer_angle)
 state.apply_torque(steering_axis * config.steer_inertia_kg_m2 * (steer_rate - old_steer_rate) / dt)
 var old_axle: Vector3 = basis * (Geometry.steering_basis(old_steer) * Vector3.RIGHT)
 var new_axle: Vector3 = basis * (Geometry.steering_basis(steer_angle) * Vector3.RIGHT)
 state.apply_torque((new_axle - old_axle) * wheels[0].omega * wheels[0].inertia / dt)
 # A finite rider mass shifts combined COM. No artificial airborne attitude torque.
 var target_offset := Vector3(command.lean * 0.18, 0.06 if command.stand else -0.04, -command.weight * 0.22)
 # Acceleration-limited rider carriage stores relative angular momentum.
 var rider_acceleration: Vector3 = ((target_offset - rider_offset) * 25 - rider_velocity * 10).limit_length(1.2)
 rider_velocity += rider_acceleration * dt
 rider_offset += rider_velocity * dt
 var next_momentum: Vector3 = Vector3(rider_offset.x, 0.65 + rider_offset.y, rider_offset.z).cross(rider_velocity) * config.rider_mass_kg
 rider_reaction = -(next_momentum - rider_momentum) / dt
 state.apply_torque(basis * rider_reaction)
 rider_momentum = next_momentum
 center_of_mass = rider_offset * (config.rider_mass_kg / mass)
 var drive: float = engine.step(dt, command.throttle if not crashed else 0.0, command.clutch, wheels[1].omega)
 force_total = Vector3.ZERO
 passive_roll_moment = (basis * rider_reaction).dot(forward)
 var contacts: int = 0
 for i in range(2):
  var wheel = wheels[i]
  var station = stations[i]
  var axis: Vector3 = basis * Geometry.axis(i, steer_angle, wheel.extension)
  var rest_hub: Vector3 = state.transform * Geometry.hub(i, wheel.extension, steer_angle)
  var origin: Vector3 = rest_hub + axis * wheel.extension
  var tire_forward: Vector3 = basis * (Geometry.steering_basis(steer_angle) * Vector3.FORWARD if i == 0 else Vector3.FORWARD)
  var hit: Dictionary = sample_patch(state.get_space_state(), origin, axis, tire_forward, wheel)
  var has_road: bool = not hit.is_empty() and axis.dot(hit.get("normal", Vector3.UP)) > 0.25
  var normal: Vector3 = hit.normal if has_road else Vector3.UP
  var mount_offset: Vector3 = origin - state.transform.origin - basis * center_of_mass
  var mount_velocity: Vector3 = state.linear_velocity + state.angular_velocity.cross(mount_offset)
  var mount_accel_vector: Vector3 = ((mount_velocity - previous_mount_velocity[i]) / dt).limit_length(150)
  var mount_accel: float = mount_accel_vector.dot(axis)
  previous_mount_velocity[i] = mount_velocity
  var contact_axle: Vector3 = basis * (Geometry.steering_basis(steer_angle) * Vector3.RIGHT if i == 0 else Vector3.RIGHT)
  var support_radius: float = wheel.radius * sqrt(maxf(0.01,1-pow(contact_axle.dot(normal),2))) / maxf(axis.dot(normal),0.25)
  var road_compression: float = station.compression + wheel.extension + support_radius - float(hit.distance) if has_road else -1.0
  # Four implicit wheel substeps within each 240 Hz chassis step.
  for sub in range(4):
   station.step(dt / 4, road_compression, -mount_velocity.dot(normal), axis.dot(normal), mount_accel, config, has_road, axis.dot(Vector3.UP))
  wheel.extension = Geometry.REST - station.compression
  wheel.compression = station.compression
  wheel.load = station.load
  wheel.grounded = has_road and wheel.load > 1
  var hub_local: Vector3 = Geometry.hub(i, wheel.extension, steer_angle)
  var hub_world: Vector3 = state.transform * hub_local
  var axle: Vector3 = basis * (Geometry.steering_basis(steer_angle) * Vector3.RIGHT if i == 0 else Vector3.RIGHT)
  # Round tire contact includes lean/camber geometry, rather than a chassis-down point.
  var radial: Vector3 = (-normal).slide(axle).normalized()
  wheel.point = hub_world + radial * wheel.radius
  var offset: Vector3 = wheel.point - state.transform.origin
  var velocity: Vector3 = state.linear_velocity + state.angular_velocity.cross(offset - basis * center_of_mass)
  var suspension_reaction: Vector3 = axis * station.spring_force
  # The guide transmits forces transverse to travel; spring transmits axial load.
  var wheel_gravity: Vector3 = Vector3.DOWN * station.unsprung_mass * 9.81
  var normal_reaction: Vector3 = suspension_reaction + normal * wheel.load - axis * wheel.load * normal.dot(axis) + (wheel_gravity - station.unsprung_mass * mount_accel_vector).slide(axis)
  state.apply_force(normal * wheel.load, offset)
  state.apply_force(normal_reaction - normal * wheel.load, hub_world - state.transform.origin)
  force_total += normal_reaction
  passive_roll_moment += (offset-basis*center_of_mass).cross(normal*wheel.load).dot(forward)
  passive_roll_moment += (hub_world-state.transform.origin-basis*center_of_mass).cross(normal_reaction-normal*wheel.load).dot(forward)
  var brake: float = command.front_brake * config.brake_nm[0] if i == 0 else command.rear_brake * config.brake_nm[1]
  if wheel.grounded:
   contacts += 1
   wheel.normal = normal
   tire_forward = tire_forward.slide(normal).normalized()
   var right: Vector3 = tire_forward.cross(normal).normalized()
   var surface: Dictionary = track.surface_at(wheel.point) if track else {"name":"hardpack", "mu":0.95, "rolling":0.018}
   wheel.surface = surface.name
   var arm: Vector3 = offset - basis * center_of_mass
   var long_arm: Vector3 = arm.cross(tire_forward)
   var lat_arm: Vector3 = arm.cross(right)
   var effective := Vector2(state.inverse_mass + long_arm.dot(state.inverse_inertia_tensor * long_arm), state.inverse_mass + lat_arm.dot(state.inverse_inertia_tensor * lat_arm))
   if i == 0:
    virtual_rider.front_longitudinal = velocity.dot(tire_forward)
    virtual_rider.front_inverse_mass = effective.y
   var tire_force: Vector2 = wheel.forces(dt, velocity.dot(tire_forward), velocity.dot(right), surface.mu, 0, drive if i == 1 else 0, brake, effective)
   var rolling: float = -tanh(velocity.dot(tire_forward) * 2) * wheel.load * surface.rolling
   var tangential: Vector3 = tire_forward * (tire_force.x + rolling) + right * tire_force.y
   wheel.applied_force = tangential
   state.apply_force(tangential, offset)
   force_total += tangential
   if i == 0:
    front_roll_arm = arm.cross(right).dot(forward)
    passive_roll_moment += arm.cross(tire_forward*(tire_force.x+rolling)).dot(forward)
   else:
    passive_roll_moment += arm.cross(tangential).dot(forward)
  else:
   wheel.detach()
   wheel.surface = "air"
  var previous_omega: float = wheel.omega
  wheel.spin(dt, drive if i == 1 else 0, brake)
  state.apply_torque(axle * wheel.inertia * (wheel.omega - previous_omega) / dt)
  var gyro: Vector3 = state.angular_velocity.cross(axle * wheel.omega * wheel.inertia)
  state.apply_torque(gyro)
  passive_roll_moment += gyro.dot(forward)
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

func sample_patch(space: PhysicsDirectSpaceState3D, origin: Vector3, up: Vector3, forward: Vector3, wheel: RefCounted) -> Dictionary:
 var total: float = 0
 var point_sum := Vector3.ZERO
 var normal_sum := Vector3.ZERO
 var distance_sum: float = 0
 wheel.contact_samples = 0
 for n in [-1, 0, 1]:
  var along: float = n * config.contact_half_patch_m
  var curvature: float = wheel.radius - sqrt(wheel.radius * wheel.radius - along * along)
  var start: Vector3 = origin + forward * along
  var query := PhysicsRayQueryParameters3D.create(start, start - up * (config.suspension_rest_m + wheel.radius + 0.08 - curvature), 1, [get_rid()])
  var hit: Dictionary = space.intersect_ray(query)
  if hit.is_empty(): continue
  var weight: float = 2.0 if n == 0 else 1.0
  total += weight
  wheel.contact_samples += 1
  point_sum += hit.position * weight
  normal_sum += hit.normal * weight
  distance_sum += (start.distance_to(hit.position) + curvature) * weight
 if total == 0: return {}
 return {"position": point_sum / total, "normal": normal_sum.normalized(), "distance": distance_sum / total}

func telemetry() -> Dictionary:
 return {"engine": "Godot Physics", "sprung_mass_kg": mass, "total_mass_kg": mass + 16, "architecture": "unsprung DOFs + compliant bristle contact", "controller": SIMULATION_VERSION, "steer_input":command.steer, "steer_target_deg":rad_to_deg(steering_target), "roll_rate_rad_s": angular_velocity.dot(-global_basis.z), "yaw_rate_rad_s": angular_velocity.y, "lean_request_rate_rad_s": virtual_rider.lean_request_rate, "front_slip_angle_deg": rad_to_deg(wheels[0].slip_angle), "rear_slip_angle_deg": rad_to_deg(wheels[1].slip_angle), "front_suspension_velocity_m_s": stations[0].velocity, "rear_suspension_velocity_m_s": stations[1].velocity, "heading_per_steer":virtual_rider.front_heading_gain, "steer_target_rate":steering_target_rate, "steer_actual_rate":steer_rate, "hand_torque_nm":steering_torque, "front_lateral_m_s":wheels[0].lateral_velocity, "rear_lateral_m_s":wheels[1].lateral_velocity, "front_grip_use":wheels[0].utilization, "rear_grip_use":wheels[1].utilization, "front_fx_n":wheels[0].force.x, "front_fy_n":wheels[0].force.y, "rear_fx_n":wheels[1].force.x, "rear_fy_n":wheels[1].force.y, "front_world_force": [wheels[0].applied_force.x,wheels[0].applied_force.y,wheels[0].applied_force.z], "rear_world_force":[wheels[1].applied_force.x,wheels[1].applied_force.y,wheels[1].applied_force.z], "requested_front_fy_n":virtual_rider.desired_front_force, "front_force_limited":virtual_rider.force_limited, "roll_integral":virtual_rider.roll_integral, "target_lean_deg": rad_to_deg(virtual_rider.lean_request), "front_contact_samples": wheels[0].contact_samples, "rear_contact_samples": wheels[1].contact_samples, "ticks": simulation_ticks, "speed_m_s": linear_velocity.length(), "rpm": engine.rpm, "gear": engine.gear, "lean_deg": rad_to_deg(lean_angle), "steer_deg": rad_to_deg(steer_angle), "front_load_n": wheels[0].load, "rear_load_n": wheels[1].load, "front_slip": wheels[0].slip, "rear_slip": wheels[1].slip, "front_compression_m": wheels[0].compression, "rear_compression_m": wheels[1].compression, "crashed": crashed, "last_crash": last_crash}
