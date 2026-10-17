extends RefCounted
## Engine owns crank angular momentum. Clutch torque is equal and opposite at crank/wheel.
var rpm: float = 1900.0
var gear: int = 1
var clutch_torque: float = 0.0
var config: Dictionary
var automatic: bool = true
var clutch_assist: bool = true
var shift_cooldown: float = 0.0

func _init(data: Dictionary) -> void:
 config = data
 reset()

func reset() -> void:
 rpm = config.idle_rpm
 gear = 1
 clutch_torque = 0.0
 shift_cooldown = 0.0

func shift(direction: int) -> void:
 var next: int = clampi(gear + direction, 1, config.gears.size())
 if shift_cooldown <= 0.0 and next != gear:
  gear = next
  shift_cooldown = 0.16

func torque_at(value: float) -> float:
 var curve: Array = config.torque_curve
 for i in range(1, curve.size()):
  if value <= float(curve[i][0]):
   return lerpf(float(curve[i - 1][1]), float(curve[i][1]), clampf(inverse_lerp(float(curve[i - 1][0]), float(curve[i][0]), value), 0, 1))
 return float(curve[-1][1])

func step(dt: float, throttle: float, clutch: float, rear_omega: float) -> float:
 shift_cooldown = maxf(0, shift_cooldown - dt)
 if automatic:
  if rpm > 11500: shift(1)
  elif rpm < 4700: shift(-1)
 var ratio: float = config.primary_ratio * config.gears[gear - 1] * config.final_ratio
 var omega: float = rpm * TAU / 60.0
 var idle_omega: float = config.idle_rpm * TAU / 60.0
 var engagement: float = 1.0 - clutch
 if clutch_assist:
  engagement *= clampf((rpm - 2200.0) / 1800.0, 0.0, 1.0)
 if shift_cooldown > 0.08: engagement = 0.0
 clutch_torque = clampf((omega - rear_omega * ratio) * 0.16, -config.clutch_capacity_nm, config.clutch_capacity_nm) * engagement
 var combustion: float = torque_at(rpm) * throttle if rpm < config.limiter_rpm else 0.0
 var idle_governor: float = clampf((idle_omega - omega) * 0.5, 0, 12)
 var drag: float = config.engine_braking_nm * (1.0 - throttle) + omega * 0.001
 omega += (combustion + idle_governor - drag - clutch_torque) / config.engine_inertia_kg_m2 * dt
 rpm = clampf(omega * 60.0 / TAU, 0, config.limiter_rpm + 400)
 return clutch_torque * ratio * 0.94
