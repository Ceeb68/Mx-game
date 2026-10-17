# PROJECT: NEXT-GENERATION REALISTIC MOTOCROSS SIMULATOR
## COMPLETE GAME DEVELOPMENT BLUEPRINT — FROM SCRATCH

You are acting as the lead game developer, senior physics engineer, vehicle dynamics specialist, technical architect, 3D gameplay programmer, and game systems designer for a completely new motocross simulator.

We are building a serious standalone PC motocross game inspired by the realism, motorcycle handling, skill requirements, and competitive racing of MX Bikes and MX Simulator.

**THIS IS NOT A ROBLOX GAME. THIS IS NOT AN ARCADE MOTOCROSS GAME.**

I want a full-featured, high-quality motocross simulator built around realistic motorcycle dynamics and authentic motocross racing.

This is a ground-up development specification.

Read the entire document carefully before writing code.

The priority is not simply to produce a game that runs. The priority is to establish a strong technical foundation for a game that can eventually compete with established motocross simulators in handling, realism, depth, and overall riding experience.

---

# 1. PROJECT VISION

Our ultimate goal is to create a realistic motocross simulator that combines:

- The realistic motorcycle dynamics of MX Bikes.
- The precise riding and competitive challenge of MX Simulator.
- The graphical presentation of a modern PC racing game.
- Realistic professional motocross, supercross, and arenacross.
- Detailed, believable motorcycles.
- Accurate rider movement and body positioning.
- Realistic terrain interaction.
- Skill-based multiplayer competition.
- A meaningful rider progression and career system.
- Extensive bike customization.
- Authentic motorcycle audio.
- Smooth performance and responsive controls.

The most important element is the riding experience.

**The game must be enjoyable because the motorcycle behaves believably, not because the physics are artificially simplified.**

This simulator should reward real motocross skills such as throttle control, braking technique, corner entry, weight shifting, jumping, scrubbing, whipping, line selection, and momentum conservation.

I want someone experienced with motocross to recognize the behavior of a real motorcycle.

However, do not artificially introduce difficulty through excessive instability, poor controls, unpredictable traction, or unrealistic crashes.

Realism means believable physical behavior, not making the game unnecessarily frustrating.

# 2. DEVELOPMENT ARCHITECTURE — START CLEAN

Treat this as a fresh game development project.

First, inspect the available environment, existing repository, installed dependencies, and supported development tools.

If we are inside an existing project, do not overwrite or destroy the original game. Create an isolated new project, branch, or clearly separated prototype as appropriate.

Choose the technology stack according to the actual project requirements.

The architecture must support:

- Standalone Windows PC builds.
- Modern 3D rendering.
- High-frequency deterministic or sufficiently reproducible physics updates.
- Custom motorcycle vehicle physics.
- Detailed terrain and collision geometry.
- Procedural rider animation.
- Gamepad support.
- Configurable keyboard controls.
- Eventually, networked multiplayer racing.
- Extensible motorcycle and track data.
- Save systems and rider progression.
- Performance profiling and debugging.

Do not assume that a basic four-wheel vehicle controller can realistically simulate a motorcycle.

Do not rely on a generic rigidbody vehicle prefab without evaluating its physical limitations.

Do not implement multiple competing motorcycle controllers.

The game should have one authoritative motorcycle simulation architecture with well-defined subsystems.

Separate the following systems:

1. Core physics simulation.
2. Motorcycle chassis and rigidbody dynamics.
3. Front and rear wheel dynamics.
4. Tire and ground interaction.
5. Suspension.
6. Steering and rider input.
7. Engine, clutch, transmission, and drivetrain.
8. Rider dynamics and animation.
9. Crash detection and recovery.
10. Terrain and track systems.
11. Audio.
12. Camera.
13. User interface.
14. Racing and progression.
15. Networking.
16. Development diagnostics and testing.

Use clean, maintainable, modular code with explicit ownership of physical forces.

**Do not build systems that secretly override each other.**

# 3. MOTORCYCLE PHYSICS — HIGHEST PRIORITY

This is the most important part of the entire game.

