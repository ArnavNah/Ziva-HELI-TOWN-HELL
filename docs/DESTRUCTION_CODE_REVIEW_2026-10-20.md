# Destruction code review — 20 October 2026

Partially implemented. The core effect system works, but this pass is not complete or ready to sign off against the destruction brief.

## Verified

- Script parse check: 0 parse failures.
- Existing destruction suite: 21 checks passed.
- Existing player death/results suite: 12 / 12 passed.
- Existing shooting FX suite: 10 / 10 passed.
- Additional focused audit probe: Headless and Compatibility-rendered reproduction completed; problems recorded below.

The checks used isolated ZIVA_TEST_DATA_DIR profiles. Game source was not changed. The audit added only its probe, reports and evidence artifacts.

Implemented: a shared FXManager, 48 fragment heads, 256 MultiMesh smoke puffs, four shared flash lights, a pausable effect root, ground/air death separation, player crash smoke and dying-input lockout.

## Findings

### 1. [P1] Boss destruction is missing

Location: [src/enemies/boss/heavy_gunship_boss.gd:198](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/src/enemies/boss/heavy_gunship_boss.gd:198>).

The boss hides and frees itself without calling play_destruction. The generic FX listener skips enemies, so it does not supply a fallback. AudioManager also skips its generic enemy explosion sound.

Evidence: Killing a real HeavyGunshipBoss through its DamageReceiver produced 0 burning heads and 0 composed explosions; the game entered BOSS_DECISION.

Correction: Emit one boss destruction event before the existing decision pause, without replaying rewards or changing modal ownership. Make the initial visible flash meaningful while paused.

### 2. [P1] Transition cleanup misses flashes, dust and wreckage

Location: [src/effects/fx_manager.gd:377](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/src/effects/fx_manager.gd:377>).

clear_combat_effects resets the pools but leaves separately created destruction nodes. Only the fireball container joins combat_explosions; the initial flash and contact dust do not. Legacy wreckage lives under the tree root with no cleanup group.

Evidence: After 20 paused test blasts, manager cleanup left all 60 extra flash/fireball/dust nodes. The real UIFlow transient cleanup removed the fireballs but left 40 flash/dust nodes and 6 rigid debris bodies. They can survive into a new run and resume there.

Correction: Give each composed destruction event one owned container or pooled slot, including its flash, dust and callbacks. Explicitly clear all wreck/debris owners during transition and reset run-scoped work.

### 3. [P2] The initial flash renders as a bright square

Location: [src/effects/fx_manager.gd:541](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/src/effects/fx_manager.gd:541>).

The destruction flash uses a plain QuadMesh and an additive StandardMaterial3D with no alpha texture or UV-falloff shader. The whole rectangle is therefore visible.

Evidence: The Compatibility-rendered capture shows a large pale square around the blast. The live material has neither a falloff ShaderMaterial nor an alpha texture.

Correction: Reuse the existing weapon_fake_light.gdshader with an appropriate burst/falloff shape. Keep depth testing on and fade the mask to zero at its edges.

### 4. [P2] Fragment movement slows down when FPS drops

Location: [src/effects/burning_fragment_trail.gd:198](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/src/effects/burning_fragment_trail.gd:198>).

min(delta, 0.033) discards elapsed time. This changes fragment age, trajectory and smoke fade below roughly 30 FPS; it is not just a limit on puff emission.

Evidence: Feeding one second as 60 updates advanced head age to 1.00 s. Feeding the same second as 20 updates advanced it to only 0.66 s.

Correction: Advance the full simulation time using a bounded fixed-step accumulator or suitable integration. Limit smoke samples independently, discarding excess sampling work rather than slowing the whole effect.

### 5. [P2] Explosion and debris budgets are not enforced

Location: [src/effects/fx_manager.gd:448](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/src/effects/fx_manager.gd:448>).

The 48 heads, 256 puffs and 4 lights are bounded. Composed explosions, their meshes/materials/Tweens/contact dust, and legacy rigid debris are still allocated per request with no event or debris cap. There is no reserved hero event slot.

Evidence: 20 simultaneous requests created 20 composed fireball containers and 60 new top-level effect nodes; the brief proposed 12 ordinary events plus a reserved hero slot. This is a capacity check, not an FPS benchmark.

Correction: Pool/cap complete event instances and physical debris, reserve player/boss capacity, and degrade distant smoke/dust first. Do not count only the pooled fragment arrays when reporting bounded resources.

