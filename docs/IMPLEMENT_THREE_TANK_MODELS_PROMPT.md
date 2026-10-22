# Implement three articulated enemy tanks in Godot

Work in `C:/Users/Prime 3/Documents/ziva-heli-town-helll`. Integrate the three supplied tank models into the real game with independent turret yaw, gun elevation, firing recoil, and believable chassis movement. Preserve current enemy AI, combat balance, navigation, rewards, and unrelated changes. Read `AGENTS.md` first. Preserve the capital `E` in `res://assets/Enemy/`.

## 1. Source assets and proposed assignments

The source root is `res://assets/Enemy/enemy_tanks/`, containing:

| Folder | Proposed existing enemy role | Body triangles | Turret triangles | Gun triangles | Complete tank triangles |
| --- | --- | ---: | ---: | ---: | ---: |
| `azure_siege_tank` | `rail_crawler`: long blue rail-style cannon | 7,544 | 2,831 | 701 | 11,076 |
| `desert_ironclad` | `siege_tank`: conventional heavy cannon | 8,371 | 4,836 | 412 | 13,619 |
| `ironclad_sentinel` | `gatling_heavy`: rotary cannon | 6,690 | 2,974 | 1,620 | 11,284 |

These assignments are visual recommendations, not confirmed user assignments or existing bindings. Use them as the proposed initial configuration unless the user supplies a different mapping. Keep model-to-role assignments data-driven and easy to change. The Azure folder's name does not require replacing `siege_tank`. Do not arbitrarily turn the single-barrel Desert model into the four-barrel Flak Tank, replace the wheeled Assault APC, or convert every ground enemy to a tank.

Each folder includes `body.glb`, `turret.glb`, `gun.glb`, `turret_complete.glb`, `tank_assembled.glb`, `assembled_preview.png`, and its corresponding `<folder>_separated.blend` source. Inspect the models and their previews before implementation.

Verified GLB facts:

- The three primary parts are genuinely separate meshes. None of these GLBs contains animation clips or a skin/skeleton. Build procedural animation; do not assume existing clips named Idle, Move, Aim, or Fire.
- `turret_complete.glb` includes both turret and gun geometry. Do not combine it with an additional `gun.glb`; do not render `tank_assembled.glb` together with another full set of parts.
- Each standalone part has an identity scene-node transform. Its assembly offset is absent from that standalone scene and must be recovered from `tank_assembled.glb`.
- The assembled hierarchy is `Tank → Body` and `Tank → Turret.001 → {Turret_Mesh, Gun.001 → Gun_Mesh}`. These are source names, not a requirement to expose those names to gameplay code.
- Each GLB uses embedded base-color, normal, and metallic/roughness images. Within each tank folder, the image bytes are identical across the component and assembled exports. Different tank folders use different images. Share resources within each model; do not identify textures only by generic names such as `Image_0` or `Material_0`.

## 2. Recover the bind pose and normalize coordinates

The following translations were read directly from the assembled GLBs. Values are in original GLB coordinates, before source rotation, normalization, or gameplay scaling:

| Model | Turret translation relative to Tank | Gun translation relative to turret |
| --- | --- | --- |
| Azure | `(0.3787, -0.0149, 0)` | `(-0.1090, 0.0950, 0)` |
| Desert | `(0.0602, -0.0471, 0)` | `(-0.0539, 0.1132, 0)` |
| Sentinel | `(0.0959, -0.0046, 0)` | `(-0.1223, 0.1311, 0)` |

Re-read these transforms during implementation. Use the assembled model as the bind-pose reference. Placing all standalone files at `(0,0,0)` will not reconstruct it correctly. Node names containing `Pivot_Centered` do not prove that the pivot is the correct mechanical joint.

All three models are Y-up, with guns extending principally along source **negative X**. The game's normalized forward direction is **negative Z**. A Y rotation of approximately **-90 degrees** maps source -X to game -Z. Verify orientation visually and mathematically rather than adding unexplained 90-degree corrections in aim code.

