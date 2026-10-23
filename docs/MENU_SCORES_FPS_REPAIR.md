# Aircraft menu, game-over scores, and runtime cost repair

Completed 2026-10-23. Changes were checked with Ziva MCP script validation and isolated local Godot runs. Ziva's live `run_scene` tool returned `Not signed in (no API key on init payload)`, so rendered acceptance used the installed Godot 4.7.1 executable instead.

## Visible changes

- Aircraft selection now has a fitted layout with a separate 3D preview, aligned details panel, aircraft carousel, wallet, and utility controls. Text is larger, descriptions are shorter, and long loadout values wrap within their column.
- Performance labels and values share the same baseline, with consistently spaced bars underneath. Launch, Back, and Upgrade Hangar use ordinary aligned button text instead of oversized nested shortcut badges.
- The preview camera frames the airframe inside its own area. Wallet/high-score values no longer overflow into the panel or offscreen.
- Game over retains the dark battlefield overlay, large headline, Play Again, and Quit. It now visibly displays the settled sortie score, career high score, time, kills, coins, and wave. New records receive a visible badge.
- Enemy death settlement now uses each enemy's configured `score_value`, correcting the shared hardcoded 50-point reward. Direct death XP remains zero; physical collection remains authoritative.

Rendered evidence:

- `artifacts/aircraft-selection-repaired.png`
- `artifacts/aircraft-selection-repaired-960.png`
- `artifacts/game-over-score-gameplay.png`

## Performance fixes

1. **Idle/hidden aircraft showroom rendering.** The isolated 3D viewport previously rendered continuously. It now requests redraws during selection transitions, dragging, and zooming, and stops when idle or when an ancestor is hidden. The preview also occupies its own portion of the screen rather than rendering a full-screen 3D background behind the details panel.
2. **Road graph lookup.** Ground vehicle replanning previously scanned all 2,413 graph points for both endpoints. The regular road network now computes the nearest endpoint from two analytic candidates. A 10,000-position comparison, including positions beyond map edges, verified equal closest-point distances against the original full search.
3. **Repeated road routes.** A bounded 128-route cache shares route computations. Returned arrays are independent copies so one vehicle clearing its path cannot corrupt another vehicle's route.
4. **First-combat graph construction.** The road graph is prepared during scene loading instead of on the first ground enemy's physics tick.
5. **Shared material outline contamination.** Outlining a unit previously changed `next_pass` on shared source materials. Outlines now use an instance-scoped overlay, preventing unrelated meshes sharing the base material from acquiring an extra render pass. Wheel Mesh/Material sharing and distinct building surface materials are preserved.

The measured 10,000-query microbenchmark took 518,658 microseconds for the reference full search versus 85,985 microseconds for the analytic lookup: approximately **6.0× faster for this lookup operation**, not overall game FPS.

## Current rendered stress result and limits

The final benchmark uses the full 16×16 city, 24 production enemies drawn from enabled ground/air types, real AI/combat, uncapped frames, and the Intel Iris Xe / OpenGL Compatibility renderer. Windows can suppress offscreen rendering, so this run uses `--disable-render-loop` and explicitly draws once per sampled frame.

| Scenario | Average frame time | Equivalent FPS | P95 frame time |
| --- | ---: | ---: | ---: |
| Stationary combat | 22.05 ms | 45.4 | 30.83 ms |
| Camera/player flight route with combat | 29.28 ms | 34.2 | 49.06 ms |
| Diagnostic with enemy AI disabled | 20.27 ms | 49.3 | 22.52 ms |
| Diagnostic with AI disabled and city hidden | 14.86 ms | 67.3 | 17.92 ms |

**Stable 60 FPS is not established for heavy combat.** The current stress case still has substantial rendering and physics/AI cost. Earlier profiling runs used automatic rendering plus explicit draws and encountered a transient missing mission script while other workspace files were changing, so those wall-clock FPS values are not a valid controlled before/after comparison. No overall FPS multiplier is claimed.