### 6. [P2] Reduce Flashes does not cover the whole destruction effect

Location: [src/effects/burning_fragment_trail.gd:39](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/src/effects/burning_fragment_trail.gd:39>).

Burning tips always use emission energy 2.5 and never read Reduce Flashes. Existing lights and flash/fireball materials do not refresh when the preference changes. The fireball Tween also targets the opaque edge color after its reduced initial alpha.

Evidence: Tip emission stayed 2.5 before and after toggling the preference. An already active test light remained about 2.764 energy shortly after the toggle; it continued its ordinary fade instead of applying the new reduction.

Correction: Apply reduced core size/intensity to tips and every destruction layer, preserve the reduced alpha throughout color ramps, and update active owners when settings change.

### 7. [P2] Surface impact is inferred from altitude and uses the actor center

Location: [src/player/player_helicopter.gd:1209](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/src/player/player_helicopter.gd:1209>).

Player and enemy crashes capture a collision normal but pass global_position as the blast point. Both additionally require y <= 3 to classify a surface hit. A real rooftop/wall impact above that height is classified as an airburst, while a low-altitude heuristic can claim ground contact without a collision.

Evidence: Source: player_helicopter.gd:1209–1232 and base_enemy.gd:1065–1074. The actual get_slide_collision(...).get_position() is not used. This finding is based on the impact code; a rendered rooftop scenario was not run.

Correction: Use the real collision position and normal, independent of world altitude. For timeout/no-contact, perform a bounded surface query or explicitly choose an airborne breakup.

### 8. [P2] Cosmetic fragments consume the global gameplay RNG

Location: [src/effects/burning_fragment_trail.gd:143](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/src/effects/burning_fragment_trail.gd:143>).

The scatter is described as seeded, but uses global randf_range throughout launch and smoke creation. Visual requests therefore advance the same global RNG used by gameplay such as critical-hit rolls.

Evidence: With the same global seed, inserting a fragment launch changed the next randf result. There is no separate cosmetic RandomNumberGenerator in this emitter.

Correction: Use a dedicated cosmetic RNG with an explicit per-event seed. Keep smoke variation, fragment scatter and sound variation independent of gameplay randomness.

### 9. [P2] Player death starts the rupture sound twice

Location: [src/player/player_helicopter.gd:1150](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/src/player/player_helicopter.gd:1150>).

Death start explicitly plays explosion, then immediately calls play_destruction with the drone profile, which plays explosion again. This stacks the same rupture sound.

Evidence: Source: player_helicopter.gd:1150–1155 and FXManager.play_destruction audio call at fx_manager.gd:531. The later heavy impact and defeat cue are separate legitimate beats.

Correction: Choose one sound owner for the initial rupture. Retain the intentional later heavy contact sound and defeat cue.

## Other incomplete items

- has_wreck/wreck_lifetime profile fields are currently not consumed by play_destruction. The player still calls the legacy six generic glowing boxes. Persistent wrecks were optional in the corrected reference brief, so this is an unfinished extension rather than a requirement to add long-lived wreckage.
- The supplied render_destruction_showcase.gd directly calls FXManager rather than killing real actors, writes to a hardcoded external folder, and samples only 100 frames. It cannot certify real player/boss death integration or sustained performance.
- The existing tests mostly check pool/state availability. They do not assert boss FX, complete teardown, flash shape, FPS-independent timing, live preference changes or rupture sound counts.

## Evidence and limits

- Rendered on Godot 4.7.1, Compatibility/OpenGL 3.3, Intel Iris Xe, 1280×720.
- The flash capture deliberately pauses at spawn to expose the short-lived shape. It is an isolated effect inspection, not a normal gameplay screenshot or performance sample.
- Boss probe uses the real boss DamageReceiver/callback/EventBus path in an isolated scene. It does not exercise the full boss-decision UI.
- Some headless checks emitted ObjectDB cleanup warnings. This review does not attribute them to a particular production leak.
- No sustained FPS benchmark, five-run end-to-end retry soak, or complete enemy-family visual pass was performed. The confirmed defects already prevent sign-off.

Evidence: artifacts/destruction-code-review-20261020/observations.json, source-sha256.json, audit_destruction_probe.gd, initial-explosion-flash.png; logs under artifacts/menu-repair-tests/.

Recommended order: repair boss integration and complete teardown first; then fix the masked flash, full-time simulation and event budgets; finish active settings, real contact positioning, cosmetic RNG and sound ownership.
