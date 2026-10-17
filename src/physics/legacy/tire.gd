extends RefCounted
## Combined brush law with distance-based relaxation and implicit wheel/contact coupling.
## Tire coefficients remain estimates, exposed in 250f.json for calibration.
var omega: float = 0.0
var load: float = 0.0
var compression: float = 0.0
var slip: float = 0.0
var slip_angle: float = 0.0
var force: Vector2 = Vector2.ZERO
var grounded: bool = false
var extension: float = 0.43
var point: Vector3 = Vector3.ZERO
var surface: String = "air"
var radius: float
var inertia: float
var normal: Vector3 = Vector3.UP
var contact_samples: int = 0
var utilization: float = 0.0
var longitudinal_stiffness: float = 12.0
var lateral_stiffness: float = 15.0
var relaxation_length: float = 0.12
var sliding_ratio: float = 0.87

func _init(wheel_radius: float, wheel_inertia: float) -> void:
 radius = wheel_radius
 inertia = wheel_inertia

func configure(data: Dictionary, index: int) -> void:
 longitudinal_stiffness = data.tire_longitudinal_stiffness
 lateral_stiffness = data.tire_lateral_stiffness[index]
 relaxation_length = data.tire_relaxation_length_m
 sliding_ratio = data.tire_sliding_ratio

func reset() -> void:
 omega = 0.0
 load = 0.0
 compression = 0.0
 slip = 0.0
 slip_angle = 0.0
 force = Vector2.ZERO
 grounded = false
 extension = 0.43
 surface = "air"
 normal = Vector3.UP
 contact_samples = 0
 utilization = 0.0

func forces(dt: float, longitudinal: float, lateral: float, mu: float, _legacy_relaxation: float, drive: float = 0.0, brake: float = 0.0, inverse_effective_mass: Vector2 = Vector2(0.01, 0.01)) -> Vector2:
 var reference: float = maxf(absf(longitudinal), 1.0)
 slip = (omega * radius - longitudinal) / reference
 slip_angle = atan2(lateral, maxf(absf(longitudinal), 0.5))
 var cx: float = longitudinal_stiffness * load / reference
 var cy: float = lateral_stiffness * load / reference
 # Predict free wheel speed, then solve the force-induced relative speed change.
 # This prevents increased tire stiffness from making light wheels chatter at 240 Hz.
 var free_omega: float = move_toward(omega + (drive - omega * 0.015) / inertia * dt, 0, brake / inertia * dt)
 var fx: float = cx * (free_omega * radius - longitudinal) / (1 + cx * dt * (radius * radius / inertia + inverse_effective_mass.x))
 var fy: float = -cy * lateral / (1 + cy * dt * inverse_effective_mass.y)
 var limit: float = maxf(load * mu, 0.0001)
 var demand := Vector2(fx, fy)
 var normalized_demand: float = demand.length() / limit
 var sliding_mu: float = lerpf(1, sliding_ratio, smoothstep(2.0, 5.0, normalized_demand))
 var target: Vector2 = demand.normalized() * limit * tanh(normalized_demand) * sliding_mu
 # Relaxation is a distance travelled through the patch, bounded in time at rest.
 var tau: float = clampf(relaxation_length / maxf(absf(longitudinal), 2), dt, 0.045)
 force = force.lerp(target, 1 - exp(-dt / tau))
 if force.length() > limit: force = force.normalized() * limit
 utilization = force.length() / limit
 return force

func spin(dt: float, drive_torque: float, brake_torque: float) -> void:
 var next: float = omega + (drive_torque - force.x * radius - omega * 0.015) / inertia * dt
 omega = move_toward(next, 0.0, brake_torque / inertia * dt)
