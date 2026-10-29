# Air enemy integration — 30 October 2026

Implemented in the existing project and verified with real controllers, public spawning, projectile sweeps, damage, city gameplay, and the production chase camera. Model loading alone was not treated as combat verification.

## Final mapping

Production wrappers remain authoritative under `scenes/enemies/air/`. Each wrapper contains one model assembly; model scale and placement live inside the wrapper. Physics roots remain at unit scale.

| Enemy/controller | Model | Production wrapper | Model scale |
|---|---|---|---:|
| `attack_gunship` / AttackGunship | Iron Viper | `iron_viper_visuals.tscn` | 10.5 |
| `rocket_gunship` / RocketGunship | Crimson Desert | `crimson_desert_visuals.tscn` | 9.5 |
| `heavy_gunship_boss` / HeavyGunshipBoss | Desert Rotorblade | `desert_rotorblade_boss_visuals.tscn` | 12.5 |
| `interceptor` / Interceptor | Crimson Skyblade | `crimson_skyblade_visuals.tscn` | 6.2 |
| `escort_fighter` / ProceduralRaider | Astra Viper | `astra_viper_visuals.tscn` | 6.8 |
| `attack_wing` / ProceduralRaider | Ironclad Skyrunner | `ironclad_skyrunner_visuals.tscn` | 6.2 |
| `heavy_bomber` / ProceduralRaider | Ironclad Skycarrier | `ironclad_skycarrier_visuals.tscn` | 8.5 |
| `torpedo_vtol` / ProceduralRaider | Viperhawk | `viperhawk_gunship_visuals.tscn` | 7.0 |
| `stealth_vtol` / ProceduralRaider | Shared Viperhawk, cool tint and attack-state cue | same wrapper | 7.0 |
| `minelayer` / Minelayer | Shared Viperhawk, warm tint and underside deployment cue | same wrapper | 7.0 |

Original sources are preserved under capital-E `assets/Enemy/air/`. Derived `*_flight.glb` helicopter assemblies and `*_animated.glb` Skyrunner, Skycarrier, and Viperhawk assemblies are generated from the supplied Blender sources by `tools/prepare_air_animation_assets.py`. Astra Viper and Crimson Skyblade continue to instance their supplied GLBs.

The Airborne Titan still uses `modular_fortress_boss.gd`, four destructible engines, its launch bay, core rules, and escort summoning. Its actual harbor boss route was tested. The helicopter alias was removed from RaiderVisuals. Existing drone visuals and the seven active ground vehicles remain in their existing routes.

## Hierarchy, sockets, and animation

```text
Enemy (existing combat controller and physical colliders)
  Visuals (AirVisualRig)
    CosmeticOffset                    # bounded translational recoil only
      Model                           # one imported aircraft assembly
        Fuselage / Body               # fixed geometry
        Main_Rotor, Tail_Rotor        # helicopter blades where applicable
        Upper_Rotor, Lower_Rotor      # boss, opposite Y rotations
        Propeller_L/R or Fan_L/R      # derived independent moving geometry
        Fixed_*                       # extracted stationary mast/support geometry
      Sockets                         # shares Model's scale and placement
        Cannon / Cannon_L/R
        Rocket_L0, Rocket_R0, ...      # eight alternating physical tube outlets
        Barrage_L/R
        Pod_L/R, MineDrop, BombDrop
        Exhaust[_L/R]                 # restrained fighter exhaust glows
      StateCue, MineCue, MissileCue    # role/state presentation
    RotorController                   # one shared rest-basis animator
```

The helicopter rotors are siblings of the fixed fuselage in the derived assemblies. Their visible rest geometry, boss shaft separation, materials, and UVs are retained. Iron Viper uses local Y main and local X tail rotation. Crimson Desert's blades rotate around Y and its inner tail fan around X; fixed tail support and duct geometry stay stationary. Its main shaft was recentered from the old bounding-box-centered pivot while preserving the visible rest pose. The boss counterrotates its separate upper/lower rotors around Y; there is no added tail rotor.

Inspection of the Blender sources found loose blade islands inside the combined Skyrunner and Viperhawk bodies. Those islands are separated around centered Z propeller shafts and Y fan shafts. Skyrunner nacelles and Viperhawk shrouds stay fixed. Skycarrier had no independent blade islands: small four-blade assemblies were deliberately authored inside the existing engine openings, leaving the nacelles intact.

The shared animator reconstructs each part from its saved rest basis and bounded angle, avoiding accumulated transform drift. Speed response uses an analytically integrated exponential, including death coast-down. New airborne instances start at flight speed. Pause inherits the game tree. Reset restores the original bases, phase, and full flight speed. Death animations keep the existing lifetime and collision shutdown; rotor coast-down does not delay removal. Main/coaxial baseline is 1440 degrees/s, tail baseline 2160 degrees/s; axes and speeds remain configurable. No opaque blur duplicate was added.