I want a motorcycle physics model capable of reproducing the behavior of a real motocross bike.

It must not behave like a car with two wheels or an object that is simply rotated according to player input.

The simulation must account for:

- Motorcycle mass.
- Center of mass.
- Mass distribution.
- Rotational inertia.
- Wheelbase.
- Steering geometry.
- Rake and trail.
- Wheel angular velocity.
- Gyroscopic effects.
- Front/rear suspension.
- Tire contact forces.
- Weight transfer.
- Engine torque.
- Braking forces.
- Rider mass and positioning.
- Angular momentum.
- Gravity.
- Terrain contact.
- Collision forces.

Use physically meaningful measurements and parameters wherever possible.

Build the simulation around a consistent fixed physics timestep, ideally supporting a sufficiently high update frequency for stable vehicle dynamics.

Decouple physics from the rendering frame rate.

Make the motorcycle's parameters data-driven so different engine classes and bike models can share the same physics architecture while having distinct handling characteristics.

## 3.1 Tire traction and grip

Implement realistic tire behavior.

Both tires must have their own contact and force calculations.

Account for:

- Longitudinal slip.
- Lateral slip.
- Slip angle.
- Tire normal load.
- Combined acceleration/braking/cornering forces.
- Terrain friction properties.
- Wheel rotation.
- Load transfer.
- Sliding friction.
- Progressive traction loss.
- Traction recovery.

Use a physically coherent tire-force model appropriate for motocross tires on deformable dirt.

Tires should not behave like they are on ice.

At the same time, they must not have infinite grip.

The motorcycle should feel planted and predictable at appropriate speeds.

Under excessive throttle, the rear wheel should be capable of spinning and stepping sideways.

Under excessive front braking or cornering load, the front tire should be capable of losing traction.

Sliding should be progressive enough to allow an experienced player to recognize and react to it.

**Do not make every small front-wheel slide an instant crash.**

The relationship between throttle, tire loading, terrain, steering input, and traction should produce believable behavior.

## 3.2 Steering and lean physics

Implement proper two-wheeled steering dynamics.

The motorcycle must naturally lean into corners based on its movement, steering geometry, rider input, and tire forces.

Include:

- Countersteering at appropriate speeds.
- Natural turn initiation.
- Lean-angle control.
- Steering torque.
- Steering response.
- Dynamic self-stability where physically appropriate.
- Speed-dependent steering behavior.
- Realistic corner radius.
- Appropriate roll inertia.
- Smooth corrections.
- Controlled transitions between left and right turns.

The front wheel should steer relative to the chassis.

Do not fake steering by directly rotating the entire motorcycle in the requested direction.

The motorcycle must be able to make tight motocross corners, wide sweeping turns, and fast directional changes.

The player must not feel as though the motorcycle weighs several times its actual weight.

It should respond promptly without feeling unnaturally twitchy.

## 3.3 Motorcycle balance

Balance must result from the motorcycle's physical dynamics and rider control.

At speed, the bike should possess believable directional stability.

At low speeds, it should become more difficult to balance, but still allow realistic correction.

Avoid:

- Random tipping.
- Excessive low-speed instability.
- Forced upright rotation.
- Overpowered auto-balance.
- Unexplained changes to lean angle.
- Crashing because of minor steering inputs.

If assistance is required to make controller input practical, implement it transparently as an optional, tunable input-control layer rather than a hidden force that undermines the simulation.

## 3.4 Suspension

Build functioning independent front and rear suspension.

Include:

- Spring rates.
- Preload.
- Static and rider sag.
- Compression damping.
- Rebound damping.
- Suspension travel.
- Bottoming resistance.
- Suspension velocity.
- Unsprung mass where appropriate.
- Contact-force transfer into the chassis.

Suspension must physically influence handling.

The front forks must dive appropriately during braking.

The rear shock must react appropriately to acceleration, impacts, and terrain.

When landing from a jump, both suspension systems should compress according to the forces involved.

Suspension should not be merely a visual animation.

Create a tuning architecture that can eventually support adjustable suspension setups.

## 3.5 Acceleration and braking physics

