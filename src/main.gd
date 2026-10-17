extends Node3D
const Motorcycle = preload("res://src/physics/replacement/motorcycle.gd")
const Track = preload("res://src/world/test_track.gd")
const Visual = preload("res://src/presentation/bike_visual.gd")
const SettingsPanel = preload("res://src/ui/controls_panel.gd")
const Controls = preload("res://src/controls.gd")
var bike: RigidBody3D
var camera: Camera3D
var controls: Node
var rider_animation: Node3D
var hud: Label
var diagnostics: Label
var menu: PanelContainer
var debug_visible: bool = true
var camera_mode: int = 0
var follow_distance: float = 5.0
var camera_smoothing: float = 6.0
var recovery = preload("res://src/physics/local_recovery.gd").new()
var recovery_clock: float = 0
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
 bike = load("res://src/physics/legacy/motorcycle.gd").new() if "--legacy" in OS.get_cmdline_user_args() else Motorcycle.new()
 bike.position = spawn_points[0]
 bike.track = track
 add_child(bike)
 var presentation = load("res://src/physics/legacy/bike_visual.gd").new() if "--legacy" in OS.get_cmdline_user_args() else Visual.new()
 bike.add_child(presentation)
 rider_animation = presentation.rider
 controls = Controls.new()
 controls.bike = bike
 add_child(controls)
 controls.action_pressed.connect(handle_action)
 camera = Camera3D.new()
 camera.fov = 72
 camera.far = 700
 camera.position = bike.position + Vector3(0, 2.5, 5)
 add_child(camera)
 camera.current = true
 make_ui()
 if "--self-test" in OS.get_cmdline_user_args(): add_child(preload("res://src/diagnostics/build_smoke.gd").new())
 print("TERRA_MX_RUNTIME engine=GodotPhysics3D script=",bike.get_script().resource_path," controller=", bike.SIMULATION_VERSION, " physics_hz=", Engine.physics_ticks_per_second, " terrain=physical_heightfield bike=250F")

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
 subtitle.text = "250F   /   GROUND TEST 3.4 EXPERIMENTAL   /   240 Hz"
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
 help.text = "250F  /  GROUND TEST 3.4 EXPERIMENTAL
Controls: open Settings → Controls
Escape: menu recovery   •   All bindings save automatically"
 root.add_child(help)
 menu = SettingsPanel.new()
 menu.game = self
 menu.controls = controls
 root.add_child(menu)
 menu.hide()

func toggle_menu() -> void:
 menu.visible = not menu.visible
 bike.freeze = menu.visible
 controls.paused = menu.visible
 controls.clear_commands()
 if menu.visible:
  menu.find_children("", "Button", true, false)[0].grab_focus()
 else:
  controls.cancel_capture()
  controls.await_neutral = true
  controls.save_profile()

func handle_action(action: String) -> void:
 match action:
  "settings": toggle_menu()
  "gear_up": bike.engine.shift(1)
  "gear_down": bike.engine.shift(-1)
  "posture": bike.command.stand = not bike.command.stand
  "reset": reset_bike()
  "camera": camera_mode = (camera_mode + 1) % 2
  "diagnostics": debug_visible = not debug_visible
  "next_lane":
   lane = (lane + 1) % spawn_points.size()
   reset_bike(true)

func _unhandled_input(event: InputEvent) -> void:
 # Recovery shortcut cannot be lost through a conflicting/custom menu mapping.
 if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE and controls.bindings.settings != KEY_ESCAPE and controls.capture_action.is_empty(): toggle_menu()

func reset_bike(to_lane: bool = false) -> void:
 var pose: Transform3D
 if to_lane:
  recovery.select_lane(spawn_points[lane])
  pose=Transform3D(Basis.IDENTITY,spawn_points[lane])
 else:
  pose=recovery.resolve(bike,spawn_points[lane])
 bike.reset_at(pose)
 controls.clear_commands()

func _physics_process(dt: float) -> void:
 recovery_clock+=dt
 if recovery_clock>=0.25 and not bike.reset_requested:
  recovery.record(bike)
  recovery_clock=0

