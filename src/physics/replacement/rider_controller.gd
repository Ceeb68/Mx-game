extends RefCounted
## Contact-moment roll controller and inverse discrete tread model.
## Outputs a steering target only. No chassis attitude assignment or roll actuator.
var lean_request: float = 0
var steering_request: float = 0
var roll_integral: float = 0
var previous_roll_error: float = 0
var lean_request_rate: float = 0
var grounded: bool = true
var passive_roll_moment: float = 0
var front_roll_arm: float = -0.7
var front_slip_angle: float = 0
var front_grip: float = 0
var actual_steer: float = 0
var front_heading_gain: float = cos(deg_to_rad(27))
var desired_front_force: float = 0
var unconstrained_front_force: float = 0
var force_limited: bool = false
var controlled_force: float = 0
var front_tire: RefCounted
var front_longitudinal: float = 0
var front_inverse_mass: float = 0.04
func reset() -> void:
 lean_request = 0
 lean_request_rate = 0
 steering_request = 0
 roll_integral = 0
 previous_roll_error = 0
 unconstrained_front_force = 0
 force_limited = false
func step(dt: float, input: float, body_lean: float, speed: float, roll: float, roll_rate: float, mu: float, config: Dictionary) -> float:
 force_limited = false
 unconstrained_front_force = 0
 var tuning: Dictionary = config.handling.rider
 var v2: float = maxf(speed * speed, 1)
 var limit: float = minf(atan(mu * tuning.grip_lean_fraction), atan(v2 * tan(0.48) / (9.81 * config.wheelbase_m)))
 var target: float = input * minf(limit, deg_to_rad(tuning.max_lean_deg)) + body_lean * deg_to_rad(tuning.body_lean_deg)
 # Bound requested roll acceleration/lean rate to avoid saturating the front patch.
 var previous_request: float = lean_request
 lean_request = move_toward(lean_request,target,deg_to_rad(tuning.lean_rate_deg_s)*dt)
 lean_request_rate = (lean_request - previous_request) / dt
 if not grounded:
  steering_request = input * tuning.air_steer_rad
  roll_integral = 0
  previous_roll_error = 0
  desired_front_force = 0
  return steering_request
 var error: float = roll - lean_request
 # A crossed lean target invalidates the accumulated one-sided trim.
 # Keep PD balance and bounded integral gain; discard the stale correction.
 if error * previous_roll_error < 0: roll_integral = 0
 previous_roll_error = error
 if grounded and absf(speed)>2.2:
  roll_integral = clampf(roll_integral + error * dt * tuning.roll_ki, -tuning.integral_limit, tuning.integral_limit)
 else:
  roll_integral = 0
 # Follow a bounded fraction of target motion; retain damping of unexpected roll.
 var desired_acceleration: float = clampf(tuning.roll_kp * error + tuning.roll_kd * (roll_rate - lean_request_rate * tuning.target_rate_tracking) + roll_integral,-tuning.max_roll_acceleration_rad_s2,tuning.max_roll_acceleration_rad_s2)
 var equilibrium: float = atan(9.81 * tan(roll) * config.wheelbase_m / v2)
 var dynamic: float = config.wheelbase_m * 0.62 / v2 * desired_acceleration
 # Invert the active tread model against actual ground roll moments.
 # Unlike curvature feedforward, this remains meaningful during turn initiation.
 if grounded and front_grip > 20 and absf(front_roll_arm) > 0.2:
  unconstrained_front_force = (-config.inertia_kg_m2[2] * desired_acceleration - passive_roll_moment) / front_roll_arm
  desired_front_force = clampf(unconstrained_front_force, -front_grip, front_grip)
  force_limited = absf(unconstrained_front_force) > front_grip
  var gain: float=maxf(0.2,front_heading_gain)
  var tire_heading_change: float=front_tire.heading_for_force(dt,desired_front_force,front_longitudinal,front_tire.lateral_velocity,front_inverse_mass,(-tuning.max_steer_rad-actual_steer)*gain,(tuning.max_steer_rad-actual_steer)*gain)
  var low_speed_control: float=actual_steer+tire_heading_change/gain
  # Preserve the established faster-speed inverse. Apply the signed-vector
  # repair in the low-speed regime and fade continuously over the same
  # 2.2--3 m/s region used by the existing balance/support transitions.
  var desired_slip_angle: float=front_tire.lateral_angle_for_force(dt,desired_front_force,front_longitudinal,front_inverse_mass)
  var established_control: float=actual_steer+(front_slip_angle-desired_slip_angle)/gain
  var low_speed_weight: float=1-smoothstep(tuning.blend_end_m_s,3.0,absf(speed))
  controlled_force=lerpf(established_control,low_speed_control,low_speed_weight)
 else:
  controlled_force = equilibrium + dynamic
 var blend: float = smoothstep(tuning.blend_start_m_s, tuning.blend_end_m_s, absf(speed))
 steering_request = clampf(lerpf(input * tuning.low_speed_steer_rad, controlled_force, blend), -tuning.max_steer_rad, tuning.max_steer_rad)
 return steering_request