A motocross motorcycle should react to throttle and braking according to real physical forces.

Include:

- Rear-wheel torque delivery.
- Front-wheel lifting.
- Rear-wheel traction limits.
- Engine braking.
- Front/rear brake independence.
- Weight transfer.
- Rear-wheel lockup.
- Front-wheel lockup.
- Controlled braking slides.
- Wheelies.
- Stoppies where physically possible.

The bike should be able to accelerate aggressively.

A powerful 450 should feel meaningfully different from a 125 two-stroke.

Do not simply multiply vehicle velocity when the throttle is pressed.

# 4. ENGINE, CLUTCH, AND TRANSMISSION

Create a proper motorcycle powertrain simulation.

Each bike should have configurable:

- Engine displacement.
- Engine configuration.
- Two-stroke or four-stroke behavior.
- Idle RPM.
- Maximum RPM.
- Rev limiter.
- Torque curve.
- Horsepower curve.
- Gear ratios.
- Final drive gearing.
- Engine inertia.
- Engine braking characteristics.
- Clutch engagement behavior.

Throttle input should influence engine torque rather than directly setting motorcycle speed.

Implement working manual transmissions.

Include realistic clutch behavior for starts, shifts, and low-speed riding.

The player must be able to shift gears manually.

Support optional automatic shifting or clutch assistance through gameplay settings.

Two-stroke power delivery should be noticeably different from four-stroke power delivery.

A 125 two-stroke should require more attention to RPM and gearing.

A 450 four-stroke should have stronger low-end torque and different engine braking behavior.

# 5. AIRBORNE MOTORCYCLE PHYSICS

Airborne physics are extremely important.

I want realistic jumping comparable in feel and control to MX Bikes.

The motorcycle should preserve physical momentum when leaving the ground.

Include:

- Realistic takeoff trajectories.
- Pitch rotation.
- Roll rotation.
- Yaw rotation.
- Angular inertia.
- Rider weight shifting.
- Wheel-related pitch influences.
- Controlled pitch correction.
- Realistic sideways whip movement.
- Realistic scrubbing behavior.
- Smooth whip recovery.
- Believable landing orientation.

The bike should not float unnaturally.

It should not automatically snap upright.

It should not spin excessively from small player inputs.

Whips must be initiated intentionally and require control to bring the bike back.

Scrubs should allow the player to change bike attitude and manage jump trajectory through physically meaningful interactions with the jump face and airborne motion.

Do not fake a scrub by simply lowering the motorcycle in the air.

Both straight jumps and aggressive sideways jumps must feel consistent.

# 6. LANDING AND CRASH PHYSICS

Implement an intelligent, physics-based crash system.

A crash should occur because the motorcycle enters an unrecoverable physical situation.

Evaluate:

- Ground impact force.
- Landing angle.
- Wheel contact conditions.
- Lean angle.
- Motorcycle velocity.
- Suspension loading.
- Unrecoverable loss of balance.
- Collision severity.

Allow imperfect landings when the forces and motorcycle orientation are recoverable.

Examples:

A slightly sideways landing should not automatically result in a crash.

A reasonably controlled rear-wheel slide should be recoverable.

Landing severely crossed up at high speed may produce a crash.

Over-rotating a whip should have consequences.

Crashes should be physically believable and visually convincing.

Eventually include proper rider separation, ragdoll behavior, bike tumbling, and recovery animations.

Respawning must cleanly reset all simulation states.

# 7. RIDER PHYSICS AND ANIMATION

The rider must not appear glued to the motorcycle.

I want realistic motocross body movement.

Implement a rider system that can support:

- Sitting.
- Standing.
- Forward weight shifting.
- Rearward weight shifting.
- Side-to-side lean.
- Leg extension during cornering.
- Standing attack position.
- Jump takeoff posture.
- Landing absorption.
- Braking posture.
- Acceleration posture.
- Whip body positioning.
- Smooth transitions between riding positions.

Use inverse kinematics or another appropriate procedural animation technique to maintain natural hand and foot placement.

The rider's:

