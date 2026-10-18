# Isolated comparisons — inactive suspension candidates

Every row used the same existing ground/landing scripts and thresholds. These
are successive factor-isolation runs, not simultaneous changes shipped together.
All B candidates added a braking-bumps ground failure (5/13 rather than baseline
4/13); none was accepted. Their supported 11 landing checks still passed, but
that is insufficient to accept a rough-ground regression. Landing observation
counts are separate. See the per-run `experiments/*-results.json` for all cases.

| Run | Tire version | Suspension change | Ground failures | Landing observation failures |
| --- | --- | --- | ---: | ---: |
| B / B1 | A1 | coordinated unilateral, signed stops/rebound, moving road, average | 5 | 2 |
| B2 | A1 | same, frozen road | braking-bumps subset 1/1 | not run |
| B3 | A1 | only average reactions | 5 | 4 |
| B4 | A2 | only average reactions | 5 | 4 |
| B5 | A2 | coordinated correction | 5 | 2 |
| B6 | A2 | coordinated + carcass damping 700/800 | 5 | 4 |
| B7 | A2 | original solver, carcass damping 700/800 | 5 | 4 |
| B8 | A2 | only unilateral unloading re-solve | 5 | 3 |
| B9 | A2 | original solver, compression damping 1300/1400 | 5 | 3 |
| B10 | A2 | unilateral + signed reaction/stops, frozen road, last reaction | 5 | 4 |
| B11 | final A | B10, exact rotating inverse restored | 5 | 4 |
| B12 | final A | only travel-stop reaction impulse | 5 | 3 |
| Retained | final A | original v3.5 solver/tuning | **4** | **3** |

A1 is the first wheel-speed renewal experiment, saved as
`tire-wheel-transport.gd.txt`; A2 restored carrier-speed renewal for the force
solve and established inverse but still had the wheel-speed low-speed numerical
inverse and rearranged scalar/vector multiplication. Final A restores both
carrier-speed inverse forms and original unconstrained trial-vector order,
retaining the finite-brake constraint repair. Those corrections prevent treating
a changed low-speed inverse as a tire-only comparison. None of A1/A2 is shipped.
Final A paired contact results match the final live build exactly.

Source snapshots:

- `station-v35.gd.txt`: retained baseline.
- `station-full.gd.txt`, `motorcycle-full.gd.txt`: coordinated correction.
- `station-frozen-road.gd.txt`, `motorcycle-average.gd.txt`: B2 geometry held.
- `station-unilateral.gd.txt`: B8.
- `station-unilateral-signed.gd.txt`: B10/B11.
- `station-travel-stop.gd.txt`: B12.

To reproduce a prototype in an isolated copy of the baseline project, replace
only the corresponding `src/physics/replacement/` files using these snapshots,
use the indicated tire variant and change only the damping numbers listed in
the table. For B3/B4 use `motorcycle-average.gd.txt` with `station-v35.gd.txt`.
For B7/B9 retain both original suspension files. A2 is reconstructed from A1 by
restoring carrier-speed convection in the rotating force and
`lateral_angle_for_force`; final A is the active tire file. The final Stage A
contact law defaults are in `data/250f.json`; non-default damping values belong
only to the listed experiments. Version banners in snapshots are historical.
No prototype changes controller gains or terrain mu.

Some failed runs end on the side or upside down without a crash flag. They remain
failed whenever roll thresholds are exceeded. In particular, B9 `small_bumps`
and B12 `whoops` are not successful merely because `crashed=false`.

The passive fixed-mount probe can pass while whole-bike riding deteriorates.
That difference is the reason the conservation-corrected prototype was withheld.
It is a useful isolated development starting point, not a validated replacement.
