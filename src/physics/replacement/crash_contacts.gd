extends RefCounted
## Native chassis contacts fitted to existing handlebar and footpeg geometry.
## These are fixed conservative envelopes, not animated wheel rigid bodies.
static func install(body: RigidBody3D) -> void:
 for part in [{"name":"HandlebarContact","center":Vector3(0,0.48,-0.55),"width":0.80,"radius":0.025}, {"name":"FootpegContact","center":Vector3(0,-0.25,0.12),"width":0.56,"radius":0.025}]:
  var collider:=CollisionShape3D.new()
  collider.name=part.name
  var capsule:=CapsuleShape3D.new()
  capsule.radius=part.radius
  capsule.height=part.width
  collider.shape=capsule
  collider.position=part.center
  collider.rotation.z=PI/2
  body.add_child(collider)