- Hands should remain connected to the handlebars.
- Feet should interact correctly with the footpegs.
- Knees should bend naturally.
- Arms should respond to steering and suspension.
- Torso should react to movement.

Rider movement must be smooth, without sudden snapping between positions.

Where appropriate, body position should influence the combined motorcycle/rider center of mass and resulting dynamics.

The rider should visually and physically respond to acceleration, braking, cornering, jumping, and landing.

The eventual animation quality should resemble actual motocross riding, rather than generic character animations.

# 8. REALISTIC MOTORCYCLE MODELS

I want detailed modern motocross motorcycles.

The eventual motorcycle roster should cover contemporary race-oriented 125 two-strokes, 250 four-strokes, and 450 four-strokes, plus appropriate additional two-stroke classes.

Use real-world motorcycle specifications where reliable data is available.

Target the visual detail of modern production motocross motorcycles, including recognizable:

- Frames.
- Engines.
- Exhaust systems.
- Radiators.
- Suspension.
- Brake components.
- Wheels.
- Tires.
- Plastics.
- Number plates.
- Handlebars.
- Controls.
- Chain and sprockets.

Build a flexible motorcycle definition system that supports major modern manufacturers and their relevant racing classes.

Different motorcycles should have distinct:

- Weight.
- Dimensions.
- Engine performance.
- Suspension characteristics.
- Handling geometry.
- Gear ratios.
- Visual appearance.
- Audio character.

If official branding, model assets, or manufacturer artwork requires licensing, use appropriately original placeholder assets and a licensing-ready data structure rather than copying protected game models or branding without permission.

For the initial playable prototype, build **one high-quality 250cc four-stroke motorcycle** before expanding the roster.

# 9. BIKE CUSTOMIZATION AND GARAGE

Eventually implement a complete garage system.

Players should be able to:

- Purchase motorcycles.
- Select their current motorcycle.
- Change plastics and graphics.
- Customize number plates.
- Select their race number.
- Change wheel and rim appearance.
- Customize handlebars and grips.
- Change exhaust components where supported.
- Equip different gear.
- Save motorcycle setups.

Implement realistic mechanical setup options including:

- Suspension stiffness and damping.
- Suspension sag.
- Final drive gearing.
- Tire selection.
- Tire pressures where supported by the tire model.
- Brake tuning where appropriate.

Changes to mechanical setup should actually affect the physics.

Do not claim that a mechanical upgrade improves performance unless it changes the relevant simulation parameters.

# 10. TERRAIN AND TRACK PHYSICS

The ground must behave like motocross terrain.

Support different riding surfaces such as:

- Hardpack dirt.
- Soft loam.
- Deep sand.
- Mud.
- Loose soil.
- Rutted corners.
- Compacted racing lines.
- Rough braking bumps.

Different terrain types must influence tire traction and rolling resistance.

Loose terrain should behave differently from hardpack.

Eventually implement dynamic terrain deformation.

Repeated riding should be capable of creating:

- Ruts.
- Braking bumps.
- Acceleration chop.
- Worn lines.
- Changing corner shapes.

Terrain deformation must affect the physical riding surface, not simply the visual appearance.

Design the track system so dynamic terrain can be expanded later without requiring a complete physics rewrite.

# 11. MOTOCROSS, SUPERCROSS, AND ARENACROSS TRACKS

The full game should feature three major disciplines.

## Outdoor motocross

Create believable professional outdoor motocross tracks with:

- Natural elevation changes.
- Large jumps.
- Tabletops.
- Doubles.
- Step-ups.
- Step-downs.
- Rutted corners.
- Berms.
- Fast straights.
- Technical braking zones.
- Rough terrain.
- Multiple racing lines.

Tracks such as Unadilla and other famous outdoor motocross venues should serve as references for the scale, flow, elevation, and professional racing character.

Do not directly reproduce proprietary track assets or protected layouts without appropriate rights.

## Supercross

Implement stadium-style supercross tracks.

Include:

- Rhythm lanes.
- Whoops.
- Triples.
- Doubles.
- Dragon backs.
- Tight 180-degree turns.
- Steep berms.
- Technical jump combinations.

Supercross should reward precision and jump timing.

