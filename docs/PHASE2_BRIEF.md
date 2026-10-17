# PHASE 2 — CRITICAL PHYSICS IMPROVEMENTS, RIDER MODEL & CONTROLLER CUSTOMIZATION

I've tested the first playable version of our new motocross simulator.

**IMPORTANT: I LIKE THIS NEW VERSION MORE THAN OUR PREVIOUS GAME. WE ARE KEEPING THIS FOUNDATION AND CONTINUING DEVELOPMENT.**

However, the physics are currently very rough and need significant improvements before we can properly enjoy the riding experience.

Remember that our target is MX Bikes-level motorcycle realism, handling precision, and competitive motocross simulation.

This is still an early prototype, so I understand that the physics are not finished. I want us to make significant, measurable improvements to the existing implementation rather than restarting again.

I have four major complaints and development requests.

## PRIORITY 1 — THE MOTORCYCLE IS EXTREMELY SLIPPERY

Right now, riding feels like the motorcycle is constantly on ice.

The tires do not feel properly connected to the ground, making normal riding unnecessarily difficult.

The bike slides around too easily, has poor directional stability, and lacks predictable traction.

**This is currently one of the biggest problems with the game.**

I want you to investigate and improve:

- Front tire lateral traction.
- Rear tire lateral traction.
- Longitudinal acceleration and braking grip.
- Tire slip calculations.
- Contact patch behavior.
- Tire normal loads.
- Terrain friction interactions.
- Steering and tire-force relationships.
- Weight transfer during cornering.
- Progressive grip loss and recovery.
- Low-speed traction behavior.

The tires should have enough realistic traction for the player to confidently accelerate, brake, and navigate corners.

When the motorcycle is upright and moving straight on normal dirt, it should track straight without unexplained lateral sliding.

When cornering, the tires should progressively develop the forces required to turn the motorcycle.

I should be able to lean through normal corners without the motorcycle immediately sliding away.

However, do not make the tires artificially glued to the surface.

I still want controlled rear-wheel slides, front-wheel traction loss, and realistic tire spin when the riding conditions justify it.

**EXPECTED RESULT:** The motorcycle should feel planted and predictable, with meaningful traction that responds naturally to speed, throttle, braking, steering, and terrain.

## PRIORITY 2 — FIX UNNATURAL BIKE MOVEMENT AND MAKE IT MORE STABLE

This is equally important.

The current motorcycle moves unnaturally and feels extremely unstable.

It sometimes rotates, leans, or reacts in ways that do not resemble a real motorcycle.

The overall movement feels weird and disconnected from what I expect when riding.

I want the chassis, steering, wheels, and rider physics to behave like one physically consistent system.

Investigate:

- Incorrect or excessive rotational forces.
- Chassis mass and center of mass.
- Incorrect rotational inertia.
- Angular velocity and angular damping.
- Steering torque calculations.
- Lean control.
- Front-wheel steering geometry.
- Wheel contact stability.
- Suspension forces.
- Input response.
- Unexpected collisions.
- Physics timestep instability.
- Incorrect coordinate systems.
- Conflicting stabilization and steering calculations.

**I WANT THE MOTORCYCLE TO FEEL SIGNIFICANTLY MORE STABLE.**

Specifically:

1. Riding straight should feel steady and predictable.
2. Small steering corrections should not produce extreme movements.
3. Normal cornering should feel controlled.
4. Leaning should be progressive and natural.
5. The bike should not randomly fall over.
6. The front end should not suddenly wash out during ordinary turns.
7. The bike should not snap sideways without a physical reason.
8. The motorcycle should not feel excessively heavy or sluggish.
9. The bike should not bounce, wobble, or rotate unpredictably.
10. The player should be capable of correcting small balance mistakes.
11. Landing from jumps should not create random rotational instability.
12. Standing starts and low-speed maneuvering should be manageable.

I want realistic stability, not artificial arcade stabilization.

However, recognize that a real motorcycle is controlled by a rider who continuously makes balance and steering corrections.

A gamepad cannot directly reproduce every physical rider input.

Therefore, if necessary, implement a realistic virtual-rider controller that translates player input into appropriate steering and balance corrections.

This must be carefully tuned, physically coherent, and should not override genuine motorcycle dynamics.

Any optional rider assistance should be configurable.

**EXPECTED RESULT:** The motorcycle should feel natural, responsive, controllable, and physically stable without removing the skill required to ride competitively.

## PRIORITY 3 — ADD A PROPER 3D MOTOCROSS RIDER

I also want a significant visual improvement.

The game needs an actual, recognizable, correctly proportioned motocross rider.

I do not want a generic capsule, mannequin, or placeholder object permanently sitting on the motorcycle.

Create or integrate a suitable original or properly licensed 3D rider asset, compatible with the existing rendering engine and animation system.

The rider should have:

- Realistic human body proportions.
- Proper motocross helmet.
- Motocross goggles.
- Jersey.
- Racing pants.
- Motocross gloves.
- Motocross boots.
- Correct seated riding posture.
- Realistic arm and leg positions.

The rider must be correctly scaled to the motorcycle.

### Rider animations

Implement believable motocross movement, including:

- Sitting on the bike.
- Standing on the footpegs.
- Leaning forward.
- Leaning backward.
- Leaning left and right.
- Standing attack position.
- Braking posture.
- Acceleration posture.
- Smooth cornering transitions.
- Reacting to jumps and landings.
- Moving appropriately with suspension travel.

The rider's hands should remain properly aligned with the handlebars.