Socket queries are pure. `commit_shot()` advances an outlet only after projectile creation. Rocket salvo count/index also advance only on successful launch; blocked salvos release slots and recover without consuming a tube. Projectile origin, obstruction query, muzzle flash, and tracer use the same selected socket. Flashes follow the captured Marker3D during movement, banking, and cosmetic recoil. The three-shot bracket, 24 base damage, 135 speed, 0.28 s spacing, warning timing, and cooldown are retained.

Iron Viper retains its six-shot cannon attack and receives no rocket attack. Fixed gun geometry uses a configurable 70-degree cone. Aircraft yaw uses the existing shared steering controller to face a combat target during relevant hover/orbit behavior; no second bank/pitch animation or fake gun articulation is applied. Interceptor keeps its pass, break, and re-engagement states and six-round burst.

**Interceptor speed authority:** the dedicated controller already predicted and fired at **310 units/s**. This value is now named `Interceptor.PROJECTILE_SPEED`. EnemyData's **280** remains documented legacy metadata. This integration does not silently change live projectile speed.

Bomber shots now start at the belly `BombDrop`; their existing downward velocity, spread, damage, warning/slot rules, and generic projectile behavior remain. Viperhawk missiles retain 72 speed, homing, and existing lock-warning integration. Mines use `MineDrop`, keep their 1.5 s arming delay, 25 s lifetime, cadence, and 30 damage, and guard against repeat detonation. Viperhawk variants share actual mesh resources and cached material variants, with distinct loadout/deployment cues.

The boss's spread uses explicit alternating barrage sockets, including per-socket obstruction and flashes. Existing health, phases, spread counts/speeds, slot acquisition, warnings, and rewards remain. Phase damage changes an instance-local cue material. Its warning label is below the hull, enlarged, and visible over rooftops so it avoids the boss HUD. The modular fortress battery fallback remains available to the Titan and ground fortress.

## Other completed fixes

- Restored flight steering for attack wing, stealth VTOL, and bomber, which had fallen through to ground steering in the inspected controller. Existing standoff/weave and attack profiles remain.
- Replaced rotor/empty-corner collision boxes with hull shapes plus narrow wing boxes or Viperhawk duct cylinders. Elite scaling applies to all physical shapes. Air spawn clearance now considers the existing visual bounds radius.
- Fixed `DamageData.clone_scaled()` when a firing enemy has already been freed. Blast damage retains its snapshotted strength and source bearing, with a null live owner instead of a freed reference.
- Replaced the obsolete `tools/build_clean_air_scenes.gd` generator with read-only wrapper validation. It cannot erase socket/animation work. The Python wrapper authoring tool contains the complete current setup. The old gameplay-verifier entry point now delegates to the real integration suite.
- Converted all seven mislabeled nested `textures/albedo.png` JPEG payloads into real PNGs **at the same paths**. Import UIDs and decoded RGB pixels are preserved. Original bytes are backed up under `.codex-backups/air-albedo/`; pixel hashes are recorded in the texture migration artifact. No normal maps or metallic/roughness packing were changed, and no `.godot` binaries were edited.

## Tests and recorded evidence

Godot 4.7.1, Windows, GL Compatibility, Intel Iris Xe. Test saves use `ZIVA_TEST_DATA_DIR` beneath the audit artifact directory.

| Check | Result |
|---|---|
| `tests/test_air_enemy_integration.gd` | **174/174 passed**, clean runtime error log |
| `tests/test_seven_ground_vehicles_integration.gd`, rendered | **64/64 passed**, including screenshot; active/disabled roster and shared wheels retained |
| `tests/test_xp_upgrade_effects.gd` | **65/65 passed**, including physical XP collection, real controller card effects, draft input, and restart reset |
| `tools/build_clean_air_scenes.gd` | All eight wrappers validated; no files overwritten |
| `tests/capture_air_enemy_encounters.gd` | Actual main scene/city, chase camera, movement, primary fire, boss route, restart, and captures completed; clean runtime error log |
| Normal public spawning in generated city | All nine mapped non-boss roles succeeded without bypass or custom positions |
| Full editor reimport/reload | Completed; no air resource warnings or script errors in final reload |

