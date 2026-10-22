# Replace Assault APC visuals with the supplied modular armored vehicle

Implement this in the existing Godot project:
`C:/Users/Prime 3/Documents/ziva-heli-town-helll`

Use the new model in `assets/Enemy/tank_game_ready/` to replace **Assault APC (`assault_apc`)** only. Deliver an assembled, animated, independently aiming and correctly firing enemy in the real game. Preserve its existing AI and weapon balance.

## 1. Correct model assignment

Although the files are named tank, inspection of the actual assembled GLB shows an armored carrier with a sloped front cab, windows, a tall transport body, wheel arches and a compact roof gun. It is a better match for the existing Assault APC than the Siege Tank. The Siege Tank is a heavy large-cannon enemy with explosive artillery behavior; this replacement should retain the APC's rapid bullet bursts. Do not replace the Siege Tank, Flak Tank, Incendiary Tank, Scout Buggy or all ground enemies together.

A source-model render is available at `artifacts/tank-source-review-20261020/tank-source-preview.png`. It confirms the broad shape, turret placement and wheel arches awaiting their separate wheel instances. It is a Blender asset inspection, not proof of a working Godot import, animation or gameplay integration.

## 2. Read current files and inspect the source

Read AGENTS.md and recheck source files before editing. Other work may be modifying enemy visuals, effects and the Scout Buggy integration; preserve unrelated changes. All new enemy source assets belong in `assets/Enemy/`, preserving the capital E.

The supplied directory is `res://assets/Enemy/tank_game_ready/`:

- `tank_hull.glb`, `tank_turret.glb`, `tank_assembled.glb`
- Matching `.blend` and `.fbx` sources/exports
- `Tank_Tire_Reduced.glb`
- `textures/tank_base_color.png`, `tank_metallic_roughness.png`, `tank_normal.png`
- `README.md`

Prefer the GLBs for the runtime import. Use the assembled export or a single assembly of the separate hull and turret, never both complete versions layered together. Preserve original files and save any articulated or closed-hull derivatives separately. Do not rename the asset folder just because its intended enemy is Assault APC.

Verified source metadata:

| File | Triangles | Meshes / materials | Animation clips |
| --- | ---: | --- | ---: |
| tank_hull.glb | 2,712 | 1 / 1 | 0 |
| tank_turret.glb | 936 | 1 / 1 | 0 |
| tank_assembled.glb | 3,648 | 2 / 2 | 0 |
| Tank_Tire_Reduced.glb | 1,499 | 1 / 1 | 0 |

The assembled source hierarchy is `Tank_Hull → TurretMount → Tank_Turret`. The actual GLB mount translation is about **(-0.009013, 0.117920, -0.000682)** in its parent coordinates. The README lists approximately (-0.009, 0.0007, 0.1179), with a different axis arrangement. Use the actual imported transform; do not paste the README coordinates into Godot.

The hull is approximately 0.954 source units along X, 0.444 along Z and 0.301 high along Y. Its long axis is X and the cannon extends predominantly toward negative X. Gameplay expects +Y up and -Z forward. Normalize orientation with a clear wrapper transform and verify visually, rather than scattering asset correction angles through aim code.

The turret is one mesh: turret shell, gun and mount are not yet an independently articulated gun rig. No supplied GLB contains animation clips. The existence of a separate turret and centered yaw mount does not prove that gun elevation or recoil is ready. Inspect the Blender source, actual pivots, normals, UVs, material slots, hidden fragments and wheel-well clearance. A low triangle count alone does not approve the asset.

## 3. Preserve the current Assault APC behavior

Read and work through:

- `src/enemies/enemy_data.gd`: variant parameters and wave scaling.
- `src/enemies/enemy_spawner.gd`: creates the APC as `ProceduralRaider`, adds its collider/DamageReceiver, and routes its visuals through RaiderVisuals.
- `src/enemies/raider_visuals.gd`: current procedural `assault_apc` chassis, wheels and direct-child Turret.
- `src/enemies/procedural_raider.gd`: pursuit, movement, predictive aiming, warnings, bursts, muzzle resolution and projectile setup.
- `src/enemies/base_enemy.gd`: movement, modifiers, pause, death and common aiming.
- `src/combat/projectile.gd`, `src/combat/damage_data.gd`: actual shot behavior and enemy damage scaling.
- `src/effects/fx_manager.gd`, `autoload/shader_manager.gd`: muzzle effects and outlines.

