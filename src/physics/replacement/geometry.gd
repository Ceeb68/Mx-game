extends RefCounted
## Reduced-coordinate mechanism shared by contact, rendering and hand IK.
const REST := 0.43
const TRAVEL := 0.30
const RAKE := 0.471239
const HEAD := Vector3(0, 0.40, -0.306904)
const REAR_PIVOT := Vector3(0, -0.17, 0.15)
static func steering_basis(angle: float) -> Basis:
 return Basis(Vector3(0, cos(RAKE), sin(RAKE)), -angle)
static func rear_angle(extension: float) -> float:
 var arm := Vector3(0,-0.02-REST,0.74)-REAR_PIVOT
 return atan2(arm.y,arm.z)+(REST-extension)/arm.length()
static func axis(index: int, angle: float, extension: float = REST) -> Vector3:
 if index == 0: return steering_basis(angle) * Vector3(0,cos(RAKE),sin(RAKE))
 var theta: float = rear_angle(extension)
 return Vector3(0,cos(theta),-sin(theta))
static func hub(index: int, extension: float, angle: float) -> Vector3:
 if index == 0:
  # At full extension axle remains at the old wheelbase; travel follows rake.
  var axle := Vector3(0, -0.02 - REST, -0.74) + axis(0, 0) * (REST - extension)
  return HEAD + steering_basis(angle) * (axle - HEAD)
 var length: float = (Vector3(0,-0.02-REST,0.74)-REAR_PIVOT).length()
 var theta: float = rear_angle(extension)
 return REAR_PIVOT + Vector3(0,sin(theta),cos(theta))*length
static func grip(side: float, angle: float) -> Vector3:
 return HEAD + steering_basis(angle) * (Vector3(side * 0.35, 0.48, -0.55) - HEAD)

static func heading_per_steer(chassis: Basis, normal: Vector3, angle: float) -> float:
 # Ground-heading derivative of the existing raked steering mechanism.
 # On level ground at zero steer: cos(rake)*cos(lean), not cos(rake)/cos(lean).
 var forward: Vector3 = chassis * (steering_basis(angle) * Vector3.FORWARD)
 var derivative: Vector3 = -(chassis * axis(0, angle)).cross(forward)
 var projected: Vector3 = forward.slide(normal)
 if projected.length_squared() < 0.01: return 0
 return -normal.dot(projected.cross(derivative.slide(normal))) / projected.length_squared()