The air suite covers non-bypass public spawning, unit physics scale, bound sockets, pure queries, identical shared Viperhawk meshes, variant materials, equal elapsed-time rotor results at 30/60/120 FPS with changing speed, stationary shaft origins, reset at flight speed, actual tree pause/resume, eight distinct alternating rocket outlets, obstruction without outlet consumption, dead-shooter rejection, safe freed-owner damage cloning, real AI attacks from all nine roles, real projectile and effect origins, homing/drop profiles, single damage application on a compound collider, actual wave-10 helicopter boss construction, phase transitions, once-only rewards, and the harbor Titan's engines/launch bay.

The gameplay capture runs used real `PlayerCamera` and player control input. The final movement/fire segment moved the helicopter approximately 50 m. A real restart created a fresh air enemy and reset XpManager totals to zero. Enemy spawning currently allocates new nodes rather than pooling enemies; wrapper reset is tested, but no nonexistent full-enemy reuse path is claimed.

One older suite, `tests/test_xp_magnet_and_card_draft.gd`, returned **46/52**. Its four magnet failures and two overlay failures run without entering ACTIVE; current `XpDrop._can_collect` and `LevelUpUi._can_present` intentionally reject MENU. It also assumes immediate draft presentation. That legacy fixture was left unchanged. The current 65-check XP suite verifies the real collection/draft/restart contracts successfully.

Final reload still reports duplicate UIDs in the pre-existing ground `assets/Enemy/tank_game_ready/backup_original/` copies. Those warnings are outside the air resource paths and were not represented as resolved.

Artifacts are local audit outputs under `artifacts/air-model-review/` (Git-ignored):

- `integration.log`, `integration-errors.log`, `ground-regression.log`, `xp-upgrades.log`, and `xp-regression.log` record assertions and the legacy failure.
- `gameplay.log` records actual public city spawn coordinates, the camera/controller run, and restart.
- `model-contact-sheet.png` shows the eight aircraft; `socket-audit.png` marks source-space sockets and moving shaft nodes.
- `gameplay-nine-aircraft.png`, `gameplay-turning-and-fire.png`, `gameplay-24-aircraft.png` show actual camera encounters and scale context.
- `gameplay-boss-warning.png` and `gameplay-boss-final-phase.png` show the real boss presentation in the city. The focused boss capture stages its position for readability.
- `source-components.json`, `derived-parts.json`, `texture-migration.json`, `render-performance.json`, and `final-reload*.log` record authoring/import/performance evidence.

## Rendering measurements and limits

Final main-scene samples at 1280×720, existing 60 FPS cap, VSync disabled. These are short frame-interval samples including game logic, city, effects, UI, and normal camera culling; they are not isolated GPU timings. Stress groups use the public spawner's explicit fixture bypass to hold a chosen aircraft mix independently of encounter budgets.

| Spawned aircraft | Frames sampled | Median frame ms | P95 frame ms | Mean draw calls | Mean rendered primitives |
|---:|---:|---:|---:|---:|---:|
| 0 | 120 | 16.59 | 28.81 | 242 | 299,639 |
| 9 | 180 | 19.17 | 30.57 | 340 | 556,588 |
| 24 | 180 | 23.69 | 45.48 | 488 | 982,758 |

An earlier run measured 16.67/21.54 ms median at 9/24 aircraft, so these short captures show run-to-run variation. **The 24-aircraft stress case does not sustain the 60 FPS budget on this Iris Xe.** No blanket mesh reduction or additional LOD system was added; the existing normal import LOD generation remains enabled. A sustained fixed-camera GPU profile is appropriate before further geometry/material changes.

Optional nacelle tilt, fighter control surfaces, and opening bay doors remain unanimated because the supplied moving structure is combined. Their fixed meshes are preserved. The current stealth controller has no separate gameplay cloak state; this change preserves its combat behavior and adds readable material/state cues, without inventing invisibility rules. No full campaign-length soak, physical gamepad hardware session, or all-hardware performance guarantee is claimed.

## Reproduction

Run through the installed Godot executable with `--path` pointing at this project:

```text
--headless --script tests/test_air_enemy_integration.gd
--script tests/test_seven_ground_vehicles_integration.gd
--headless --script tests/test_xp_upgrade_effects.gd
--headless --script tools/build_clean_air_scenes.gd
--script tests/capture_air_enemy_encounters.gd
--script tests/capture_air_enemy_encounters.gd -- --boss-only
--script tests/render_air_socket_audit.gd
```

Set `ZIVA_TEST_DATA_DIR` to a disposable local test-save directory before gameplay and XP checks. The normal capture script writes rendering measurements; `--boss-only` refreshes focused warning/phase screenshots without replacing performance measurements.

For deliberate asset regeneration, run Blender in background mode with `--python tools/prepare_air_animation_assets.py`, then `python tools/build_air_visual_wrappers.py`, followed by normal Godot import. `tools/normalize_air_albedo.py` is an idempotent reference-safe texture migration, not a blind rename operation.
