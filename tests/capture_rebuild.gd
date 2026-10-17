extends SceneTree
func _initialize() -> void: call_deferred("run")
func frame(path: String) -> void:
 for i in range(3): await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(path)
func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 for i in range(8): await process_frame
 game.bike.freeze=true
 game.controls.paused=true
 game.set_process(false)
 game.hud.hide()
 var visual=game.bike.get_child(1)
 visual.set_process(false)
 game.camera.fov=45
 game.camera.position=game.bike.position+Vector3(2.3,0.95,-2.6)
 game.camera.look_at(game.bike.position+Vector3(0,0.25,-0.25))
 game.bike.steer_angle=0.40
 game.bike.wheels[0].extension=0.43
 visual._process(0)
 game.diagnostics.text="FROZEN ARTICULATION VIEW • v3\nSteer +22.9° • fork extension 430 mm\nThese are mechanism inspection poses, not a riding sequence."
 await frame("res://docs/rebuild-fork-extended.png")
 game.bike.wheels[0].extension=0.15
 visual._process(0)
 game.diagnostics.text="FROZEN ARTICULATION VIEW • v3\nSteer +22.9° • fork extension 150 mm\nHigh fender stays on triple clamp; axle travels beneath it."
 await frame("res://docs/rebuild-fork-compressed.png")
 game.bike.wheels[0].extension=0.38
 game.bike.steer_angle=-0.40
 visual._process(0)
 game.diagnostics.text="FROZEN ARTICULATION VIEW • v3\nSteer −22.9° • fork extension 380 mm\nBars, fender, clamps and axle share the raked steering pivot."
 await frame("res://docs/rebuild-steering-opposite.png")
 print("REBUILD_CAPTURE three rendered mechanism views saved")
 quit()
