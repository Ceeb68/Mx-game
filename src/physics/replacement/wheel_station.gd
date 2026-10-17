extends RefCounted
## Independent unsprung translation, implicit tire carcass + spring/damper solve.
## Chassis receives suspension reaction; tire load is NOT the chassis spring force.
var compression: float = 0
var velocity: float = 0
var spring_force: float = 0
var load: float = 0
var unsprung_mass: float
var index: int
var bottomed: bool = false
func _init(i: int) -> void:
 index = i
 unsprung_mass = 7.0 if i == 0 else 9.0
func reset() -> void:
 compression = 0
 velocity = 0
 spring_force = 0
 load = 0
func step(dt: float, road_compression: float, closing_speed: float, projection: float, mount_acceleration: float, config: Dictionary, contact: bool, gravity_projection: float = 1) -> void:
 var k: float = config.spring_n_m[index]
 var preload_force: float = config.preload_n[index]
 var c: float = config.compression_ns_m[index] if velocity > 0 else config.rebound_ns_m[index]
 var kt: float = 110000 if contact else 0
 var ct: float = 650 if contact else 0
 var a: float = maxf(0.25, projection)
 var penetration: float = (road_compression - compression) * a
 # Implicit solve of m*q'' = N*a - spring - gravity - mount acceleration.
 var drive: float = kt * penetration * a + ct * closing_speed * a - preload_force - k * compression - unsprung_mass * (9.81 * gravity_projection + mount_acceleration)
 velocity = (velocity + dt * drive / unsprung_mass) / (1 + dt * (c + ct * a * a) / unsprung_mass + dt * dt * (k + kt * a * a) / unsprung_mass)
 var old: float = compression
 compression = clampf(compression + dt * velocity, 0, config.suspension_travel_m)
 bottomed = compression >= config.suspension_travel_m
 if compression == 0 and velocity < 0: velocity = 0
 if bottomed and velocity > 0: velocity = 0
 spring_force = maxf(0, preload_force + k * compression + c * velocity)
 load = maxf(0, kt * (road_compression - compression) * a + ct * (closing_speed - (compression - old) / dt * a))
 if compression == 0:
  spring_force = load * a - unsprung_mass * (9.81 * gravity_projection + mount_acceleration)
 if bottomed: spring_force = maxf(spring_force, load * a - unsprung_mass * (9.81 * gravity_projection + mount_acceleration))
