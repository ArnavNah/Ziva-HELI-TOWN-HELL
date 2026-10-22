# Playability fix prompts — Heli-Town Hell

Prepared **21 October 2026**, from the current project audit.

**Project:** `C:/Users/Prime 3/Documents/ziva-heli-town-helll`

Use the prompts in this order:

1. Fix aiming and the crosshair.
2. Make movement and the camera responsive.
3. Fix pickup placement and XP accessibility/pacing.
4. Reduce town loading time and building pop-in.
5. Verify the complete game loop.

You can give the AI this whole file. For a smaller task, copy **Shared instructions** and one numbered prompt together. The tuning targets below are proposed starting values, not measured results or previously approved fixed specifications.

## Shared instructions for every prompt

Work directly in `C:/Users/Prime 3/Documents/ziva-heli-town-helll` and implement the requested changes, including verification. Inspect current source before editing; some fixes may already have been applied by another task.

Read:

- `AGENTS.md`
- `GRAPHICS_ART_DIRECTION.md`
- `MENU_FLOW_NOTES.md`
- `docs/PLAYABILITY_AUDIT_2026-10-21.md`
- `artifacts/playability-audit-20261021/controls-pickups.json`
- `artifacts/playability-audit-20261021/world-profile.json`

Preserve unrelated work. Keep Godot Compatibility, the town's current art, aircraft models, helicopter identity, enemy AI roles, weapon mods, score/credit settlement and working menu routes. Make focused changes; do not rebuild the entire game or add an external plugin.

Respect `assets/Enemy/` with a capital E. Follow the current AGENTS.md rules for Scout Buggy, Assault APC and the shared wheel resources. These tasks do not require replacing enemy models.

Use `ZIVA_TEST_DATA_DIR` before autoloads initialize when testing. Prefer the existing `tools/run_menu_checks.py` wrapper. Never test purchases, rewards or reset behavior against the player's actual profile.

Keep gameplay input, pause, loading, death, upgrade choices and results under the existing UIFlow/GameManager ownership. No held fire or movement may leak through menus. Keep retry/scene changes safe when an asynchronous task is canceled.

Treat the audit measurements as diagnostic baselines. Its rendered profiler completed sampling but emitted resource-cleanup errors on shutdown, so it was not a clean passing test. Investigate any new errors separately and do not claim a stable frame rate from that short sample.

For each task deliver:

- The implemented changes and a short plain-language explanation.
- Changed files and any deliberate control/balance decisions.
- Focused test results plus rendered evidence when appearance matters.
- Before/after measurements where applicable.
- Remaining limitations, without claiming completion when required checks fail.

## Prompt 1 — Fix sticky aim and make the crosshair truthful

### Goal

The gun should respond predictably to the player's mouse. The crosshair must communicate where the gun can actually shoot. An enemy should not remain selected indefinitely after the cursor leaves it.

### Inspect first

- `src/player/player_turret.gd`
- `src/player/player_weapons.gd`
- `src/player/player_salvo.gd`
- `src/player/player_camera.gd`
- `src/ui/hud.gd`
- `scenes/player/player.tscn`
- `src/combat/projectile.gd`

### Confirmed problems

- Hover targeting assigns `current_target_score = 100`. Replacement then requires a score of at least 120, while normal candidates score much lower.
- The selected target can remain valid even beyond the 140 m acquisition range.
- `settle_timer` is decremented but does not release the lock.
- The HUD draws its reticle at the mouse independently of the barrel.
- Turret yaw/pitch limits can prevent reaching the requested point. The audit reproduced about 66.7° of rear-cursor/barrel disagreement.
- Cursor projection assumes the ground is always at y=0, which does not represent roofs, slopes or flying targets.

### Implement

