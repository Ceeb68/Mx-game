extends RefCounted
## Relaxed brush approximation, limited by a combined-force friction circle.
## Dirt coefficients are provisional, not measured motocross tire data.
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

func _init(wheel_radius: float, wheel_inertia: float) -> void:
 radius = wheel_radius
 inertia = wheel_inertia

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

func forces(dt: float, longitudinal: float, lateral: float, mu: float, relaxation: float) -> Vector2:
 slip = (omega * radius - longitudinal) / maxf(absf(longitudinal), 2.0)
 slip_angle = atan2(lateral, maxf(absf(longitudinal), 1.5))
 # Smooth saturation gives progressive breakaway without discontinuous sign changes.
 var demand := Vector2(slip * 8.0, -tan(slip_angle) * 6.0)
 var magnitude: float = demand.length()
 var target: Vector2 = demand / maxf(magnitude, 0.0001) * tanh(magnitude) * load * mu
 force = force.lerp(target, 1.0 - exp(-dt / relaxation))
 # Re-limit after relaxation: unloading must immediately reduce available grip.
 if force.length() > load * mu: force = force.normalized() * load * mu
 return force

func spin(dt: float, drive_torque: float, brake_torque: float) -> void:
 # Backward-Euler dry brake prevents crossing through zero under braking alone.
 var next: float = omega + (drive_torque - force.x * radius - omega * 0.015) / inertia * dt
 omega = move_toward(next, 0.0, brake_torque / inertia * dt)
