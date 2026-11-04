# Gameplay scale, HUD layout, and responsive helicopter motion

Follow-up implementation and verification: [completed fixes, 4 November](PRESENTATION_AND_CONTROLLER_FIX_RESULTS_2026-11-04.md). The findings below describe the pre-fix state.

Review date: 3 November 2026. Source inspection and new rendered diagnostics completed; gameplay code has not been changed by this review.

## Copy-ready implementation request

Improve the existing Godot game at `C:\Users\Prime 3\Documents\ziva-heli-town-helll` so the gameplay HUD, player helicopter, enemies, and camera feel proportionally consistent, and the helicopter moves like a responsive aircraft rather than a rigid model sliding over the town.

Read `AGENTS.md` and `docs/IMPLEMENT_CONTROLLER_360_MOVEMENT_FIX_PROMPT.md`. Coordinate this work with that left-stick repair: smooth camera-relative 360-degree translation and independent right-stick aiming are requirements. Preserve unrelated working-tree changes. Implement and verify the work in the real game, rather than delivering a standalone showcase or only editing documentation.

Consistent scale means a coherent relationship between objects and a readable interface. It does not mean making a buggy, helicopter, fighter, and boss identical in size. Preserve useful role silhouettes and deliberate boss scale. Keep the supplied models, the seven enabled ground vehicles, the nine modeled regular aircraft roles, and the regular-wave exclusion policy. Preserve scripted Titan launch-bay escorts and the universal shared wheel resources.

### Evidence already collected

1. The project uses a 1280x720 logical canvas, `canvas_items` stretching, and `expand` aspect handling. At 960x540 and 1920x1080, the diagnostic still reported a 1280x720 logical viewport; 1024x768 expanded it to 1280x960. Physical window pixels and logical UI coordinates must be distinguished. Applying a second resolution multiplier indiscriminately would introduce another scaling defect.

2. Production `src/ui/survival_hud.gd` contains fixed positions, panel widths, and 8–22 point font overrides mixed with anchors. In the new rendered long-score fixture, the stats row occupied `(18,23)` through `(664,45)`, while the timer occupied `(480,23)` through `(800,52)`. Large score/high-score text visibly collided with the timer at both 1280x720 and 960x540. The rectangle conflict persisted at the other tested resolutions. The default small-value state is less crowded, so testing only zeros misses this.

3. `src/ui/hud.gd::_draw_target_bracket` uses a fixed 46x46 box, a 40x4 health bar, and an 8-point target label. It projects an origin offset, rather than fitting the bracket to the rendered vehicle. A close helicopter, a distant buggy, and a large boss therefore receive the same bracket dimensions. Salvo locks are similarly center markers; retain their distinct meaning rather than blindly making them oversized bounding boxes.

4. A mesh-bounds diagnostic measured approximate visible extents in gameplay units: Apache `(10.96,4.47,13.77)`, Nighthawk `(10.08,4.11,12.67)`, Warlock `(11.84,4.82,14.87)`, Scout Buggy `(2.20,1.94,3.81)`, Assault APC `(2.97,2.20,5.91)`, attack gunship `(7.86,3.34,9.97)`, interceptor `(4.16,1.69,6.03)`, and heavy bomber `(8.11,2.31,7.01)`. These are combined mesh AABBs in the sampled poses, including rotor geometry where present, excluding named blur planes and cue meshes. They are not separate fuselage dimensions or evidence that all these ratios are wrong. Establish body/rotor/wing dimensions separately before choosing adjustments. The same player collision box `(3.6,2.5,11.5)` is used for all three visually scaled airframes; inspect fair hull coverage rather than extending collision to every rotor tip.

5. The main and tail rotors resolve to actual imported nodes under `Visuals/ApacheModel/Player`. However, `side_wings`, `skid_left`, and `skid_right` are null in the live player instance. The corresponding optional animation blocks do nothing. Inspect the imported hierarchy instead of assuming the old procedural node names exist.