Normalize mesh transforms and all mounting translations consistently. Set the assembled ground-contact plane at the enemy's ground origin and center the hull footprint. Correct source orientation in static mesh/import wrappers; operate the articulated yaw and pitch pivots in a clear normalized coordinate system. Keep bind transforms and avoid applying source translation or scale twice.

Source hull dimensions, expressed as length X / height Y / width Z, are:

- Azure: `0.617676 / 0.181640 / 0.335450`.
- Desert: `0.810547 / 0.219726 / 0.481934`.
- Sentinel: `0.797363 / 0.316406 / 0.525390`.

The current Siege/Gatling collider baseline is approximately `3.6 × 2.2 × 7.0` game units, and the Rail Crawler has its own `3.9 × 2.5 × 6.2` baseline. Preserve proportions and calibrate each model to its assigned role, town roads, player helicopter, and production camera. A seven-unit hull length alone would make these hulls roughly 3.8–4.6 units wide. Do not silently stretch them or leave wide visible armor outside a much narrower collision/spawn envelope. Measure hull and gun overhang separately, and report any justified collision/clearance adjustment.

## 3. Reuse existing integration points

Read the current versions of:

- `src/enemies/enemy_spawner.gd`, `enemy_data.gd`, `base_enemy.gd`.
- `src/enemies/field_raider_visuals.gd`, `raider_visuals.gd`, `procedural_raider.gd`.
- `src/enemies/ground/siege_tank.gd`, `gatling_heavy.gd`.
- `src/enemies/ground/scout_buggy_turret.gd`, `assault_apc_turret.gd`.
- `src/combat/projectile.gd`, `damage_data.gd`, `damage_receiver.gd`.
- Relevant muzzle/outline behavior in `src/effects/fx_manager.gd` and `autoload/shader_manager.gd`.

The model routes differ: Siege Tank uses the spawner's conventional visual path, Gatling Heavy uses `RaiderVisuals` and an existing procedural scene, and Rail Crawler uses `FieldRaiderVisuals` and `ProceduralRaider`. Updating one visual builder does not integrate all three. Replace each selected role's old geometry completely, while preserving other roles and the working Scout Buggy/APC.

Keep the existing `CharacterBody3D`, simple body collider, `DamageReceiver`, street navigation, attack permissions, spawn clearance, pursuit, windup, burst/recovery states, scaling, modifiers, rewards, death and despawn behavior. Do not introduce `VehicleBody3D`, individual physics wheels, another weapon timer, or a second AI controller.

## 4. Build one shared articulation system with per-model configuration

Create reusable visual scenes and a shared tank controller. Keep per-model source paths, fit scale, bind offsets, muzzle placement, pitch limits, recoil and chassis response in configuration resources rather than three copies of the same script.

Suggested hierarchy, with new paths adapted consistently to existing AI:

```text
EnemyRoot (existing CharacterBody3D / enemy brain)
├── CollisionShape3D
├── DamageReceiver
└── VisualRig
    └── ChassisMotion (small visual-only settling; carries all attachments)
        ├── HullModel
        └── TurretYaw
            ├── TurretModel
            └── GunPitch
                └── Recoil
                    ├── GunModel
                    └── Muzzle (Marker3D; normalized -Z points outward)
```

Sentinel may add a correctly isolated `BarrelSpin` pivot within the gun assembly. Both a normalized hierarchy reconstructed from the supplied parts and a safely restructured assembled import are acceptable. Preserve source assets and the assembled appearance in either case.

Provide a consistent controller interface:

```text
track_aim(world_target, delta, turn_speed_deg, tolerance_deg) -> bool
get_muzzle_position() -> Vector3
get_muzzle_transform() -> Transform3D
play_recoil()
reset_pose_or_teleport_sampling()
```

