# Town graphics direction — updated 19 October 2026

The user explicitly prefers the supplied Megabonk reference and wants its chunky,
painted pixel texture character across the town's buildings, ground, trees and
destructible objects, combined with the Nuclear Strike identity of this helicopter
game. The supplied robot reference is a secondary reference for coarse surface
pixels and worn materials. Preserve this preference in future graphics work.

The complete visual explanation, reusable image prompts, sources, proposed asset
budgets and implementation sequence are in [the standalone HTML guide](docs/town-art-direction.html).

Working art rules, now implemented in the playable reference street:

- Chunky readable low-poly silhouettes; authored pixel albedo with deliberate color
  clusters; restrained military-town palette; roofs prioritized for the flight camera.
- Start environment density near 16 texels/m and selected hero assets near 32.
  These are recommendations, not user-approved fixed budgets or Megabonk measurements.
- Nearest with mipmaps for 3D textures. Keep stable perspective and disable strong
  PSX wobble/affine distortion by default. Optional retro effects come after asset approval.
- Blender/source modeling and pixel-editor cleanup feed GLB/PNG into Godot;
  image generation supplies concepts/material candidates, not production-ready meshes.
- Keep one style across intact, damaged and collapsed states, including interiors and rubble.
- Approve a house/road/grass/tree/prop/destruction slice under the existing gameplay camera
  before migrating the whole town. Save it as the reference for subsequent generations.

Implementation reviewed 19 October 2026: the town now has original painted
128-pixel tiles, editable SVG sources, a shared padded atlas, distinct wall/roof/
glass/trim/interior assignments, a common nominal 16 texels/m scale, and generated
mipmaps. Damage and collapse retain their material family. A playable reference
street uses the production flight camera; all ten archetypes use the material rules.
Foliage stays sector-batched. Optional retro controls are checked on rendered output.

The renderer, map dimensions and camera settings were preserved. Apache source
textures were retained and their generated imports rebuilt. The existing grading
pass was retuned, with no default chromatic fringes, wobble or dithering.

See [the visual results](docs/town-art-results.html) and
[the implementation/verification report](docs/CURRENT_GRAPHICS_STAGE_2026-10-17.md).
Final checks use matched snapshots because another task was editing gameplay and
menus concurrently. The report records older gameplay-test failures, menu import
diagnostics and variable performance readings; it does not certify stable 60 FPS.
The HTML's older audit and planning sections are retained as historical context.

Communication preference: the user asked for an easier explanation. The HTML now
opens with a plain-language guide (shape, skin and lighting), five first steps and
three short prompts. The complete technical guide remains in an optional expandable
section. Use this simpler explanation style for future graphics discussions.
