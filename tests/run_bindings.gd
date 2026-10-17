extends SceneTree
var failures: int = 0
var checks: int = 0
var game: Node3D
var controls: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool, title: String) -> void:
 checks += 1
 print("PASS " if ok else "FAIL ",title)
 if not ok: failures += 1
func tick(count: int = 4) -> void:
 for i in range(count): await physics_frame
func key(code: Key, down: bool = true) -> void:
 var event:=InputEventKey.new()
 event.keycode=code
 event.physical_keycode=code
 event.pressed=down
 Input.parse_input_event(event)
func motion(value: float) -> void:
 var event:=InputEventJoypadMotion.new()
 event.device=0
 event.axis=JOY_AXIS_LEFT_Y
 event.axis_value=value
 Input.parse_input_event(event)
func button(code: JoyButton, down: bool = true) -> void:
 var event:=InputEventJoypadButton.new()
 event.device=0
 event.button_index=code
 event.pressed=down
 Input.parse_input_event(event)
func run() -> void:
 game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 await tick()
 controls=game.controls
 controls.profile_path="user://test-controls-v2.cfg"
 controls.reset_bindings()
 game.toggle_menu()
 game.menu.tabs.current_tab=1
 game.menu.binding_buttons["throttle/keyboard"].pressed.emit()
 key(KEY_T)
 await tick()
 key(KEY_T,false)
 check(controls.keyboard.throttle.code==KEY_T and controls.capture_action.is_empty(),"Controls UI captures a new keyboard throttle binding")
 game.toggle_menu()
 await tick()
 key(KEY_W)
 await tick()
 check(game.bike.command.throttle==0,"old throttle key no longer drives the motorcycle")
 key(KEY_W,false)
 key(KEY_T)
 await tick()
 check(game.bike.command.throttle==1,"rebound throttle key drives the active controller")
 game.toggle_menu()
 game.toggle_menu()
 await tick()
 check(game.bike.command.throttle==0 and controls.await_neutral,"resume waits for held riding input to return to neutral")
 key(KEY_T,false)
 await tick()
 check(not controls.await_neutral,"neutral release restores input without stale throttle")
 game.toggle_menu()
 game.menu.binding_buttons["rear_brake/keyboard"].pressed.emit()
 key(KEY_S)
 await tick()
 key(KEY_S,false)
 check(controls.pending_conflicts==["front_brake"] and game.menu.conflicts.visible,"duplicate binding warns before changing either action")
 game.menu.conflicts.get_child(0).pressed.emit()
 check(controls.keyboard.rear_brake.code==KEY_S and controls.keyboard.front_brake.code==KEY_SPACE,"Swap exchanges the two keyboard bindings")
 game.menu.binding_buttons["throttle/gamepad"].pressed.emit()
 motion(0.12)
 await tick()
 motion(0.58)
 await tick()
 check(controls.capture_action=="throttle","axis drift and sub-threshold noise do not capture a binding")
 motion(0.81)
 await tick()
 check(controls.gamepad.throttle=={"kind":"axis","code":JOY_AXIS_LEFT_Y,"direction":1},"firm analog movement captures signed axis binding")
 motion(0.45)
 await tick()
 var analog: float=controls.mapping_strength(controls.gamepad.throttle,0)
 check(absf(analog-0.45)<0.02,"mapped analog axis retains progressive engine input values")
 motion(0)
 game.menu.binding_buttons["gear_up/gamepad"].pressed.emit()
 button(JOY_BUTTON_B)
 await tick()
 button(JOY_BUTTON_B,false)
 check(controls.pending_conflicts==["camera"],"controller button conflict is reported")
 game.menu.conflicts.get_child(1).pressed.emit()
 check(controls.gamepad.gear_up.code==JOY_BUTTON_B and controls.gamepad.camera.is_empty(),"Replace clears the old controller assignment explicitly")
 game.menu.binding_buttons["camera/keyboard"].pressed.emit()
 var old: Dictionary=controls.keyboard.camera.duplicate()
 key(KEY_ESCAPE)
 await tick()
 key(KEY_ESCAPE,false)
 check(controls.capture_action.is_empty() and controls.keyboard.camera==old and game.menu.visible,"Escape cancels capture without closing settings or changing a binding")
 game.menu.binding_buttons["clutch/gamepad"].pressed.emit()
 controls.on_device_changed(0,false)
 check(controls.capture_action.is_empty(),"controller disconnect cancels capture and clears transient input")
 game.menu.binding_buttons["lean_left/gamepad"].pressed.emit()
 button(JOY_BUTTON_DPAD_LEFT)
 await tick()
 check(controls.gamepad.lean_left=={"kind":"button","code":JOY_BUTTON_DPAD_LEFT} and controls.mapping_strength(controls.gamepad.lean_left,0)==1,"D-pad remapping produces a working digital input")
 button(JOY_BUTTON_DPAD_LEFT,false)
 controls.set_option("steering_deadzone",0.22)
 controls.set_option("steering_sensitivity",0.8)
 controls.set_option("vibration",false)
 controls.set_option("invert_weight",true)
 controls.save_profile()
 var cfg:=ConfigFile.new()
 check(cfg.load(controls.profile_path)==OK and cfg.get_value("keyboard","throttle").code==KEY_T,"control profile was written to disk")
 print("BINDINGS_RESULT checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
