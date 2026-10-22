# Tactical environment and menu update

The game now combines a higher tactical chase camera and compact military scale with colorful low-poly environment materials.

- Camera: 38–44 m follow distance, 52 m height offset, reduced speed zoom. Generated buildings now range from 4.5–19 m tall, keeping ground encounters visible from the starting altitude.
- Environment: world-space meadow patches, stepped light bands on buildings and roads, wind on batched pine foliage, rocks and green clearings, atmospheric distance fog, corrected helipad H, and fuel tanks placed above ground.
- Enemies: 16 roles total, including scout buggy (wave 1), attack wing (wave 2), and mortar crawler (wave 4). Underrepresented roles receive higher selection weights. Existing wave gates and population targets remain enforced. Interceptors now have a fixed-wing silhouette; tanks have role colors and gunship rotors animate.
- Spawning: clearance queries no longer intersect the floor; automatic spawns respect world bounds, check hostile clearance, and defer when no valid location is available. Unknown role IDs are rejected. City generation uses a local RNG instead of resetting combat randomness.
- Menu: operations layout, isolated 3D aircraft preview, selected-aircraft captions, styled controls, keyboard launch and focus restoration. Settings/hangar overlays disable underlying deployment controls.

## Verification

Run the renderer-backed integration check from the project directory:

```powershell
python tools/run_godot_check.py tests/verify_polish.gd
```

The final run passed **287/287 checks** and saved actual frames to `artifacts/menu.png`, `artifacts/gameplay.png`, and `artifacts/settings.png`. It covers menu navigation, keyboard deployment, selected aircraft propagation, shaders/foliage, new role creation and movement, and collision-checked ground/air spawn locations at the center and map corners.

Existing suites also passed: acceptance matrix (12/12), spawn specification (4/4), enemy movement (4/4), flight/camera (4/4), roster/districts (5/5). Their logs are in `artifacts/`.

Ziva MCP was accessed through the running local endpoint for project inspection, settings updates, script compilation, editor diagnostics, and scene access. Ziva live capture returned a sign-in/API-key error, so screenshots and integration checks used Godot 4.7.1 directly with the project's GL Compatibility renderer.

`tools/ziva_call.py` targets the local session at port 7012. It is a session-specific development helper, not a game dependency.

Original source files are preserved in `.codex-backups/before-polish.zip` because this workspace has no Git repository. Screenshots and backups are excluded from Godot's asset importer.
