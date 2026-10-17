extends SceneTree
var failures: int = 0
var checks: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String, evidence: Variant = null) -> void:
 checks+=1
 print("PASS " if ok else "FAIL ",text," ",JSON.stringify(evidence))
 if not ok: failures+=1
func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 for i in range(8): await physics_frame
 var bike=game.bike
 var rider=game.bike.get_child(1).rider
 bike.freeze=true
 game.controls.set_physics_process(false)
 check(rider.pose_ticks>0 and rider.skeleton.get_bone_count()==17,"active rider is driven by a 17-bone Skeleton3D")
 var meshes=rider.model.find_children("*","MeshInstance3D",true,false)
 var skinned: bool=false
 for mesh in meshes:
  if mesh.skin!=null: skinned=true
 check(skinned,"rendered rider uses actual imported skin weights",meshes.size())
 rider.set_process(false)
 var worst_error: float=0
 var max_hand_error: float=0
 var max_foot_error: float=0
 var greatest_step: float=0
 var poses: Array=[]
 var previous: Vector3=rider.joint_positions.pelvis
 for command in [[true,0.0,0.0,0.0],[false,0.0,0.0,0.0],[true,1.0,0.0,0.0],[true,-1.0,0.0,0.0],[true,0.0,1.0,0.45],[true,0.0,-1.0,-0.45],[false,1.0,0.5,0.3]]:
  bike.command.stand=command[0]
  bike.command.weight=command[1]
  bike.command.lean=command[2]
  bike.steer_angle=command[3]
  for i in range(90):
   rider.update_pose(1.0/60)
   var pelvis: Vector3=rider.joint_positions.pelvis
   greatest_step=maxf(greatest_step,pelvis.distance_to(previous))
   previous=pelvis
   worst_error=maxf(worst_error,rider.limb_error)
   for suffix in ["L","R"]:
    var hand_pose: Transform3D=rider.skeleton.get_bone_global_pose(rider.bone_ids["hand."+suffix])
    var foot_pose: Transform3D=rider.skeleton.get_bone_global_pose(rider.bone_ids["foot."+suffix])
    max_hand_error=maxf(max_hand_error,rider.skeleton.to_global(hand_pose.origin).distance_to(bike.to_global(rider.hand_targets[suffix])))
    max_foot_error=maxf(max_foot_error,rider.skeleton.to_global(foot_pose.origin).distance_to(bike.to_global(rider.foot_targets[suffix])))
  poses.append(rider.joint_positions.pelvis)
 check(absf(poses[0].y-poses[1].y)>0.20,"sit and stand produce distinct correctly scaled skeletal poses",poses.slice(0,2))
 check(greatest_step<0.035,"posture and body movement blend smoothly at 60 FPS",greatest_step)
 check(worst_error<0.002,"two-bone IK preserves arm and leg lengths across body and steering extremes",worst_error)
 check(max_hand_error<0.001,"actual wrist bones remain attached to rotating handlebar targets",max_hand_error)
 check(max_foot_error<0.001,"actual ankle bones remain attached to footpeg targets",max_foot_error)
 check(poses[2].z<poses[3].z-0.15 and poses[4].x>0.08 and poses[5].x< -0.08,"rider visibly shifts forward, backward, left and right")
 var velocity: Vector3=bike.linear_velocity
 var angular: Vector3=bike.angular_velocity
 rider.update_pose(1.0/60)
 check(bike.linear_velocity==velocity and bike.angular_velocity==angular,"rider animation adds no chassis velocity or stabilizing force")
 game.camera_mode=1
 game._process(1.0/60)
 var helmet_mask: bool=not game.camera.get_cull_mask_value(2)
 game.camera_mode=0
 game._process(1.0/60)
 check(helmet_mask and game.camera.get_cull_mask_value(2) and meshes[0].layers==2,"helmet camera hides the self-occluding rider skin; chase camera restores it")
 print("RIDER_RESULT checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