## Arenacross

Create smaller indoor racing environments with:

- Short technical layouts.
- Compact rhythm sections.
- Tight corners.
- Smaller jumps.
- Intense racing.
- Limited track width.

The physics must remain consistent between the disciplines.

The motorcycle should react to the different terrain and track designs naturally.

# 12. CAMERA SYSTEM

Implement a polished motocross camera system.

Include:

1. Third-person chase camera.
2. First-person helmet or rider camera.
3. Fixed cinematic cameras.
4. Replay cameras.

The main chase camera should:

- Smoothly follow the bike.
- Handle jumps correctly.
- Follow direction changes.
- Avoid excessive shaking.
- Maintain useful visibility during whips.
- Adjust intelligently to terrain.
- Avoid clipping through the ground.

Include configurable field of view, follow distance, smoothing, and camera sensitivity.

The camera should help communicate motorcycle movement without hiding poor physics through visual tricks.

# 13. PLAYER CONTROLS

Support both keyboard and gamepad.

Gamepad support is particularly important.

Implement configurable mappings for:

- Throttle.
- Front brake.
- Rear brake.
- Steering.
- Rider lean.
- Forward/backward weight shifting.
- Gear up.
- Gear down.
- Clutch.
- Rider sitting/standing controls.
- Reset motorcycle.
- Camera changes.

Support analog input correctly.

Provide adjustable input sensitivity and dead zones.

Implement optional assists separately from the core physics:

- Automatic shifting.
- Clutch assistance.
- Limited steering assistance.
- Configurable input smoothing.

The simulation should remain physically consistent regardless of control scheme.

Do not force arcade handling to make keyboard use possible.

# 14. AUDIO DESIGN

Sound is extremely important for immersion.

Create an audio architecture that supports authentic motorcycle engine sounds.

Include:

- Engine idle.
- RPM-dependent engine sound.
- Acceleration.
- Deceleration.
- Engine braking.
- Gear shifts.
- Rev limiter.
- Two-stroke and four-stroke differences.
- Exhaust characteristics.
- Tire sliding.
- Dirt impacts.
- Suspension movement.
- Landing impacts.
- Rider/bike collisions.

Sound must be synchronized with real engine RPM and throttle state.

Avoid simply changing the pitch of one generic sound sample across the entire RPM range.

Use layered or otherwise technically appropriate engine-audio synthesis.

Use legally obtained, licensed, or original audio assets.

# 15. RACING SYSTEM

The eventual game needs authentic motocross racing.

Implement:

- Starting gates.
- Practice sessions.
- Qualifying.
- Race sessions.
- Timed motos.
- Lap counting.
- Split times.
- Race positions.
- Finishing results.
- Penalties for cutting the track.
- Results screens.
- Race classifications.

Riders should be able to compete in different motorcycle classes.

The race system must accommodate outdoor motocross, supercross, and arenacross.

Race rules, event formats, and classes should be configurable.

# 16. TIME TRIAL MODE

Create a dedicated time-trial system.

Players should be able to select a track and motorcycle and compete for their fastest lap.

Include:

- Lap timer.
- Sector splits.
- Personal best.
- Track record.
- Lap invalidation for cutting.
- Optional ghost racing.
- Replay saving.
- Eventual online leaderboards.

Accurate timing is essential.

Time trials should support both casual practice and highly competitive riding.

# 17. SINGLE-PLAYER CAREER MODE

Build a career progression system.

Players should begin as an amateur rider with limited equipment and resources.

The eventual career should allow the player to:

- Create a rider profile.
- Choose a race number.
- Start on an entry-level motorcycle.
- Practice.
- Enter amateur races.
- Earn prize money.
- Purchase better motorcycles.
- Improve bike equipment.
- Sign with teams.
- Progress into more competitive events.
- Compete in professional-style championships.

Implement race weekends and seasonal championship standings.

The career should reward actual racing performance.

Career difficulty must arise from realistic opponents and meaningful competition rather than artificially worsening player physics.

Design AI competitors to follow the same fundamental racing rules and plausible vehicle behavior.