Existing brains expect a direct-child `Turret` in several places. Either retain a compatible controller at that interface or update every resolver and cached reference to the new rig. Retain the old fallback for unrelated procedural enemies. Do not leave `$Turret` pointing to a removed node, or run the old whole-turret aiming helper alongside the new controller.

## 5. Independent yaw, elevation and physically coherent firing

Rotate the turret around its roof mounting ring on local Y. Elevate only the gun around its actual hinge on normalized local X; keep turret roof and hull upright relative to their chassis frame. Recheck hinge clearance against armor at several elevations.

Calculate aim from the actual pivot transforms, including changing hull heading, nested parents, source corrections and scale. Use smooth, bounded angular movement and shortest-path yaw. Support a moving airborne player and targets on either side and behind the vehicle. Handle missing/freed targets safely.

Important existing inconsistency: Scout Buggy's `track_aim` uses degrees per second and degree tolerances, whereas the APC controller currently uses a radians-style rate and a dot-product threshold. Do not copy its signature and pass values such as `150, 24` without reconciling units. Define the new API in degrees, convert once internally, and compare actual barrel angular error against the degree tolerance.

Configure gun depression/elevation per model after testing geometry. Targets outside mechanical elevation/traverse limits must produce a not-aligned/unreachable result and let the existing AI reposition or abort cleanly. Do not let a clamped gun report alignment merely because it reached its clamp.

The existing generic `track_turret()` rotates an entire node in 3D. It is not sufficient for these articulated meshes. The current Siege/Gatling code also uses approximate origins such as turret position plus `UP * 1.5`; replace those with the real posed muzzle.

Use one target solution for gun tracking, warning line, line-of-sight test, projectile spawn and effects. Preserve prediction and intentional aim commitment during the final warning interval. Do not keep visually tracking the live player while firing toward an older committed point. Revalidate barrel alignment and muzzle LOS before an actual shot; a small configurable firing-alignment threshold, initially around 2–3 degrees, is a visual tuning proposal rather than a verified source requirement. Report any resulting cadence change.

Read the committed target into a local value before cleanup changes aim flags. Keep burst behavior internally consistent with each enemy's commitment rules. Do not reset commitment flags and accidentally substitute a different target midway through a shot.

## 6. Recoil and the rotary cannon

Place Muzzle at the actual visible barrel opening, not merely at a guessed object origin or bounding-box corner. If there are multiple physical outlets, use appropriate per-outlet markers without multiplying the existing gameplay damage or shot count.

On every actual shot, translate only the recoiling barrel/breech along its own backward axis and smoothly return to its saved bind position. Gun pitch, yaw and muzzle location must remain coherent during recoil. Do not move the entire turret, hull, collider, or navigation root backward.

Expose kick distance and recovery per model. Proposed initial final-game-scale tuning: approximately `0.10–0.20 m` for the heavy single-shot cannon and `0.02–0.05 m` for the Gatling assembly, then calibrate to model dimensions and shot timing. These are tuning suggestions, not measurements. Repeated shots must not accumulate transform drift or create one unbounded tween per bullet.

Sentinel's `gun.glb` is a single mesh; it is not an independently exported rotary-barrel rig. Inspect its Blender source and isolate only the rotating barrel cluster into a derived asset if necessary. Preserve fixed receiver/mantlet parts, UVs and materials. Spin the cluster around the real bore axis during windup/fire and ease it down afterward. Do not spin the whole turret, fixed gun housing or an off-center cluster that orbits its hinge. Preserve the existing Gatling spin-up and attack timing.

## 7. Chassis movement and enclosed running gear

Let existing physics/navigation move and turn the tank toward its travel direction, independently of turret aim. Preserve forward-driving steering; do not make the hull instantly face the player while moving sideways. Avoid adding a second movement update or calling `move_and_slide()` twice per tick.

