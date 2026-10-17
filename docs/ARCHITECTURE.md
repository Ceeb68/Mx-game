# Architecture — replacement prototype 0.3.0

See [the complete physics investigation and design](PHYSICS_REBUILD.md).

`src/main.gd` selects **one** controller: replacement by default, preserved v2 with `--legacy`. The chassis remains a Godot rigid body at 240 Hz. Independent wheel-station states use four implicit substeps per chassis step. The tire module owns wheel/tread state, station module owns unsprung travel, powertrain owns crank/clutch state, virtual rider supplies steering requests, and the chassis owns all force application. The mechanism geometry is shared by tire support, suspension travel, visual hierarchy and grip IK. Controls, UI, track and camera remain separate consumers/producers of command or presentation data.

No gameplay path assigns chassis pose/velocity except reset. Pause deliberately freezes the selected body. Visual transforms follow simulated generalized coordinates; they are not separate collision bodies. This is a reduced-coordinate approximation with estimated parameters, not a full articulated multibody solver or measured tire model. See the design document for the omitted couplings and validation limits.

The [Phase 2 architecture document](PHASE2_ARCHITECTURE.md) is retained for historical comparison.
