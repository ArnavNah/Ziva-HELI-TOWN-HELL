# Are the playability prompts implemented?

Checked **24 October 2026** against the supplied 21 October prompts and the current project source.

**Answer: partially. The main repairs exist and several work well, but all five prompts are not complete.** The most urgent remaining problem is unsafe cancellation during town generation. Aiming and XP also have reproducible edge cases.

This was a review. Gameplay source and existing acceptance tests were not changed. New diagnostic scripts and evidence are under `artifacts/playability-verification-20261024/`.

## Easy status table

| Prompt | Status | What this means |
|---|---|---|
| 1. Aiming and crosshair | Partially implemented | The old permanent target lock is repaired; rear aiming has a warning. Assistance can still pull toward an off-cursor enemy, and nearby-cover impact feedback can be wrong. |
| 2. Movement and camera | Main changes implemented; verification incomplete | Braking and camera turning are much more responsive in the tested Apache flight. All-aircraft, upgraded, 30/60/120 FPS acceptance coverage is not established. |
| 3. XP collection and progression | Partially implemented | Production XP/card integration passes. XP can still be collected during death, and translated-parent placement is incorrect. The requested card breather is absent from the current overlay. |
| 4. Town loading and pop-in | Partially implemented | Geometry caching, time-budget checks and real progress exist. Loading is faster, but large stalls remain and cancellation produces script errors. Visibility alignment remains incomplete. |
| 5. Complete game verification | Not complete | A short rendered smoke test passes after adapting its spawn fixture. This does not establish the requested 5–10 minute combat run, all aircraft/weapons, or the full death/retry matrix. |

The current `AGENTS.md` takes precedence over the older prompts: `XpManager` owns XP and the draft queue; `LevelUpUi` is the production overlay; `RunProgression` mirrors totals. Do not restore the old progression loop. Diagnostic spawning used only the enabled Scout Buggy, with the explicit fixture bypass; no disabled vehicle was enabled.

## Remaining problems, in repair order

### 1. Canceling loading lets the old town keep generating

**Confirmed runtime failure.** After five normal deployments, the probe started a sixth deployment and called the existing `UIFlow.return_to_menu()` route while town generation was suspended at a frame-budget yield. Generation continued on the detached scene. The log then reported repeated “outside the active scene tree” errors and finally:

```text
SCRIPT ERROR: Invalid access to property or key 'process_frame'
on a base object of type 'null instance'.
at: _prepare_session (res://scenes/main_game.gd:70)
```

The loading screen has an attempt counter, but city generation and the session-preparation continuation do not honor that cancellation. Successful normal deployment does not cover this failure.

**Needed:** invalidate the old generation/session attempt before scene replacement. Check the token, tree membership and queued-deletion state after every await and before attaching content, publishing completion or activating a run. Stop the old work instead of only suppressing its errors.

Source: [city_generator.gd:41](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/src/world/city_generator.gd:41>), [main_game.gd:61](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/scenes/main_game.gd:61>).

### 2. XP can still be awarded during the helicopter death animation

**Confirmed runtime failure.** With the player in the real death-animation state (`is_dying = true`, run still ACTIVE), a production `XpDrop` continued attraction and awarded 1 XP. Neither attraction nor final collection checks that the player is dying. A larger reward could also open a draft during the death sequence: `LevelUpUi` currently has no player-death check in its opening path.

**Needed:** stop collection for a dying/invalid player and invalidate drops belonging to an ended run. Keep XP awarded once, at collection, through `XpManager`. Prevent draft presentation while the player is dying; preserve the current authoritative progression architecture.

Source: [xp_drop.gd:49](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/src/loot/xp_drop.gd:49>), [xp_drop.gd:101](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/src/loot/xp_drop.gd:101>), [level_up_ui.gd:81](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/src/ui/level_up_ui.gd:81>).

### 3. Aim assistance still reaches beyond its advertised screen region

**Confirmed runtime behavior that leaves Prompt 1 incomplete.** The new system correctly clears the old indefinitely retained target and rejects targets beyond 140 m. However, when a target is outside the 65-pixel acquisition / 90-pixel retention region, it still qualifies through the old 18 m world-space circle.

In a controlled 1280×720 camera test, a target was acquired **140.7 pixels away from the cursor**, because its ground distance was **17.95 m**. This is fresh acquisition, not just retention.

**Needed:** make the chosen screen region/projected bounds a real limit, or define and test an explicit alternative with a clear indication. Keep free aim available near enemies.

Source: [player_turret.gd:119](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/src/player/player_turret.gd:119>).

### 4. The impact marker casts from the turret pivot, not the firing muzzle