6. Existing aircraft animation is present. A one-second isolated flight diagnostic reached approximately -18 degrees of visual pitch forward, +13.5 degrees backward, and -7.1 degrees of steady bank when strafing right. The lateral bank shrinks toward a small cruise lean once its speed error disappears. Pitch and bank mainly follow command/local speed heuristics, while climb/descent have no comparable dedicated attitude cue. Hover is driven by repeated sine waves, and the normal hover-bob function has no landed suppression. Verify actual grounded behavior before changing it.

7. The chase camera follows hull yaw tightly and adds only 10% of bank, capped at 2.5 degrees. The body attitude is physics-stepped, then written to Visuals in render processing; the camera uses the interpolated body transform. Audit update order and interpolation ownership before adding more smoothing. Turret and muzzle nodes are outside Visuals, so changing cosmetic hull transforms requires a deliberate mount/aim alignment check.

### Part A: coherent vehicle, world, and camera scale

Create a reproducible scale audit for all three player airframes, all seven active ground vehicles, all nine regular air roles, and the three actual biome boss routes. Instantiate production scenes/controllers. Use both a neutral comparison scene with shared distance/orientation and the normal gameplay camera in the generated town. Compare tanks, cars, road lanes, roofs, landing zones, rotor clearance, and representative buildings. Include elites. A foreground player naturally projects larger than an enemy farther from the camera; do not mistake perspective for an asset-scale error.

Measure model-local and world dimensions, hull length, rotor/wing span, ground-contact height, origin/pivot, collider placement, and projected screen bounds. Distinguish body bounds from decorative blades, particles, trails, damage effects and warning geometry. Record representative near/normal/far engagement distances and low/normal/high flight altitudes. Use the actual encounter ranges and all biomes when selecting samples.

Choose and document consistent target proportions per class and a standard gameplay camera profile. Tune camera distance, height, FOV, aim visibility and look-ahead together. The player must remain identifiable without hiding incoming threats or taking over the screen, and ordinary enemies must remain identifiable at useful combat distances. Preserve foreground/background perspective. Camera occlusion recovery, speed pull-back and aspect-ratio changes must not cause sudden apparent size jumps. Do not use dynamic per-enemy scaling based on camera distance.

Store necessary model normalization in clear per-vehicle configuration rather than scattering compensating scale factors across scenes/scripts. Keep physics roots at unit scale. If a vehicle is resized, synchronize its model, appropriate colliders, wheel contacts, turret mount, pivot/elevation rig, muzzle sockets, recoil distances, smoke/exhaust anchors, ground clearance, spawn clearance, and elite scaling exactly once. Maintain pure weapon socket queries and actual projectile origins. Preserve shared wheel meshes/materials and enclosed tank running gear.

Audit player airframe variants and hangar previews too: preview camera framing may differ, but it must not change gameplay dimensions or cause duplicated variant scaling. Avoid replacing the player's model solely to alter proportions.

### Part B: responsive HUD and correctly fitted target UI

Introduce one coherent HUD layout and sizing policy using containers, anchors, logical safe margins, consistent spacing, and a small type/icon hierarchy. Preserve the current visual identity while making critical information readable. Keep an unobstructed central combat area. Separate top-left survival/run stats, top-center wave/timer and boss information, top-right radar, bottom mission actions, and transient warnings with a layout that can adapt instead of overlapping.

Handle long score/high-score/credit values, long weapon and mission names, low fuel/hull, queued levels, missile alerts, boundary warnings, boss health, cargo, controller disconnect text and expanded radar. Show these combinations together. Reflow or intentionally compact secondary data; do not solve collisions by silently hiding hull, ammunition, timer or actionable mission information. Decorative HUD controls must not capture gameplay input, and mission/menu controls must remain accessible by controller.