1. Establish one aiming solution containing requested world point, reachable barrel direction, actual projected impact point, target validity and any out-of-arc/blocked state. The HUD, turret and firing code must consume compatible information.
2. Give direct mouse intent priority. Aim assist may help a nearby visible target, but must not pull shots toward an unrelated enemy across the screen. Prefer screen-space proximity to projected bounds or an actual collider hit over the current unconditional 18 m ground circle.
3. Revalidate range, death, scene membership, line of sight and the cursor-assistance region before retaining a target. Recompute comparable scores each update. Release to free aim promptly when the cursor leaves. Remove unused timers or give them a short explicit, tested purpose.
4. Raycast the cursor into relevant world/enemy collision layers, excluding the player. Resolve a real damageable point rather than blindly using a ground vehicle's root origin. Use a stable fallback plane only when no valid surface is hit.
5. Preserve the existing turret limits for this first repair. Do not silently grant 360° fire or rotate the aircraft automatically. For an unreachable point, clearly distinguish mouse intent from reachable gun aim with an out-of-arc cue or actual-impact marker.
6. Ensure aiming uses the current camera transform in a deliberate update order. Verify interpolation/smoothing does not make cursor conversion use a visibly different camera pose.
7. Preserve weapon spread, damage, cadence, ammo, recoil, homing and painted-salvo semantics. Reuse the muzzle transform selected for the actual shot; its getter alternates barrels and must not be called again just for HUD/FX placement.
8. Keep controller input working under the current supported behavior. Do not invent a controller aiming mode without implementing its input and UI contract.

### Acceptance checks

- Acquire enemy A, move to empty ground and confirm prompt return to free aim.
- Move from A to B; move A beyond range, behind a wall, into death and out of the scene. No stale lock or freed-node error.
- Test front, side and rear cursor positions, low/high flight, moving aircraft, roofs and slopes.
- After settling, projected barrel/impact feedback agrees with the real projectile trajectory within a documented tolerance. Rear limits are visible to the player.
- Free aim remains possible when enemies are nearby but outside the assistance region.
- Recheck all four weapons, alternating muzzles, salvo launch and pause/loading/death input protection.

Adapt the aiming portion of `artifacts/playability-audit-20261021/controls_pickups_probe.gd` into assertions that verify the corrected behavior. The audit probe itself records the old fault and is not a passing acceptance suite for the repair.

## Prompt 2 — Make flight and camera feel responsive

### Goal

Reduce the uncontrolled sliding and moving-camera confusion while retaining the helicopter's visual weight. The player should be able to stop, turn and aim reliably in streets.

### Inspect first

- `autoload/input_manager.gd`
- `src/player/player_helicopter.gd`
- `src/player/player_camera.gd`
- `data/game_constants.gd`
- `data/aircraft_specs.gd`
- Flight manual/control text and aircraft upgrade consumers.

### Baseline

At approximately 36 m/s, releasing thrust produced 18.47 m of travel in the following second and left 9.34 m/s of speed. Camera yaw lag during a sustained turn was about 12.58°.

The current controls are W/S forward/reverse relative to aircraft heading, A/D turn, Q/E strafe. These bindings are an existing design, not an accidental reversed-axis bug.

### Implement

1. Keep the existing bindings and heading-relative movement as the default for this pass. Do not silently change A/D into strafing. If another movement mode is later added, it needs matching input, camera, manual and controller support.
2. Separate movement response from cosmetic pitch/bank. Visual weight must not require excessive actual stopping distance or camera delay.
3. Introduce predictable hands-off horizontal braking. As a proposed initial target at the baseline Apache's 36 m/s, aim for speed below about 2 m/s within 0.4–0.6 s after release and roughly 5–8 m or less additional travel. Tune through rendered play rather than snapping velocity instantly to zero.
4. Preserve deliberate S braking/reverse behavior, forward/reverse speed limits, diagonal normalization, strafe authority, dash duration/cooldown and meaningful aircraft differences. Permanent handling/thrust/speed upgrades must continue to affect their documented consumers.
5. Reduce stacked camera lag. Start with much tighter position/yaw following, a sustained-turn yaw lag below roughly 5°, restrained roll and little idle drift. Keep these values centralized and explain the chosen defaults.
6. Preserve camera occlusion protection, but avoid large rapid zoom changes near walls. Test corridors and rooftops; do not remove collision checks to make the camera appear stable.
7. Review physics interpolation: a render-updated camera should follow a consistent interpolated target pose when interpolation is enabled. Verify this rather than disabling interpolation globally as a shortcut.
8. Keep altitude/climb/descend, flight ceiling, ground clearance, crash damage, fuel and battlefield boundaries working. Do not remove collisions or make the player invulnerable as a responsiveness fix.
9. Preserve Screen Shake Off and Reduce Flashes. Do not add new camera effects to compensate for control problems.

