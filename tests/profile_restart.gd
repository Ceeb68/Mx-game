extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var controls=load("res://src/controls.gd").new()
 controls.profile_path="user://test-controls-v2.cfg"
 root.add_child(controls)
 controls.set_physics_process(false)
 var ok: bool=controls.keyboard.throttle.code==KEY_T and controls.keyboard.rear_brake.code==KEY_S and controls.gamepad.throttle.get("kind")=="axis" and controls.gamepad.throttle.code==JOY_AXIS_LEFT_Y and controls.gamepad.gear_up.code==JOY_BUTTON_B and controls.gamepad.camera.is_empty() and absf(controls.options.steering_deadzone-0.22)<0.001 and absf(controls.options.steering_sensitivity-0.8)<0.001 and controls.options.invert_weight and not controls.options.vibration
 print("PASS " if ok else "FAIL ","bindings and response options reload in a separate Godot process")
 print("PERSISTENCE_RESULT checks=1 failures=",0 if ok else 1)
 quit(0 if ok else 1)
