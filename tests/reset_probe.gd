extends SceneTree
func _initialize() -> void:call_deferred("run")
func ticks(n: int) -> void:
 for i in range(n):await physics_frame
func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 game.controls.set_physics_process(false)
 var results: Array=[]
 for scenario in ["upright","crashed","half_track","near_jump","invalid_terrain","lane_switch"]:
  var p:=Vector3(-24,0.95,-60)
  if scenario=="near_jump":p=Vector3(0,2.45,-52)
  game.bike.reset_at(Transform3D(Basis(Vector3.UP,0.3),p))
  await ticks(120)
  if scenario=="crashed":game.bike.crashed=true
  if scenario=="invalid_terrain":
   game.bike.reset_at(Transform3D(Basis.IDENTITY,Vector3(1000,1,1000)))
   await ticks(4)
  var before: Vector3=game.bike.position
  if scenario=="lane_switch":game.handle_action("next_lane")
  else:game.reset_bike()
  await ticks(4)
  var after: Vector3=game.bike.position
  results.append({"scenario":scenario,"before":[before.x,before.y,before.z],"after":[after.x,after.y,after.z],"horizontal_reset_distance_m":Vector2(after.x-before.x,after.z-before.z).length(),"crashed_after":game.bike.crashed,"speed_after_m_s":game.bike.linear_velocity.length()})
 FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify(results))
 print("RESET_COMPARISON ",JSON.stringify(results))
 quit()
