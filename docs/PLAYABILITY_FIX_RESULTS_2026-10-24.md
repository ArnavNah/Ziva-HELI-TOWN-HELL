# Playability fixes — 24 October 2026

Rechecked on 27 October 2026 with Godot 4.7.1. Gameplay and transition tests pass; rendered combat performance remains below the desired smooth-play target on the tested Intel Iris Xe machine.

The audited aiming, death-time XP, pickup placement, card timing and loading-cancellation defects have been repaired. The full 16×16 town, seven active ground vehicles, art assets and authoritative `XpManager` progression remain in place.

## What changed for the player

| Area | Result |
|---|---|
| Mouse aiming | Assistance stays inside 65 pixels when acquiring a target, or 90 pixels when retaining it. Moving away returns to free aim. |
| Crosshair | The impact marker starts at the next firing muzzle. It is visible during normal aiming as well as outside the turret arc; blocked aim changes its warning color. HUD queries do not alternate barrels. |
| Camera | The camera follows the interpolated aircraft pose, with its own interpolation disabled to avoid smoothing twice. The helicopter updates the camera before projecting mouse aim. |
| XP | Dying players cannot collect rewards. Drops carry a run-generation identifier, so old drops cannot pay the next run. Body contact still collects once without needing a prior magnet lock. |
| Pickup position | World spawn points are converted into the parent's coordinates before `_ready()`. Idle bobbing uses a local baseline, so moved parents no longer add their height twice. This covers production XP and legacy supply pickups. |
| Upgrade cards | A 0.35-second presentation delay precedes the first card. Further earned choices resume combat for 2.5 seconds between cards. Pause freezes that interval; death prevents presentation. |
| Loading cancellation | Resource request, roads, buildings, vegetation, readiness and final reveal all check cancellation. The reveal explicitly draws a frame, so a hidden/minimized Windows window cannot hang while waiting for a draw signal. |
| Town resources | Road markings/sidewalks are split into cached rows. Building cache keys preserve exact dimensions, palette variants and a version. Collapsing one building keeps other instances' shared shapes intact. |
| Buildings appearing late | Buildings, props and vegetation now share a 260 m visibility limit with 35 m margins. Day fog reaches its far value at 200 m to conceal that boundary, including foliage-sector offsets. |

`XpManager` still awards XP on collection and owns levels/queued choices. `LevelUpUi` remains the production overlay. The legacy `RunProgression` automatic draft loop was not restored. This repair did not alter the ground-vehicle roster or wheel/model assets.

## Verification

| Check | Result |
|---|---|
| Reproduced aiming/XP/cache edge cases | 24/24 pass |
| Production XP, cards and real controller effects | 20/20 pass |
| Flight and run/wave timing | 19/19 pass |
| 3 aircraft × baseline/Ghost Rotor × 30/60/120 FPS | 87/87 pass; physics stayed at 60 Hz |
| Rendered menus/settings/upgrades/results/deploy cycles | 183/183 pass |
| Cancel during request, resources, roads, buildings, dressing and reveal; then deploy again | 22/22 pass, rendered |
| Runtime budgets, shared outlines and zero direct kill XP | 9/9 pass |
| Rendered game-loop smoke check | 20/20 pass |
| Five-minute rendered combat + five real crash/results/Play Again cycles | 29/29 pass; 127 kills, 363 physically collected XP, 797 enemy shots, four weapons, salvo and Super |

The smoke check now uses the enabled Scout Buggy's explicit fixture-spawn bypass and the production `XpDrop` path. The menu test uses `LevelUpUi`, not the old draft dialog. Timing tests advance the director in small simulation steps, preserving its existing 0.1-second stall clamp. GUI tests allow hover routing to process before a synthetic click.

The final parse scan reports zero failures. Two concurrently edited enemy controller files briefly failed to parse because member declarations preceded `class_name`; their declarations were moved below `extends`. Rendered game-loop verification was rerun after those fixes and passed 20/20.

### Flight measurements

| Aircraft | Baseline coast after releasing thrust, first second | Ghost Rotor coast, first second |
|---|---:|---:|
| Apache | 3.87 m | 7.60 m |
| Nighthawk | 4.46 m | 8.74 m |
| Warlock | 3.41 m | 6.70 m |

Stopping distances were identical across the tested render caps. Camera follow lag in the matrix stayed below 5 degrees. Dashes lasted 17 physics frames in the recorded fixture.

Ghost Rotor intentionally gives +25% speed and −35% drag. It consequently coasts farther than the baseline aircraft. Its test preserves that tradeoff, bounds half-second residual speed below 4.5 m/s, and requires speed below 1 m/s after one second. Baseline aircraft require half-second speed below 2 m/s. These are explicit fixture expectations, not a removal of upgrade effects to obtain a pass.

The original October 21 Apache diagnosis measured 18.47 m of first-second coast, 9.34 m/s remaining after that second, and 12.58° of camera lag. Current baseline braking remains substantially more responsive.

### Loading measurements and limits

