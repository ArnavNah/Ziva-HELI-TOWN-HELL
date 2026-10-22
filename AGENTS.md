# Project guidance

# XP progression

- `XpManager` is the authoritative run XP/level/draft queue. Award XP on physical collection, never directly on enemy death. Reset it in `GameManager.start_new_run`. `RunProgression` mirrors its totals/level for compatibility; do not restore its separate automatic draft loop. The production overlay is `LevelUpUi`.
- Resource card effects must modify the real `PlayerWeapons`, `PlayerSalvo`, and helicopter controllers. Keep per-weapon magazine upgrades separate from the legacy all-weapons API. Preserve card eligibility, icons, rarity borders, and one selection per gained level. Cluster bomblets must clear their own `cluster_count` to prevent recursive spawning.

# Enemy asset locations

- Active ground roster: exactly seven active ground vehicles:
  1. Scout Buggy (`scout_buggy`): light 4-wheeled reconnaissance buggy with rapid dual bursts.
  2. Assault APC (`assault_apc`): heavy 4-wheeled modular armored carrier with high-speed autocannon bursts.
  3. Azure Siege Tank (`rail_crawler`): long blue sniper rail cannon (`body.glb`, `turret.glb`, `gun.glb`).
  4. Desert Ironclad (`siege_tank`): conventional heavy 125mm artillery cannon (`body.glb`, `turret.glb`, `gun.glb`).
  5. Ironclad Sentinel (`gatling_heavy`): rotary autocannon with isolated rotating barrel cluster (`gun_barrels_mesh.res`) and fixed trunnion mantlet.
  6. Raptor Raider (`raptor_raider`): mobile cannon raider with 4 wheels, independent yaw, elevation, and drift-free firing recoil.
  7. Desert Barrage Rover (`desert_barrage_rover`): 6-wheeled missile barrage vehicle with 8 distinct launch tube outlets, deterministic alternating pod sequencing, and standoff salvos.
  All seven active ground vehicles are fully integrated, animated, and verified in gameplay with real combat, spawner routing, independent turret tracking, elevation limits, recoil, and chassis dynamics.
  Keep the other eight ground types disabled (`rocket_buggy`, `flame_tank`, `mortar_crawler`, `sam_launcher`, `technical_truck`, `flak_tank`, `missile_carrier`, `infantry_squad`), preserving their sources. Both wave selection and direct public spawning reject disabled types.

- User-supplied new enemy models belong in `assets/Enemy/`. Preserve the capital `E` in Godot resource paths.
- The Scout Buggy source assets are in `assets/Enemy/scout_buggy_Game_Asset/`: `Desert_Recon_Buggy_Body.glb`, `Desert_Recon_Buggy_Tire.glb`, and `Desert_Recon_Buggy_Turret.glb`.
- The armored carrier source assets are in `assets/Enemy/tank_game_ready/` (`tank_hull`, `tank_turret`, `tank_assembled` exports and Blender sources). Despite their filenames, inspection of the rendered model identifies it as the best visual replacement for Assault APC (`assault_apc`), not Siege Tank. See `docs/IMPLEMENT_ASSAULT_APC_MODEL_PROMPT.md`. The user clarified this APC should use its separate wheel, with animated wheel instances.
- The three tank source assets are in `assets/Enemy/enemy_tanks/`:
  - `azure_siege_tank/` -> Azure Siege Tank (`rail_crawler`): long blue sniper rail cannon (`body.glb`, `turret.glb`, `gun.glb`, `tank_assembled.glb`). Visual rig in `scenes/enemies/azure_siege_tank_visuals.tscn`.
  - `desert_ironclad/` -> Desert Ironclad (`siege_tank`): conventional heavy 125mm artillery cannon (`body.glb`, `turret.glb`, `gun.glb`, `tank_assembled.glb`). Visual rig in `scenes/enemies/desert_ironclad_visuals.tscn`.
  - `ironclad_sentinel/` -> Ironclad Sentinel (`gatling_heavy`): rotary autocannon with isolated rotating barrel cluster (`gun_barrels_mesh.res`) and fixed trunnion mantlet (`gun_housing_mesh.res`). Visual rig in `scenes/enemies/ironclad_sentinel_visuals.tscn` and `scenes/enemies/gatling_heavy_visuals.tscn`.
- The two new ground vehicle source assets are in `assets/Enemy/new ground/`:
  - `Raptor_Raider/` -> Raptor Raider (`raptor_raider`): `raptor_chassis_mesh.res`, `raptor_turret_base_mesh.res`, `raptor_turret_gun_mesh.res`, `raptor_material.tres`. Visual rig in `scenes/enemies/raptor_raider_visuals.tscn`.
  - `Desert_Barrage_Rover/` -> Desert Barrage Rover (`desert_barrage_rover`): `desert_chassis_mesh.res`, `desert_launcher_base_mesh.res`, `desert_launcher_pods_mesh.res`, `desert_material.tres`. Visual rig in `scenes/enemies/desert_barrage_rover_visuals.tscn`.

- Shared controllers and configs:
  - `src/enemies/ground/multi_axle_wheel_controller.gd`: data-driven multi-axle wheel controller driving wheel spin from actual planar traveled distance, blocked detection, reverse motion, dynamic front steering, and elite scale support for arbitrary axle counts (4 wheels for Raptor, 6 wheels for Desert Rover).
  - `src/enemies/ground/raptor_cannon_turret.gd`: independent yaw, trunnion elevation (-10 to +55 deg), mechanical reachability reporting, and drift-free translational recoil.
  - `src/enemies/ground/desert_barrage_launcher.gd`: independent yaw, angled rest pose, elevation clamping (-5 to +60 deg), 8 distinct tube markers with deterministic alternating Left/Right salvo sequencing, where pure queries do not advance the tube index.
  - `src/enemies/ground/tank_model_config.gd` and `src/enemies/ground/config/*.tres`.
  - `src/enemies/ground/articulated_tank_turret.gd`: independent yaw on Y, elevation on X with mechanical limits and reachability reporting, drift-free translational recoil, and rotary barrel spin.
  - `src/enemies/ground/tank_chassis_controller.gd`: movement-driven pitch/roll, settling, and gapless turret mount synchronization. Enclosed running gear preserved for all three tanks.

- User preference: use one universal shared wheel Mesh/Material resource for wheeled enemy vehicles (`scout_buggy`, `assault_apc`, `raptor_raider`, `desert_barrage_rover`), with per-vehicle mount/size/animation configuration and per-position instances. Do not create separate unique wheel asset copies per model. The supplied `assets/Enemy/tank_game_ready/Tank_Tire_Reduced.glb` / `universal_wheel_mesh.res` is the universal shared wheel. Tanks maintain enclosed/hidden running gear without fake exposed wheels.