Add restrained cosmetic acceleration/braking pitch, turn roll and settling, driven by actual planar displacement, velocity change and yaw rate. Keep motion damped and subtle, returning to bind pose at rest. Sample actual movement after physics, so wall-blocked vehicles do not animate as if still traveling. Reset sampling on spawn, teleport and respawn. Any common chassis motion must carry the turret mounting frame too, without opening a gap between turret and hull.

The supplied bodies are single meshes with no separately exported tracks or road wheels. Respect the enclosed/hidden running-gear preference for tanks. Do not invent exposed wheels, rotate the whole hull to imitate tracks, or scroll the entire body texture. If true tread movement is desired later, it needs intentionally isolated tread geometry/materials or a derived asset. Do not claim it already exists.

The universal shared-wheel rule continues to apply to wheeled APC/Buggy vehicles; this tank task must not create unique wheel copies or alter their wheel rigs.

## 8. Performance, materials and lifecycle

Preserve supplied material appearance. Reuse the same imported Mesh, textures and immutable Material resources across instances of the same tank. The assembled GLB already shares one material across its three meshes; separate GLBs can import duplicate texture resources despite containing identical image bytes. Reuse the assembled resources or explicitly share one material/texture set per model.

Do not call Make Unique on every tank's mesh/material, duplicate textures for each enemy, or force all model-specific textures into one shared material. Keep silhouette-outline overrides and any shader animation parameters compatible with resource sharing.

Avoid extra dynamic lights, high-count particles, physics bodies, full-time bone rigs, per-frame target scene searches or separate raycasts duplicating the existing LOS checks. Respect visibility/distance policies, pause, loading, game over, death and despawning. Do not add autonomous animation nodes that continue under an always-processing UI parent. Cancel/reset recoil, barrel spin and pending callbacks cleanly when a unit dies or is freed.

## 9. Verify in the real game

Build a repeatable test arena that spawns all three through the production spawner and lets the player move around and above them. Also check them at real wave gates and from the normal gameplay camera. Preserve the player's save with `ZIVA_TEST_DATA_DIR` for automated tests.

Require evidence for:

1. All three imports assemble like their reference previews, with no duplicate or missing pieces, misplaced pivots, floating hulls or material loss.
2. Hull movement and turret aim remain independent through left/right/behind targeting and changing chassis yaw.
3. Only the gun elevates; limits, close overhead targets and terrain/roof clearance behave correctly.
4. Actual projectile origins and muzzle flashes follow the visible barrel through yaw, pitch and recoil; LOS is checked from that same posed muzzle.
5. Shot direction and the visible aim agree, including prediction, committed warnings, burst fire and interruption.
6. Recoil returns to bind pose after many shots. Sentinel's rotating cluster spins around its center without moving fixed gun parts.
7. Movement animation stops when stationary or blocked, reverses appropriately, and resets after teleport. Attachments remain connected during chassis settling.
8. Pause, death, game over, replay, missing targets and despawn produce no new debugger errors or freed-instance callbacks.
9. Multiple instances share intended resources while each has independent pose/recoil state; elite scaling remains correct.
10. Scout Buggy, Assault APC and unrelated enemies still use their intended visuals, muzzle logic and behavior. Enemy stat/XP/economy values have not changed inadvertently.

Measure frame time, draw calls and memory with a representative combat population before and after, using the same settings and encounter. State measured results; do not claim a performance gain from triangle counts alone.

## 10. Deliverables

Deliver the three runtime visual scenes, shared animation/aim controller, per-model configuration, production-spawner integration, targeted tests, and a short calibration note documenting mapping, orientation, fit scale, pivots, muzzle placement, elevation/recoil settings and any derived assets.

Provide in-engine screenshots or short clips of each tank moving, aiming up/down, rotating its turret independently and firing. Include one normal gameplay-camera view. Finish with validation results, changed-file paths, measured performance and any remaining limitations. A Blender/source preview or a successful import alone is not proof that the tank works in gameplay.
