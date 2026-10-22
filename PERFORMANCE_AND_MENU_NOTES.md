# Expanded battlefield, performance fixes, and pixel-art menu

The city is now **608 × 608 metres** with **16 × 16 lots**, up from 304 × 304 metres and 8 × 8 lots. Both dimensions doubled, giving four times the generated area. Ground collision, backdrop placement, enemy spawning, player steering and dash clamping use the expanded perimeter. Square boundary handling lets the player reach the map's corners.

Rendering and simulation changes:

- Buildings combine facade details into one surface and use a simple mesh for shadows. Decorative scenery is divided into 76 m sectors with distance culling.
- Shared environment materials reduce resource creation. Particle and enemy primitives use fewer polygons. Flat roads and particles avoid redundant shadow passes.
- Nearby directional shadows use two splits, a 1024 atlas and crisp filtering, replacing the expensive default 4096 atlas.
- Enemy obstacle and rooftop probes run at short intervals while movement still updates each physics tick. Idle damage receivers sleep until a status effect needs processing. HUD telemetry updates ten times per second.
- Endless waves cap simultaneous enemies at 40. Distant enemies retire to free the spawn budget, and explosion/spark bursts have bounded visual budgets.

## Measured performance

Two runs used the same timed flight route, seed, 24 active enemies, 1280 × 720 resolution, GL Compatibility renderer, and Intel Iris Xe GPU. Each run warmed for two seconds and measured the next six seconds with VSync disabled.

| Metric | Original 8 × 8 map | Optimized 16 × 16 map |
| --- | ---: | ---: |
| Average FPS | 71.7 | 183.0 |
| Average frame time | 13.94 ms | 5.46 ms |
| 95th percentile frame time | 19.28 ms | 8.43 ms |
| Average draw calls | 744 | 465 |
| Average rendered primitives | 341,032 | 61,986 |

The new outer-map flight test averaged 214.8 FPS with 23 surviving enemies. These are local uncapped benchmark results; actual performance depends on the encounter and display settings. JSON measurements are in `artifacts/performance_timed_baseline.json`, `artifacts/performance_timed_optimized.json`, and `artifacts/performance_timed_outer_map.json`.

## Reference-style menu

The user-provided title screen inspired the new dark pixel-art hangar, sculpted cream/cobalt title, teal riveted button stack, and pixel font. The backdrop is original artwork generated with the built-in ImageGen tool and saved as `assets/ui/pixel_hangar_menu.png`. The prompt is recorded in `artifacts/menu_art_prompt.txt`.

Deploy, Hangar, Academy, Settings, Manual, Exit and aircraft selection remain live Godot Controls. Overlays block accidental deployment, Escape closes them, and closing restores launch focus. A single image replaces the continuously rendered 3D preview.

## Validation

```powershell
python tools/run_godot_check.py tests/verify_polish.gd
python tools/run_godot_check.py tests/verify_expanded_world.gd
python artifacts/run_comparison.py timed_optimized
```

The rendered integration suite passed 287/287 checks. Expanded-world checks passed 23/23, including actual building damage and collapse, status effect wake/sleep behavior, corner access, remote spawns, enemy retirement and effect cleanup. Acceptance, boundary, enemy movement, spawn specification and combat-text suites also passed.

Screenshots: `artifacts/menu.png`, `artifacts/gameplay.png`, `artifacts/settings.png`, and `artifacts/expanded_map.png`. A pre-change source backup is saved at `.codex-backups/before-performance-map.zip`.