# 18. IN-GAME ECONOMY

Implement an earnable in-game currency system.

Players should earn money through:

- Career races.
- Championships.
- Event objectives.
- Time-trial challenges.
- Career milestones.

Currency should be spendable on:

- Motorcycles.
- Rider gear.
- Visual customization.
- Approved equipment upgrades.
- Garage items.

Keep the economy balanced.

It should reward progression without excessive grinding.

If optional monetization is eventually considered, keep it separate from the initial simulator development and avoid undermining competitive racing with pay-to-win mechanics.

# 19. ONLINE MULTIPLAYER

Eventually implement competitive online multiplayer.

Support:

- Dedicated servers.
- Public lobbies.
- Private lobbies.
- Practice sessions.
- Qualifying sessions.
- Online racing.
- Spectator mode.
- Server browser.
- Custom race settings.
- Different motorcycle classes.
- Online lap timing.
- Race results.

The network architecture should protect race integrity.

Use a suitable server-authoritative or carefully validated hybrid approach.

Provide smooth presentation through appropriate interpolation and prediction.

Avoid allowing clients to arbitrarily submit their motorcycle position without validation.

Design for latency, packet loss, and reconnect behavior.

Do not attempt to build full multiplayer before the core offline motorcycle physics are validated.

# 20. USER INTERFACE

Build a clean, modern interface.

The eventual main menu should contain:

- Ride.
- Career.
- Multiplayer.
- Time Trial.
- Garage.
- Rider Customization.
- Settings.
- Replays.

The in-game HUD should support:

- Speed.
- Gear.
- RPM.
- Lap time.
- Current position.
- Race time.
- Session information.

Provide optional minimalist HUD modes.

All menus should work with both mouse and gamepad.

The interface should look like a polished PC racing game rather than a generic debug application.

# 21. GRAPHICS AND VISUAL QUALITY

Target modern, believable PC graphics.

Focus on:

- Realistic lighting.
- Proper shadows.
- High-quality terrain.
- Detailed motorcycles.
- Detailed riders.
- Dust effects.
- Dirt particles.
- Tire marks.
- Suspension movement.
- Realistic environmental materials.
- Good distance rendering.
- Stable camera movement.

Visual effects should support the physics rather than conceal flaws.

Eventually support different weather and lighting conditions.

Allow graphical settings for a range of PC hardware.

The simulator should remain responsive even during graphically demanding races.

# 22. REPLAY SYSTEM

Implement a replay architecture that can eventually support:

- Full race replays.
- Slow motion.
- Multiple camera angles.
- Rider-follow cameras.
- Free camera.
- Lap review.
- Clip creation.
- Replay saving.

Prioritize accurate reconstruction of bike movement, rider animation, and collisions.

Design replay recording to support future content creation and competitive racing review.

# 23. PERFORMANCE AND PHYSICS ACCURACY

Performance is critical.

Target:

- Stable, high-frequency physics simulation.
- At least 60 FPS rendering on an appropriate target PC configuration.
- Higher frame rates on capable hardware.
- Minimal controller latency.
- Efficient terrain collision detection.
- Stable physics during high-speed riding.
- No frame-rate-dependent steering.
- No random physics explosions.
- No unexplained movement or teleporting.

Use profiling tools and measurable benchmarks.

Avoid unnecessary allocations and expensive operations in high-frequency physics loops.

Performance optimizations must not silently change motorcycle handling.

# 24. PHYSICS DEBUGGING AND VALIDATION

Build developer diagnostic tools from the very beginning.

I do not want to repeatedly encounter situations where code is supposedly changed but the riding feels identical.

Create an optional physics debugging interface showing:

- Current motorcycle speed.
- Engine RPM.
- Current gear.
- Lean angle.
- Steering angle.
- Pitch, roll, and yaw rates.
- Front/rear tire load.
- Tire slip values.
- Suspension compression.
- Contact state.
- Applied forces.
- Current terrain type.
- Active physics controller.
- Last crash reason.

Make it possible to verify that parameter changes are actually affecting the live simulation.

Any major physics change should be accompanied by:

1. Identification of the active code path.
2. Explanation of the change.
3. Evidence from available testing.
4. Expected observable behavior.
5. Specific manual test instructions.

If you cannot actually launch and play the game, say so.

Never claim handling has improved without evidence that the modified simulation is active.

# 25. CREATE A PHYSICS TEST TRACK FIRST

Before building the full game, create a dedicated development track.

Include:

- Flat straight.
- Wide flat corner.
- Tight corner.
- Banked berm.
- Small tabletop.
- Large tabletop.
- Jump with a defined landing.
- Braking bumps.
- Whoops.
- Rough terrain.

This is the first environment where the motorcycle must be developed and tested.

Do not start with an enormous open world or an entire racing championship.

The initial goal is one motorcycle on a functional track with genuinely good physics.

# 26. REQUIRED DEVELOPMENT ORDER

This project is too large to implement correctly in one undifferentiated coding pass.

Follow this phased development plan.

## PHASE A — Core playable foundation

Build:

- Project architecture.
- Functional 3D environment.
- One motorcycle.
- Working controller input.
- Basic camera.
- Motorcycle rigidbody.
- Wheel contact simulation.
- Working throttle and braking.
- Basic steering.
- Basic terrain collision.
- Physics diagnostic system.

Deliver a runnable prototype.

## PHASE B — Serious motorcycle dynamics

Develop and validate:

- Tire traction.
- Steering and lean.
- Weight transfer.
- Suspension.
- Engine and transmission.
- Jumping.
- Airborne control.
- Landings.
- Recoverable slides.
- Crash detection.

This phase is extremely important.

Do not proceed to large-scale content production until the motorcycle is actually enjoyable and believable to ride.

## PHASE C — Rider and presentation

Implement:

- Improved motorcycle model.
- Rider model.
- Rider animations.
- Body positioning.
- Audio.
- Camera polish.
- Dust and dirt particles.
- Improved track appearance.

## PHASE D — Racing foundation

Implement:

- Laps.
- Race timing.
- Starting gates.
- Basic AI opponents.
- Race positions.
- Results.
- Time trials.
- Basic replay support.

## PHASE E — Content expansion

Add:

- Additional motorcycles.
- More tracks.
- MX/SX/AX disciplines.
- Motorcycle customization.
- Rider customization.
- Garage.

## PHASE F — Career and progression

Implement:

- Career events.
- Rider progression.
- Currency.
- Championships.
- Motorcycle purchasing.
- Career rewards.

## PHASE G — Multiplayer

Implement and test:

- Server architecture.
- Online synchronization.
- Lobbies.
- Dedicated servers.
- Online races.
- Leaderboards.
- Spectating.

## PHASE H — Optimization and polish

Complete:

- Performance improvements.
- Stability testing.
- Visual polish.
- Audio refinement.
- Physics tuning.
- User experience improvements.
- Bug fixing.
- Build and packaging systems.

# 27. NON-NEGOTIABLE DEVELOPMENT RULES

Follow all of these rules throughout development.

**RULE 1:** Prioritize realism and physically coherent behavior.

**RULE 2:** Do not use arcade vehicle movement as a substitute for motorcycle physics.

**RULE 3:** Do not directly rotate the motorcycle to simulate realistic leaning.

**RULE 4:** Do not create artificially slippery handling to increase difficulty.

**RULE 5:** Do not introduce unrealistic automatic stabilization that fights the player's controls.

**RULE 6:** Do not sacrifice steering responsiveness in the name of realism.

**RULE 7:** Do not make all small mistakes result in crashes.

**RULE 8:** Do not hide physics problems behind visual animations.

**RULE 9:** Do not replace working code unnecessarily.

**RULE 10:** Do not claim a feature is complete when it is only a placeholder.

**RULE 11:** Do not introduce systems that conflict with existing calculations.

**RULE 12:** Do not prioritize menus, graphics, or content over a functional motorcycle.

**RULE 13:** Do not use fake physics values simply to produce impressive visual effects.

**RULE 14:** Do not create systems that only work on one track.

**RULE 15:** Keep physical motorcycle parameters configurable and well documented.