Current APC data is wave gate 3, cap 4, 75 base hull, speed 15, score 160 and XP 5. Its intended role is armored mobile shooter, with engagement range 28–45 m, weapon reach 70 m, 0.35 s warning, aim commitment at 70%, 2.2 s base cooldown and three-round bursts at 0.12 s intervals. The existing shot path uses 9 base damage, speed 160, zero blast radius, collision mask 3 and `enemy_bullet` effects. Re-read these values in case concurrent work changed them intentionally. Preserve their latest intended values and per-wave stat/damage scaling.

Retain CharacterBody3D as the physics root, the existing steering/navigation and the working approach-before-fire behavior. Keep spawn clearance, wave gates, caps, rewards, pause, recovery, death and applicable attack permissions. Do not introduce VehicleBody3D, extra wheel physics or a second AI/weapon controller. The visual gun has one barrel; it can fire the existing three-round burst without adding fake extra barrels or changing damage.

## 4. Assemble the reusable rig with a universal shared wheel

Create a reusable scene such as `scenes/enemies/assault_apc_visuals.tscn` and a small aim/animation component. Replace only the APC's procedural visuals. Remove or bypass its old chassis, wheels and turret so no duplicate geometry remains.

Use the existing direct-child `Turret` interface or adapt every access point consistently. Instantiate the rig before BaseEnemy ready-time visual and modifier binding. Suggested runtime hierarchy:

```text
AssaultAPC (existing CharacterBody3D / ProceduralRaider)
├── CollisionShape3D
├── DamageReceiver
├── Visuals
│   ├── HullModel
│   └── Wheels (mounts for shared wheel instances; fitted to actual arches)
│       ├── FrontSteeringPivots → SpinPivots → SharedWheelMesh instances
│       └── RemainingAxleSpinPivots → SharedWheelMesh instances
└── Turret (vertical yaw pivot at the actual roof mounting ring)
    ├── TurretBodyModel
    └── GunPitch (horizontal elevation pivot at the gun hinge)
        ├── FixedGunCradle / mantlet parts as appropriate
        └── Recoil (only parts that physically slide)
            ├── GunModel
            └── Muzzle (Marker3D: barrel tip, local -Z outward)
```

The user has clarified that the separate wheel should be used on this APC and wants one universal wheel asset shared across wheeled enemy models. Keep the actual wheel arches open and fit the wheel instances to them. The earlier enclosed-running-gear preference applies to the tank designs, not this wheeled APC. Count the actual model's arches/axles before assembly; do not force the old procedural APC's six-wheel count onto a source body with a different layout.

Use `assets/Enemy/tank_game_ready/Tank_Tire_Reduced.glb` as the initial universal wheel source: 1,499 triangles. Create a shared wheel scene/resource wrapper such as `scenes/enemies/shared/universal_wheel.tscn`; this is a proposed new runtime wrapper, not an existing asset. Every wheel position on every supported wheeled vehicle should reference the same Mesh and Material resources. Keep the original Scout Buggy tire as source/reference, but do not introduce another separately loaded wheel mesh per vehicle type when the universal wheel can fit.

Current APC collision baseline is about **3.2 m wide × 2.2 m high × 6.2 m long**, with its bottom on the root ground plane. Matching a 6.2 m hull to the 0.954-unit source length gives an initial uniform scale near 6.5. Treat that as a starting estimate only: the complete source with turret is about 0.400 units tall, so the final assembled visual height needs measuring separately. Match town roads, the player and production camera. Do not silently increase collision width or length to fill a preview window.

Correct orientation, calculate the final lower contact plane, then transform the real mount into the enemy's coordinate system. Avoid double application of scale, source correction rotation or mount translation. Keep simple body collision appropriate for road navigation; no detailed mesh or barrel collision is needed for cosmetic articulation.

### Shared data, individual wheel positions

“One universal wheel” means one reusable mesh and material, not one wheel node for the entire vehicle. Each visible tire still needs its own transform so it can occupy an axle position, spin and steer. Instance nodes must reference the same Mesh, textures and Material resources; avoid Make Unique, `mesh.duplicate()`, per-instance copied textures, and separate exported wheel files for each vehicle type. Vehicle configuration should contain only mount positions, radius/width scale, axle orientation, steering membership and spin-sign corrections. Scale the instance transforms, not the shared mesh vertex data. Preserve source assets; do not delete the user's original wheel files as part of this reuse change.