Use the existing canvas stretch deliberately. Implement an explicit saved HUD/text scale preference if needed for readability, independently of 3D camera/vehicle scale. Apply it through a coherent layout/theme strategy; do not scale the whole CanvasLayer and break mouse/aim projection. Reticle, turret targeting, salvo locks, mission arrows and UI drawing must agree on the same logical coordinate space, with any canvas transform applied exactly once.

Fit the selected-target bracket to cached projected visual hull bounds or an explicit per-vehicle targeting envelope. Handle off-center pivots, turrets, elite scale and cosmetic motion. Clamp decorative padding, corner lengths, line widths, and label/health-bar dimensions to readable minima/maxima without pretending a distant enemy is physically larger. Handle near-plane clipping, behind-camera targets, partially visible objects and invalid/dead targets without giant rectangles, NaNs or jumping labels. Keep lock dots and selection envelopes distinguishable. Avoid walking every mesh every frame; cache suitable bounds and refresh only when configuration or relevant pose changes.

Use the same target anchor policy across the HUD, InputManager, turret and salvo painter where appropriate. Keep the actual impact reticle tied to the firing muzzle and preserve blocked/out-of-arc feedback. UI drawing and bounds queries must not advance a weapon outlet or modify gameplay targeting merely to improve presentation.

### Part C: responsive helicopter physics and motion

Keep responsive arcade flight with bounded inertia. Complete the controller prompt's direction-independent planar movement first or integrate it in the same coherent change. Do not add sluggish steering, huge drift or a full rigid-body simulation that makes left/right dodging harder.

Separate the collision/movement root from a documented cosmetic flight rig. Drive desired body attitude from requested acceleration, measured velocity change, braking, yaw rate and climb/descent state in the proper aircraft-local frame. Use bounded, frame-rate-independent spring/damping or equivalent stable response. Verify rotation signs against the imported model: forward acceleration should visibly dip the nose, braking should flare, sideways acceleration should lean into motion, lateral braking should counter-bank, and turning should communicate load. Climb/descent should have appropriate restrained load/pitch cues without implying that every vertical move requires a large pitch angle.

Use configurable values and distinct airframe response profiles. Nighthawk may feel lighter and Warlock heavier while both retain precise stick control. Preserve engine/rotor condition, cargo, speed/handling/thrust upgrades, shield/dash ownership, altitude constraints and collision damage. Cosmetic bank must not rotate the movement vector, yaw the camera unexpectedly or alter hit calculations. Ground and roof contact must remain stable and fair.

Replace repetitive or overlarge idle bobbing with subtle bounded hover stabilization that blends naturally with maneuvers. Suppress hover motion appropriately on landing, settle on the actual landing gear/contact plane, and transition cleanly through takeoff, landing, dash, damage, death and retry. Do not create fake positional motion by moving the collider while the aircraft is meant to hover. Keep any visual/collider offset small and explicitly bounded.

Bind animation to the imported model's real nodes. Snapshot rest transforms and apply reversible offsets from those baselines; no cumulative drift or hard-coded reset to unrelated model coordinates. Animate independent wings/gear only if real separable geometry exists. If it is combined, document the limitation instead of pretending null hooks animate it. Preserve original source assets and derive any necessary rig changes reproducibly.

Keep main/tail rotors rotating around verified local shaft axes. Tune startup/load/landing/damage/death RPM and rotor blur from actual rotor dimensions and runtime load. Verify at 30/60/120 FPS to avoid an apparently stopped/reversed rotor due to sampling. Preserve pause behavior and bounded phases. Use restrained rotor/load audio, optional downwash near surfaces and small secondary flex only where they improve feedback without obscuring threats or exceeding the performance budget.

Synchronize the visible turret mount, real muzzle transform, muzzle flash, projectile origin, smoke and exhaust with the chosen attitude rig. Preserve independent gimbal aiming and mechanical limits. Do not let weapons visibly detach from a banking fuselage, fire from an old pose, clip into the hull or drift during repeated recoil. Update camera, presentation pose, aiming and projection in an explicit order with exactly one intended interpolation/smoothing owner per transform. Keep the image stable enough for precise right-stick and mouse aiming.

