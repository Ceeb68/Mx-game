extends RefCounted
## Input-to-steering controller only. Never changes chassis orientation or adds roll torque.
var lean_request: float = 0.0
var steering_request: float = 0.0
func reset() -> void:
 lean_request = 0
 steering_request = 0
func step(dt: float, input: float, body_lean: float, speed: float, roll: float, roll_rate: float, mu: float, config: Dictionary) -> float:
 var velocity: float = absf(speed)
 var geometric_limit: float = atan(velocity * velocity * tan(0.48) / (9.81 * config.wheelbase_m))
 var grip_limit: float = atan(mu * 0.82)
 var limit: float = minf(deg_to_rad(config.rider_max_lean_deg), minf(geometric_limit, grip_limit))
 var target: float = input * limit + body_lean * deg_to_rad(5)
 lean_request = move_toward(lean_request, target, deg_to_rad(config.rider_lean_rate_deg_s) * dt)
 var feedforward: float = atan(9.81 * tan(lean_request) * config.wheelbase_m / maxf(velocity * velocity, 4))
 # Steering-to-roll authority scales with v². Maintain bounded feedback
 # authority while accelerating, instead of leaving low speed open-loop.
 var gain_scale: float = clampf(pow(config.rider_reference_speed_m_s, 2) / maxf(velocity * velocity, 1), 0.1, config.rider_max_low_speed_gain)
 var controlled: float = feedforward + gain_scale * (config.rider_roll_gain * (roll - lean_request) + config.rider_roll_damping_s * roll_rate)
 var blend: float = smoothstep(config.rider_blend_start_m_s, config.rider_blend_end_m_s, velocity)
 var requested: float = lerpf(input * deg_to_rad(30), controlled, blend)
 steering_request = move_toward(steering_request, clampf(requested, -0.52, 0.52), config.rider_steering_rate_rad_s * dt)
 return steering_request
