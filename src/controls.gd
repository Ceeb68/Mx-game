extends Node
## One persisted command mapping, shared by keyboard, pad, and the in-game editor.
signal action_pressed(action: String)
signal mappings_changed
signal capture_changed(message: String)
signal conflict_found(actions: Array)
signal device_changed(message: String)
const ACTIONS := ["throttle", "front_brake", "rear_brake", "left", "right", "lean_left", "lean_right", "forward", "backward", "clutch", "gear_up", "gear_down", "posture", "reset", "camera", "settings", "next_lane", "diagnostics"]
const TITLES := ["Throttle", "Front brake", "Rear brake", "Steer left", "Steer right", "Rider lean left", "Rider lean right", "Rider forward", "Rider backward", "Clutch", "Gear up", "Gear down", "Sit / stand", "Reset motorcycle", "Camera", "Pause / menu", "Next test lane", "Telemetry"]
const DISCRETE := ["gear_up", "gear_down", "posture", "reset", "camera", "settings", "next_lane", "diagnostics"]
var bike: RigidBody3D
var profile_path: String = "user://controls_v2.cfg"
var keyboard: Dictionary = {}
var gamepad: Dictionary = {}
# Kept as a read-only-style compatibility view for diagnostics and old scripts.
var bindings: Dictionary = {}
var options := {"steering_sensitivity": 1.0, "steering_deadzone": 0.10, "lean_sensitivity": 1.0, "lean_deadzone": 0.10, "throttle_deadzone": 0.03, "brake_deadzone": 0.03, "steering_curve": 1.35, "smoothing_s": 0.10, "invert_steering": false, "invert_lean": false, "invert_weight": false, "combined_lean": false, "vibration": true, "vibration_strength": 0.35, "steering_assist": true, "foot_support": true, "automatic": true, "clutch_assist": true, "fov": 72.0, "follow_distance": 5.0}
var paused: bool = false
var steer: float = 0.0
var capture_action: String = ""
var capture_device: String = ""
var pending_binding: Dictionary = {}
var pending_conflicts: Array = []
var axis_armed: Dictionary = {}
var capture_seconds: float = 0
var held: Dictionary = {}
var pads: Array = []
var save_timer: Timer
var was_impact: bool = false
var await_neutral: bool = false
const CONTINUOUS := ["throttle", "front_brake", "rear_brake", "left", "right", "lean_left", "lean_right", "forward", "backward", "clutch"]
const RANGES := {"steering_sensitivity": Vector2(0.2, 2), "steering_deadzone": Vector2(0, 0.4), "lean_sensitivity": Vector2(0.2, 2), "lean_deadzone": Vector2(0, 0.4), "throttle_deadzone": Vector2(0, 0.3), "brake_deadzone": Vector2(0, 0.3), "steering_curve": Vector2(0.6, 2.5), "smoothing_s": Vector2(0, 0.35), "vibration_strength": Vector2(0, 1), "fov": Vector2(50, 100), "follow_distance": Vector2(3, 10)}

func defaults() -> void:
 var keys := [KEY_W, KEY_S, KEY_SPACE, KEY_A, KEY_D, KEY_Q, KEY_E, KEY_UP, KEY_DOWN, KEY_SHIFT, KEY_PAGEUP, KEY_PAGEDOWN, KEY_TAB, KEY_R, KEY_C, KEY_ESCAPE, KEY_F6, KEY_F1]
 keyboard.clear()
 gamepad.clear()
 for i in range(ACTIONS.size()):
  keyboard[ACTIONS[i]] = {"kind": "key", "code": keys[i]}
  gamepad[ACTIONS[i]] = {}
 for spec in [["throttle", JOY_AXIS_TRIGGER_RIGHT, 1], ["front_brake", JOY_AXIS_TRIGGER_LEFT, 1], ["left", JOY_AXIS_LEFT_X, -1], ["right", JOY_AXIS_LEFT_X, 1], ["lean_left", JOY_AXIS_RIGHT_X, -1], ["lean_right", JOY_AXIS_RIGHT_X, 1], ["forward", JOY_AXIS_RIGHT_Y, -1], ["backward", JOY_AXIS_RIGHT_Y, 1]]:
  gamepad[spec[0]] = {"kind": "axis", "code": spec[1], "direction": spec[2]}
 for spec in [["rear_brake", JOY_BUTTON_A], ["clutch", JOY_BUTTON_LEFT_SHOULDER], ["gear_up", JOY_BUTTON_RIGHT_SHOULDER], ["gear_down", JOY_BUTTON_X], ["posture", JOY_BUTTON_Y], ["reset", JOY_BUTTON_BACK], ["camera", JOY_BUTTON_B], ["settings", JOY_BUTTON_START]]:
  gamepad[spec[0]] = {"kind": "button", "code": spec[1]}
 sync_legacy_view()