The supplied reduced tire is about 1.017 source units across, larger than the source hull's approximately 0.954-unit length. Normalize wheel size independently to fit measured wheel wells before applying the final assembled-vehicle scale. Its thin/axle dimension is local Z. Correct the mesh below a centered spin pivot so rotation is around the axle, not an orbit around the vehicle. Use proper orientation rotations rather than negative scale for the opposite side.

Animate each spin pivot from signed actual traveled distance divided by the measured final wheel radius. Reverse movement reverses rotation; stopping or being blocked by a wall stops it. Ignore vertical displacement and teleports. Smoothly steer the appropriate front axle around local Y, with a reasonable configurable visual limit, leaving non-steering axles fixed. Update after movement, respect pause/death and reset displacement sampling on spawn/teleport. Cosmetic transforms need no extra wheel physics bodies. Reuse the existing Scout Buggy wheel-controller behavior where correct, while keeping per-vehicle mounting data separate.

Resource sharing saves mesh/texture memory and maintenance work, but does not eliminate the GPU cost of drawing every visible wheel, per-instance transform updates, shadows or draw calls. Report complete assembled triangle counts as 3,648 + 1,499 × wheel count before any articulation changes, and measure final results. Start with normal shared MeshInstance3D resources for individually animated wheels; only introduce MultiMesh/batching if profiling justifies its added management complexity. Do not claim zero per-wheel cost or a measured frame-rate gain without evidence.

Validate shared resource identity between several wheel instances and supported vehicle types, correct per-vehicle dimensions, and no unintended material edits propagating to other vehicles. Any new wheel optimization should be made once in the shared source/derived resource, so vehicles benefit without extra per-model wheel copies.

## 5. Build real yaw, elevation and recoil

Use the supplied Blender source to separate the gun/barrel/breech from the turret shell where necessary. Preserve UVs, materials, silhouettes and the assembled bind pose. Place the vertical yaw pivot at the ring center and the elevation pivot at the actual gun trunnion. Keep the turret roof, hatch and armor upright while the gun elevates. Do not pitch or recoil the entire turret shell, duplicate the complete turret under multiple pivots, or cut the mesh by a guessed plane without inspecting the resulting geometry.

The project already has an articulated Scout Buggy controller at `src/enemies/ground/scout_buggy_turret.gd`. Current ProceduralRaider calls `Turret.track_aim()` when present, resolves `get_muzzle_position()` and named Muzzle markers through `get_muzzle_origin()`, and calls `play_recoil()` when firing. Reuse these interfaces where appropriate, preserving the Scout Buggy. Review the controller before sharing it; do not copy its measured scale, hinge coordinates or absolute recoil offsets into this unrelated model.

Provide `track_aim(target_point, delta, turn_speed, tolerance)`, `get_muzzle_position()`, a muzzle transform accessor if needed, and `play_recoil()` on the new turret component. Aim yaw in the vehicle parent's coordinate space and pitch in the yawed turret's space. Account for the corrected source orientation and changing chassis yaw. Use smooth bounded turning, explicit depression/elevation limits and real barrel alignment. Select limits that the gun and roof geometry can support; do not assume the BaseEnemy helper comments enforce them.

If the player is above the reachable elevation, return a meaningful not-aligned/out-of-reach state and let the existing AI reposition rather than firing through the turret roof. Keep the mount attached to the real roof socket while moving and turning. Avoid cannon collision with the cabin or hull. Constrain traverse if the actual geometry cannot support full rotation.

During the 0.35 s warning, use the existing predicted target. During the committed portion, gun aim, warning endpoint and the fired shot must agree on the committed point. Preserve the aim value before cleanup resets commitment flags. Do not freeze a warning at one point while the barrel tracks another, and do not fire early merely because an animation clip has reached a keyframe.

Recoil should be a brief gun-only local backward motion with a smooth return to its saved bind transform. For this compact gun, start around 0.03–0.08 m at final game scale, with recovery fast enough to work at the 0.12 s burst spacing; tune visually and allow overlapping burst kicks without permanent drift. These are proposed visual values, not measured asset requirements. Avoid resetting all local coordinates to zero or moving the entire turret ring. Drive recoil from each actual shot, not from a looping idle/firing animation.

Optional chassis settling must stay subtle, visual-only and coherent with the separately parented turret. Do not move the physics root or change navigation. Omit it if it creates floating attachments. Pause, death, interruption and despawning must not leave recoil or aiming updates running on freed nodes.

## 6. Make muzzle, aim and bullets agree

