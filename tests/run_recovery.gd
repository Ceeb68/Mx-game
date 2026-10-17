extends SceneTree
var checks: int=0
var failures: int=0
func _initialize() -> void:call_deferred("run")
func ticks(n: int) -> void:
 for i in range(n):await physics_frame
func check(ok: bool,label: String) -> void:
 checks+=1
 print("PASS " if ok else "FAIL ","recovery/",label)
 if not ok:failures+=1
func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 game.controls.set_physics_process(false)
 var bike=game.bike
 bike.reset_at(Transform3D(Basis(Vector3.UP,0.4),Vector3(-24,0.95,-60)))
 await ticks(120)
 var before: Vector3=bike.position
 var heading: Vector3=(-bike.global_basis.z).slide(Vector3.UP).normalized()
 game.reset_bike()
 await ticks(4)
 check(Vector2(bike.position.x-before.x,bike.position.z-before.z).length()<0.25 and (-bike.global_basis.z).dot(heading)>0.99 and bike.linear_velocity.length()<1,"upright reset preserves local area and horizontal heading")
 await ticks(120)
 game.recovery.record(bike)
 var checkpoint: Vector3=game.recovery.checkpoint.origin
 bike.crashed=true
 bike.crash_time=1
 bike.steer_rate=4
 bike.wheels[0].tread=Vector2(0.1,0.1)
 game.reset_bike()
 await ticks(4)
 check(not bike.crashed and bike.crash_time==0 and absf(bike.steer_rate)<0.01 and bike.wheels[0].tread.length()<0.01,"reset clears crash, steering and tire states")
 check(bike.position.distance_to(game.spawn_points[game.lane])>40,"half-track reset does not return to lane start")
 bike.reset_at(Transform3D(Basis.IDENTITY,Vector3(0,3,-52)))
 await ticks(4)
 game.reset_bike()
 await ticks(4)
 check(absf(bike.position.z+52)<0.1 and bike.position.y>2.1 and bike.position.y<3,"reset near tabletop clears physical terrain")
 bike.reset_at(Transform3D(Basis.IDENTITY,Vector3(1000,1,1000)))
 await ticks(4)
 game.reset_bike()
 await ticks(4)
 check(game.recovery.last_source=="safe checkpoint" and bike.position.distance_to(checkpoint)<1,"invalid terrain falls back to validated safe checkpoint")
 game.handle_action("next_lane")
 await ticks(4)
 check(game.lane==1 and bike.position.distance_to(game.spawn_points[1])<0.1 and game.recovery.last_source=="lane start","F6 deliberately selects the next lane start")
 check(bike.classify_crash(1.0,0.5,1,2)=="none","upright chassis contact alone is recoverable regardless of forward speed")
 check(bike.classify_crash(0.2,1.0,1,2)!="none","grounded excessive lean remains a crash condition")
 check(bike.classify_crash(0.6,7.0,1,0)=="tumbling chassis impact","fast tilted chassis impact remains severe")
 check(bike.classify_crash(0.6,7.0,0,0)=="none","airborne rotation alone does not trigger a crash")
 var station_type=load("res://src/physics/replacement/wheel_station.gd")
 var near=station_type.new(0)
 var air=station_type.new(0)
 near.compression=0.1
 air.compression=0.1
 near.velocity=-0.1
 air.velocity=-0.1
 near.step(1.0/960,-0.2,1.0,1.0,-9.81,bike.config,true)
 air.step(1.0/960,-0.2,1.0,1.0,-9.81,bike.config,false)
 check(near.load==0 and is_equal_approx(near.velocity,air.velocity) and is_equal_approx(near.compression,air.compression),"separated tire ray hit produces the same free suspension motion as air")
 near.reset()
 near.step(1.0/960,0.01,1.0,1.0,0,bike.config,true)
 check(near.load>0 and near.compression>0,"physical tire overlap engages carcass and compresses suspension")
 print("RECOVERY_RESULT checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
