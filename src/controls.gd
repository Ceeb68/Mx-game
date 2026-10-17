extends Node
## Common analog command contract for keyboard, standard gamepad, and test harness.
var bike: RigidBody3D
var deadzone: float = 0.12
var sensitivity: float = 1.0
var smoothing: float = 9.0
var bindings: Dictionary = {"throttle": KEY_W, "front_brake": KEY_S, "rear_brake": KEY_SPACE, "left": KEY_A, "right": KEY_D, "forward": KEY_UP, "backward": KEY_DOWN, "lean_left": KEY_Q, "lean_right": KEY_E, "clutch": KEY_SHIFT, "gear_up": KEY_PAGEUP, "gear_down": KEY_PAGEDOWN, "posture": KEY_TAB, "reset": KEY_R, "camera": KEY_C, "next_lane": KEY_F6, "diagnostics": KEY_F1, "settings": KEY_ESCAPE}
var pad_bindings: Dictionary = {"steer_axis": JOY_AXIS_LEFT_X, "weight_axis": JOY_AXIS_RIGHT_Y, "lean_axis": JOY_AXIS_RIGHT_X, "throttle_axis": JOY_AXIS_TRIGGER_RIGHT, "front_brake_axis": JOY_AXIS_TRIGGER_LEFT, "rear_brake": JOY_BUTTON_A, "clutch": JOY_BUTTON_LEFT_SHOULDER, "gear_up": JOY_BUTTON_RIGHT_SHOULDER, "gear_down": JOY_BUTTON_X, "posture": JOY_BUTTON_Y, "camera": JOY_BUTTON_B, "reset": JOY_BUTTON_BACK, "settings": JOY_BUTTON_START}
var paused: bool = false
var steer: float = 0.0

func _ready() -> void:
 var cfg := ConfigFile.new()
 if cfg.load("user://controls.cfg") == OK:
  for action in bindings: bindings[action] = int(cfg.get_value("keys", action, bindings[action]))
  for action in pad_bindings: pad_bindings[action] = int(cfg.get_value("gamepad", action, pad_bindings[action]))
  deadzone = clampf(float(cfg.get_value("input", "deadzone", deadzone)), 0, 0.5)
  sensitivity = clampf(float(cfg.get_value("input", "sensitivity", sensitivity)), 0.2, 2)
  smoothing = clampf(float(cfg.get_value("input", "smoothing", smoothing)), 1, 40)
 else:
  for action in bindings: cfg.set_value("keys", action, bindings[action])
  for action in pad_bindings: cfg.set_value("gamepad", action, pad_bindings[action])
  cfg.set_value("input", "deadzone", deadzone)
  cfg.set_value("input", "sensitivity", sensitivity)
  cfg.set_value("input", "smoothing", smoothing)
  cfg.save("user://controls.cfg")

func key(action: String) -> float:
 return 1.0 if Input.is_physical_key_pressed(bindings[action]) else 0.0

func axis(value: float) -> float:
 return signf(value) * maxf(0, absf(value) - deadzone) / (1 - deadzone)

func _physics_process(dt: float) -> void:
 if paused: return
 var pads := Input.get_connected_joypads()
 var pad: int = pads[0] if not pads.is_empty() else -1
 var target: float = key("right") - key("left")
 var throttle: float = key("throttle")
 var front_brake: float = key("front_brake")
 var rear_brake: float = key("rear_brake")
 var weight: float = key("forward") - key("backward")
 var lean: float = key("lean_right") - key("lean_left")
 var clutch: float = key("clutch")
 if pad >= 0:
  target += axis(Input.get_joy_axis(pad, pad_bindings.steer_axis))
  weight -= axis(Input.get_joy_axis(pad, pad_bindings.weight_axis))
  lean += axis(Input.get_joy_axis(pad, pad_bindings.lean_axis))
  throttle = maxf(throttle, maxf(0, Input.get_joy_axis(pad, pad_bindings.throttle_axis)))
  front_brake = maxf(front_brake, maxf(0, Input.get_joy_axis(pad, pad_bindings.front_brake_axis)))
  rear_brake = maxf(rear_brake, float(Input.is_joy_button_pressed(pad, pad_bindings.rear_brake)))
  clutch = maxf(clutch, float(Input.is_joy_button_pressed(pad, pad_bindings.clutch)))
 steer = move_toward(steer, clampf(target * sensitivity, -1, 1), dt * smoothing)
 bike.command.throttle = throttle
 bike.command.front_brake = front_brake
 bike.command.rear_brake = rear_brake
 bike.command.steer = steer
 bike.command.weight = clampf(weight, -1, 1)
 bike.command.lean = clampf(lean, -1, 1)
 bike.command.clutch = clutch

func _unhandled_input(event: InputEvent) -> void:
 if paused: return
 if event is InputEventKey and event.pressed and not event.echo:
  if event.physical_keycode == bindings.gear_up: bike.engine.shift(1)
  if event.physical_keycode == bindings.gear_down: bike.engine.shift(-1)
  if event.physical_keycode == bindings.posture: bike.command.stand = not bike.command.stand
 if event is InputEventJoypadButton and event.pressed:
  if event.button_index == pad_bindings.gear_up: bike.engine.shift(1)
  if event.button_index == pad_bindings.gear_down: bike.engine.shift(-1)
  if event.button_index == pad_bindings.posture: bike.command.stand = not bike.command.stand
