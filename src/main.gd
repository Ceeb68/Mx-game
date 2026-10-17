extends Node3D
const Motorcycle = preload("res://src/physics/motorcycle.gd")
const Track = preload("res://src/world/test_track.gd")
const Visual = preload("res://src/presentation/bike_visual.gd")
const Controls = preload("res://src/controls.gd")
var bike: RigidBody3D
var camera: Camera3D
var controls: Node
var hud: Label
var diagnostics: Label
var menu: PanelContainer
var debug_visible: bool = true
var camera_mode: int = 0
var follow_distance: float = 5.0
var camera_smoothing: float = 6.0
var lane: int = 0
var spawn_points := [Vector3(0, 1.1, 15), Vector3(-24, 1.1, 15), Vector3(22, 1.1, -18), Vector3(42, 1.1, -18), Vector3(-53, 1.1, 15), Vector3(78, 1.1, -35)]
var elapsed: float = 0.0

func _ready() -> void:
 var environment := WorldEnvironment.new()
 var env := Environment.new()
 env.background_mode = Environment.BG_SKY
 var sky := Sky.new()
 var sky_mat := ProceduralSkyMaterial.new()
 sky_mat.sky_top_color = Color(0.20, 0.38, 0.52)
 sky_mat.sky_horizon_color = Color(0.77, 0.81, 0.77)
 sky.sky_material = sky_mat
 env.sky = sky
 env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 env.ambient_light_color = Color(0.72, 0.79, 0.89)
 env.ambient_light_energy = 0.6
 env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
 environment.environment = env
 add_child(environment)
 var sun := DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-42, -30, 0)
 sun.light_color = Color(1.0, 0.9, 0.75)
 sun.light_energy = 1.6
 sun.shadow_enabled = true
 sun.directional_shadow_max_distance = 150
 add_child(sun)
 var track := Track.new()
 add_child(track)
 bike = Motorcycle.new()
 bike.position = spawn_points[0]
 bike.track = track
 add_child(bike)
 bike.add_child(Visual.new())
 controls = Controls.new()
 controls.bike = bike
 add_child(controls)
 camera = Camera3D.new()
 camera.fov = 72
 camera.far = 700
 camera.position = bike.position + Vector3(0, 2.5, 5)
 add_child(camera)
 camera.current = true
 make_ui()
 print("TERRA_MX_RUNTIME controller=MotorcycleSimulation/v1 physics_hz=", Engine.physics_ticks_per_second, " terrain=physical_heightfield bike=250F")

func make_ui() -> void:
 var canvas := CanvasLayer.new()
 add_child(canvas)
 var root := Control.new()
 root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 root.mouse_filter = Control.MOUSE_FILTER_IGNORE
 canvas.add_child(root)
 var header := Label.new()
 header.position = Vector2(30, 20)
 header.text = "TERRA / MX     •     DYNAMICS LAB"
 header.add_theme_font_size_override("font_size", 26)
 root.add_child(header)
 var subtitle := Label.new()
 subtitle.position = Vector2(31, 55)
 subtitle.text = "250F   /   DEVELOPMENT BUILD   /   240 Hz"
 subtitle.modulate = Color(1, 0.65, 0.3)
 root.add_child(subtitle)
 hud = Label.new()
 hud.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
 hud.position = Vector2(30, -135)
 hud.add_theme_font_size_override("font_size", 25)
 root.add_child(hud)
 diagnostics = Label.new()
 diagnostics.position = Vector2(30, 100)
 diagnostics.add_theme_font_size_override("font_size", 16)
 diagnostics.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.04))
 diagnostics.add_theme_constant_override("outline_size", 5)
 root.add_child(diagnostics)
 var help := Label.new()
 help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
 help.position = Vector2(-560, -100)
 help.text = "W / S  throttle / front brake     SPACE  rear brake
A / D  steer     ↑ / ↓  body     Q / E  lateral lean
PGUP / PGDN  shift     SHIFT  clutch     TAB  posture
R  reset     F6  next lane     C  camera     F1  telemetry     ESC  settings"
 root.add_child(help)
 menu = PanelContainer.new()
 menu.position = Vector2(460, 120)
 menu.custom_minimum_size = Vector2(500, 570)
 var style := StyleBoxFlat.new()
 style.bg_color = Color(0.045, 0.065, 0.075, 0.98)
 style.content_margin_left = 24
 style.content_margin_right = 24
 style.content_margin_top = 20
 style.content_margin_bottom = 20
 menu.add_theme_stylebox_override("panel", style)
 root.add_child(menu)
 var list := VBoxContainer.new()
 list.add_theme_constant_override("separation", 12)
 menu.add_child(list)
 var title := Label.new()
 title.text = "SESSION / CONTROLS"
 title.add_theme_font_size_override("font_size", 24)
 list.add_child(title)
 for item in [["Steering assistance (steering torque only)", "steering_assist"], ["Low-speed foot support (≤ 3 m/s)", "foot_support"], ["Automatic shifts", "automatic"], ["Clutch assistance", "clutch_assist"]]:
  var check := CheckButton.new()
  check.text = item[0]
  check.button_pressed = true
  var property: String = item[1]
  check.toggled.connect(func(on: bool):
   if property == "automatic" or property == "clutch_assist": bike.engine.set(property, on)
   else: bike.set(property, on)
  )
  list.add_child(check)
 add_slider(list, "Camera field of view", 50, 100, 72, func(v: float): camera.fov = v)
 add_slider(list, "Chase distance / m", 3, 10, 5, func(v: float): follow_distance = v)
 add_slider(list, "Input sensitivity", 0.2, 2, 1, func(v: float): controls.sensitivity = v)
 add_slider(list, "Gamepad deadzone", 0, 0.4, 0.12, func(v: float): controls.deadzone = v)
 var resume := Button.new()
 resume.text = "RESUME RIDING"
 resume.pressed.connect(toggle_menu)
 list.add_child(resume)
 var quit_button := Button.new()
 quit_button.text = "EXIT TO DESKTOP"
 quit_button.pressed.connect(func(): get_tree().quit())
 list.add_child(quit_button)
 menu.hide()