The rider's feet should interact correctly with the footpegs.

Knees, elbows, arms, and legs should bend naturally.

Use skeletal animation and inverse kinematics where appropriate.

**IMPORTANT:** Avoid stiff movement, limbs clipping through the motorcycle, floating feet, or sudden animation snapping.

Use a proper rider skeleton or rig if supported by our engine.

If no suitable 3D asset exists in the project, identify a compatible asset workflow and implement as much of the actual rider system as possible. Be clear about any asset limitations rather than pretending a primitive placeholder is a finished rider.

### Rider physics

Eventually, rider body movement should also influence motorcycle balance and weight distribution.

For now, prioritize a properly rendered, correctly attached, smoothly animated rider without destabilizing the physics system.

**EXPECTED RESULT:** I should see a believable motocross rider operating the motorcycle instead of an obviously unfinished placeholder.

## PRIORITY 4 — FULLY CUSTOMIZABLE CONTROLLER AND KEYBOARD BINDS

I want a proper control configuration system.

The player must be able to customize their controls instead of being forced to use predefined bindings.

Create an accessible **Controls** section inside the settings menu.

### Controller support

Support connected gamepads through the input capabilities of the current engine.

Allow players to remap:

- Throttle.
- Front brake.
- Rear brake.
- Steering left/right.
- Rider lean left/right.
- Rider forward/backward movement.
- Clutch.
- Gear up.
- Gear down.
- Sit/stand.
- Reset motorcycle.
- Camera switching.
- Pause/menu.

Support analog sticks, triggers, digital buttons, and directional pads where appropriate.

Analog inputs must retain their full analog functionality.

For example, assigning throttle to a trigger should allow progressive throttle control instead of converting it into an on/off button.

### Controller customization settings

Include:

- Steering sensitivity.
- Steering deadzone.
- Rider lean sensitivity.
- Rider lean deadzone.
- Throttle deadzone.
- Brake deadzone.
- Optional axis inversion.
- Optional steering response curve.
- Optional input smoothing.
- Vibration options when supported.

Allow the player to choose between independent steering and rider-lean controls or a suitable combined control scheme.

### Keyboard controls

All relevant gameplay actions must also support customizable keyboard bindings.

The user should be able to click an action, press a new key, and assign it.

### Input remapping interface

When selecting an action to rebind:

1. Display a clear prompt asking the player to press a key, button, or move an analog axis.
2. Detect the intended input.
3. Apply the new binding.
4. Warn about conflicting bindings.
5. Allow the player to resolve conflicts.
6. Provide a reset-to-default option.
7. Save settings so they persist after restarting the game.

Handle controller disconnections and reconnections gracefully.

Do not accidentally bind analog stick drift or trigger noise while waiting for input.

Make the interface straightforward and usable with either a mouse or controller.

**EXPECTED RESULT:** I should be able to fully configure my preferred controller layout and save it permanently.

## IMPORTANT — DEVELOPMENT AND TESTING REQUIREMENTS

Before modifying code, inspect the active implementation of:

- Tire physics.
- Motorcycle rigidbody.
- Steering.
- Rider/balance control.
- Suspension.
- Input mapping.
- Rider rendering and animation.

Make sure you are changing systems that are actually active during gameplay.

Do not blindly add more forces or arbitrary multipliers.

Do not rewrite the entire game.

Do not remove existing working features.

Do not sacrifice airborne control or acceleration behavior to fix ground traction.

### Required development order

**STEP 1:** Diagnose and improve tire traction.

**STEP 2:** Correct unnatural chassis movements and improve stability.

**STEP 3:** Test steering, leaning, and basic riding together.

**STEP 4:** Implement customizable input bindings and controller settings.

**STEP 5:** Add or improve the 3D rider and animation system.

**STEP 6:** Perform integration tests and address regressions.

Implement these in manageable, verifiable changes.

### Required tests

Test the following where runtime testing is available:

- Acceleration in a straight line.
- Maintaining a straight trajectory without excessive steering corrections.
- Progressive left and right turns.
- Low-speed maneuvering.
- Moderate-speed cornering.
- Aggressive throttle on dirt.
- Braking in a straight line.
- Braking while cornering.
- Intentional rear-wheel sliding.
- Basic jumping and landing.
- Controller remapping and setting persistence.
- Rider animation during movement.

If you cannot test actual gamepad input or visually inspect rider animations, explain the limitation and provide me with a short manual test procedure.

Do not claim that the physics feel fixed without actual gameplay verification.

## WHAT I EXPECT FROM THIS UPDATE

After this update, I want to launch the game and immediately notice:

1. **Much better traction.**
2. **Significantly improved motorcycle stability.**
3. **More natural bike movement.**
4. **Better steering and leaning behavior.**
5. **Fewer unexplained crashes.**
6. **A proper-looking motocross rider.**
7. **Smooth basic rider animations.**
8. **Fully remappable controller and keyboard controls.**

Our long-term goal is still MX Bikes-level realism.

Do not turn this into an arcade motocross game to make it easier.

Instead, correct the underlying physics and develop a better system for translating player inputs into realistic motorcycle behavior.

I understand that this is an early prototype.

I do not expect the entire simulator to be finished yet.

**I DO EXPECT THE NEXT BUILD TO BE NOTICEABLY MORE STABLE, MORE CONTROLLABLE, AND LESS SLIPPERY THAN THE CURRENT BUILD.**

Implement these improvements in the existing new project, run the available tests, and explain what was actually changed.

Preserve the working foundation.

Make the next build playable and ready for another round of hands-on testing.