### Acceptance checks

- Measure acceleration, release stopping distance, speed after release, reverse transition and turn response before/after.
- Compare controlled 30/60/120 FPS runs, keeping physics settings documented. Stopping and dash behavior must remain comparable in simulation time.
- Test every aircraft with baseline and representative upgrades, diagonal input, Q/E strafe, rapid A/D changes and movement during firing.
- Fly along streets and around a tall building with the actual camera. Record camera lag and occlusion behavior.
- Verify aim/reticle changes from Prompt 1 still work during fast turns and camera movement.
- Verify crash/death, pause and retry flow.

Review `tests/verify_flight_timing.gd`, `tests/test_flight_camera_sim.gd` and `tests/test_flight_altitude_collision_and_blood_fx.gd`. Update assertions only for deliberate documented feel changes; preserve safety, timing and collision invariants.

## Prompt 3 — Fix pickup placement and XP accessibility/pacing

### Goal

XP should remain where it was intentionally spawned, become accessible at normal combat distances and give readable progression feedback. Preserve once-only rewards.

### Inspect first

- `src/loot/loot_manager.gd`
- `src/loot/pickup.gd`
- `src/player/run_progression.gd`
- `src/combat/damage_receiver.gd`
- `src/enemies/enemy_data.gd`
- `data/game_constants.gd`
- `src/ui/hud.gd`, `autoload/game_manager.gd` and pickup/progression upgrade consumers.

### Confirmed behavior

- LootManager adds the item to the tree before setting its position. Pickup._ready stores the default y as its bob baseline, so an air drop at y=25.5 snapped close to y=0 on the first idle update.
- Nearby collection is already fast: about 0.32 s at 20 m, 0.50 s at 40 m and 0.55 s at 47 m, with a stationary player at 14 m altitude.
- The magnet's 48 m radius includes a remaining vertical penalty. A pickup 48 m horizontally away can therefore fail to attract.
- Target assistance can engage enemies up to 140 m away, leaving drops far outside the magnet region.
- Enemy XP is multiplied by 0.5, rounded down and clamped before spawning. This is deliberate existing balance, not an arithmetic exception. First cumulative level thresholds are 10 and 25 XP.

### Implement

1. Fix initialization order. Set the intended transform before the pickup captures its baseline, or provide an explicit spawn initializer that sets position and baseline together. Handle non-origin parents correctly.
2. Preserve air drops at the intended altitude. If a particular item should land on terrain, query a real surface and initialize it there; never snap it accidentally to y=0.
3. Define a consistent XP-specific attraction policy. A suitable first implementation is immediate attraction for XP spawned by the existing enemy reward path within the player's supported combat envelope, with an explicit horizontal acquisition range and separate altitude limit. Existing idle proximity attraction can remain for previously uncollected gems. Bound the policy to the active run/player; do not attract arbitrary pickups across the entire map.
4. Base the envelope on the repaired aiming/engagement rules and actual kill distances. Document the chosen radius/height. Preserve meaningful pickup-radius upgrades and avoid unintentionally changing tactical supply pickup behavior.
5. Keep pursuit speed sufficient to catch a moving or dashing helicopter, with bounded motion and no orbiting/overshoot. Do not simply raise every pickup speed again; nearby travel is already quick.
6. Make reward scaling explicit in one place. Show expected XP per normal enemy and expected kills/time to early upgrades. If removing or reducing the hidden 0.5 multiplier, update the intended balance table and the relevant tests together. Do not also reduce all thresholds blindly; compare the combined result in a normal combat sample.
7. Preserve the existing authoritative reward path: no direct XP on kill plus a second gem payout, no duplicate collection signals, no scenery XP, no duplicate boss rewards, and no post-death/previous-run XP transfer.
8. Award XP on arrival/collection as before, and keep progression/HUD feedback synchronized. Preserve protected upgrade dialogs, queued levels, the existing short presentation delay and the combat breather between consecutive cards unless measured play establishes a reason to retune them.
9. Merge nearby low-value XP or reuse pickup resources if kill density makes item counts expensive. Preserve total XP exactly; do not silently discard rewards when a cosmetic pool is full.

