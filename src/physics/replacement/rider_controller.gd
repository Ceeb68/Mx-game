extends RefCounted
## Contact-moment roll controller and inverse discrete tread model.
## Outputs a steering target only. No chassis attitude assignment or roll actuator.
var lean_request: float = 0
var steering_request: float = 0
var roll_integral: float = 0
var grounded: bool = true
var passive_roll_moment: float = 0
var front_roll_arm: float = -0.7
var front_slip_angle: float = 0
var front_grip: float = 0
var actual_steer: float = 0
var desired_front_force: float = 0
var controlled_force: float = 0
var front_tire: RefCounted
var front_longitudinal: float = 0
var front_inverse_mass: float = 0.04
func reset() -> void:
 lean_request = 0
 steering_request = 0
 roll_integral = 0
func step(dt: float, input: float, body_lean: float, speed: float, roll: float, roll_rate: float, mu: float, config: Dictionary) -> float:
 var v2: float = maxf(speed * speed, 1)
 var limit: float = minf(atan(mu * 0.55), atan(v2 * tan(0.48) / (9.81 * config.wheelbase_m)))
 var target: float = input * minf(limit, deg_to_rad(40)) + body_lean * deg_to_rad(5)
 # Bound requested roll acceleration/lean rate to avoid saturating the front patch.
 lean_request = move_toward(lean_request,target,deg_to_rad(100)*dt)
 if not grounded:
  steering_request = input * 0.30
  roll_integral = 0
  desired_front_force = 0
  return steering_request
 var error: float = roll - lean_request
 if grounded and absf(speed)>2.2:
  roll_integral = clampf(roll_integral + error * dt * 6, -3, 3)
 else:
  roll_integral = 0
 var desired_acceleration: float = clampf(10.24 * error + 8.32 * roll_rate + roll_integral,-20,20)
 var equilibrium: float = atan(9.81 * tan(roll) * config.wheelbase_m / v2)
 var dynamic: float = config.wheelbase_m * 0.62 / v2 * desired_acceleration
 # Invert the active tread model against actual ground roll moments.
 # Unlike curvature feedforward, this remains meaningful during turn initiation.
 if grounded and front_grip > 20 and absf(front_roll_arm) > 0.2:
  desired_front_force = clampf((-config.inertia_kg_m2[2] * desired_acceleration - passive_roll_moment) / front_roll_arm, -front_grip, front_grip)
  var desired_slip_angle: float = front_tire.lateral_angle_for_force(dt,desired_front_force,front_longitudinal,front_inverse_mass)
  var tire_heading_change: float = front_slip_angle - desired_slip_angle
  controlled_force = actual_steer + tire_heading_change * maxf(0.3,cos(roll)) / cos(deg_to_rad(config.rake_deg))
 else:
  controlled_force = equilibrium + dynamic
 var blend: float = smoothstep(0.4, 2.2, absf(speed))
 steering_request = clampf(lerpf(input * 0.52, controlled_force, blend), -0.56, 0.56)
 return steering_request
