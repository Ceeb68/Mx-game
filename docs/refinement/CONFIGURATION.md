# Active tuning in this steering-only update

`data/250f.json` → `handling.rider` is the active replacement virtual rider.
`handling.steering` controls the finite steering actuator. All extracted settings
retain v3.1 values except `target_rate_tracking` (new, 0.35).
`handling.input` seeds response defaults: curve 1.35, smoothing 0.06 seconds.
The saved `user://controls_v2.cfg` response fields override these defaults;
there is no second runtime input filter. Existing profiles are preserved.
Set Steering smoothing to 0.06 in Settings to try the new default on an existing
profile. Leave sensitivity, curve, assists, and bindings unchanged for comparison.

The following top-level fields are **legacy controller only**, not active v3.2
handling tuning. They are retained for the separate v2 implementation:

- `steer_servo_nm_rad`, `steer_damping_nm_s`
- `rider_max_lean_deg`, `rider_lean_rate_deg_s`, `rider_roll_gain`,
  `rider_roll_damping_s`, `rider_steering_rate_rad_s`,
  `rider_reference_speed_m_s`, `rider_max_low_speed_gain`,
  `rider_blend_start_m_s`, `rider_blend_end_m_s`
- `tire_longitudinal_stiffness`, `tire_lateral_stiffness`,
  `tire_relaxation_length_m`, `tire_sliding_ratio` are loaded by the tire base
  class but its force law is overridden by replacement/contact_tire.gd.
- `tire_relaxation_s` is not consumed by the replacement bristle law.

Active suspension spring/compression/rebound/preload/travel settings remain
at the existing top level. Carcass, tread, rider carriage, foot support and
airborne constants have **not yet been migrated or retuned**. That work belongs
to the separate suspension/airborne updates requested by the user. Do not edit
legacy lookalike fields to tune the replacement controller.

`target_rate_tracking=0` and input smoothing 0.10 restore the v3.1 steering
response mathematics. Target-rate feedforward remains bounded by the existing
lean-request rate, force budget, roll acceleration limit and steering torque
limit. It acts through front contact force, never direct chassis rotation.
