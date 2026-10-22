# Final two ground vehicles: inspected assets and implementation prompt

Inspected 2026-10-23 using raw GLB structure, rendered Godot previews, current enemy code, and Ziva MCP project information. This document is a handoff prompt; production integration has not been performed.

## Verified findings

| Design | Running gear | Chassis triangles | Weapon triangles | Total without wheels |
| --- | --- | ---: | ---: | ---: |
| Desert Barrage Rover | Six wheels, three axles | 6,421 | 2,476 | 8,897 |
| Raptor Raider | Four wheels, two axles | 5,101 | 1,247 | 6,348 |

There are two designs and twelve GLB exports, including duplicate part exports, complete assemblies, and centered weapon variants. There are no animations or skins. Each chassis and each weapon is a single mesh primitive. The chassis meshes retain structural hubs/fenders but lack tires. Each weapon combines its pedestal/base and moving weapon geometry; independent elevation/recoil requires further articulation work.

Source forward is -X, up is +Y. A -90-degree Y wrapper aligned the previews to game forward -Z. Native hull dimensions (length X, height Y, width Z): Desert `(0.954590, 0.345703, 0.482910)`; Raptor `(0.956055, 0.302246, 0.646972)`. These are source units, not final game meters.

Assembly weapon translations relative to the identity chassis node:

- Desert: `(0.3195800185, 0.03393600136, 0.0)`.
- Raptor: `(0.2150879949, 0.05151399970, 0.000243999064)`.

These are measured assembly transforms, **not verified yaw or elevation pivot locations**. Centered weapon GLBs reset node translation; their vertex bounds are unchanged, so their filenames do not establish mechanical pivots.

The shared wheel resource has one surface and native AABB position `(-0.495692, -0.515129, -0.208077)`, size `(1.017128, 1.017455, 0.419287)`. Its thin/axle axis is Z and its center has a small offset. Wheel mounts, individual mechanical pivots, and final game scale still need calibration during implementation. Existing wheel controllers assume four wheels.

Inspection evidence: `artifacts/final-ground-model-inspection.json` and `artifacts/final-ground-*-*.png`. Full GLBs repeatedly embed the same three 2048×2048 textures within each design; avoid loading duplicate material/image sets into the production rigs. Both models use the generic material name `Material_0`, which does not mean their materials are interchangeable.

## Copy-paste implementation prompt

