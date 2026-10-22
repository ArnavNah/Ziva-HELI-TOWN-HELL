# Painted town kit

Original pixel artwork for the ZIVA town. Each material has a **128 × 128 PNG** and an editable **SVG** made from integer rectangles and connected polygons. The artwork uses a small palette and grouped patches instead of photographic noise. Source reference images remain reference only.

The 16 tiles are arranged in this order:

| Row | Column 1 | Column 2 | Column 3 | Column 4 |
| --- | --- | --- | --- | --- |
| 1 | Brick | Plaster | Slate roof | Glass |
| 2 | Trim/paint | Metal | Exposed interior | Wood |
| 3 | Leaf clusters | Bark | Stone | Asphalt |
| 4 | Grass | Paving | Industrial panels | Damage mask |

`town_atlas.png` is 640 × 640: 4 × 4 cells of 160 pixels, each containing its 128-pixel tile and 16 pixels of wrapped padding on all sides. The shader calculates derivatives before wrapping the tile UVs and caps the mip footprint at level 4 to keep neighboring materials out of the sampled region.

`StylizedMaterials.TILE_METERS` sets the repeating tile span to 8 m: **16 authored texels per meter**. `DetailMesh` applies this once to generated UVs. Roads and foliage use the same span through world mapping. The unique existing helipad keeps its full authored image.

To edit the art:

1. Edit a tile's SVG in a vector editor or as text. Keep its 128-pixel canvas, integer coordinates, solid fills, and rectangle/polygon shapes. Keep wrapped edges consistent.
2. Run `python tools/build_town_palette.py --from-svg` from the project folder. This exports the edited sources to PNG and repacks the atlas without replacing the SVG artwork. Python requires Pillow.
3. Reimport the changed PNGs in Godot. Their saved import presets enable mipmaps and lossless compression.
4. Run `scenes/world/town_art_review.tscn` and inspect the normal flight camera, roof, foliage, road, props, damage and weather.

Running `python tools/build_town_palette.py` **without** `--from-svg` recreates the original authored sources from the palette and shape instructions in that script, replacing manual tile edits. Save custom art before doing that.

All environment PNGs and the retained starter textures have mipmap generation enabled. Atlas and tile sampling use nearest with mipmaps. Matte response, no normal maps, no transparency on foliage, native resolution, and no default wobble or dithering form the main visual style.
