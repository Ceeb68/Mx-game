# Terra MX — Physics replacement prototype / 0.3.0

Native Godot 4.6.3 motocross prototype. This build keeps **Godot Physics** and replaces the motorcycle architecture with **ReducedCoordinateMotorcycle/v3**: independent unsprung suspension states, compliant tread contact, contact-moment rider control, shared raked steering/suspension geometry, and rider angular-momentum transfer. It is an experimental reduced-coordinate simulation, not a calibrated production race simulator.

**[Download the Windows rebuild prototype](https://github.com/Ceeb68/Mx-game/raw/refs/heads/prototype-download/build/TerraMX-rebuild-v3-windows.zip)**

Extract the ZIP and run `TerraMX.exe`. No Godot installation is required. OpenGL 3.3-capable graphics are needed. The debug display must identify **Godot Physics • ReducedCoordinateMotorcycle/v3**. Use `Compare-legacy.bat` to launch the preserved v2 controller and visual hierarchy. [The original Phase 2 build remains available](https://github.com/Ceeb68/Mx-game/raw/refs/heads/prototype-download/build/TerraMX-rebuild-v3-windows.zip).

Windows execution and physical gamepad feel remain unverified on this Linux development machine. Automated tests and rendered inspection cannot prove that subjective riding feel is fixed.

## What changed

- Separate front/rear unsprung translation and compliant tire carcass loads; chassis springs no longer directly define tire contact load.
- Stateful elastic tread adhesion, combined grip limits and progressive sliding, with unchanged terrain friction coefficients.
- Grounded virtual rider requests front lateral force from actual roll moments and inverts the discrete tire model into steering. Bounded hand torque drives a physical steering DOF.
- Front fender, clamps, bars and axle share a raked steering pivot; fixed-length fork tubes telescope. Rear axle follows a swingarm arc and the shock follows its endpoints.
- Acceleration-limited rider movement transfers angular momentum; wheel throttle/brake pitch control remains. No airborne attitude snapping.
- Existing track, skinned rider, cameras, binding editor, saved profiles and settings remain connected. Optional foot-down support remains a grounded low-speed development aid.

Read the [engine investigation, implementation details and limitations](docs/PHYSICS_REBUILD.md), [validation results](docs/VALIDATION.md), and [architecture](docs/ARCHITECTURE.md). The v2 source and previous packages are preserved.

## Default controls

| Action | Keyboard | Standard controller |
| --- | --- | --- |
| Throttle / front brake | W / S | RT / LT |
| Rear brake | Space | A / Cross |
| Steering | A / D | Left stick X |
| Body forward / backward | Up / Down | Right stick Y |
| Rider lateral lean | Q / E | Right stick X |
| Clutch disengage | Shift | LB / L1 |
| Shift up / down | Page Up / Page Down | RB / X |
| Stand / sit | Tab | Y / Triangle |
| Chase / rider camera | C | B / Circle |
| Reset | R | Back / View |
| Settings / pause | Escape | Start / Menu |
| Next lane / diagnostics | F6 / F1 | Assign in Controls if desired |

The chase and rider viewpoints are retained. The rider camera remains a basic development viewpoint, not a fully polished helmet camera.

## Customize and save controls

1. Open **Escape → Controls** (or Start/Menu, then the Controls tab).
2. Select the keyboard or controller cell for an action. Press a key/button or move the intended analog axis firmly from neutral. Steering and rider directions are bound separately to signed axis halves or digital buttons.
3. Drift below 0.25 and motion below 0.65 do not capture an axis. Return an already-deflected axis to neutral first. Escape or **Cancel rebind** cancels; an unanswered capture times out after 15 seconds.
4. Conflicts are shown before applying. **Swap** exchanges two bindings, **Replace** clears the previous assignment, and **Cancel** preserves the layout. **Reset all bindings** restores the standard layout.
5. Under **Response**, adjust steering/lean sensitivity and deadzones, throttle/brake deadzones, steering curve/smoothing, inversion, independent/combined rider lean, and vibration. **Riding** contains persistent assists and camera settings.

Changes save automatically to `user://controls_v2.cfg` (atomic file replacement). Existing first-build keyboard/controller mappings are migrated from `controls.cfg` when no v2 profile exists; the old file is preserved. On Windows, the normal location is `%APPDATA%/Godot/app_userdata/Terra MX · Dynamics Lab/`. With `launch.sh`, data is under `.godot/runtime/data/godot/app_userdata/Terra MX · Dynamics Lab/` unless XDG variables are already supplied.

Controller mappings are device-independent and apply to the first connected gamepad. Disconnecting clears transient input and cancels capture; reconnecting retains mappings. Resume/reconnect waits for riding controls to return to neutral before accepting throttle or steering. **Escape remains an emergency menu shortcut after remapping Pause**, and is reserved for cancelling a capture. Menus use Godot's normal mouse/keyboard/D-pad focus navigation. A physical gamepad and vibration still need hands-on verification.

## Short hands-on test

1. Ride the straight with assists at defaults. Make small left/right corrections, then a progressive sweeper and a left/right reversal at 25–40 km/h. Compare with the retained original build.
2. Try a standing start and a slow turn. Brake straight, then apply light front brake midcorner. Deliberately lock the rear brake in a safe area and release it to recover.
3. Approach the small tabletop around 40–50 km/h. Brief rear brake in flight should still pitch the nose down; land and continue. Use R if needed.
4. Toggle sitting/standing, body position and camera. Look for seat clipping, floating boots, hand separation or abrupt joint transitions; the skinned animation remains presentation-only; the separate reduced rider carriage supplies physical momentum reactions.
5. Rebind throttle to a trigger and a keyboard key, swap two conflicts, change response settings, quit/relaunch and confirm they persist. Unplug/reconnect the controller, release its controls, and confirm the saved layout still works.

Report lane, speed, gear, assist/response settings, controller model, and the exact input sequence for problems. Bounded automated improvements do not establish that the riding feel is fixed.

## Develop and test

Install **Godot 4.6.3 standard** (no .NET). Import `project.godot`, then F5, or:

```sh
cd /workspace/Mx-game
./launch.sh --editor
./launch.sh
./tests/run_all.sh
```

`launch.sh` supplies writable XDG directories when absent. The full suite runs the shipped scene/controller, input/UI tests, a separate-process profile reload, skeletal IK checks, and expanded handling scenarios. Graphical capture: `godot --path . --script res://tests/capture_rebuild.gd` with a display. Headless tests cannot establish subjective riding or physical controller behavior.

The rider asset is retained at `assets/rider/terra_rider.glb`. Its reproducible original Blender source is `tools/build_rider.py`; rebuild with `blender -b --python tools/build_rider.py`, then reimport in Godot. Blender is needed only to edit/regenerate the character, not to run or export the game. No external character assets or textures are used.

## Export

Use matching 4.6.3 standard templates. The prepared cloud machine retains checksum-verified templates under `/workspace/.mx-runtime/data/godot/export_templates/4.6.3.stable`.

```sh
mkdir -p build/windows build/linux
export XDG_DATA_HOME=/workspace/.mx-runtime/data
export XDG_CONFIG_HOME=/workspace/.mx-runtime/config
export XDG_CACHE_HOME=/workspace/.mx-runtime/cache
godot --headless --path . --export-release 'Windows Desktop'
godot --headless --path . --export-release Linux
```

Presets explicitly include bike JSON and the referenced glTF rider; tests/docs/authoring tools are excluded from the runtime pack. `build/TerraMX-rebuild-v3-windows.zip`, `build/TerraMX-rebuild-v3-linux.zip`, and `build/TerraMX-rebuild-v3-source.zip` contain this update. Engine notices are in `docs/licenses/` and included in packages. No publication or Windows execution is implied by a successful local export.