func _ready() -> void:
 defaults()
 load_profile()
 save_timer = Timer.new()
 save_timer.one_shot = true
 save_timer.wait_time = 0.3
 save_timer.timeout.connect(save_profile)
 add_child(save_timer)
 pads = Input.get_connected_joypads()
 Input.joy_connection_changed.connect(on_device_changed)
 apply_assists()

func sync_legacy_view() -> void:
 for action in keyboard: bindings[action] = keyboard[action].get("code", 0)

func load_profile() -> void:
 var cfg := ConfigFile.new()
 if cfg.load(profile_path) == OK:
  for action in ACTIONS:
   var key_mapping: Variant = cfg.get_value("keyboard", action, keyboard[action])
   var pad_mapping: Variant = cfg.get_value("gamepad", action, gamepad[action])
   if valid_mapping(key_mapping, "keyboard"): keyboard[action] = key_mapping
   if valid_mapping(pad_mapping, "gamepad"): gamepad[action] = pad_mapping
  for option in options:
   var value: Variant = cfg.get_value("response", option, options[option])
   if typeof(value) == typeof(options[option]): options[option] = value
 else:
  # Migrate existing first-build keyboard layouts without overwriting that file.
  var legacy := ConfigFile.new()
  if legacy.load("user://controls.cfg") == OK:
   for action in ACTIONS:
    var code: int = int(legacy.get_value("keys", action, keyboard[action].code))
    if code > 0: keyboard[action] = {"kind": "key", "code": code}
   var pairs := {"steer_axis": ["left", "right"], "lean_axis": ["lean_left", "lean_right"], "weight_axis": ["forward", "backward"]}
   for pair in pairs:
    if legacy.has_section_key("gamepad", pair):
     for side in range(2): gamepad[pairs[pair][side]] = {"kind": "axis", "code": int(legacy.get_value("gamepad", pair)), "direction": -1 if side == 0 else 1}
   for action in ["rear_brake", "clutch", "gear_up", "gear_down", "posture", "reset", "camera", "settings"]:
    if legacy.has_section_key("gamepad", action): gamepad[action] = {"kind": "button", "code": int(legacy.get_value("gamepad", action))}
   for action in ["throttle", "front_brake"]:
    if legacy.has_section_key("gamepad", action + "_axis"): gamepad[action] = {"kind": "axis", "code": int(legacy.get_value("gamepad", action + "_axis")), "direction": 1}
 for option in RANGES: options[option] = clampf(float(options[option]), RANGES[option].x, RANGES[option].y)
 sync_legacy_view()

func valid_mapping(value: Variant, device: String) -> bool:
 if not value is Dictionary: return false
 if value.is_empty(): return true
 if not value.get("code", null) is int: return false
 if device == "keyboard": return value.get("kind") == "key" and value.code > 0
 if value.get("kind") == "button": return value.code >= 0 and value.code < JOY_BUTTON_MAX
 return value.get("kind") == "axis" and value.code >= 0 and value.code < JOY_AXIS_MAX and value.get("direction", 0) in [-1, 1]

func save_profile() -> void:
 var cfg := ConfigFile.new()
 for action in ACTIONS:
  cfg.set_value("keyboard", action, keyboard[action])
  cfg.set_value("gamepad", action, gamepad[action])
 for option in options: cfg.set_value("response", option, options[option])
 var error: Error = cfg.save(profile_path + ".tmp")
 if error == OK: error = DirAccess.rename_absolute(ProjectSettings.globalize_path(profile_path + ".tmp"), ProjectSettings.globalize_path(profile_path))
 if error != OK: capture_changed.emit("Could not save controls: " + error_string(error))

func set_option(option: String, value: Variant) -> void:
 if not options.has(option): return
 if RANGES.has(option): value = clampf(float(value), RANGES[option].x, RANGES[option].y)
 options[option] = value
 apply_assists()
 if save_timer: save_timer.start()