The latest rendered five-cycle menu test measured **6.40 s** for its first deployment and **2.70–2.89 s** for subsequent deployments. All three aircraft and normal readiness handoffs were exercised. These are observed timings, not a disk-cache-cold guarantee. Earlier runs were faster; scene preparation and shader/upload timing vary materially between runs.

An earlier fresh-process diagnostic during this repair took 5.89 s initially, then 2.48–2.96 s on repeat deployment. Cold resource acquisition, shader work and render upload can still hitch; the 5 ms generation budget is a cooperative CPU budget, not a guarantee that every GPU/frame interval stays below 5 ms. No 60 FPS guarantee is made.

The map still has 142 buildings. Mesh instance count increased from 713 to 744 because the two giant road-detail meshes became row chunks; the layout and scenery were preserved. The palette-correct building cache contains 29 variants in this town rather than incorrectly sharing 15 variants.

### Rendered combat performance still needs work

The latest forced-draw 1280×720 Compatibility-renderer benchmark on Intel Iris Xe placed 24 enemies in the full town. It measured **32.8 FPS** stationary and **37.0 FPS** while flying (average frame times 30.5 and 27.0 ms; 95th percentiles 41.5 and 43.4 ms). Disabling enemy AI in the diagnostic lifted the average to 66.8 FPS; hiding the city lifted it to 91.0 FPS. These diagnostic toggles change more than one load at once and do not isolate a single culprit. They show that the town draw cost and active combat both matter. Town/rendering edits made while this check was in progress improved this benchmark over the earlier 20.8–22.3 FPS sample, but the game is still below a 60 FPS smooth-play target under heavy combat on this hardware.

The five-minute soak tests progression and transition stability with an autopilot and boosted health, fuel and ammo. Its ordinary frame-loop samples are not a reliable GPU benchmark because Windows can suppress drawing for hidden windows. Use the latest forced-draw benchmark in `artifacts/runtime-budget-playability-latest.json` for performance assessment. The soak does not validate survival balance or human control feel.

### Audio shutdown limitation

Quit routes now stop new sound requests, stop pooled/BGM players, clear stream handles, and allow a short mixer interval before termination. Test teardown uses that path too. The dedicated audio check confirms the players stop and release their stream handles.

Some rendered runs still report `AudioStreamPlaybackWAV`/`AudioStreamWAV` ObjectDB warnings at process exit. Verbose diagnostics identify these separately from the former canceled-generation script errors. This symptom is consistent with a [known Godot audio-server shutdown issue](https://github.com/godotengine/godot/issues/76745), but matching the symptom does not prove an identical engine cause. This repair does not patch the Godot binary or suppress those warnings. A passing assertion count is therefore not presented as a universally clean engine shutdown.

## Main implementation files

- [Aiming](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/src/player/player_turret.gd>), [camera](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/src/player/player_camera.gd>), [HUD](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/src/ui/hud.gd>)
- [XP manager](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/src/player/xp_manager.gd>), [XP drop](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/src/loot/xp_drop.gd>), [loot spawning](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/src/loot/loot_manager.gd>), [legacy pickups](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/src/loot/pickup.gd>)
- [Production card overlay](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/src/ui/level_up_ui.gd>)
- [Town generation](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/src/world/city_generator.gd>), [vegetation](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/src/world/field_dressing.gd>), [building caches](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/src/world/destructible_building.gd>), [props](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/src/world/town_props.gd>), [weather/fog](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/src/world/weather_system.gd>)
- [Scene readiness](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/scenes/main_game.gd>), [transition ownership](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/autoload/ui_flow.gd>), [loading reveal](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/src/ui/menus/loading_screen.gd>)
- [Audio shutdown](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/autoload/audio_manager.gd>), [main-menu quit](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/src/ui/menus/main_menu.gd>), [pause-menu quit](<C:/Users/Prime 3/Documents/ziva-heli-town-helll/src/ui/menus/pause_menu.gd>)

Original versions of the initial implementation targets were saved under `artifacts/playability-fixes-20261024/before/`. Other workspace changes were preserved.

## Rerun

Run from the project root; the wrapper isolates profiles/settings from the player's save.

```powershell
python tools/run_menu_checks.py --parse
python tools/run_menu_checks.py --script tests/test_playability_remaining_fixes.gd
python tools/run_menu_checks.py --script tests/verify_xp_spec_integration.gd
python tools/run_menu_checks.py --script tests/verify_flight_timing.gd
python tools/run_menu_checks.py --script tests/test_flight_frame_rates.gd
python tools/run_menu_checks.py --script tests/test_generation_cancellation.gd --rendered
python tools/run_menu_checks.py --script tests/test_menu_repair.gd --rendered
python tools/run_menu_checks.py --script tests/verify_playability_game_loop.gd --rendered
python tools/run_menu_checks.py --script tests/test_playability_combat_soak.gd --rendered --timeout 480
$env:ZIVA_BENCH_LABEL = 'playability-latest'
python tools/run_menu_checks.py --script tests/profile_menu_gameplay_budget.gd --rendered --manual-render
```

Evidence is in `artifacts/menu-repair-tests/`, with combat and flight JSON under `artifacts/playability-fixes-20261024/` and forced-render performance data in `artifacts/runtime-budget-playability-latest.json`.
