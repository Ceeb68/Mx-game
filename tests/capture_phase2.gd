extends SceneTree
func _initialize() -> void: call_deferred("run")
func frame(path: String) -> void:
 for i in range(2): await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(path)
func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 for i in range(8): await process_frame
 game.bike.freeze=true
 game.controls.paused=true
 game.set_process(false)
 game.diagnostics.hide()
 game.hud.hide()
 var rider=game.bike.get_child(1).rider
 game.camera.fov=50
 game.camera.position=game.bike.position+Vector3(2.0,1.25,2.5)
 game.camera.look_at(game.bike.position+Vector3(0,0.55,0))
 await frame("res://docs/phase2-standing.png")
 game.camera.position=game.bike.position+Vector3(-1.8,1.3,-2.3)
 game.camera.look_at(game.bike.position+Vector3(0,0.55,0))
 await frame("res://docs/phase2-front.png")
 game.bike.command.stand=false
 for i in range(90): rider.update_pose(1.0/60)
 game.camera.position=game.bike.position+Vector3(2.1,1.1,1.8)
 game.camera.look_at(game.bike.position+Vector3(0,0.45,0))
 await frame("res://docs/phase2-seated.png")
 game.camera_mode=1
 game._process(1.0)
 await frame("res://docs/phase2-helmet.png")
 game.camera_mode=0
 game._process(1.0)
 game.menu.show()
 game.menu.tabs.current_tab=1
 await frame("res://docs/phase2-controls.png")
 game.menu.tabs.current_tab=2
 await frame("res://docs/phase2-response.png")
 print("PHASE2_CAPTURE six rendered views saved")
 quit()