```text
Implement the final TWO ground vehicles in my existing Godot project:
C:\Users\Prime 3\Documents\ziva-heli-town-helll

Use the connected Ziva MCP to inspect the editor and verify the result. Read AGENTS.md and the current production enemy pipeline before editing. Implement and test the vehicles in real gameplay, not only in a showroom. Preserve unrelated work, source assets, current helicopter handling, XP collection/card behavior, and existing working enemies. Use isolated test profiles so verification does not change my saved progress.

1. ROSTER AND ASSET MAPPING

Add two new ground variant IDs:
- raptor_raider: Raptor Raider, a mobile cannon raider.
- desert_barrage_rover: Desert Barrage Rover, a wheeled missile barrage vehicle.

These are additions. The final active ground roster must contain exactly seven:
scout_buggy, assault_apc, rail_crawler, siege_tank, gatling_heavy,
raptor_raider, desert_barrage_rover.

Preserve the existing five mappings and their working rigs. Keep these eight old types disabled in both wave selection and public spawning:
rocket_buggy, flame_tank, mortar_crawler, sam_launcher,
technical_truck, flak_tank, missile_carrier, infantry_squad.

Use these exact sources, preserving capital Enemy and the space in new ground:

Raptor:
res://assets/Enemy/new ground/Raptor_Raider/Chassis.glb
res://assets/Enemy/new ground/Raptor_Raider/Gun_Turret.glb
Assembly reference:
res://assets/Enemy/new ground/Raptor_Raider/Raptor_Raider_Complete.glb

Desert:
res://assets/Enemy/new ground/Desert_Barrage_Rover/Chassis.glb
res://assets/Enemy/new ground/Desert_Barrage_Rover/Missile_Barrage_Launcher.glb
Assembly reference:
res://assets/Enemy/new ground/Desert_Barrage_Rover/Desert_Barrage_Rover_Complete.glb

The chassis/ and guns/ folders contain duplicate exports. Choose one canonical source for each part. Complete GLBs are alignment references; never render complete and separated assemblies together. Preserve the Blender/FBX originals. Neither model contains baked animations or a skeleton.

2. ASSEMBLY, ORIENTATION, SCALE, AND PIVOTS

Read docs/IMPLEMENT_FINAL_TWO_GROUND_VEHICLES_PROMPT.md and the JSON inspection report. Source forward is -X; a Y=-90-degree visual wrapper aligns it to game forward -Z. Apply uniform scale once and document the transform chain. Match the complete assembly before introducing articulation. Source weapon translations relative to chassis are:
Desert (0.3195800185, 0.03393600136, 0)
Raptor (0.2150879949, 0.05151399970, 0.000243999064).

These are assembly offsets, not guaranteed mechanical pivots. Centered weapon exports only remove node translation; they do not split moving parts or establish proper hinges.

Measure roof-ring centers, gun trunnions, wheel hubs, and muzzle positions from geometry. Save measured pivots, bind transforms, wheel mounts, radii, and limits in per-vehicle configuration resources. Do not invent exact coordinates or stretch models independently by axis. Calibrate length, width, clearance, and simple collision shapes alongside Scout Buggy, Assault APC, the helicopter, and roads. Raptor is proportionally much wider than Scout Buggy; do not copy Scout's collider blindly. Keep physical enemy roots under the existing CharacterBody3D movement system.

3. REUSE THE UNIVERSAL WHEEL

Use exactly the existing shared wheel Mesh and Material:
res://assets/Enemy/tank_game_ready/universal_wheel_mesh.res
Existing reusable scene:
res://scenes/enemies/shared/universal_wheel.tscn
Original source:
res://assets/Enemy/tank_game_ready/Tank_Tire_Reduced.glb

Do not copy or duplicate unique wheel mesh/material resources for either new vehicle. Every wheel should be a lightweight instance referencing the same shared resources as Scout/APC. Per-vehicle scale, mount position, axle orientation, steering flag, and animation sign are configuration, not new wheel assets. Retain chassis suspension/hub/fender geometry unless inspection proves something is a duplicate tire.

Raptor needs FOUR wheel instances: front and rear axles.
Desert needs SIX wheel instances: front, middle, and rear axles.
Measure the actual hub centers and wheel arch clearance. The shared wheel's native axle is Z and its center is slightly offset; use a static orientation/centering wrapper, separate steering and spin pivots, and correct outward-facing wheel sides. Avoid mirroring with negative scales. Keep physical wheel diameter and configuration radius consistent.

Use a data-driven wheel animator supporting arbitrary axle/mount counts. Existing scout_buggy_wheel_controller.gd and assault_apc_wheel_controller.gd hardcode four wheels; do not attach either unchanged to the six-wheel Rover. Existing vehicles can keep their controllers unless a shared refactor is needed and regression-tested.

Animate from actual planar movement after collision resolution:
spin_delta = signed_travel_distance / effective_world_wheel_radius.
Reverse must reverse spin; blocked/stationary vehicles must stop spinning. Ignore vertical falling, spawn displacement, and teleports. Account for the complete transform scale, including elite and visual scaling. Front axle steering should smoothly follow actual turns, return to center, and behave correctly in reverse; middle/rear axles remain fixed by default. Initialize heading consistently to avoid a first-frame steering snap. Reset caches on pooling/respawn; stop animation on death and respect pause.

4. ARTICULATED WEAPONS AND CHASSIS

Each supplied weapon is currently ONE mesh combining its base and moving parts. Inspect the supplied separated .blend files first; separate fixed pedestal/yaw components from elevating weapon geometry and recoil components as necessary, preserving UVs/materials and assembled appearance. Do not pitch the entire roof pedestal or recoil the complete vehicle. Save derived runtime parts separately and leave originals intact. Verify derived geometry has no missing or doubled faces.

Provide independent yaw and elevation, explicit mechanical limits, actual bore-aligned muzzle markers, and a shared-compatible turret API. Inspect articulated_tank_turret.gd, scout_buggy_turret.gd, assault_apc_turret.gd, and their callers. Their track_aim parameter units are not all identical; use explicit degree-based names/conversion for new rigs, and never pass degree values into a radians API accidentally.

Preserve the production enemy/Turret lookup contract or update every caller deliberately. Use separate yaw, elevation, recoil, and mesh-bind transforms. Aim in the correct local frame after chassis rotation/scale. The target is the live player/committed combat aim point; yaw remains independent of hull heading. Smooth tracking must cross +/-180 degrees without snapping. Report alignment AND mechanical reachability, preventing shots when the barrel cannot reach the target. Test elevated helicopter targets and sloped ground. Do not fire through the chassis or nearby walls.

Raptor: articulate the cannon above its ring, add a true muzzle at the barrel tip, and apply short backward barrel recoil only when a real shot occurs. Recover exactly to the bind transform without accumulating drift during bursts.

Desert: preserve the supplied angled launcher rest pose. There are two missile pods, with four visible tube openings per pod. Place one Marker3D at each of the eight actual tube outlets. Configure a deterministic alternating-pod tube order. Telegraphed aim, line-of-sight checks, flash/smoke, projectile origin, and projectile direction must refer to the same selected tube. Merely querying a muzzle must not advance the tube index; advance only when a shot is actually emitted. Do not force all eight tubes to fire simultaneously. Use controlled salvos and visible launch exhaust; avoid cannon-style sliding recoil on the entire missile rack. Use existing projectiles rather than spawning the decorative launcher model as a projectile.

Add restrained acceleration/braking pitch, cornering roll, and damped settling derived from real movement. Keep hull/turret mounting synchronized without floating or roof gaps. Keep wheel contact believable while the body moves. Cosmetic chassis motion must not move collision shapes or destabilize AI movement. Avoid perpetual idle bouncing and one RigidBody per wheel.

5. CONNECT REAL GAMEPLAY AND SPAWNING

Inspect/update the actual paths:
src/enemies/enemy_data.gd
src/enemies/enemy_spawner.gd
src/enemies/procedural_raider.gd
src/enemies/field_raider_visuals.gd where relevant
src/enemies/encounter/spawn_card_catalog.gd
and applicable encounter, navigation, ground classification, minimap, and combat consumers.

Add authoritative specs, active whitelist entries, real spawn cards, visual routing, calibrated collision dimensions, and explicit movement/weapon branches for BOTH new IDs. Check FIELD_ROLES dispatch and all variant-specific matches. Never let an unknown new ID fall back to an air gunship, default mortar movement, placeholder model, or wrong projectile.

Raptor should pursue/reposition as a mobile wheeled cannon vehicle with readable controlled bursts. Desert should maintain a suitable standoff distance and launch readable limited rocket salvos. Use existing navigation/steering, CombatDirector attack slots, cooldowns, aim commitment, range gates, obstruction checks, and projectile/damage systems. Keep shots physically consistent with the weapon's reachable direction. Respect stunned, dead, paused, and missing-player states. Tune wave gates, costs, caps, damage, speed, and rewards relative to current enemies; record the chosen values and rationale.

Ensure both receive normal damage, die once, update kills/score/ground minimap classification, and drop the correct coins/physical XP. XpManager remains authoritative: no direct XP award on death. Preserve air/support enemies and existing progression.

6. PERFORMANCE AND RESOURCE HYGIENE

Cache/load reusable scenes, meshes, textures, materials, and mount references once. Do not parse GLBs, extract meshes, scan the scene tree, rebuild collision, or allocate materials every frame or spawn. Each design repeats the same three embedded 2048px textures across exports; consolidate runtime resource references within that design after verifying equivalent texture content and correct PBR channels. Do not merge the two designs merely because both materials are named Material_0. Preserve original appearance and normal/roughness/metallic mapping under the project's GL Compatibility renderer.

Use simple vehicle collision and existing culling/LOD conventions. Share wheel Mesh/Material identities even across multiple enemies. Keep muzzle effects bounded and short-lived. Measure representative wave frame time against the current build and address any regression introduced by this work.

7. VERIFY BEFORE REPORTING DONE

Add focused checks and a rendered demonstration with a real solid floor, then verify live gameplay through Ziva:
- Exactly seven active ground IDs; eight disabled IDs rejected by director and public spawning.
- Each new ID produces its own correct model, ground AI, collider, and real attack.
- Four Raptor wheels and six Desert wheels, all sharing the SAME Mesh/Material resources across vehicles.
- Forward, reverse, cornering, blocked movement, teleport, pause, death, respawn, and elite-scale wheel behavior.
- No floating, buried tires, backwards meshes, clipped roofs, stretched models, or detached turrets.
- Independent yaw/elevation reaches moving and elevated targets; impossible angles cannot fire.
- Raptor burst recoil returns to bind pose; Desert tube selection/telegraphs/projectiles agree.
- Projectiles actually damage the player; death, coins, physical XP, score, and minimap work once.
- Existing five ground vehicles, air enemies, helicopter handling, and XP/card flow still work.
- No new parser/runtime errors, missing assets, leaked nodes, or material duplication per instance.

Update AGENTS.md and relevant roster docs to reflect seven integrated ground vehicles ONLY after implementation and verification. Deliver exact new variant mappings, changed files, measured mount/config values, selected combat tuning, test results, screenshots of both complete wheeled rigs, and any remaining limitations. Do not claim visual success based only on a headless test.
```
