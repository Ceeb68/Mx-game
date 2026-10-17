extends RefCounted
## Terrain-validated local recovery; never writes a running body's pose directly.
var checkpoint: Transform3D = Transform3D.IDENTITY
var has_checkpoint: bool = false
var last_source: String = "lane fallback"
func heading_basis(basis: Basis) -> Basis:
 var forward: Vector3=(-basis.z).slide(Vector3.UP)
 if forward.length_squared()<0.05:forward=-checkpoint.basis.z if has_checkpoint else Vector3.FORWARD
 return Basis.looking_at(forward.normalized(),Vector3.UP)
func candidate(bike: RigidBody3D, location: Vector3, basis: Basis) -> Dictionary:
 # Physical mesh extents, with a margin so the entire bike stays on terrain.
 if location.x < -88 or location.x > 128 or location.z < -218 or location.z > 58:return {}
 var space=bike.get_world_3d().direct_space_state
 var high: float=-INF
 var low: float=INF
 for offset in [Vector3.ZERO,basis.x*0.5,-basis.x*0.5,basis.z*1.0,-basis.z*1.0]:
  var p: Vector3=location+offset
  var q=PhysicsRayQueryParameters3D.create(Vector3(p.x,maxf(location.y+4,10),p.z),Vector3(p.x,-30,p.z),1,[bike.get_rid()])
  var hit=space.intersect_ray(q)
  if hit.is_empty() or hit.normal.y<0.82:return {}
  high=maxf(high,hit.position.y)
  low=minf(low,hit.position.y)
 if high-low>0.65:return {}
 var pose:=Transform3D(basis,Vector3(location.x,high+0.95,location.z))
 var query:=PhysicsShapeQueryParameters3D.new()
 var shape:=BoxShape3D.new()
 shape.size=Vector3(0.5,0.5,1.5)
 query.shape=shape
 query.transform=pose
 query.collision_mask=1
 query.exclude=[bike.get_rid()]
 if not space.intersect_shape(query,1).is_empty():return {}
 return {"pose":pose}
func record(bike: RigidBody3D) -> void:
 if bike.crashed or bike.crash_time>0 or bike.global_basis.y.dot(Vector3.UP)<0.85:return
 if not bike.wheels[0].grounded or not bike.wheels[1].grounded:return
 var hit=candidate(bike,bike.global_position,heading_basis(bike.global_basis))
 if not hit.is_empty():
  checkpoint=hit.pose
  has_checkpoint=true
func resolve(bike: RigidBody3D, fallback: Vector3) -> Transform3D:
 var basis:=heading_basis(bike.global_basis)
 for radius in [0.0,2.0,4.0,8.0]:
  for n in range(1 if radius==0 else 8):
   var offset:=Vector3(cos(n*TAU/8)*radius,0,sin(n*TAU/8)*radius)
   var hit=candidate(bike,bike.global_position+offset,basis)
   if not hit.is_empty():
    last_source="current area" if radius==0 else "nearby terrain"
    return hit.pose
 if has_checkpoint:
  var hit=candidate(bike,checkpoint.origin,checkpoint.basis)
  if not hit.is_empty():
   last_source="safe checkpoint"
   return hit.pose
 last_source="lane fallback"
 return Transform3D(Basis.IDENTITY,fallback)
func select_lane(position: Vector3) -> void:
 checkpoint=Transform3D(Basis.IDENTITY,position)
 has_checkpoint=false
 last_source="lane start"