**Confirmed runtime failure near cover.** `_update_actual_impact_point()` starts at `pitch_pivot.global_position`. The actual muzzle is 1.35 m ahead and slightly sideways. A test placed a thin wall between those two points. The impact marker hit that wall **0.825 m behind the actual muzzle**, even though a projectile starting at the muzzle would be beyond it.

The ordinary long-distance direction test passes because that small offset disappears over a long ray; it does not validate nearby-cover behavior. The HUD also draws the separate actual-impact dot only when the requested aim is outside the turret arc, so ordinary in-arc obstruction feedback remains incomplete.

**Needed:** calculate feedback from the same non-mutating muzzle origin and barrel direction used for the shot, and communicate blocked aim in the normal firing arc. Do not toggle the alternating muzzle just to draw the HUD.

Source: [player_turret.gd:216](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/src/player/player_turret.gd:216>), [hud.gd:244](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/src/ui/hud.gd:244>).

### 5. XP positioning still mixes local and world coordinates

**Confirmed under a translated parent.** Normal origin-parent air drops now retain their height. However, `spawn_xp_drop()` assigns a world position to local `drop.position`, and idle bobbing stores global Y but writes local Y.

Reproduction: parent at `(100, 20, 50)`, requested world drop at `(8, 25, -30)`. The drop appeared near `(108, 45.5, 20)` rather than the requested point plus its normal scatter. Its first manual idle update then moved global Y from **45.5 to about 65.5**. This is a general-parent correctness gap; it is not evidence that every drop is misplaced in the current origin-based MainGame.

**Needed:** convert world spawn coordinates through the parent before attaching the drop, and use one coordinate space consistently for its bob baseline.

Source: [loot_manager.gd:71](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/src/loot/loot_manager.gd:71>), [xp_drop.gd:59](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/src/loot/xp_drop.gd:59>).

## Improvements verified

### Flight and camera

The adapted rendered smoke test measured:

| Measurement | 21 October diagnostic baseline | Current check |
|---|---:|---:|
| Hands-off travel during first second | 18.47 m | 3.87 m |
| Speed after one second of release | 9.34 m/s | 0.00 m/s |
| Camera yaw lag during sustained turning | 12.58° | 1.93° |

The current flight reached 35.4 m/s before release. These are controlled Apache checks, not a complete flight-feel assessment for every aircraft or frame rate. The camera updates before mouse conversion, and its process-frame guard prevents duplicate follow updates.

The camera still reads raw `global_transform` while physics interpolation is enabled. Interpolated-camera alignment at different render rates needs a dedicated moving-camera test; this source observation alone does not prove visible jitter.

### XP and cards

`verify_xp_spec_integration.gd` passed **16/16** checks, including production drop collection once, XP/HUD synchronization, level-up pausing, one card selection per gained level, distinct offers, assigned icons, rarity borders and real damage/fire-rate/salvo/XP/magnet upgrade effects.

The real Rotary Overdrive card increased the machine-gun magazine from **300 to 390**, as expected. That check passed but its process reported ObjectDB leak warnings at exit.

Production enemy rewards now use `spawn_xp_drop()` with an immediate attraction envelope of **140 m horizontal / 50 m vertical**. Normal variant XP is clamped to **2–10** per drop. `XpManager` starts with a **25 XP** requirement and scales each later requirement by `25 × level^1.35`; the old 10/25 cumulative threshold table is not the current production architecture. Depending on reward size, the first upgrade requires roughly 3–13 ordinary enemy drops before modifiers. Actual kills/time-to-upgrade in a representative combat run was not measured here.

The current production `LevelUpUi` immediately opens the next queued draft without resuming combat. The old short presentation delay / combat breather requested in Prompt 3 has therefore not been preserved in this overlay. Add any chosen delay there, without restarting `RunProgression`'s old draft loop.

### Town loading

Five rendered menu/deploy cycles completed with the **16×16 grid, 142 buildings and 713 mesh instances** intact. There were 15 cached intact building meshes. Progress reads real generation stages and readiness still gates gameplay.

| Cycle | Deployment | WORLD frames | Largest WORLD interval | Largest observed deployment interval |
|---|---:|---:|---:|---:|
| 1, first in process | 3.81 s | 57 | 336 ms | 600 ms |
| 2, warm | 2.69 s | 72 | 142 ms | 273 ms |
| 3, warm | 3.08 s | 88 | 140 ms | 281 ms |
| 4, warm | 2.94 s | 77 | 125 ms | 416 ms |
| 5, warm | 2.47 s | 54 | 120 ms | 421 ms |