**RULE 16:** Provide the actual implemented code, not just descriptions or pseudocode.

**RULE 17:** Use meaningful tests, logs, and diagnostics to validate the simulation.

**RULE 18:** Keep the game launchable and playable at the end of each major development phase.

**RULE 19:** Do not reproduce proprietary MX Bikes or MX Simulator source code or assets.

**RULE 20:** Never report a successful physics overhaul based solely on compilation. The active runtime must be verified.

# 28. FIRST PLAYABLE BUILD — ACCEPTANCE CRITERIA

The first milestone must be a playable motorcycle physics prototype.

I should be able to launch the game and:

1. Spawn on the test track.
2. Accelerate smoothly from a standstill.
3. Brake with believable weight transfer.
4. Shift through working gears.
5. Turn gradually in both directions.
6. Navigate a flat corner without random tire washout.
7. Make a tight turn with appropriate rider control.
8. Ride over bumps without excessive instability.
9. Jump a small tabletop.
10. Adjust the motorcycle's pitch in the air.
11. Land and continue riding.
12. Experience realistic traction loss when I deliberately exceed the available grip.
13. Recover from minor slides.
14. Crash when an actual unrecoverable physical event occurs.
15. Observe diagnostics proving the physics systems are active.

These are observable requirements, not merely features that must exist in the code.

The prototype should also provide a reliable reset mechanism and a clear way to exit the game.

# 29. HOW TO BEGIN DEVELOPMENT RIGHT NOW

Do not respond with an enormous theoretical development plan and no implementation.

Do not try to implement all 28 sections in one pass.

Instead:

**STEP 1:** Inspect the project environment and determine the actual engine, framework, and tools available.

**STEP 2:** Establish a suitable clean project architecture without damaging the existing game.

**STEP 3:** Create the foundational 3D application.

**STEP 4:** Implement a basic dirt test environment.

**STEP 5:** Create one physically simulated 250cc four-stroke motorcycle with the necessary chassis, wheel, suspension, steering, and drivetrain architecture.

**STEP 6:** Implement functional keyboard and gamepad input where supported.

**STEP 7:** Establish the working third-person camera.

**STEP 8:** Implement the first functioning version of realistic tire contact, steering, balancing, suspension, throttle, and braking.

**STEP 9:** Add the initial physics debugging overlay.

**STEP 10:** Build and execute the project using available tools, verify that active gameplay systems are connected, and fix any errors that can be detected.

**STEP 11:** Provide exact instructions for launching and testing the build.

**STEP 12:** Report which requirements are implemented, which are placeholders, which are unverified, and what should be developed next.

Do not mark a phase complete just because files were created.

If you have working runtime access, verify the game directly.

If runtime testing requires my input, provide concise, specific riding tests and await my feedback before deciding that the handling is correct.

# 30. FINAL VISION

I want this to eventually feel like sitting on a genuine race-ready motocross motorcycle.

When I accelerate, the motorcycle should react to engine torque and traction.

When I brake, the chassis should respond to weight transfer.

When I enter a corner, the front tire, rear tire, steering, and rider position should work together naturally.

When I accelerate out of a rut, the rear tire should react believably to the available grip.

When I hit a jump, the suspension and motorcycle momentum should determine the takeoff.

When I whip, I should feel precise control over the motorcycle's rotation without unnatural snapping.

When I land, the suspension should absorb the impact and the motorcycle should continue according to the physical forces involved.

**I want realistic motocross riding, not the appearance of realistic motocross riding.**

The long-term ambition is a highly detailed, competitive motocross simulator with multiple motorcycles, realistic tracks, online racing, and a complete career system.

But our immediate goal is much simpler:

**BUILD ONE MOTORCYCLE THAT FEELS EXCEPTIONAL TO RIDE.**

Everything else will be built around that foundation.

Begin implementing Phase A now, then move into the earliest necessary Phase B systems to produce a meaningful playable riding prototype. Preserve a stable, working build and provide clear evidence of what you actually accomplished.

The finished initial milestone must be something I can launch, ride, test, and provide feedback on.

START DEVELOPMENT.
