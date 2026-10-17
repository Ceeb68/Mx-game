extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 var bike=game.bike
 game.controls.set_physics_process(false)
 bike.reset_at(Transform3D(Basis.IDENTITY,Vector3(-24,0.78,25)))
 for i in range(3): await physics_frame
 for i in range(960):
  bike.command.throttle=0.55
  bike.command.steer=0.25 if i>360 else 0
  await physics_frame
  if i%30==0: print("START ",i," speed ",bike.linear_velocity.length()," roll ",rad_to_deg(bike.lean_angle)," target ",rad_to_deg(bike.virtual_rider.lean_request)," steer ",rad_to_deg(bike.steer_angle)," angular ",bike.angular_velocity," foot ",bike.support_torque," contacts ",bike.wheels[0].load," ",bike.wheels[1].load," crash ",bike.crashed)
 quit()