func add_slider(parent: Node, title: String, minimum: float, maximum: float, value: float, callback: Callable) -> void:
 var label := Label.new()
 label.text = "%s  %.2f" % [title, value]
 parent.add_child(label)
 var slider := HSlider.new()
 slider.min_value = minimum
 slider.max_value = maximum
 slider.step = 0.01
 slider.value = value
 slider.value_changed.connect(func(v: float):
  label.text = "%s  %.2f" % [title, v]
  callback.call(v)
 )
 parent.add_child(slider)

func toggle_menu() -> void:
 menu.visible = not menu.visible
 # Freeze the simulation explicitly, rather than letting a paused rider roll away.
 bike.freeze = menu.visible
 controls.paused = menu.visible
 for action in ["throttle", "front_brake", "rear_brake", "steer", "lean", "weight", "clutch"]:
  bike.command[action] = 0.0
 if menu.visible: menu.find_children("", "Button", true, false)[0].grab_focus()

func _unhandled_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo:
  var code: int = event.physical_keycode
  if code == controls.bindings.settings: toggle_menu()
  elif code == controls.bindings.diagnostics: debug_visible = not debug_visible
  elif code == controls.bindings.camera: camera_mode = (camera_mode + 1) % 2
  elif code == controls.bindings.reset: reset_bike()
  elif code == controls.bindings.next_lane:
   lane = (lane + 1) % spawn_points.size()
   reset_bike()
 if event is InputEventJoypadButton and event.pressed:
  if event.button_index == controls.pad_bindings.settings: toggle_menu()
  if event.button_index == controls.pad_bindings.reset: reset_bike()
  if event.button_index == controls.pad_bindings.camera: camera_mode = (camera_mode + 1) % 2

func reset_bike() -> void:
 bike.reset_at(Transform3D(Basis.IDENTITY, spawn_points[lane]))
 controls.steer = 0.0

func _process(dt: float) -> void:
 elapsed += dt
 var forward: Vector3 = -bike.global_basis.z
 var heading: Vector3 = Vector3(forward.x, 0, forward.z).normalized()
 if heading.length() < 0.5: heading = Vector3.FORWARD
 var target: Vector3 = bike.global_position + Vector3.UP * 0.55
 var desired: Vector3 = target - heading * follow_distance + Vector3.UP * 2.0
 if camera_mode == 1:
  desired = bike.global_position + bike.global_basis * Vector3(0, 1.12, -0.18)
  target = desired + heading * 10 + Vector3.DOWN * 0.8
 # Camera terrain ray, excluding the motorcycle; avoid clipping across jump faces.
 var query := PhysicsRayQueryParameters3D.create(target, desired, 1, [bike.get_rid()])
 var hit := get_world_3d().direct_space_state.intersect_ray(query)
 if not hit.is_empty(): desired = hit.position + hit.normal * 0.3
 desired.y = maxf(desired.y, bike.track.height_at(desired.x, desired.z) + 0.45)
 camera.global_position = camera.global_position.lerp(desired, 1 - exp(-dt * camera_smoothing))
 if camera.global_position.distance_to(target) > 0.1: camera.look_at(target)
 var rpm: float = bike.engine.rpm
 hud.text = "%03d km/h    %d GEAR    %05d RPM
%s   •   %s    %s" % [bike.linear_velocity.length() * 3.6, bike.engine.gear, rpm, "CRASH — R TO RESET" if bike.crashed else "FREE PRACTICE", "AUTO" if bike.engine.automatic else "MANUAL", "STANDING" if bike.command.stand else "SEATED"]
 diagnostics.visible = debug_visible
 if debug_visible:
  var f = bike.wheels[0]
  var r = bike.wheels[1]
  diagnostics.text = "ACTIVE: MotorcycleSimulation/v1   |   tick %d   Δt %.5f s
Lean %+5.1f°   steer %+5.1f°   assist %s   feet %s
Angular rate xyz: %+.2f / %+.2f / %+.2f rad/s
             FRONT          REAR
Load         %5.0f N        %5.0f N
Compression  %5.0f mm       %5.0f mm
Slip ratio   %+.3f         %+.3f
Slip angle   %+.1f°          %+.1f°
Contact      %s            %s
Surface      %s / %s
Force Σ      %.0f / %.0f / %.0f N
Steer torque %.1f Nm   foot torque %.1f Nm
Crank %.0f RPM   clutch %.1f Nm   air %.2f s
Last crash: %s" % [bike.simulation_ticks, bike.last_dt, rad_to_deg(bike.lean_angle), rad_to_deg(bike.steer_angle), "ON" if bike.steering_assist else "OFF", "ON" if bike.foot_support else "OFF", bike.angular_velocity.x, bike.angular_velocity.y, bike.angular_velocity.z, f.load, r.load, f.compression * 1000, r.compression * 1000, f.slip, r.slip, rad_to_deg(f.slip_angle), rad_to_deg(r.slip_angle), str(f.grounded), str(r.grounded), f.surface, r.surface, bike.force_total.x, bike.force_total.y, bike.force_total.z, bike.steering_torque, bike.support_torque, rpm, bike.engine.clutch_torque, bike.airborne_time, bike.last_crash]
