extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var scene = load("res://scenes/main.tscn").instantiate()
 root.add_child(scene)
 for i in range(6): await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://docs/prototype.png")
 scene.toggle_menu()
 for i in range(2): await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://docs/settings.png")
 print("RENDER_CAPTURE saved prototype.png and settings.png")
 quit()
