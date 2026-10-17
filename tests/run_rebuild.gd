extends SceneTree
const Tire = preload("res://src/physics/replacement/contact_tire.gd")
const Station = preload("res://src/physics/replacement/wheel_station.gd")
const Geometry = preload("res://src/physics/replacement/geometry.gd")
var checks: int = 0
var failures: int = 0
var evidence: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label_: String, value: Variant = null) -> void:
 checks += 1
 if not ok: failures += 1
 evidence.append({"check":label_,"passed":ok,"evidence":value})
 print("PASS " if ok else "FAIL ",label_," ",JSON.stringify(value))
func ticks(n: int) -> void:
 for i in range(n): await physics_frame
func run() -> void:
 var game = load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 var bike = game.bike
 game.controls.set_physics_process(false)
 check(bike.get_script().resource_path == "res://src/physics/replacement/motorcycle.gd" and bike.SIMULATION_VERSION == "ReducedCoordinateMotorcycle/v3.4-ground-experimental","shipped scene selects replacement implementation",bike.telemetry())
 check(ProjectSettings.get_setting("physics/3d/physics_engine") == "GodotPhysics3D","collision backend explicitly selected: Godot Physics")
 check(absf(bike.mass + 16 - bike.config.mass_kg)<0.001,"sprung and unsprung masses sum to 181 kg",[bike.mass,7,9])
 bike.reset_at(Transform3D(Basis.IDENTITY,Vector3(-24,1,25)))
 await ticks(720)
 check(absf(bike.wheels[0].load + bike.wheels[1].load - 181*9.81)<40,"independent tire loads support total mass",[bike.wheels[0].load,bike.wheels[1].load])
 check(bike.linear_velocity.length()<0.02,"no idle creep from raked suspension guide",bike.linear_velocity.length())
 check(absf(bike.stations[0].load-bike.stations[0].spring_force)>40,"contact load is distinct from suspension force (unsprung mass)",[bike.stations[0].load,bike.stations[0].spring_force])
 var station=Station.new(0)
 var legacy=load("res://src/physics/legacy/suspension.gd")
 var old_force: float=legacy.normal_load(bike.config,0,0.12,0)
 station.step(1.0/960,0.12,0,1,0,bike.config,true)
 check(station.compression>0 and station.compression<0.01 and station.load>old_force,"road step excites wheel inertia instead of directly assigning compression",{"new_compression":station.compression,"new_contact_load":station.load,"legacy_instant_load":old_force})
 for i in range(960): station.step(1.0/960,0.12,0,1,0,bike.config,true)
 check(absf(station.velocity)<0.02 and station.compression>0.05 and station.compression<0.12,"wheel transient settles through spring and carcass compliance",[station.compression,station.velocity])
 var inverse_tire=Tire.new(0.335,0.85)
 inverse_tire.load=900
 inverse_tire.omega=10/inverse_tire.radius
 var angle: float=inverse_tire.lateral_angle_for_force(1.0/240,300,10,0.04)
 var inverse_force: Vector2=inverse_tire.forces(1.0/240,10,10*tan(angle),0.85,0,0,0,Vector2(0.01,0.04))
 check(absf(inverse_force.y-300)<0.01,"rider inverse requests the intended transient force from the production tire law",inverse_force)
 var tire=Tire.new(0.335,0.85)
 tire.load=900
 tire.omega=10/tire.radius
 var f: Vector2=tire.forces(1.0/240,10,0.5,0.85,0)
 check(f.y<0 and f.length()<=765,"new tread contact opposes lateral slip without velocity locking",f)
 var first: float=f.y
 f=tire.forces(1.0/240,10,0,0.85,0)
 check(f.y<0 and absf(f.y)<absf(first),"tread stores and progressively releases elastic shear",[first,f.y])
 tire.omega=100
 for i in range(240): f=tire.forces(1.0/240,10,8,0.85,0)
 check(tire.sliding and f.x>0 and f.y<0 and f.length()<=765.001,"combined high-slip demand enters finite sliding friction",[f,tire.slip,tire.utilization])
 tire.load=50
 f=tire.forces(1.0/240,10,8,0.85,0)
 check(f.length()<=42.501,"unloading immediately reduces combined force",f)
 tire.detach()
 check(tire.force==Vector2.ZERO and tire.tread==Vector2.ZERO,"airborne tire clears stored ground shear")
 var visual=bike.get_child(1)
 bike.freeze=true
 visual.set_process(false)
 bike.steer_angle=0.4
 bike.wheels[0].extension=0.40
 visual._process(0)
 var fender=visual.steering.get_node("FrontFender")
 var before: Transform3D=fender.transform
 var fender_world: Transform3D=fender.global_transform
 var hub_before: Vector3=visual.hubs[0].global_position
 bike.wheels[0].extension=0.22
 visual._process(0)
 check(fender.get_parent()==visual.steering and visual.hubs[0].get_parent()==visual.steering,"front fender and axle share steering assembly")
 check(fender.transform==before and fender.global_transform.is_equal_approx(fender_world) and visual.hubs[0].global_position.distance_to(hub_before)>0.17,"fork compression moves axle relative to fixed high fender",visual.hubs[0].global_position.distance_to(hub_before))
 check(visual.hubs[0].position.is_equal_approx(Geometry.hub(0,0.22,0)-Geometry.HEAD),"rendered axle exactly matches simulated raked fork geometry")
 var rear_length_a: float=Geometry.hub(1,0.43,0).distance_to(Geometry.REAR_PIVOT)
 var rear_length_b: float=Geometry.hub(1,0.13,0).distance_to(Geometry.REAR_PIVOT)
 check(absf(rear_length_a-rear_length_b)<0.00001,"rear axle follows constant-length swingarm arc",[rear_length_a,rear_length_b])
 check(absf(visual.upper_forks[0].scale.y-0.62)<0.0001 and absf(visual.lower_forks[0].scale.y-0.44)<0.0001,"telescopic fork tube lengths remain fixed")
 bike.freeze=false
 visual.set_process(true)
 bike.reset_at(Transform3D(Basis.IDENTITY,Vector3(-24,8,25)),Vector3(0,0,-10))
 bike.foot_support=false
 bike.command.clutch=1
 await ticks(60)
 check(absf(bike.angular_velocity.x)<0.02 and absf(bike.angular_velocity.z)<0.02,"freefall guide reactions do not generate unexplained chassis rotation",bike.angular_velocity)
 var pitch: float=bike.angular_velocity.x
 bike.command.weight=1
 await ticks(30)
 check(not bike.wheels[0].grounded and bike.rider_reaction.length()>1 and absf(bike.angular_velocity.x-pitch)>0.02,"airborne rider movement transfers angular momentum through torque",{"reaction":bike.rider_reaction,"pitch_change":bike.angular_velocity.x-pitch})
 check(bike.support_torque==0,"ground support never adds airborne stabilization")
 bike.command.weight=0
 bike.command.clutch=0
 bike.foot_support=true
 bike.reset_at(Transform3D(Basis.IDENTITY,Vector3(-24,0.78,25)),Vector3(0,0,-10))
 await ticks(3)
 for wheel in bike.wheels: wheel.omega=10/wheel.radius
 bike.engine.gear=2
 bike.engine.automatic=false
 bike.engine.rpm=6000
 bike.command.throttle=0.4
 await ticks(120)
 bike.command.steer=0.40
 var countersteer: float=0
 var peak_lean: float=0
 var slip_peak: float=0
 for i in range(1440):
  await physics_frame
  if i<120: countersteer=minf(countersteer,bike.steer_angle)
  peak_lean=maxf(peak_lean,absf(rad_to_deg(bike.lean_angle)))
  slip_peak=maxf(slip_peak,absf(rad_to_deg(bike.wheels[0].slip_angle)))
 check(countersteer < -0.002 and bike.lean_angle>deg_to_rad(4),"right turn begins with countersteering then develops right lean",[rad_to_deg(countersteer),rad_to_deg(bike.lean_angle)])
 check(not bike.crashed and peak_lean<35 and slip_peak<5 and bike.linear_velocity.length()>5,"six-second corner remains supported and rideable",{"peak_lean":peak_lean,"peak_front_slip":slip_peak,"speed":bike.linear_velocity.length()})
 var file=FileAccess.open("user://rebuild-results.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":evidence},"  "))
 print("REBUILD_RESULT checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
