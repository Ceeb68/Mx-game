extends Node
## Explicit exported-build self-test. Never runs during a normal play session.
func _ready() -> void: call_deferred("run")
func ticks(count: int) -> void:
 for i in range(count): await get_tree().physics_frame
func run() -> void:
 var game=get_parent()
 var bike=game.bike
 game.controls.set_physics_process(false)
 bike.steering_assist=true
 bike.foot_support=true
 bike.engine.automatic=true
 bike.engine.clutch_assist=true
 bike.reset_at(Transform3D(Basis.IDENTITY,Vector3(-24,1.0,25)))
 await ticks(360)
 var supported: bool=bike.wheels[0].grounded and bike.wheels[1].grounded
 bike.command.throttle=0.7
 await ticks(720)
 var speed: float=bike.linear_velocity.length()
 var accelerated: bool=speed>3 and not bike.crashed
 bike.command.throttle=0
 bike.command.front_brake=0.5
 bike.command.rear_brake=0.25
 await ticks(180)
 var slowed: bool=bike.linear_velocity.length()<speed-0.5 and not bike.crashed
 var rider=game.rider_animation
 var rigged: bool=rider.skeleton.get_bone_count()==17 and rider.pose_ticks>100
 var expected: String="MotorcycleSimulation/v2" if "--legacy" in OS.get_cmdline_user_args() else "ReducedCoordinateMotorcycle/v3.3-landing"
 var controller_ok: bool=bike.SIMULATION_VERSION==expected and bike.simulation_ticks>1000
 var ok: bool=supported and accelerated and slowed and rigged and controller_ok
 print("BUILD_SMOKE ",JSON.stringify({"passed":ok,"supported":supported,"accelerated":accelerated,"braked":slowed,"rider_rig":rigged,"controller":bike.SIMULATION_VERSION,"speed_before_brake":speed,"speed_after_brake":bike.linear_velocity.length(),"ticks":bike.simulation_ticks}))
 get_tree().quit(0 if ok else 1)