The diagnostics are sequential phases with evolving enemy positions; they locate remaining cost but are not precise isolated percentage measurements. The production 60 FPS cap, map size, and enemy roster were not changed by these repairs.

Some full-scene fixtures still produce ObjectDB cleanup warnings at process exit. Final functional checks had no parser/runtime errors, but this work does not claim to resolve every shutdown resource warning or all remaining performance bottlenecks.

Benchmark evidence: `artifacts/runtime-budget-final-manual-render.json`.

## Verification

| Suite | Result |
| --- | ---: |
| Aircraft specification/menu/runtime equality | 69/69 |
| New rendered layout and visible results acceptance | 48/48 |
| Minimal debrief layout/navigation | 17/17 |
| Menu loading, Play Again, Quit, purchases, and controller navigation | 35/35 |
| World materials, building destruction, and shared resources | 77/77 |
| New runtime-cost/score regression checks | 9/9 |
| Urban road path generation | 1/1 |
| Retro outlines and shader toggles | 6/6 |
| **Total functional assertions** | **262/262** |

The rendered layout suite checks all three aircraft at 960×540, 1280×720, 1920×1080, and 2560×1080, including non-overlapping major panels, visible game-over scores, and the overlay on the actual paused battlefield. Navigation checks verify Play Again returns to selection and does not pay the run twice.

Ziva compiled all six changed production scripts successfully. Its script subprocess reports a cleanup warning after validation; compilation results were all true. The full-scene local rendered run also confirmed current game loading after the mission script became available again.

## Files changed by this repair

- `src/ui/menus/vehicle_selection_menu.gd`
- `src/ui/menus/debrief_screen.gd`
- `src/combat/damage_receiver.gd`
- `src/world/urban_pathfinder.gd`
- `scenes/main_game.gd`
- `autoload/shader_manager.gd`

New checks: `tests/test_aircraft_results_layout.gd`, `tests/test_runtime_budget_fixes.gd`, `tests/profile_menu_gameplay_budget.gd`. The existing retro shader test now recognizes instance overlays and uses explicit test spawning. `tools/run_menu_checks.py` accepts `--manual-render` for reproducible explicit-draw benchmarks. Original sources are preserved under `.codex-backups/menu-scores-fps-20261023/`.

Reproduce the focused checks:

```powershell
python tools/run_menu_checks.py --rendered --script tests/test_aircraft_results_layout.gd
python tools/run_menu_checks.py --script tests/test_runtime_budget_fixes.gd
python tools/run_menu_checks.py --script tests/test_menu_navigation_edges.gd
python tools/run_menu_checks.py --rendered --manual-render --script tests/profile_menu_gameplay_budget.gd
```

## Combat follow-up — 2026-10-24

Continued the remaining combat investigation after the menu/results work. Added these production changes:

- Pooled muzzle flashes, impact flashes, surface light patches, and projectile trails disable their frame callbacks while inactive. All 128 idle pool slots now sleep; activation wakes a slot, and expiry returns it to sleep. Detaching trails keep processing until their particle tail has faded. Reusing a fading trail also restores the exhaust flare immediately.
- Projectile sweep raycasts disable automatic updates because the projectile already calls `force_raycast_update()` after setting each sweep endpoint. A real 600 m/s collision test verifies the explicitly updated, disabled raycast still detects the wall and applies damage.
- The small emissive projectile tracer uses eight radial segments and one ring, and does not cast shadows.
- Enemy avoidance, navigation LOS, weapon LOS, and roof probes reuse one private ray-query parameter resource per enemy across 15 query sites. Every call resets the ray endpoints, collision mask, and inside-hit flag. Self exclusion uses the enemy's RID. Existing probe intervals, physics rate, collision masks, and steering behavior remain intact.

