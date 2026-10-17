extends RefCounted
## Returns normal contact load in N. The chassis is the sole force applicator.
static func normal_load(config: Dictionary, index: int, compression: float, velocity: float) -> float:
 var damping: float = config.compression_ns_m[index] if velocity > 0 else config.rebound_ns_m[index]
 var bottom: float = maxf(0, compression - config.suspension_travel_m * 0.88)
 return clampf(config.preload_n[index] + compression * config.spring_n_m[index] + velocity * damping + bottom * bottom * 350000.0, 0, 22000)
