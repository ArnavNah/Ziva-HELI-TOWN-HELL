# Combat and sortie feature expansion — 24 October 2026

Implemented in the existing Godot game. User guide: [feature-expansion-implementation.html](feature-expansion-implementation.html). Recorded weapon sounds and music remain pending the user's supplied assets; exact handoff is [AUDIO_ASSET_HANDOFF.md](AUDIO_ASSET_HANDOFF.md).

## Shipped behavior

- Mortal protection snapshots eligibility above 30% hull over a 0.2-second combat burst. A lethal qualifying hit leaves 1 HP and owns a 0.5-second protection grace. Rearm requires 15 seconds and 60% hull recovery. Environmental impacts/fuel starvation do not trigger it. Emergency audio/banner/desaturation and restrained red feedback preserve visibility; dash/shield ownership remains intact.
- Live targeting homing missiles produce screen-edge alerts and a rate-limited receiver tone; urgency uses 25m proximity or one-second estimated time to arrival. Flares query the actual shared projectile registry and only divert missiles aimed at this player.
- Explosions inherit the projectile collision mask rather than querying both factions. Player ordnance cannot splash the player; enemy ordnance cannot wipe its own cohort. Destructible world bodies can receive explosions. Bomblets inherit targeting and retain the non-recursion guard.
- Cannon kick is camera-only and follows the shake preference. Existing directional damage arcs and railgun tracking telegraphs were retained.
- Two real one-time evolution cards extend the production deck to 38 entries, using prerequisites and actual weapon payload effects. XpManager stays authoritative; resource-card effects and per-weapon magazine upgrades remain real controller state.
- Existing hangar ranks now also drive flat small-arms plating, expanded radar, and rank-3 automatic chaff. Chaff spends the normal charge and cooldown.
- Aircraft selection has Town / Desert Canyon / Harbor Night choices. Desert uses collision-backed mesas/outposts, warm terrain and periodic sandstorm visibility changes; Harbor has industrial blocks, ships, containers, cranes and sweeping searchlights. The same road graph remains navigable.
- Selected biome routes wave 10 to Heavy Gunship, Mega Crawler or Airborne Titan. New bosses have separate weak-point receivers, a readable health/phase panel, phase transitions and existing attack-slot/telegraph contracts. Ground battery/radar removal exposes its core; carrier engines must all be destroyed before direct core damage is accepted. Treads/weapon systems/engines/bay destruction actually change movement and attacks. Carrier launches use the director's purchase/refund transaction, caps, wave gates and physical clearance. Components do not settle extra kills/credits/XP. Boss death uses the once-only existing decision flow.
- Rooftop supply event starts from wave 2, validates a level physical roof, requires eight seconds of stable hover with no enemies within 30m, and drops real shield/overdrive pickups and XP. Destroying the roof cancels the event. The timed SAM objective now has a reserved, 1.5-second warning and real low-damage flak shot; cleanup releases its lease.
- The existing rotor WAV is now loaded. Optional WAV replacements use the existing effect pool; three valid, matching recorded stems enable additive music layering. Recorded stems keep fixed pitch through overdrive to avoid drift. Missing assets keep existing procedural fallbacks.

## Verification

All commands use `ZIVA_TEST_DATA_DIR` pointing at separate fixture profile folders under `artifacts/feature-expansion/`; personal saves were not used. Godot 4.7.1, local runner `tools/run_strike_checks.py`.

| Test | Result |
| --- | --- |
| tests/test_feature_expansion.gd | 25 checks passed (burst boundaries, prerequisites, actual blast modifier, sample loading, three-stem mix and alignment) |
| tests/test_live_feature_expansion.gd | 57 checks passed in real main-game scenes (faction damage, alerts/chaff, rooftop loot, SAM attack, boss movement/firing, weak points, launch budgets, settlement, director routing, sortie selector) |
| tests/test_xp_upgrade_effects.gd | 65/65 passed, including actual explosive cannon projectiles and both new cards |
| tests/test_gameplay_stability_and_upgrades.gd | 20/20 passed, including double-scaling, blast deduplication, shield/dash ownership, lethal HUD update and persistent magazines |
| tests/test_tactical_missions.gd | 78 passed, 0 failed |
| tests/test_director_regressions.gd | 46 passed, 0 failed |
| tests/verify_active_ground_roster.gd | Zero failures; exactly seven ground roles, disabled public spawning rejected, 9,600 wave/theme selections respected gates |

291 checks across the six counted suites, plus the separate active-roster verification. Final logs are `artifacts/strike-<test-name>.log`.

Concurrent task changes to XP drop run ownership and delayed draft presentation were preserved. Regression fixtures were updated to perform player collection in an active run and wait for the actual overlay before keyboard selection. Production XP/drop/UI implementations were not reverted.

Visual evidence uses `tests/render_feature_expansion.gd` with the real game renderer. Staged screenshots live in `artifacts/feature-expansion/`, including the roof supply, emergency/missile feedback, both new bosses, sandstorm, docks, and sortie selection at 1280x720 and 960x540. These are staged visual checks, not proof of full-run balance or frame-rate guarantees.

## Practical limits

- Bosses and new district props are functional code-built low-poly art. Final custom boss models and a final environment art pass can replace these meshes without changing the weak-point/combat contracts.
- No recorded weapon library or finished military score was supplied. User elected to provide those; current fallback audio remains available and the handoff paths are ready.
- Automated tests prove specific contracts and short real-frame combat sequences. A complete human-played wave-1-to-10 balance pass is still needed before claiming release tuning or a locked frame rate.
- Some earlier isolated Godot checks reported ObjectDB cleanup warnings at shutdown. Final named suite runs completed without script errors; this is not a claim that all engine/editor-wide import or lifecycle issues across unrelated assets were fixed.

## Main changed code

New policy: `src/player/mortal_protection.gd`; new bosses: `src/enemies/boss/modular_fortress_boss.gd`, `boss_core_receiver.gd`, `boss_component_receiver.gd`; new biome construction: `src/world/sortie_biome.gd`; new HUD panel: `src/ui/boss_tracker.gd`.

Integrated into the existing helicopter/camera/weapons/countermeasures, HUD/damage indicator/minimap, resource card database, ProfileManager, AudioManager, GameManager/CombatDirector, EnemySpawner, weather/city generation, main scene, mission manager/specs, terrain/grade shaders, and aircraft selection. Existing seven-vehicle asset rigs and universal wheel resources were preserved.
