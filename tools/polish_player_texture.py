"""
Remaster and polish the Apache helicopter texture.
Eliminates AI artifacts, blotches, and fake scribbles, creating a clean,
AAA-quality military gunship finish with crisp canopy glass, clean panel
shading, carbon rotor blades with safety tips, and refined mechanical trim.
"""
import numpy as np
from PIL import Image, ImageFilter

def polish_textures():
    base_path = "assets/player/player_apache_basecolor.png"
    im = Image.open(base_path).convert("RGB")
    w, h = im.size
    print(f"Loading texture: {w}x{h}")
    arr = np.array(im, dtype=np.float32)

    # 1. Identify active UV islands (non-black pixels)
    # Background in the texture is pure or near black (sum < 10)
    lum = np.mean(arr, axis=2)
    island_mask = lum > 8.0

    # 2. Extract chromaticity & base lightness
    # Separate the noisy AI color variations from the structural shading
    r = arr[:, :, 0]
    g = arr[:, :, 1]
    b = arr[:, :, 2]

    # Target tactical palette:
    # Body Armor: Clean Military Dark Olive Drab (CARC)
    # Target R: ~54, G: ~66, B: ~52 (rich military green, clean and unified)
    target_body_r = 56.0
    target_body_g = 68.0
    target_body_b = 54.0

    # Detect body panels: olive/greenish/yellowish pixels (where G is highest or R/G are dominant)
    # In the raw texture, body pixels have R in [45, 120], G in [50, 130], B in [40, 110]
    is_greenish = (g >= b) & (g >= r * 0.85) & (lum > 25.0) & island_mask
    
    # Structural shading (normalized lightness)
    # Smooth the structural shading with bilateral/box filter to kill AI pixel noise while keeping panel edges
    lum_img = Image.fromarray(lum.astype(np.uint8))
    # Slight blur to kill high-frequency AI dithering/smudges
    lum_smooth = np.array(lum_img.filter(ImageFilter.MedianFilter(size=5)), dtype=np.float32)

    # Relative luminance factor centered around median body luminance (~78)
    shading_factor = np.clip(lum_smooth / 78.0, 0.45, 1.45)

    # Reconstruct clean body panels
    new_r = r.copy()
    new_g = g.copy()
    new_b = b.copy()

    # Apply unified military armor coating to body panels
    new_r[is_greenish] = target_body_r * shading_factor[is_greenish]
    new_g[is_greenish] = target_body_g * shading_factor[is_greenish]
    new_b[is_greenish] = target_body_b * shading_factor[is_greenish]

    # 3. Clean up the Cockpit Canopy Glass:
    # Cockpit UVs are located in the lower-left fuselage shells:
    # Left shell cockpit: x in [80, 520], y in [2048, 2900]
    # Right shell cockpit: x in [560, 950], y in [3100, 3950]
    # Windows in these regions have dark gray/black/cloudy pixels surrounded by frame borders
    for (x0, y0, x1, y1) in [(80, 2048, 520, 2900), (560, 3100, 950, 3950)]:
        sub_mask = np.zeros_like(island_mask)
        sub_mask[y0:y1, x0:x1] = island_mask[y0:y1, x0:x1]
        # Canopy glass panes have lower lightness or specific glass outline
        # In the crop we saw: glass interior pixels have lum in [20, 95] and (abs(r - g) < 15) and (abs(g - b) < 15) (neutral gray)
        is_glass_candidate = sub_mask & (lum > 18.0) & (lum < 95.0) & (abs(r - g) < 20) & (abs(g - b) < 20)
        # Give glass a sleek, deep polarized dark blue-tinted cockpit finish (R: 20, G: 28, B: 36)
        new_r[is_glass_candidate] = 22.0
        new_g[is_glass_candidate] = 30.0
        new_b[is_glass_candidate] = 40.0

    # 4. Clean up the weird AI dial scribbles on top fuselage:
    # Region x in [940, 1150], y in [2800, 3700] has messy scribble lines on the spine
    spine_mask = np.zeros_like(island_mask)
    spine_mask[2800:3700, 940:1150] = island_mask[2800:3700, 940:1150]
    is_scribble = spine_mask & is_greenish
    # Smooth spine to clean military olive
    new_r[is_scribble] = target_body_r * np.clip(lum_smooth[is_scribble] / 80.0, 0.7, 1.2)
    new_g[is_scribble] = target_body_g * np.clip(lum_smooth[is_scribble] / 80.0, 0.7, 1.2)
    new_b[is_scribble] = target_body_b * np.clip(lum_smooth[is_scribble] / 80.0, 0.7, 1.2)

    # 5. Rotor Blades Polish:
    # Rotor blades are the long dark vertical strips in x in [2450, 2850], y in [1300, 3400]
    rotor_mask = np.zeros_like(island_mask)
    rotor_mask[1300:3400, 2450:2850] = island_mask[1300:3400, 2450:2850]
    is_blade = rotor_mask & (lum > 15.0)
    # Sleek matte carbon graphite finish
    new_r[is_blade] = 26.0 * np.clip(lum_smooth[is_blade] / 60.0, 0.8, 1.3)
    new_g[is_blade] = 28.0 * np.clip(lum_smooth[is_blade] / 60.0, 0.8, 1.3)
    new_b[is_blade] = 30.0 * np.clip(lum_smooth[is_blade] / 60.0, 0.8, 1.3)

    # Add crisp military hazard warning stripes at blade tips:
    # Blade tips are at y in [1300, 1420] on the rotor strips
    blade_tips = np.zeros_like(island_mask)
    blade_tips[1300:1440, 2450:2850] = island_mask[1300:1440, 2450:2850]
    new_r[blade_tips] = 235.0 # Bright hazard yellow
    new_g[blade_tips] = 190.0
    new_b[blade_tips] = 32.0

    # 6. Clip, preserve black background, and assemble
    out_arr = np.stack([new_r, new_g, new_b], axis=2)
    out_arr = np.clip(out_arr, 0.0, 255.0).astype(np.uint8)
    out_arr[~island_mask] = 0

    out_img = Image.fromarray(out_arr)
    out_img.save(base_path)
    print(f"Saved polished basecolor texture to: {base_path}")

    # Generate thumbnail for inspection
    out_thumb = out_img.copy()
    out_thumb.thumbnail((512, 512))
    thumb_path = "C:/Users/Prime 3/.gemini/antigravity/brain/7fe842b3-2e28-4d17-b446-0deca635b154/polished_basecolor_thumb.png"
    out_thumb.save(thumb_path)
    print(f"Saved thumbnail to: {thumb_path}")

    # 7. Also smooth the normal map to eliminate the crumpled tin-foil AI noise
    norm_path = "assets/player/player_apache_normal.png"
    norm_im = Image.open(norm_path).convert("RGB")
    # A subtle 3x3 median filter on the normal map removes chaotic AI grain while keeping bevel seams
    norm_clean = norm_im.filter(ImageFilter.MedianFilter(size=3))
    norm_clean.save(norm_path)
    print(f"Saved smoothed normal map to: {norm_path}")

if __name__ == "__main__":
    polish_textures()
