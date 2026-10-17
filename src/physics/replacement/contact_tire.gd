extends "res://src/physics/tire.gd"
## Stateful elastic tread (bristle) contact, backward-Euler relative velocity solve.
## Static adhesion transitions to sliding; both directions share one friction budget.
var tread := Vector2.ZERO
var sliding: bool = false
var longitudinal_velocity: float = 0
var lateral_velocity: float = 0
var applied_force := Vector3.ZERO
func reset() -> void:
 super.reset()
 longitudinal_velocity = 0
 lateral_velocity = 0
 applied_force = Vector3.ZERO
 tread = Vector2.ZERO
 sliding = false
func forces(dt: float, longitudinal: float, lateral: float, mu: float, _legacy: float, drive: float = 0, brake: float = 0, inverse_effective_mass: Vector2 = Vector2(0.01,0.01)) -> Vector2:
 longitudinal_velocity = longitudinal
 lateral_velocity = lateral
 var free: float = move_toward(omega + (drive - omega * 0.015) * dt / inertia, 0, brake * dt / inertia)
 var relative := Vector2(free * radius - longitudinal, -lateral)
 slip = (omega * radius - longitudinal) / maxf(absf(longitudinal), 1)
 slip_angle = atan2(lateral, maxf(absf(longitudinal), 0.5))
 var limit: float = maxf(0, mu * load)
 # Tread stiffness in N/m. Finite compliance, no lateral velocity overwrite.
 var stiffness := Vector2(90000, 110000) * clampf(load / 900, 0.08, 2.5)
 var convection: float = absf(longitudinal) / 0.16
 var inv := inverse_effective_mass + Vector2(radius * radius / inertia, 0)
 var trial := Vector2.ZERO
 for j in range(2):
  trial[j] = (tread[j] + dt * relative[j]) / (1 + dt * convection + stiffness[j] * dt * dt * inv[j])
 var demand: Vector2 = trial * stiffness
 sliding = demand.length() > limit
 if sliding:
  # Continuous peak-to-slide reduction; no abrupt static/kinetic switch.
  var excess: float = demand.length() / maxf(limit,0.001) - 1
  var available: float = limit * (1 - 0.12 * (1 - exp(-excess)))
  demand = demand.normalized() * available
 tread = Vector2(demand.x / stiffness.x, demand.y / stiffness.y)
 force = demand
 utilization = force.length() / maxf(limit,0.001)
 return force
func detach() -> void:
 tread = Vector2.ZERO
 force = Vector2.ZERO
 load = 0
 grounded = false
 longitudinal_velocity = 0
 lateral_velocity = 0
 applied_force = Vector3.ZERO
 slip = 0
 slip_angle = 0
 utilization = 0
func lateral_angle_for_force(dt: float, desired: float, longitudinal: float, inverse_mass: float) -> float:
 var stiffness: float = 110000 * clampf(load / 900,0.08,2.5)
 var denominator: float = 1 + dt * absf(longitudinal) / 0.16 + stiffness * dt * dt * inverse_mass
 var relative: float = (desired * denominator / stiffness - tread.y) / dt
 return atan2(-relative,maxf(absf(longitudinal),0.5))
