extends PanelContainer
var game: Node3D
var controls: Node
var prompt: Label
var devices: Label
var conflicts: HBoxContainer
var swap_button: Button
var binding_buttons: Dictionary = {}
var tabs: TabContainer

func _ready() -> void:
 position = Vector2(240, 65)
 custom_minimum_size = Vector2(960, 770)
 var style := StyleBoxFlat.new()
 style.bg_color = Color(0.035, 0.05, 0.065, 0.98)
 style.content_margin_left = 20
 style.content_margin_right = 20
 style.content_margin_top = 16
 style.content_margin_bottom = 16
 add_theme_stylebox_override("panel", style)
 var column := VBoxContainer.new()
 column.add_theme_constant_override("separation", 10)
 add_child(column)
 var title := Label.new()
 title.text = "TERRA MX  /  SETTINGS"
 title.add_theme_font_size_override("font_size", 24)
 column.add_child(title)
 devices = Label.new()
 devices.text = controls.device_status()
 devices.modulate = Color(0.96, 0.66, 0.35)
 column.add_child(devices)
 tabs = TabContainer.new()
 tabs.custom_minimum_size = Vector2(900, 530)
 tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
 column.add_child(tabs)
 var session := page("Riding")
 for pair in [["Virtual rider steering (torque control)", "steering_assist"], ["Grounded low-speed foot support", "foot_support"], ["Automatic shifting", "automatic"], ["Clutch assistance", "clutch_assist"]]:
  toggle(session, pair[0], pair[1])
 slider(session, "Camera field of view", "fov", 50, 100, 1)
 slider(session, "Camera follow distance / m", "follow_distance", 3, 10, 0.1)
 var note := Label.new()
 note.text = "Assists remain visible in telemetry. No airborne upright assistance.\nAll control and response changes save automatically."
 session.add_child(note)
 var binding_page := page("Controls")
 var heading := HBoxContainer.new()
 binding_page.add_child(heading)
 for text in ["ACTION", "KEYBOARD", "CONTROLLER"]:
  var label := Label.new()
  label.text = text
  label.custom_minimum_size.x = 280
  heading.add_child(label)
 for i in range(controls.ACTIONS.size()):
  var action: String = controls.ACTIONS[i]
  var row := HBoxContainer.new()
  binding_page.add_child(row)
  var label := Label.new()
  label.text = controls.TITLES[i]
  label.custom_minimum_size.x = 280
  row.add_child(label)
  for device in ["keyboard", "gamepad"]:
   var button := Button.new()
   button.text = controls.label_for(action, device)
   button.custom_minimum_size = Vector2(275, 34)
   button.pressed.connect(func(): controls.begin_capture(action, device))
   row.add_child(button)
   binding_buttons[action + "/" + device] = button
 var reset := Button.new()
 reset.text = "RESET ALL BINDINGS TO DEFAULTS"
 reset.pressed.connect(controls.reset_bindings)
 binding_page.add_child(reset)
 var response := page("Response")
 slider(response, "Steering sensitivity", "steering_sensitivity", 0.2, 2, 0.05)
 slider(response, "Steering deadzone", "steering_deadzone", 0, 0.4, 0.01)
 slider(response, "Rider lean sensitivity", "lean_sensitivity", 0.2, 2, 0.05)
 slider(response, "Rider lean / weight deadzone", "lean_deadzone", 0, 0.4, 0.01)
 slider(response, "Throttle deadzone", "throttle_deadzone", 0, 0.3, 0.01)
 slider(response, "Brake / clutch deadzone", "brake_deadzone", 0, 0.3, 0.01)
 slider(response, "Steering response curve (1 = linear)", "steering_curve", 0.6, 2.5, 0.05)
 slider(response, "Steering smoothing / seconds (0 = off)", "smoothing_s", 0, 0.35, 0.01)
 for pair in [["Invert steering", "invert_steering"], ["Invert lateral rider lean", "invert_lean"], ["Invert rider forward / backward", "invert_weight"], ["Combined steering + rider lean", "combined_lean"], ["Controller vibration", "vibration"]]: toggle(response, pair[0], pair[1])
 slider(response, "Vibration strength", "vibration_strength", 0, 1, 0.05)
 var vibration := Button.new()
 vibration.text = "TEST VIBRATION (connected controller required)"
 vibration.pressed.connect(controls.vibrate)
 response.add_child(vibration)
 prompt = Label.new()
 prompt.text = "Select a binding, then press a key, button, or move an axis from neutral."
 prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 prompt.custom_minimum_size.y = 44
 column.add_child(prompt)
 conflicts = HBoxContainer.new()
 column.add_child(conflicts)
 for pair in [["SWAP", "swap"], ["REPLACE", "replace"], ["CANCEL", "cancel"]]:
  var button := Button.new()
  button.text = pair[0]
  button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  var resolution: String = pair[1]
  button.pressed.connect(func(): controls.resolve_conflict(resolution))
  conflicts.add_child(button)
  if resolution == "swap": swap_button = button
 conflicts.hide()
 var footer := HBoxContainer.new()
 column.add_child(footer)
 var cancel := Button.new()
 cancel.text = "CANCEL REBIND"
 cancel.pressed.connect(controls.cancel_capture)
 footer.add_child(cancel)
 var resume := Button.new()
 resume.text = "RESUME RIDING"
 resume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 resume.pressed.connect(game.toggle_menu)
 footer.add_child(resume)
 var quit := Button.new()
 quit.text = "EXIT TO DESKTOP"
 quit.pressed.connect(func(): controls.save_profile(); get_tree().quit())
 footer.add_child(quit)
 controls.mappings_changed.connect(refresh_bindings)
 controls.capture_changed.connect(func(message: String):
  prompt.text = message if not message.is_empty() else "Choose another action, or resume riding."
  if controls.capture_action.is_empty(): conflicts.hide()
 )
 controls.conflict_found.connect(func(actions: Array):
  conflicts.show()
  swap_button.disabled = actions.size() != 1
  (swap_button if not swap_button.disabled else conflicts.get_child(1)).grab_focus()
 )
 controls.device_changed.connect(func(message: String): devices.text = message)

func page(title: String) -> VBoxContainer:
 var scroll := ScrollContainer.new()
 scroll.name = title
 scroll.follow_focus = true
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 tabs.add_child(scroll)
 var content := VBoxContainer.new()
 content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 content.add_theme_constant_override("separation", 8)
 scroll.add_child(content)
 return content

func toggle(parent: Node, title: String, option: String) -> void:
 var button := CheckButton.new()
 button.text = title
 button.button_pressed = controls.options[option]
 button.toggled.connect(func(value: bool): controls.set_option(option, value))
 parent.add_child(button)

func slider(parent: Node, title: String, option: String, minimum: float, maximum: float, step: float) -> void:
 var row := HBoxContainer.new()
 parent.add_child(row)
 var label := Label.new()
 label.custom_minimum_size.x = 540
 label.text = "%s  %.2f" % [title, controls.options[option]]
 row.add_child(label)
 var slider := HSlider.new()
 slider.custom_minimum_size.x = 300
 slider.min_value = minimum
 slider.max_value = maximum
 slider.step = step
 slider.value = controls.options[option]
 slider.value_changed.connect(func(value: float):
  label.text = "%s  %.2f" % [title, value]
  controls.set_option(option, value)
 )
 row.add_child(slider)

func refresh_bindings() -> void:
 for action in controls.ACTIONS:
  for device in ["keyboard", "gamepad"]: binding_buttons[action + "/" + device].text = controls.label_for(action, device)