### Acceptance checks

- Spawn drops at ground level, 14 m, 25 m and over elevated terrain under translated parents. Their first idle frame stays near the intended baseline.
- Test collection from normal close/medium/long kill distances and at low/high altitude, both stationary and moving/dashing.
- Compare attraction onset and arrival time at different frame rates. Check loss of player, death, pause and scene replacement.
- Verify exact total XP for individual and merged gems, simultaneous collection and repeated body-entered/attraction completion.
- Validate early level-up pacing from an actual enemy mix and record the measured time/kills to upgrades. Do not report a tuning target as an achieved result.
- Run/adapt `tests/test_xp_pacing_and_level_up_cards.gd` and `tests/test_pickup_collection_animation.gd`. Keep once-only and non-hostile assertions even if deliberate XP values change.

## Prompt 4 — Reduce world loading stalls and building pop-in

### Goal

Prepare a complete playable town faster, keep the loading animation responsive and prevent distance visibility from looking like unfinished loading. Preserve the current 16×16 map and art.

### Inspect first

- `scenes/main_game.tscn` and `scenes/main_game.gd`
- `src/world/city_generator.gd`
- `src/world/destructible_building.gd`
- `src/world/detail_mesh.gd`
- `src/world/field_dressing.gd`
- `src/world/stylized_materials.gd`, town props and material caches.
- `src/ui/menus/loading_screen.gd`
- `autoload/ui_flow.gd`

### Baseline

The measured map contains 142 buildings, 713 MeshInstance3D nodes and 2,219 descendant nodes. Deployment took approximately 6 s. World preparation occupied 215 frames, including a world-phase interval of about 303 ms. The largest interval across deployment was about 763 ms.

Loop-count yields account for roughly 213 mandatory frame waits: roads, blocks and dressing. At 60 FPS that alone is about 3.55 s. Meanwhile the loading UI advances toward 95% using a fixed 0.8 s timer rather than completed generation work.

Buildings also have a 155 m visibility cutoff, with props/vegetation near 155–160 m. Late appearance while flying may be distance culling; it is a separate issue from startup construction.

### Implement

1. Profile resource acquisition, scene instantiation, road generation, building geometry/collision, dressing, render upload and readiness separately. Do not assume the texture size is the cause.
2. Reuse immutable intact geometry and collision resources for repeated archetypes or prebuild the seeded town into resources/a scene. Key caches by all geometry/material-affecting parameters and a version. Keep deterministic layout, footprints, materials and destruction behavior intact.
3. Reuse cached source resources on retry, but create fresh run state. Do not reuse destroyed building instances, old damage, pickups, enemies or callbacks. Use per-instance copies before mutating shared meshes/material parameters or shape sizes.
4. Replace unconditional loop-count waits with a central elapsed-time generation budget. A proposed starting budget is 4–6 ms of generation work per frame; measure and tune it. Split/cache individual expensive jobs as needed instead of moving all generation into one freezing frame.
5. Worker threads may prepare pure data only when safe. Do not mutate the scene tree, create unsafe physics state or update render objects from worker threads. Keep main-thread integration bounded.
6. Publish actual completed/total work for each generation phase, or show an honest indeterminate state. Remove the fixed 0.8 s world-percentage simulation. Reach 100% only after the current readiness contract is satisfied.
7. Preserve UIFlow's single-transition guard, loading failures/Retry/Back, scene readiness, collision availability and once-only run activation. Do not shorten loading by revealing missing geometry/collision. Guard asynchronous work with a generation/attempt token and check cancellation/scene validity.
8. Reproduce visibility transitions in a moving-camera capture. Align distant silhouettes/LOD, fog and culling distances with the actual flight camera. Keep nearby buildings solid and predictable, and avoid their sudden disappearance while they can obstruct flight or shots.
9. Preserve the full map and pixel art. Do not silently shrink the grid, strip town detail, remove all shadows/collisions or disable culling globally to produce a misleading speedup.