The historical October 21 deployment was approximately 6 s and 215 WORLD frames. The current observations indicate improvement, but this is not an identical-build benchmark or an OS/disk-cache-cold test. Current measurements used Godot 4.7.1, Compatibility/OpenGL 3.3, Intel Iris Xe, 1280×720 and the project's 60 FPS cap. A headless runtime-budget test overlapped part of the warm-cycle sampling; these figures are diagnostics, not an uncontended performance benchmark.

The nominal 5 ms generation budget does **not** bound every expensive job. Whole mesh builds and portions of road/sidewalk construction still run without intermediate yields; measured WORLD stalls remain 120–336 ms. Phase-by-phase CPU/render-upload attribution is still missing.

Two additional source-level gaps remain:

- The intact-mesh cache key contains archetype, rounded dimensions and wall tile, but omits hash-dependent wall/roof color variation and a cache version. Houses with the same key can inherit another location's colors; damaged geometry is rebuilt from the original hash and can then change palette. Include every output-affecting variant in the key. Collision dimensions are also rounded in their key.
- Buildings end visibility at 160 m, while props/vegetation use approximately 260 m. The changes do not establish a consistent distant silhouette/LOD/fog solution. A flying-camera pop-in capture is still needed.

## Test results and their limits

| Check run during this review | Result |
|---|---|
| Project parse check | PASS, 0 parse failures |
| Production XP specification integration | PASS, 16/16 |
| Runtime budget/shared-resource/zero-direct-kill-XP checks | PASS, 9/9 |
| Actual resource-card magazine contract | PASS, 300 → 390; exit leak warning |
| Existing complete-game-loop test, unchanged | Stops after its first 12 checks: it stops the director, then requests a normal restricted enemy spawn and dereferences the resulting null |
| Diagnostic copy with explicit fixture spawn bypass | PASS, 20/20 short checks, rendered capture; exit leak warning |
| New edge-case diagnostic | 2/7 pass; five reproduced failures described above; exit leak warning |
| New rendered loading probe | Five normal deployments complete; cancellation fails with scene-tree/script errors |
| Existing flight/timing regression test | 13/19; not a clean pass |

The flight/timing failures need classification before that suite can be used as acceptance evidence. Five assertions inject 1–10 second `_process()` steps while the current CombatDirector deliberately clamps each call to 0.1 s. The diagonal-speed assertion compares a one-second straight acceleration sample against a later diagonal sample; it needs explicit measured speeds and cap-aware expectations before calling it a production regression. No gameplay invariant was weakened to obtain a passing result.

The original smoke test also tests legacy `spawn_pickup(XP_GEM)`, rather than the new production `XpDrop` reward path. The separate XP integration and edge-case probes cover the production path. Its printed claim that all five prompts are satisfied is broader than its actual assertions.

The rendered screenshot was inspected. It demonstrates the live town/HUD loading successfully; its single FPS readout is not a combat benchmark. ObjectDB warnings in short fixtures remain uninvestigated and are not treated as clean shutdown evidence or automatically blamed on production gameplay.

Not established by this review: a representative 5–10 minute combat soak, five death/result/retry cycles, every aircraft and weapon/mod combination, 30/60/120 FPS comparisons, long-session XP item accumulation, a moving pop-in capture or a complete matched combat performance profile. Five menu/deploy cycles were exercised, but that narrower route does not cover all of those requirements.

## Evidence and rerun commands

- [Rendered gameplay capture](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/artifacts/playability-verification-20261024/gameplay.png>)
- [Loading measurements](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/artifacts/playability-verification-20261024/loading-results.json>)
- [Edge-case log](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/artifacts/menu-repair-tests/edge_cases.log>)
- [Loading/cancellation log](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/artifacts/menu-repair-tests/loading_probe-rendered.log>)
- [Adapted smoke-test log](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/artifacts/menu-repair-tests/adapted_game_loop-rendered.log>)

Run from the project root. The wrapper provides isolated test saves. Edge and cancellation probes intentionally return failures while the defects remain.

```powershell
python tools/run_menu_checks.py --parse
python tools/run_menu_checks.py --script tests/verify_xp_spec_integration.gd
python tools/run_menu_checks.py --script tests/verify_xp_capacity_contract.gd
python tools/run_menu_checks.py --script tests/test_runtime_budget_fixes.gd
python tools/run_menu_checks.py --script tests/verify_flight_timing.gd
python tools/run_menu_checks.py --script artifacts/playability-verification-20261024/adapted_game_loop.gd --rendered
python tools/run_menu_checks.py --script artifacts/playability-verification-20261024/edge_cases.gd
python tools/run_menu_checks.py --script artifacts/playability-verification-20261024/loading_probe.gd --rendered
```
