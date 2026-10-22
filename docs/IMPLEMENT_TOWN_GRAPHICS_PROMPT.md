# Implementation prompt — current game checked 17 October 2026

Copy everything below into the coding AI working in this project.

---

Implement the next environment-art pass for ZIVA HELI TOWN HELLL in the existing
Godot project at `C:/Users/Prime 3/Documents/ziva-heli-town-helll`.

The goal is a town with chunky low-poly shapes and deliberate painted pixel
textures inspired by the supplied Megabonk reference, combined with the military
town setting and helicopter-camera readability I associate with Nuclear Strike.
Use the supplied robot image for coarse surface pixels and worn materials.
Use original assets and a consistent visual style throughout the town.

Read `GRAPHICS_ART_DIRECTION.md`, `docs/town-art-direction.html` and
`docs/CURRENT_GRAPHICS_STAGE_2026-10-17.md`. Recheck current files before editing;
the older parts of the HTML describe the state on 15 October and some work is
already implemented. Inspect the actual game, implement the changes, run it and
show the result. Do not stop after writing a plan.

CURRENT STARTING POINT

- Godot 4.7.1, GL Compatibility, 1280×720, configured 60 fps cap. Current shadow
  atlas is 1024. Keep this renderer and existing gameplay dimensions initially.
- The active main game has a 16×16 lot layout with 38 m spacing. The audit found
  142 buildings across ten archetypes. Town generation, foliage sectors, roads,
  helicopters, enemies, HUD and building destruction already exist.
- Texture sampling, UV generation and material caching already exist in
  `src/shaders/field_surface.gdshader`, `src/world/detail_mesh.gd` and
  `src/world/stylized_materials.gd`. Extend them rather than starting again.
- Nine environment texture files already exist under `assets/environment/textures`.
  Eight are 128×128; the helipad is 256×256. They are a starter kit to evaluate.
- `autoload/shader_manager.gd` already provides outlines and retro controls.
  Pixelation, dithering and vertex snapping are off by default; outlines are on.

1. ESTABLISH A CLEAN BASELINE

The latest standalone rendered check hit missing generated `.s3tc.ctex` imports
for `assets/player/player_apache_basecolor.png`, its normal map and ORM map.
This prevented `assets/player/player.glb` from loading correctly in that run.
The source files exist. Check/rebuild the affected imports and confirm that the
helicopter appears before judging the visuals. Do not replace or overwrite the
original aircraft textures as a workaround. Record any remaining startup errors.
Capture a valid before screenshot and performance baseline with the existing
camera. Do not interpret the hidden-window audit's FPS display as a benchmark.

2. FIX TEXTURE MAPPING AND MATERIAL ASSIGNMENT FIRST

Buildings currently merge their roof, wall, windows and details into one surface
using one facade texture. The audit house has bricks on its roof and trim.
Give wall, roof, glass, trim and exposed interior faces appropriate materials.
Prefer a small shared atlas/material arrangement that preserves batching. Use
extra surfaces only where justified by the result and measured rendering cost.

Define texture size in world units once. `DetailMesh.TEX_SCALE` is currently 0.25,
and facade materials multiply UVs by another 0.25. With a 128-pixel tile, box faces
therefore get approximately 8 texels/m, while terrain gets 32 texels/m. Roads use
long BoxMesh strips with fixed UV scaling, so their texture scale also needs review.
Fix these inconsistencies. Start near 16 texels/m on town surfaces and adjust from
the actual camera. Walls and roofs of different sizes should keep similar visible
pixel sizes. Avoid stretching an entire texture over a very long road strip.

All nine environment texture import files currently disable mipmap generation,
while their shaders request nearest sampling with mipmaps. Enable mipmaps for the
relevant world textures, reimport and check distant roofs and roads in motion.

3. MAKE ONE SMALL AREA MATCH THE REFERENCES

Create an art-review scene or reproducible route containing one brick house,
shop, warehouse, road junction, grass verge, broadleaf tree, pine, crate, fuel
barrel and parked vehicle. Use the existing flight camera: 35 m trailing distance,
33.5 m base height and 50° base FOV, with its current motion behavior preserved.

Use broad roof shapes, thick eaves, grouped windows, chunky tree crowns and
restrained material wear. Prefer earthy brick, sandy plaster, slate roofs and
olive foliage. Give textures connected color patches and readable material detail;
avoid fine random noise and blurry gradients. Keep grass and road contrast quieter
than enemies, hazards and loot. Reserve stronger accent colors for interactive
objects. Give foliage and props coherent surface detail as well as buildings.
Opaque faceted foliage is suitable; preserve the existing sector batching.

Reuse good existing assets. Improve weak texture art at its real working resolution
and supply actual texture files and editable sources/generation instructions.
Concept pictures alone do not complete this task. Approve the result against the
references and actual camera, then apply the working rules to all building
archetypes, roads, foliage, props and rubble in the generated town.

4. KEEP THE SAME STYLE THROUGH DESTRUCTION

The damaged state currently replaces the textured building with an untextured
StandardMaterial3D; the collapsed state becomes a roof-textured BoxMesh.
Replace this with matching damage artwork and visible missing/broken sections.
Keep original wall and roof materials identifiable, add textured exposed interiors,
and use chunky rubble from the same material family.

Preserve health thresholds, damage events, targeting and navigation behavior.
Preserve the existing 3.5 m collapsed collision height/flight clearance unless a
deliberate gameplay change is justified. Keep physical debris bounded and use
simple collisions. Individual damage must not mutate shared materials on unrelated
buildings. If surface organization changes, update affected assertions such as
`tests/verify_expanded_world.gd` without weakening behavior or performance checks.

5. KEEP THE PRESENTATION CLEAR

Keep matte surfaces and restrained lighting. Retune texture tinting, scene light
and the existing `battlefield_grade.gdshader` together. Check its chromatic
aberration and vignette against pixel clarity; reduce distracting color fringes.
Do not add another grading layer. Check day, storm and night, with a sharp HUD.

Audit existing retro controls rather than duplicating them. F7/F10 currently
iterate `_tracked_toon_materials`, but the audit found no registrations. Make
supported toggles actually affect the intended visible materials, or accurately
remove/label unsupported controls. Preserve textures and per-surface materials
when attaching outlines; a whole-mesh material override must not erase them.
Keep strong wobble, dithering and affine distortion off in the main visual style.

The current “360p/240p” effect resamples an already rendered screen; it does not
render the 3D world at lower resolution or save that rendering work. Label it
accurately. A true low-resolution SubViewport mode is optional and secondary to
finishing the town assets; if implemented, keep the HUD outside it and test all
screen-reading passes together.

6. VERIFY AND DELIVER

Run focused existing startup, world/destruction, shader, flight/camera and
performance checks as relevant. Verify visual effects on rendered output, not
just boolean flags. Fly and turn through textured streets, then trigger damage
and collapse. Use identical seed, route, camera, resolution and encounter settings
for before/after comparisons. Benchmark a representative enemy/destruction load
on the same hardware; preserve foliage culling and shared material reuse.

Deliver the working Godot scenes, meshes/textures/materials, before/after gameplay
screenshots and a short plain-language explanation of changes, checks and remaining
issues. Show a building intact, damaged and collapsed; show the town from normal
flight distance and in different weather. Update the graphics notes to reflect the
implementation. Ask only for genuinely missing information; make ordinary reversible
implementation decisions and complete the pass.
