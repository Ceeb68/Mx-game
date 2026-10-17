extends SceneTree
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
 print("PASS " if ok else "FAIL ", text)
 if not ok: failures += 1
func press(code: Key, down: bool = true) -> void:
 var event := InputEventKey.new()
 event.physical_keycode = code
 event.keycode = code
 event.pressed = down
 Input.parse_input_event(event)
func run() -> void:
 var scene = load("res://scenes/main.tscn").instantiate()
 root.add_child(scene)
 for i in range(4): await physics_frame
 for i in range(8): await physics_frame
 press(KEY_W)
 for i in range(4): await physics_frame
 check(scene.bike.command.throttle == 1, "keyboard W reaches authoritative throttle input")
 press(KEY_W, false)
 for i in range(4): await physics_frame
 check(scene.bike.command.throttle == 0, "keyboard release clears throttle")
 press(KEY_D)
 for i in range(24): await physics_frame
 check(scene.bike.command.steer > 0.5, "keyboard steering is smoothed into analog command")
 press(KEY_D, false)
 press(KEY_ESCAPE)
 for i in range(4): await physics_frame
 check(scene.menu.visible and scene.bike.freeze and scene.controls.paused, "Escape opens settings and freezes riding")
 press(KEY_ESCAPE, false)
 # Focused menus may consume navigation; use the actual Resume button signal.
 var buttons = scene.menu.find_children("", "Button", true, false)
 for button in buttons:
  if button.text == "RESUME RIDING": button.pressed.emit()
 check(not scene.menu.visible and not scene.bike.freeze and not scene.controls.paused, "Resume button restores physics and controls")
 scene.bike.engine.automatic = false
 scene.bike.engine.shift_cooldown = 0
 press(KEY_PAGEUP)
 for i in range(4): await physics_frame
 check(scene.bike.engine.gear == 2, "manual gear key shifts live transmission")
 press(KEY_PAGEUP, false)
 press(KEY_C)
 for i in range(4): await physics_frame
 check(scene.camera_mode == 1, "camera key changes viewpoint")
 press(KEY_C, false)
 press(KEY_R)
 for i in range(4): await physics_frame
 check(scene.bike.engine.gear == 1 and scene.bike.position.distance_to(scene.spawn_points[0]) < 0.1, "reset key clears drivetrain and restores spawn")
 press(KEY_R, false)
 # Validate signed analog deadzone transform independently of absent physical hardware.
 check(scene.controls.axis(0.05) == 0 and scene.controls.axis(0.9) > 0.8 and scene.controls.axis(-0.9) < -0.8, "gamepad axis deadzone preserves analog magnitude and sign")
 print("CONTROLS_RESULT checks=9 failures=", failures)
 quit(0 if failures == 0 else 1)