Original production sources are preserved in `.codex-backups/combat-queries-20261024/`. Changed sources: `src/enemies/base_enemy.gd`, `src/combat/projectile.gd`, `scenes/combat/projectile.tscn`, and the four effect scripts in `src/effects/`.

### Follow-up verification

| Suite rerun in this follow-up | Result |
| --- | ---: |
| New collision/pool/pause/faction checks | 27/27 |
| Road/outline/enemy-score regression checks | 9/9 |
| Rendered aircraft layout and visible results | 48/48 |
| Menu loading, purchases, Play Again, Quit, upgrade queue | 35/35 |
| Minimal debrief layout/navigation | 17/17 |
| Gameplay stability, upgrades, physical XP | 20/20 |
| **Distinct assertions in this follow-up** | **156/156** |

The stability fixture needed its artificial enemy assigned to hostile collision layer 4: its old default layer 1 was outside the player projectile's existing faction mask. No production damage mask was weakened to make the fixture pass. New acceptance checks separately verify that player splash cannot damage the player faction and enemy splash cannot damage its own hostile cohort.

Ziva MCP compiled all six changed scripts successfully, and its `execute_script` tool also ran the full new **27/27 behavioral checks** successfully using an isolated test profile. Its live `run_scene` still reports `Not signed in (no API key on init payload)`. With `speed=true`, it instead reports that its input harness returned no frame timings and requests a current addon harness. Those are tool limitations; no live Ziva FPS measurement is claimed. Local rendered checks captured the updated aircraft selection and the visible 3399/18000 game-over score example.

The focused ray-query microbenchmark is diagnostic, not a timing assertion. Local runs showed lower median cost with reuse (for example 75,068 versus 48,927 microseconds per 3,000 casts), while the Ziva subprocess measured 53,068 versus 58,581. Resource allocation is removed, but noisy measurements do not justify claiming a universal query speedup or an overall FPS multiplier.

### Remaining FPS limitation

**Heavy-combat FPS remains unresolved; this follow-up does not establish an overall FPS improvement or stable 60 FPS.** The same 24-enemy explicit-draw benchmark initially measured 36.6 FPS stationary and 39.7 FPS in flight. Subsequent uninstrumented runs varied substantially, with the final run measuring:

| Final stress phase | Average frame time | Equivalent FPS | P95 |
| --- | ---: | ---: | ---: |
| Stationary combat | 44.84 ms | 22.3 | 74.92 ms |
| Flight with combat | 33.51 ms | 29.8 | 53.19 ms |
| Diagnostic with enemy brains disabled | 19.04 ms | 52.5 | 23.62 ms |
| Diagnostic with brains disabled and city hidden | 12.75 ms | 78.4 | 15.42 ms |

The final averages are lower FPS than the initial sample. These sequential runs have different wall-clock-driven simulation positions and variable timing, so they do not establish whether the small budget changes cause a full-game regression or improvement. Per-variant instrumentation showed roughly 0.1–0.3 ms per enemy brain call, about 4.9 ms for the 24-unit cohort per physics step in that run; the simulation can take multiple physics steps per rendered frame. A frozen-scene diagnostic did not reliably isolate shadows, outlines, lights, or post-processing as the dominant factor. No graphics feature, map area, or active roster was removed based on those measurements.

Full-scene stress fixtures continue to report ObjectDB cleanup warnings at exit (23 in the final stress run), although no parser/runtime errors appeared in the completed acceptance checks. Further profiling is needed to resolve the remaining frame-time and shutdown-resource issues.

Evidence: `artifacts/runtime-budget-20261024-before.json`, `artifacts/runtime-budget-20261024-after.json`, `artifacts/runtime-budget-20261024-ai-profile.json`, `artifacts/runtime-budget-20261024-final.json`, and `artifacts/render-cost-diagnostics.json`.

Reproduce the new checks:

```powershell
python tools/run_menu_checks.py --script tests/test_combat_query_budget.gd
python tools/ziva_call.py execute_script artifacts/ziva-combat-behavior-check.json
```
