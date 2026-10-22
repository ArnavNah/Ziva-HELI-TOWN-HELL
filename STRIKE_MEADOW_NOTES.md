# Tactical battlefield and procedural enemies

Implemented through the local Ziva MCP bridge on 14 October 2026.

The revised helicopter camera follows 35 m behind and 33.5 m above the aircraft, with a roughly 40-degree downward angle and modest speed-based pullback to 39 m. This widens the prior close view by about 15% while keeping its angle. It keeps a stable horizon through banking and follows the interpolated aircraft transform with less turn lag.

The airframe now uses 85% of its previous size, with matching hull collision dimensions and turret/muzzle transforms. Building footprints increased by 10%, and heights use 90% of the district specifications instead of 80%. Main roads are 12 m wide and secondary roads 8 m wide. Tree crowns avoid the recorded building footprints. Elite enemies use the same 1.2 scale for visuals, turret mounts and hitboxes, with the collider offset scaled to keep their feet or tracks aligned with the road. Seeded clusters of meadow clearings interrupt the city grid.

Flight now uses a 36 m/s base cruise speed, smoother acceleration and yaw, a continuous brake-to-reverse command, and a shared cruise limit for forward-plus-strafe movement. The original aircraft handling multipliers and 72 m/s absolute cruise ceiling remain available for aircraft differences and upgrades.

Wave intermissions use the same pausable clock as gameplay. Pauses and upgrade decisions freeze both elapsed time and next-wave progression; leaving the run cancels pending progression. The HUD rounds remaining time upward and displays the three-second incoming-wave countdown explicitly.

The environment includes collision-backed faceted knolls, animated shallow ponds, broadleaf trees, pines, grass tufts and wildflowers. Vegetation remains batched into independently culled 76 m sectors. Surface and terrain shaders use banded direct lighting with proper shadow attenuation, world-space grain and foliage wind. The shadow atlas is now 2048. Coplanar building tops beneath roof caps were removed to fix roof flicker without changing roof collision heights or destruction behavior.

Color grading now runs through `src/shaders/battlefield_grade.gdshader`, on canvas layer 0 above the 3D world and below the HUD. It controls saturation, warm highlights, a gentle highlight shoulder and shadow lift. This replaces the ineffective built-in environment adjustments for the Compatibility renderer ([Godot documentation](https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html#adjustments)). Lighting and material palettes were tuned together: olive meadows, warm-gray roads, brick/slate/sandstone architecture, softer sun and neutral shadow bounce. Day, storm and night transition the grading uniforms along with their lighting; night retains visible terrain and aircraft silhouettes.

Six procedural enemies join the existing roster:

| Enemy | First wave | Behavior |
| --- | --- | --- |
| Hunter Drone | 1 | Low-altitude circling hunter with a light gun |
| Rocket Buggy | 2 | Fast lateral movement with unguided rockets |
| Escort Fighter | 3 | Sweeping aerial passes and three-round bursts |
| Incendiary Tank | 5 | Short-range advance and five incendiary rounds |
| Torpedo VTOL | 5 | Standoff strafing and paired guided missiles |
| Rail Crawler | 6 | Long-range positioning and a one-second locked-aim warning |

New silhouettes have seeded liveries. Reinforcements arrive in small approach sectors and use offset road lanes. Selection favors underrepresented ground or air families while preserving wave gates, variant caps, opening grace and the existing 40-enemy population ceiling. Bursts and rail warnings hold attack slots until completion. Blast damage preserves status-effect probabilities.

Verification passed:

- `tests/render_color_grading.gd`: 6/6 rendered pixel checks for effective world grading, unchanged HUD health-bar colors, distinct night/storm lighting and restoration of daylight. Images are `artifacts/color_grade_day.png`, `artifacts/color_grade_night.png` and `artifacts/color_grade_storm.png`.
- `tests/verify_flight_timing.gd`: 19/19 checks for actual forward, reverse, strafe and turn inputs, acceleration and speed limits, close angled framing, clock formatting, pause/resume, intermissions and returning to the menu.
- `tests/verify_strike_meadow.gd`: 132/132 runtime checks after the scale adjustment, including terrain raycasts, all six new enemy movements and weapons, rail warnings, guided missiles, incendiary payloads and wave caps.
- `tests/verify_expanded_world.gd`: 23/23 checks for expanded map bounds, destruction and resource budgets.
- Acceptance matrix: 12/12; flight/camera: 4/4; spawning specification: 4/4; existing enemy movement: 4/4; roster/districts: 5/5.
- `tests/verify_strike_live.gd`: 4/4 checks in a rendered run for forward flight, ammunition consumption, opening cohort deployment and camera framing.
- Three additional collision ray checks through Ziva confirmed hits inside the resized helicopter hull, misses outside its new width, and clearance beneath the correctly mounted elite collider.

The initial world-update benchmark in `artifacts/performance_strike_meadow.json` predates the closer camera revision. Updated preview images are `artifacts/strike_meadow_gameplay.png`, `artifacts/strike_meadow_landscape.png` and `artifacts/strike_meadow_live.png`.

Run a check with `python tools/run_strike_checks.py headless tests/verify_strike_meadow.gd`. Render gameplay with `python tools/run_strike_checks.py render tests/verify_strike_live.gd`. Benchmark with `python tools/run_strike_checks.py render tests/benchmark_gameplay.gd -- --label=strike_meadow`.

Original world-update files are preserved under `.codex-backups/strike-meadow-20261014/`, the versions before the flight and timing fixes are under `.codex-backups/flight-timing-20261014/`, and the versions before the latest scale adjustment are under `.codex-backups/scale-refinement-20261014/`. Ziva file edits, project settings and headless execution worked; its live `run_scene` tool reported that sign-in was required, so live gameplay was verified with the local Godot renderer instead.

Versions before the color-grading pass are preserved under `.codex-backups/color-grading-20261014/`.