func apply_assists() -> void:
 if not is_instance_valid(bike) or not bike.engine: return
 bike.steering_assist = options.steering_assist
 bike.foot_support = options.foot_support
 bike.engine.automatic = options.automatic
 bike.engine.clutch_assist = options.clutch_assist

func reset_bindings() -> void:
 cancel_capture()
 defaults()
 held.clear()
 save_profile()
 mappings_changed.emit()

func label_for(action: String, device: String) -> String:
 var mapping: Dictionary = keyboard[action] if device == "keyboard" else gamepad[action]
 if mapping.is_empty(): return "Unassigned"
 if mapping.kind == "key": return OS.get_keycode_string(mapping.code)
 if mapping.kind == "button":
  var names := {JOY_BUTTON_A: "A / Cross", JOY_BUTTON_B: "B / Circle", JOY_BUTTON_X: "X / Square", JOY_BUTTON_Y: "Y / Triangle", JOY_BUTTON_LEFT_SHOULDER: "LB / L1", JOY_BUTTON_RIGHT_SHOULDER: "RB / R1", JOY_BUTTON_START: "Start / Menu", JOY_BUTTON_BACK: "Back / View", JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down", JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right"}
  return names.get(mapping.code, "Button %d" % mapping.code)
 var axis_names := ["Left stick X", "Left stick Y", "Right stick X", "Right stick Y", "Left trigger", "Right trigger"]
 return "%s %s" % [axis_names[mapping.code] if mapping.code < axis_names.size() else "Axis %d" % mapping.code, "+" if mapping.direction > 0 else "−"]

func begin_capture(action: String, device: String) -> void:
 capture_action = action
 capture_device = device
 capture_seconds = 0
 pending_binding.clear()
 pending_conflicts.clear()
 axis_armed.clear()
 for pad in Input.get_connected_joypads():
  for axis_index in range(JOY_AXIS_MAX): axis_armed[Vector2i(pad, axis_index)] = absf(Input.get_joy_axis(pad, axis_index)) < 0.25
 capture_changed.emit("Binding %s: %s. Escape cancels; timeout 15 s." % [action.replace("_", " "), "press a key" if device == "keyboard" else "press a button or move an axis firmly from neutral"])

func cancel_capture() -> void:
 capture_action = ""
 pending_binding.clear()
 pending_conflicts.clear()
 axis_armed.clear()
 for action in DISCRETE: held[action] = strength(action) > 0.6
 capture_changed.emit("")

func consider_binding(candidate: Dictionary) -> void:
 var bank: Dictionary = keyboard if capture_device == "keyboard" else gamepad
 pending_binding = candidate.duplicate()
 pending_conflicts.clear()
 for action in ACTIONS:
  if action != capture_action and bank[action] == candidate: pending_conflicts.append(action)
 if pending_conflicts.is_empty(): resolve_conflict("replace")
 else:
  capture_changed.emit("Already bound to: %s. Choose Swap, Replace, or Cancel." % ", ".join(pending_conflicts))
  conflict_found.emit(pending_conflicts)

func resolve_conflict(resolution: String) -> void:
 if resolution == "cancel": cancel_capture(); return
 if capture_action.is_empty() or pending_binding.is_empty(): return
 var bank: Dictionary = keyboard if capture_device == "keyboard" else gamepad
 var old: Dictionary = bank[capture_action].duplicate()
 for action in pending_conflicts:
  bank[action] = old if resolution == "swap" and pending_conflicts.size() == 1 else {}
 bank[capture_action] = pending_binding.duplicate()
 held.clear()
 sync_legacy_view()
 save_profile()
 cancel_capture()
 mappings_changed.emit()

func _input(event: InputEvent) -> void:
 if capture_action.is_empty(): return
 if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
  cancel_capture()
  get_viewport().set_input_as_handled()
  return
 if not pending_conflicts.is_empty(): return
 if capture_device == "keyboard" and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode != KEY_NONE:
  consider_binding({"kind": "key", "code": event.physical_keycode})
  get_viewport().set_input_as_handled()
 elif capture_device == "gamepad":
  if event is InputEventJoypadButton and event.pressed:
   consider_binding({"kind": "button", "code": event.button_index})
   get_viewport().set_input_as_handled()
  elif event is InputEventJoypadMotion:
   var id := Vector2i(event.device, event.axis)
   if absf(event.axis_value) < 0.25: axis_armed[id] = true
   if axis_armed.get(id, false) and absf(event.axis_value) > 0.65:
    consider_binding({"kind": "axis", "code": event.axis, "direction": 1 if event.axis_value > 0 else -1})
    get_viewport().set_input_as_handled()

