# Town environment art — reviewed 19 October 2026

The environment pass is implemented. [Open the before/after review](town-art-results.html) for normal flight views, destruction, the playable reference street and different weather.

This replaces the earlier audit and its later unverified 60 FPS claims. Another task was editing gameplay and menus during validation. Final environment checks use saved before/after projects with identical shared gameplay, HUD, player, camera, resolution and benchmark files. Matching hashes are in `artifacts/town-art-pass-20261017/validation_snapshot_manifest.json`.

## Implemented artwork and materials

- Added 16 original 128 × 128 painted pixel tiles, matching editable SVGs, and a shared 640 × 640 atlas with 16-pixel wrapped gutters. Connected patches replace fine noise and blurry starter textures on the active town surfaces. [Editing/export instructions](../assets/environment/painted/README.md) cover regeneration and repacking edited SVG sources.
- Extended the existing DetailMesh and material factory. UV2 material IDs separate walls, roofs, glass, trim, metal, interiors and timber while each building retains **one render surface**. Immutable materials remain shared and cached.
- Unified scale through `StylizedMaterials.TILE_METERS = 8.0`: a 128-pixel tile gives **16 authored texels/m**. Geometry applies the scale once. Long roads use world mapping; terrain, foliage and props use the same nominal span. The existing unique helipad retains its full image.
- Enabled/rebuilt mipmaps for all nine starter world PNGs and the new painted PNGs. Atlas sampling calculates derivatives before wrapping and caps the footprint at mip level 4, within its padding.
- Fixed reversed pitched-roof and cylinder faces. Houses have visible broad slate roofs and thick eaves; warehouses have pitched roofs. All ten generated archetypes use the painted categories.
- Added painted bark, clustered broadleaf crowns, tiered pines, stones, wooden crates, hazard-banded barrels and parked utility vehicles. Existing foliage sector batches and visibility ranges remain.
- Damage now creates a missing roof/wall corner with textured interiors, timber framing and restrained scorch artwork. Collapse leaves incomplete low walls and merged wall/interior/slate/timber fragments. No physical fragments accumulate. Collision remains **3.5 m** high; health thresholds, damage receivers and pre-collapse structural collision are preserved.
- Retuned daylight, ground colors and the existing single grading pass together. Chromatic aberration remains zero and the vignette is minimal. Storm/night keep readable silhouettes; the HUD remains outside world effects.
- F7/F10 now affect visible town/terrain materials. Outlines duplicate each surface's own material, preserving its texture and parameters. Weak outline references avoid retaining removed instances.
- F8 is correctly labeled **screen resampling**, with 2×/3× screen blocks. It still renders the world at native resolution. A back-buffer copy lets the existing grade read the preceding retro pass. Snapping and dithering stay off by default.

Godot 4.7.1 GL Compatibility, 1280 × 720, the normal 60 FPS cap and the 1024 shadow atlas are retained. The 16 × 16 lots, 38 m spacing and 142-building layout remain. Production camera values are still 35 m trailing distance, 33.5 m base height and 50° base FOV.

## Playable reference street

Run `scenes/world/town_art_review.tscn`. It includes a brick house, shop, warehouse, junction, verge, broadleaf tree, pine, crate, barrel and parked vehicle using production assets and the production flight camera.

Use normal flight controls. Keys 1/2 damage/collapse the house; R resets it; 3/4/5 select day/storm/night. F6–F10 compare existing retro options. The review toolbar is separate from the world effects.

## Startup and checks

Apache source PNGs and the GLB were retained. Reimporting regenerated missing compressed texture outputs; the aircraft appears in the before/after captures.

Results and logs are in `artifacts/town-art-pass-20261017/validated_checks.json` and `validated-*.log`:

| Check | Result | What it covers |
| --- | --- | --- |
| Town materials | 77/77 | Ten archetypes, reuse, damage isolation, outward faces, UV span, mipmaps, rubble bounds, per-surface outlines |
| Expanded world | 23/23 | Map bounds, combat damage/collapse, 3.5 m clearance, population/FX limits |
| Rendered art review | 10/10 | Visible F6–F10 effects, sharp toolbar glyphs, real damage/collapse, unchanged intact material |
| Rendered grading | 6/6 | Effective grade, unchanged HUD colors, night/storm changes, restored daylight |
| Existing retro suite | 6/6 | Material, outline and control integration |
| Existing flight/camera simulation | 4/4 | Existing controls/camera assertions |
| Rendered live gameplay | 4/4 | Actual flight, firing/ammo use, opening enemies, camera framing |
| Matched before/after route | Completed | Same seed, movement/turn, camera, resolution and weather captures |

Rendered main-game checks load without script, shader or aircraft-import errors in the validated snapshot. This is environment integration evidence, not certification of the separately changing menu/gameplay branch.

## Measured rendering cost

Two alternating pairs use identical saved gameplay sources, seed 811, route, resolution, renderer, 24 active enemies, four damaged buildings and four collapsed buildings. The benchmark removes the cap, runs eight seconds, and excludes the initial two seconds. Both frozen versions completed without runtime errors.

| Pair | Before mean FPS | After mean FPS |
| --- | --- | --- |
| 1 | 10.5 | 10.6 |
| 2 | 15.6 | 13.8 |

Mean draws across the two runs were approximately 514 before and 520 after; mean primitive counts were 339k before and 344k after. Building surface count remains one; foliage stays sector-batched. The pass preserves batching with a small increase in measured geometry and draws.

The machine was shared with concurrent work and timing varied substantially. These readings **do not establish stable 60 FPS or a reliable FPS regression percentage**. Earlier errored runs and HUD FPS screenshots are excluded. Raw results: `frozen_performance.json` and `artifacts/performance_town_art_frozen_*.json`.

## Remaining issues and limits

- Old `verify_strike_meadow.gd` expects enemy-specific fields such as `charge_timer` that the newer procedural raider no longer exposes. Legacy weapon checks fail and the test cannot finish. Its enemy assertions were not weakened in this art pass.
- `verify_flight_timing.gd` passes 18/19: quick return-to-hover conflicts with the existing inertial glide. The flight controller was preserved; separate flight/camera and rendered live checks pass.
- The preserved menu snapshot's editor import reports missing `_flash_insufficient_funds` in `hangar_menu.gd`. Another task owns the active menu/gameplay edits. Earlier editor imports also logged a Ziva extension library-copy warning; the game renderer did not require that editor extension.
- Recheck the combined live project after the other task saves its work. Repeat a quiet-machine benchmark before promising a frame-rate target.

Pre-pass sources/art are in `.codex-backups/town-art-20261017/`. Matching validation projects are in `artifacts/town-art-pass-20261017/performance_before` and `performance_after`. The artifact folder is ignored by Godot's import scanner to avoid scanning nested projects.