### Acceptance checks

- Measure cold-process deployment, repeated retry and menu-to-game deployment with identical seed, settings and resolution. Separate resource-cache conditions explicitly.
- Compare total time, worst generation batch/frame, mandatory wait count, draw calls, primitive count and memory/resource counts.
- Show warm retry improvement and substantially fewer fixed frame waits. Report actual timings rather than guaranteeing an arbitrary load target.
- Test cancellation, failed resource load, rapid repeated Deploy/Retry and five complete scene transitions. No old generation continues into a new run.
- Test intact/damaged/collapsed buildings, rooftops, player/enemy collisions, props, vegetation and shared-material isolation.
- Fly through several streets toward the visibility boundary and capture the before/after pop-in behavior.
- Run/adapt `tests/test_loading_animation_transition.gd`, relevant menu transition checks and `tests/verify_expanded_world.gd`.
- Investigate renderer/resource cleanup errors seen by the audit; do not label the run clean while they remain unexplained.

## Prompt 5 — Verify the whole game is playable after the fixes

Read the previous four prompts and verify their implemented behavior in the actual game. Repair any integration defects introduced by those changes. This is not satisfied by separate unit tests or a static showcase.

1. Launch through Main Menu → aircraft selection → loading → ready gameplay. Verify animation responsiveness, honest progress and one run start.
2. Test all aircraft. Accelerate, release, reverse, strafe, turn, climb and dash through streets. Confirm braking and camera behavior are predictable and collisions remain readable.
3. Acquire and release targets, aim at empty ground, switch enemies, shoot toward roofs and aircraft, and test behind/outside-arc aiming. The reticle must agree with reachable shooting.
4. Use all weapons, painted salvo, mods and Super. Confirm correct muzzle placement and unchanged ammo/damage/credit behavior except deliberately documented XP tuning.
5. Kill nearby and distant ground/air enemies. Verify loot placement, attraction, correct XP totals, clear HUD feedback and usable upgrade timing.
6. Test pause/settings, Reduce Flashes, upgrade choices, boss decisions, player death/results, retry and Hangar/Menu. No held input leaks or stale cross-scene work.
7. Complete at least one representative 5–10 minute combat run and five death/retry or menu/deploy cycles. Record stuck targeting, collision/camera issues, reward duplication, cleanup errors and item accumulation.
8. Profile loading and representative combat with the same seed, camera route, resolution, aircraft and enemy mix before/after where possible. Report hardware/renderer, sample length, median/p95/worst frame time and relevant object counts. A faster idle scene alone does not certify playability.
9. Run relevant automated checks under isolated saves. Classify obsolete expectations, actual regressions and unrelated failures honestly. Do not weaken gameplay invariants to get a green summary.

Deliver a concise final verification report with rendered captures, measurements and unresolved issues. Do not mark the whole repair complete if aiming still sticks, input/camera behavior remains inconsistent, normal XP is inaccessible, scene transitions leak old state, or loading readiness is bypassed.

## Optional single prompt to run the entire repair

```text
Work in C:/Users/Prime 3/Documents/ziva-heli-town-helll.

Read docs/IMPLEMENT_PLAYABILITY_FIX_PROMPTS.md and follow its Shared instructions.
Implement Prompts 1–4 in their listed order, then complete Prompt 5's integrated
verification. Inspect current source and preserve unrelated changes.

The priorities are truthful responsive aiming, predictable helicopter controls
and camera, accessible correctly placed XP, and faster honest world preparation.
Keep existing control bindings by default, the town art/map, Compatibility
renderer, combat systems, progression integrity and menu ownership.

Carry the work through implementation and verification. Return changed files,
the deliberate tuning choices, before/after measurements, relevant test results,
rendered evidence and any remaining limitations. Use isolated test saves.
```