### Acceptance and delivery

Capture identical baseline/after states at 960x540, 1280x720, 1920x1080, 1024x768, and an ultrawide ratio. Verify default and enlarged HUD scales, resize during a run, and fullscreen/window transitions. Assert layout bounds and critical-control non-overlap, then visually inspect the screenshots; assertions alone cannot establish readable text or balanced composition. Large-value stats must no longer collide with the timer.

Provide a model/collider/socket scale table and labeled side-by-side comparisons at equal camera distance, plus normal combat screenshots. Test all active vehicles, elite scaling, close enemies, distant enemies, and actual boss construction in Town/Desert/Harbor. Do not report boss coverage from a failed normal spawn request; use its legitimate director route.

Record rendered motion sequences for hover, forward acceleration, braking, left/right strafe, diagonal/circular movement, reversal, yaw turns, climbing, descending, dash/recovery, landing/takeoff, damage and death/retry. Include controller movement and independent aiming/firing. Measure attitude onset/settling, peak tilt, braking distance, speed/direction response, visual/collider offset, rotor shaft stability and muzzle alignment. Verify the behavior at 30/60/120 render FPS with normal fixed physics, including paused states and interpolation resets. Preserve or improve the controller prompt's movement acceptance criteria; increased visual motion must not slow input response.

Add focused regressions for the reproduced HUD overlap, projection/target envelope, real animation-node binding and pose transitions. Rerun relevant existing suites, including `test_controller_handling.gd`, `test_controller_ready.gd`, `test_flight_frame_rates.gd`, `test_helicopter_lateral_handling.gd`, `test_flight_altitude_collision_and_blood_fx.gd`, `verify_playability_game_loop.gd`, `test_air_enemy_integration.gd`, `test_seven_ground_vehicles_integration.gd`, `test_gameplay_stability_and_upgrades.gd`, and `test_xp_upgrade_effects.gd`. Isolate saves with `ZIVA_TEST_DATA_DIR`. Run additional targeted checks only where actual changes require them.

Compare frame-time distributions and draw calls under equivalent town/combat conditions. Do not claim a locked frame rate from short or hidden-window samples. Report script errors, cleanup warnings, measured regressions and unavailable hardware checks separately. Finish with changed files, before/after evidence, final control/camera/HUD behavior and remaining limitations.

## Review artifacts and limits

Local diagnostic: `artifacts/scale-motion-review-2026-11-03/probe.gd`, with `probe.log` and an empty `errors.log`.

Rendered evidence: `idle-1280x720.png`, `hud-1280x720.png`, `hud-960x540.png`, `hud-1920x1080.png`, `hud-1024x768.png`, and three `motion-*.png` captures in that directory. Large score totals were deliberately injected to expose layout conflict. Motion poses were manually stepped through the real flight controller and visual update methods; they are staged evidence, not a human-played flight assessment or a performance benchmark. Player physics was disabled during scale/HUD captures to keep placement repeatable.

The normal public spawner rejected the diagnostic's `heavy_gunship_boss` request. This review did not measure its dimensions or either modular boss. Their actual director paths require separate acceptance coverage. Nine regular air roles and seven ground roles were measured. Full fuselage-only bounds, all HUD alert combinations, ultrawide presentation, true landed behavior and physical-controller feel have not been verified by this diagnostic.

Primary implementation files to inspect: `project.godot`, `src/ui/survival_hud.gd`, `src/ui/hud.gd`, `src/ui/boss_tracker.gd`, `src/ui/mission_tracker.gd`, `src/ui/minimap.gd`, `src/player/player_helicopter.gd`, `src/player/player_camera.gd`, `src/player/player_turret.gd`, `data/aircraft_specs.gd`, `scenes/player/player.tscn`, enemy visual scenes/configs, and `src/enemies/base_enemy.gd`.