Use ProceduralRaider's existing `get_muzzle_origin()` integration instead of creating another hard-coded origin. Place Muzzle at the true visible tip with -Z facing outward and make it follow the actual gun elevation and recoil. Keep a valid fallback for other procedural variants; an unavailable muzzle on the new rig must be reported rather than quietly presented as a verified import.

Use the real muzzle consistently for prediction, warning-line start, LOS checks, projectile spawn and effects. Resolve the current posed transform after relevant movement/aim updates in that physics step. Check that it is outside the weapon/roof and does not use a stale mount position from before turning.

At prompt preparation the shared firing path reads its muzzle position before triggering recoil. Choose an explicit, consistent order: launch from the bind firing pose and then recoil, or update and use the recoiled pose everywhere. Do not sample one pose for the flash and another for the projectile. Confirm the marker and real barrel tip agree in the visible frame.

Preserve the current `enemy_bullet` visual profile and FXManager integration. Projectile.setup currently accepts a third profile identifier. Do not accidentally adopt the Siege Tank's heavy explosive profile or damage because the source filenames say tank. Do not add a duplicate muzzle flash or duplicate projectile alongside the existing firing path. Each three-round burst must produce exactly three projectiles, one gun recoil event per shot, and the existing bullet collision/damage behavior.

Validate barrel direction against the committed launch vector within the intended firing tolerance. Preserve predictive lead, spread, wave damage scaling, hit attribution and environment collision sweeps. Do not bypass alignment/LOS, zero the collision mask, or damage the player directly to make a firing demonstration appear successful.

## 7. Materials, outlines and modifiers

Preserve supplied albedo, UVs and matte camouflage with readable enemy markings. Inspect actual import results: metallic-roughness uses green roughness and blue metallic; red AO needs the appropriate occlusion connection. Do not trust filenames or README claims in place of checking the material. Verify normal-map orientation, mipmaps and texture filtering in the project's GL Compatibility renderer. Share materials/textures where practical to avoid duplicate GPU allocations from the separate embedded exports.

Keep selective enemy outlines and existing culling. Avoid fragmenting the mesh into a draw object for every detail. Report final mesh/material/triangle counts after fitting shared wheels and separating moving gun geometry. Preserve original files so the derived asset can be reviewed against them.

Test ELITE scaling: BaseEnemy scales Visuals and the direct-child Turret separately by 1.2, including turret position. Keep hull, ring, hinge, muzzle, recoil distance and collider in one coherent scale without scaling twice. Preserve shield/other applicable modifiers, death handling, score and rewards. Keep the Scout Buggy's newly integrated scene and controllers working.

## 8. Verify movement, animation and actual damage

Build a repeatable test route or review scene using the real EnemySpawner `assault_apc` path and production flight camera, plus a side close-up for mechanical checks. Exercise normal and ELITE units. Verify:

1. Correct orientation, world scale, mounted turret, wheels centered in every actual wheel arch, ground contact and no duplicate old visuals.
2. Forward/reverse wheel spin, front-wheel steering, stationary/wall-blocked stop behavior, and common Mesh/Material resource identity across APC and other supported vehicles.
3. Ground pursuit and road/obstacle navigation before attacking.
4. Independent turret yaw while driving/turning; upright turret shell; gun-only pitch around the real hinge.
5. Reachable elevation limits, blocked-LOS handling and warning/aim commitment.
6. Exactly three bullets per burst from the actual barrel tip, correct muzzle effects and recoil on each shot.
7. Actual projectile collision and damage on a target; a flash or animation alone is not proof of shooting.
8. No cumulative recoil drift over at least ten bursts; clean pause/resume, interrupted windup, death and despawn.
9. Correct ELITE body/turret/muzzle alignment and unchanged behavior for the Scout Buggy and other ground units.
10. No missing textures, parse/runtime errors or unreported fallback in the delivered run.

Read and run appropriate existing enemy tests, including `tests/verify_enemy_pursuit.gd` and `tests/test_enemy_combat_intelligence.gd`, plus relevant Scout Buggy checks if shared code changes. Add focused coverage for real rig, muzzle or animation regressions. Explain any necessary update for intentionally enforced mechanical elevation limits. Headless tests alone cannot approve visual joints, wheel fit/rotation or flash alignment.

Deliver the reusable APC rig, derived articulated geometry and shared-wheel bindings, narrow visual/aim/muzzle integration, an updated setup note with measured transforms, and a rendered driving/aiming/burst-firing demonstration. Report actual results and remaining limitations clearly. A static imported hull or a yaw-only fixed gun is not the fully animated and firing result requested here.