func on_device_changed(_id: int, connected: bool) -> void:
 pads = Input.get_connected_joypads()
 clear_commands()
 await_neutral = true
 held.clear()
 if not connected and not capture_action.is_empty(): cancel_capture()
 device_changed.emit(device_status())

func device_status() -> String:
 var devices := Input.get_connected_joypads()
 return "No controller connected · keyboard is active" if devices.is_empty() else "Controller: " + Input.get_joy_name(devices[0])

func axis(value: float) -> float:
 return signf(value) * maxf(0, absf(value) - float(options.steering_deadzone)) / (1 - float(options.steering_deadzone))

func mapping_strength(mapping: Dictionary, pad: int) -> float:
 if mapping.is_empty(): return 0
 if mapping.kind == "key": return float(Input.is_physical_key_pressed(mapping.code))
 if pad < 0: return 0
 if mapping.kind == "button": return float(Input.is_joy_button_pressed(pad, mapping.code))
 return maxf(0, Input.get_joy_axis(pad, mapping.code) * float(mapping.direction))

func strength(action: String) -> float:
 var pad: int = pads[0] if not pads.is_empty() else -1
 var key_value: float = mapping_strength(keyboard[action], -1)
 var pad_value: float = mapping_strength(gamepad[action], pad)
 var dz: float = 0.10
 if action in ["left", "right"]: dz = options.steering_deadzone
 elif action in ["lean_left", "lean_right", "forward", "backward"]: dz = options.lean_deadzone
 elif action == "throttle": dz = options.throttle_deadzone
 elif action in ["front_brake", "rear_brake", "clutch"]: dz = options.brake_deadzone
 pad_value = clampf((pad_value - dz) / (1 - dz), 0, 1)
 return maxf(key_value, pad_value)

func clear_commands() -> void:
 steer = 0
 if not is_instance_valid(bike): return
 for action in ["throttle", "front_brake", "rear_brake", "steer", "lean", "weight", "clutch"]: bike.command[action] = 0.0

func _physics_process(dt: float) -> void:
 pads = Input.get_connected_joypads()
 if not capture_action.is_empty():
  if pending_conflicts.is_empty(): capture_seconds += dt
  clear_commands()
  if capture_seconds > 15: cancel_capture()
  return
 for action in DISCRETE:
  var down: bool = strength(action) > 0.6
  if down and not held.get(action, false) and (not paused or action == "settings"): action_pressed.emit(action)
  held[action] = down
 if paused:
  clear_commands()
  return
 if await_neutral:
  for action in CONTINUOUS:
   if strength(action) > 0.15:
    clear_commands()
    return
  await_neutral = false
 var requested: float = strength("right") - strength("left")
 requested = signf(requested) * pow(absf(requested), options.steering_curve) * options.steering_sensitivity
 if options.invert_steering: requested = -requested
 var tau: float = options.smoothing_s
 steer = lerpf(steer, clampf(requested, -1, 1), 1 - exp(-dt / tau)) if tau > 0.001 else clampf(requested, -1, 1)
 var lean: float = (strength("lean_right") - strength("lean_left")) * options.lean_sensitivity
 var weight: float = (strength("forward") - strength("backward")) * options.lean_sensitivity
 if options.invert_lean: lean = -lean
 if options.invert_weight: weight = -weight
 if options.combined_lean: lean += steer * 0.30
 bike.command.throttle = strength("throttle")
 bike.command.front_brake = strength("front_brake")
 bike.command.rear_brake = strength("rear_brake")
 bike.command.steer = steer
 bike.command.lean = clampf(lean, -1, 1)
 bike.command.weight = clampf(weight, -1, 1)
 bike.command.clutch = strength("clutch")
 var impact: bool = bike.wheels[0].load + bike.wheels[1].load > bike.mass * 9.81 * 2
 if impact and not was_impact: vibrate()
 was_impact = impact

func vibrate() -> void:
 if options.vibration and not pads.is_empty(): Input.start_joy_vibration(pads[0], options.vibration_strength * 0.5, options.vibration_strength, 0.12)