func _process(dt: float) -> void:
 elapsed += dt
 camera.fov = controls.options.fov
 follow_distance = controls.options.follow_distance
 var forward: Vector3 = -bike.global_basis.z
 var heading: Vector3 = Vector3(forward.x, 0, forward.z).normalized()
 if heading.length() < 0.5: heading = Vector3.FORWARD
 var target: Vector3 = bike.global_position + Vector3.UP * 0.55
 var desired: Vector3 = target - heading * follow_distance + Vector3.UP * 2.0
 camera.set_cull_mask_value(2, camera_mode == 0)
 if camera_mode == 1:
  var head: Vector3 = rider_animation.joint_positions.get("head", Vector3(0, 1.0, -0.2))
  desired = bike.to_global(head + Vector3(0, 0.13, -0.18))
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
%s   •   %s    %s" % [bike.linear_velocity.length() * 3.6, bike.engine.gear, rpm, "CRASH — R TO RESET" if bike.crashed else ("RELEASE INPUTS TO RESUME" if controls.await_neutral else "FREE PRACTICE"), "AUTO" if bike.engine.automatic else "MANUAL", "STANDING" if bike.command.stand else "SEATED"]
 diagnostics.visible = debug_visible
 if debug_visible:
  var f = bike.wheels[0]
  var r = bike.wheels[1]
  diagnostics.text = "Godot Physics • ACTIVE: %s   |   tick %d   Δt %.5f s
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
Last crash: %s" % [bike.SIMULATION_VERSION, bike.simulation_ticks, bike.last_dt, rad_to_deg(bike.lean_angle), rad_to_deg(bike.steer_angle), "ON" if bike.steering_assist else "OFF", "ON" if bike.foot_support else "OFF", bike.angular_velocity.x, bike.angular_velocity.y, bike.angular_velocity.z, f.load, r.load, f.compression * 1000, r.compression * 1000, f.slip, r.slip, rad_to_deg(f.slip_angle), rad_to_deg(r.slip_angle), str(f.grounded), str(r.grounded), f.surface, r.surface, bike.force_total.x, bike.force_total.y, bike.force_total.z, bike.steering_torque, bike.support_torque, rpm, bike.engine.clutch_torque, bike.airborne_time, bike.last_crash]

  diagnostics.text += "\nTarget lean %+.1f°   patch samples %d / %d\nGrip use %.0f / %.0f%%   saved input profile v2" % [rad_to_deg(bike.virtual_rider.lean_request), f.contact_samples, r.contact_samples, f.utilization * 100, r.utilization * 100]

  if bike.SIMULATION_VERSION.begins_with("ReducedCoordinateMotorcycle/"):
   diagnostics.text += "\nSprung 165 + unsprung 7 / 9 kg   wheel steps 960 Hz\nAxle velocity %+.2f / %+.2f m/s   requested front Fy %+.0f N" % [bike.stations[0].velocity,bike.stations[1].velocity,bike.virtual_rider.desired_front_force]

   diagnostics.text += "\nInput raw %+.2f / command %+.2f   steer target %+.1f°\nLateral velocity F/R %+.2f / %+.2f m/s\nTire Fx / Fy  F %+.0f / %+.0f N   R %+.0f / %+.0f N\nApplied world F %.0f / %.0f / %.0f N\nApplied world R %.0f / %.0f / %.0f N" % [controls.strength("right")-controls.strength("left"),bike.command.steer,rad_to_deg(bike.steering_target),f.lateral_velocity,r.lateral_velocity,f.force.x,f.force.y,r.force.x,r.force.y,f.applied_force.x,f.applied_force.y,f.applied_force.z,r.applied_force.x,r.applied_force.y,r.applied_force.z]

   diagnostics.text += "\nCrash condition: %s (%.2f s)   reset: %s" % [bike.severe_reason,bike.crash_time,recovery.last_source]
   if not bike.landing_events.is_empty():
    var touchdown: Dictionary=bike.landing_events[-1]
    diagnostics.text += "\nTouchdown %s | closing %.1f m/s | peak %.0f N" % [touchdown.first_contact,touchdown.closing_m_s,touchdown.peak_load_n]
