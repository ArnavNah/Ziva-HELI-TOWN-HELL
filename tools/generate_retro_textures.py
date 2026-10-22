"""
generate_retro_textures.py
Generates the calibrated 64px/m retro-modern painted textures for Nuclear Strike.
Features:
- Deliberate square pixel clusters (Megabonk / retro robot art style)
- 3-5 broad light/dark value groups per material
- Matte surfaces, muted olive/parchment/slate palettes
- High-contrast gameplay elements vs low-contrast world ground
- 64 px/meter calibration:
    128x128 = 2m x 2m
    256x256 = 4m x 4m
"""

import os
import random
from PIL import Image, ImageDraw

OUTPUT_DIR = os.path.abspath("assets/environment/retro_textures")
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Fixed seed for perfectly reproducible, curated painted textures
random.seed(42)

def make_chunky_noise(w, h, cell_size, palette, weights=None):
    """Fills a grid with chunky square pixel clusters from a discrete palette."""
    img = Image.new("RGB", (w, h))
    pixels = img.load()
    cols = w // cell_size
    rows = h // cell_size
    
    grid = []
    for r in range(rows):
        row = []
        for c in range(cols):
            color = random.choices(palette, weights=weights)[0]
            row.append(color)
        grid.append(row)
        
    for y in range(h):
        for x in range(w):
            c = (x // cell_size) % cols
            r = (y // cell_size) % rows
            pixels[x, y] = grid[r][c]
    return img

def blend_colors(c1, c2, factor):
    """Linearly interpolates two RGB or RGBA tuples."""
    f = max(0.0, min(1.0, factor))
    return tuple(int(c1[i] + (c2[i] - c1[i]) * f) for i in range(len(c1)))

# -------------------------------------------------------------------------
# 1. BRICK WARM 128x128 (2m x 2m -> brick is ~25cm x ~8cm -> ~16x6 px)
# -------------------------------------------------------------------------
def generate_brick_warm():
    w, h = 128, 128
    img = Image.new("RGB", (w, h), (77, 48, 39)) # Mortar base (#4d3027)
    draw = ImageDraw.Draw(img)
    
    # Palette (4 major value groups)
    p_high = (184, 103, 76)   # #b8674c
    p_base = (142, 71, 50)    # #8e4732
    p_shade = (115, 55, 38)   # #733726
    p_mortar = (77, 48, 39)   # #4d3027
    
    row_height = 8 # 16 rows across 128px
    brick_width = 20 # ~6 bricks per row
    mortar_h = 2
    mortar_w = 2
    
    for r in range(16):
        y0 = r * row_height
        y1 = y0 + row_height - mortar_h
        x_offset = (r % 2) * (brick_width // 2)
        
        for c in range(-1, 8):
            x0 = c * brick_width + x_offset
            x1 = x0 + brick_width - mortar_w
            
            # Pick base value for this brick
            var = random.random()
            if var < 0.25:
                b_color = p_high
            elif var < 0.75:
                b_color = p_base
            else:
                b_color = p_shade
                
            # Draw individual brick with square pixel wear
            for bx in range(x0, x1):
                for by in range(y0, y1):
                    wx = bx % w
                    wy = by % h
                    # Subtle top highlight and bottom shadow on brick faces
                    col = b_color
                    if by == y0 and random.random() > 0.3:
                        col = p_high
                    elif by == y1 - 1 and random.random() > 0.4:
                        col = p_shade
                    # Occasional chip on brick corner
                    if (bx == x0 or bx == x1 - 1) and random.random() < 0.15:
                        col = p_mortar
                    img.putpixel((wx, wy), col)
                    
    img.save(os.path.join(OUTPUT_DIR, "brick_warm_128.png"))
    print("Saved brick_warm_128.png")

# -------------------------------------------------------------------------
# 2. PLASTER PALE 128x128 (2m x 2m)
# -------------------------------------------------------------------------
def generate_plaster_pale():
    w, h = 128, 128
    # 4 value groups: sunlit, base, shaded, rain stain
    c_sunlit = (222, 213, 194) # #ded5c2
    c_base = (207, 197, 176)   # #cfc5b0
    c_shade = (190, 175, 154)  # #beaf9a
    c_stain = (156, 141, 119)  # #9c8d77
    
    # Chunky 4x4 clusters
    base_img = make_chunky_noise(w, h, 4, [c_sunlit, c_base, c_shade, c_stain], [0.25, 0.50, 0.20, 0.05])
    
    # Add subtle macro painted wear bands (8x8 blocks)
    pixels = base_img.load()
    for by in range(0, h, 8):
        for bx in range(0, w, 8):
            if random.random() < 0.2:
                tint = c_sunlit if random.random() < 0.5 else c_shade
                for dy in range(8):
                    for dx in range(8):
                        if random.random() < 0.6:
                            pixels[(bx + dx) % w, (by + dy) % h] = tint
                            
    base_img.save(os.path.join(OUTPUT_DIR, "plaster_pale_128.png"))
    print("Saved plaster_pale_128.png")

# -------------------------------------------------------------------------
# 3. ASPHALT ROAD 256x256 (4m x 4m, 1 lane or 2-lane half)
# -------------------------------------------------------------------------
def generate_asphalt_road():
    w, h = 256, 256
    # Low-contrast dark slate palette so units pop
    c_base = (42, 46, 51)       # #2a2e33
    c_dark = (35, 39, 43)       # #23272b
    c_wear = (53, 58, 64)       # #353a40
    c_line = (195, 185, 150)    # Muted off-white road paint (#c3b996)
    c_line_wear = (130, 125, 105)
    
    img = make_chunky_noise(w, h, 4, [c_base, c_dark, c_wear], [0.6, 0.25, 0.15])
    pixels = img.load()
    
    # Center dashed stripe (Y-axis lane line, 8px wide, dashed 32px on, 32px off)
    line_center = w // 2
    line_w = 4 # half width = 8px total (~12.5 cm)
    for y in range(h):
        # Dashes every 64 pixels (36 on, 28 off)
        if (y % 64) < 38:
            for x in range(line_center - line_w, line_center + line_w):
                # Painted edge wear
                edge_dist = abs(x - line_center)
                if edge_dist == line_w - 1 and random.random() < 0.4:
                    pixels[x, y] = c_line_wear
                elif random.random() < 0.08:
                    pixels[x, y] = c_line_wear
                else:
                    pixels[x, y] = c_line
                    
    # Dark tire wear tracks on left and right of center line
    for track_center in [line_center - 60, line_center + 60]:
        for y in range(h):
            for dx in range(-16, 16):
                x = track_center + dx
                if 0 <= x < w:
                    if random.random() < 0.45:
                        pixels[x, y] = c_dark
                        
    img.save(os.path.join(OUTPUT_DIR, "asphalt_road_256.png"))
    print("Saved asphalt_road_256.png")

# -------------------------------------------------------------------------
# 4. PAVEMENT SIDEWALK 128x128 (2m x 2m -> two 1m x 1m slabs)
# -------------------------------------------------------------------------
def generate_pavement_sidewalk():
    w, h = 128, 128
    c_high = (157, 155, 147)    # #9d9b93
    c_base = (139, 137, 129)    # #8b8981
    c_shade = (122, 120, 112)   # #7a7870
    c_groove = (82, 80, 74)     # #52504a
    
    img = make_chunky_noise(w, h, 4, [c_high, c_base, c_shade], [0.2, 0.6, 0.2])
    pixels = img.load()
    
    # 2x2 grid of slabs (each 64x64)
    for slab_x in [0, 64]:
        for slab_y in [0, 64]:
            # Groove borders (outer 2px)
            for i in range(64):
                # Top edge highlight
                if slab_y + 1 < h:
                    pixels[(slab_x + i) % w, slab_y + 1] = c_high
                # Left edge highlight
                if slab_x + 1 < w:
                    pixels[slab_x + 1, (slab_y + i) % h] = c_high
                # Bottom edge shadow
                pixels[(slab_x + i) % w, (slab_y + 62) % h] = c_shade
                # Right edge shadow
                pixels[(slab_x + 62) % w, (slab_y + i) % h] = c_shade
                
                # Deep joint groove
                pixels[(slab_x + i) % w, (slab_y + 63) % h] = c_groove
                pixels[(slab_x + 63) % w, (slab_y + i) % h] = c_groove
                
    img.save(os.path.join(OUTPUT_DIR, "pavement_sidewalk_128.png"))
    print("Saved pavement_sidewalk_128.png")

# -------------------------------------------------------------------------
# 5. GRASS OLIVE 128x128 (2m x 2m)
# -------------------------------------------------------------------------
def generate_grass_olive():
    w, h = 128, 128
    # Muted military olive palette (Megabonk terrain style)
    c_bright = (109, 143, 80)   # #6d8f50
    c_mid = (91, 124, 66)       # #5b7c42
    c_base = (74, 104, 54)      # #4a6836
    c_deep = (53, 78, 36)       # #354e24
    
    # 4x4 chunky pixel clusters
    img = make_chunky_noise(w, h, 4, [c_bright, c_mid, c_base, c_deep], [0.2, 0.45, 0.25, 0.1])
    pixels = img.load()
    
    # Add scattered clumps of tufts (2x2 brighter or deeper)
    for _ in range(35):
        cx = random.randrange(0, w, 4)
        cy = random.randrange(0, h, 4)
        t_col = c_bright if random.random() < 0.6 else c_deep
        for dy in range(4):
            for dx in range(4):
                if random.random() < 0.7:
                    pixels[(cx + dx) % w, (cy + dy) % h] = t_col
                    
    img.save(os.path.join(OUTPUT_DIR, "grass_olive_128.png"))
    print("Saved grass_olive_128.png")

# -------------------------------------------------------------------------
# 6. SOIL RICH 128x128 (2m x 2m)
# -------------------------------------------------------------------------
def generate_soil_rich():
    w, h = 128, 128
    c_high = (93, 74, 52)       # #5d4a34
    c_base = (72, 56, 39)       # #483827
    c_shade = (52, 40, 28)      # #34281c
    c_deep = (43, 32, 20)       # #2b2014
    
    img = make_chunky_noise(w, h, 4, [c_high, c_base, c_shade, c_deep], [0.2, 0.45, 0.25, 0.1])
    img.save(os.path.join(OUTPUT_DIR, "soil_rich_128.png"))
    print("Saved soil_rich_128.png")

# -------------------------------------------------------------------------
# 7. GRASS SOIL BLEND 256x256 (4m x 4m)
# -------------------------------------------------------------------------
def generate_grass_soil_blend():
    w, h = 256, 256
    # Generates a smooth organic patch transitioning from olive grass to rich soil
    c_grass_mid = (91, 124, 66)
    c_grass_base = (74, 104, 54)
    c_soil_base = (72, 56, 39)
    c_soil_shade = (52, 40, 28)
    
    img = Image.new("RGB", (w, h))
    pixels = img.load()
    
    for y in range(0, h, 4):
        for x in range(0, w, 4):
            # Center radial patch of soil with noise
            dist = (((x - 128)**2 + (y - 128)**2)**0.5) / 128.0
            noise = (random.random() - 0.5) * 0.4
            factor = max(0.0, min(1.0, dist + noise))
            
            # factor = 0 is center (soil), factor = 1 is outer (grass)
            if factor < 0.4:
                col = c_soil_shade if random.random() < 0.3 else c_soil_base
            elif factor < 0.7:
                col = c_soil_base if random.random() < 0.5 else c_grass_base
            else:
                col = c_grass_mid if random.random() < 0.4 else c_grass_base
                
            for dy in range(4):
                for dx in range(4):
                    pixels[(x + dx) % w, (y + dy) % h] = col
                    
    img.save(os.path.join(OUTPUT_DIR, "grass_soil_blend_256.png"))
    print("Saved grass_soil_blend_256.png")

# -------------------------------------------------------------------------
# 8. CRATE WOOD 128x128 (Supply crate face with stenciled bracket corners)
# -------------------------------------------------------------------------
def generate_crate_wood():
    w, h = 128, 128
    c_wood_high = (160, 116, 73) # #a07449
    c_wood_base = (135, 95, 58)  # #875f3a
    c_wood_shade = (110, 76, 44) # #6e4c2c
    c_steel_high = (95, 105, 118)
    c_steel_base = (60, 66, 74)  # #3c424a
    c_steel_dark = (35, 38, 43)
    c_stencil = (210, 185, 120)  # Military marking
    
    img = make_chunky_noise(w, h, 4, [c_wood_high, c_wood_base, c_wood_shade], [0.25, 0.55, 0.20])
    pixels = img.load()
    
    # Horizontal wood plank lines (4 planks, each 32px high)
    for y in [32, 64, 96]:
        for x in range(w):
            pixels[x, y - 1] = c_wood_shade
            pixels[x, y] = (70, 48, 28) # deep plank seam
            if y + 1 < h:
                pixels[x, y + 1] = c_wood_high
                
    # Reinforced steel frame around outer perimeter (12px wide)
    frame_w = 12
    for y in range(h):
        for x in range(w):
            is_frame = (x < frame_w or x >= w - frame_w or y < frame_w or y >= h - frame_w)
            # Diagonal braces across center
            diag1 = abs(x - y) < 8
            diag2 = abs((w - 1 - x) - y) < 8
            
            if is_frame or diag1 or diag2:
                # Steel shading
                if x == frame_w - 1 or y == frame_w - 1 or x == w - frame_w or y == h - frame_w:
                    pixels[x, y] = c_steel_dark
                elif x == 0 or y == 0:
                    pixels[x, y] = c_steel_high
                else:
                    pixels[x, y] = c_steel_base if random.random() < 0.75 else c_steel_high
                    
    # Heavy corner brackets (24x24 in each corner)
    for cy in [0, h - 24]:
        for cx in [0, w - 24]:
            for dy in range(24):
                for dx in range(24):
                    if dx < 20 and dy < 20:
                        pixels[cx + dx, cy + dy] = c_steel_base
            # Bolt / rivet in corner
            pixels[cx + 10, cy + 10] = c_steel_high
            pixels[cx + 11, cy + 10] = c_steel_high
            pixels[cx + 10, cy + 11] = c_steel_dark
            pixels[cx + 11, cy + 11] = c_steel_dark
            
    # Stenciled ammo symbol / star in center
    for y in range(54, 74):
        for x in range(54, 74):
            if 60 <= x <= 67 and 56 <= y <= 71:
                pixels[x, y] = c_stencil
            if 56 <= x <= 71 and 62 <= y <= 65:
                pixels[x, y] = c_stencil
                
    img.save(os.path.join(OUTPUT_DIR, "crate_wood_128.png"))
    print("Saved crate_wood_128.png")

# -------------------------------------------------------------------------
# 9. BARREL METAL 128x128 (Olive drab drum with hazard stripe)
# -------------------------------------------------------------------------
def generate_barrel_metal():
    w, h = 128, 128
    c_metal_high = (88, 105, 80)
    c_metal_base = (59, 72, 54)  # #3b4836
    c_metal_shade = (44, 54, 41) # #2c3629
    c_hazard_yellow = (210, 175, 45) # #d2af2d
    c_hazard_black = (30, 32, 28)
    
    img = make_chunky_noise(w, h, 4, [c_metal_high, c_metal_base, c_metal_shade], [0.2, 0.6, 0.2])
    pixels = img.load()
    
    # Metal ribs / ridges (horizontal bands at y=20..28 and y=100..108)
    for rib_y in [20, 100]:
        for dy in range(8):
            for x in range(w):
                if dy < 2:
                    pixels[x, rib_y + dy] = c_metal_high
                elif dy > 5:
                    pixels[x, rib_y + dy] = c_metal_shade
                else:
                    pixels[x, rib_y + dy] = c_metal_base
                    
    # Hazard stripe band across middle (y=52..76)
    for y in range(52, 76):
        for x in range(w):
            # Diagonal hazard chevrons
            if ((x + y) // 8) % 2 == 0:
                pixels[x, y] = c_hazard_yellow
            else:
                pixels[x, y] = c_hazard_black
                
    img.save(os.path.join(OUTPUT_DIR, "barrel_metal_128.png"))
    print("Saved barrel_metal_128.png")

# -------------------------------------------------------------------------
# 10. DEBRIS FRACTURE 128x128 (Interior cracked concrete/brick core)
# -------------------------------------------------------------------------
def generate_debris_fracture():
    w, h = 128, 128
    c_plaster = (209, 198, 179) # #d1c6b3
    c_brick = (143, 106, 85)   # #8f6a55
    c_mortar = (105, 86, 72)   # #695648
    c_shadow = (74, 53, 40)    # #4a3528
    
    # Chunky 4x4 clusters of broken rubble
    img = make_chunky_noise(w, h, 4, [c_plaster, c_brick, c_mortar, c_shadow], [0.25, 0.35, 0.25, 0.15])
    pixels = img.load()
    
    # Add deep jagged crack lines across fracture face
    for crack_start in [(10, 0), (60, 0), (100, 0)]:
        cx, cy = crack_start
        while cy < h:
            for dx in range(-1, 2):
                if 0 <= cx + dx < w:
                    pixels[cx + dx, cy] = c_shadow
            cx = (cx + random.choice([-2, -1, 0, 1, 2])) % w
            cy += 1
            
    img.save(os.path.join(OUTPUT_DIR, "debris_fracture_128.png"))
    print("Saved debris_fracture_128.png")

# -------------------------------------------------------------------------
# 11. TREE BARK 128x128 (Stylized vertical bark furrow)
# -------------------------------------------------------------------------
def generate_tree_bark():
    w, h = 128, 128
    c_high = (103, 87, 71)      # #675747
    c_base = (81, 67, 54)       # #514336
    c_shade = (61, 49, 38)      # #3d3126
    c_crevice = (46, 36, 28)    # #2e241c
    
    img = Image.new("RGB", (w, h), c_base)
    pixels = img.load()
    
    # Vertical vertical furrows (every 8-12 pixels)
    cols = []
    x = 0
    while x < w:
        cols.append(x)
        x += random.randint(8, 14)
        
    for cx in cols:
        for y in range(h):
            # Furrow wobbles slightly
            drift = int((((y * 7) % 19) / 19.0 - 0.5) * 3)
            fx = (cx + drift) % w
            pixels[fx, y] = c_crevice
            pixels[(fx + 1) % w, y] = c_shade
            pixels[(fx - 1) % w, y] = c_high if random.random() < 0.6 else c_base
            
    # Fill remaining background with chunky bark texture
    for y in range(0, h, 4):
        for x in range(0, w, 4):
            if pixels[x, y] == c_base:
                col = random.choices([c_high, c_base, c_shade], [0.25, 0.55, 0.20])[0]
                for dy in range(4):
                    for dx in range(4):
                        if pixels[(x + dx) % w, (y + dy) % h] != c_crevice:
                            pixels[(x + dx) % w, (y + dy) % h] = col
                            
    img.save(os.path.join(OUTPUT_DIR, "tree_bark_128.png"))
    print("Saved tree_bark_128.png")

# -------------------------------------------------------------------------
# 12. TREE FOLIAGE 128x128 RGBA (Alpha-cutout leaf cluster card)
# -------------------------------------------------------------------------
def generate_tree_foliage():
    w, h = 128, 128
    # RGBA image with 0.5 alpha scissor compatibility (clean 0 or 255 alpha)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    pixels = img.load()
    
    c_high = (94, 131, 68, 255)  # #5e8344
    c_base = (74, 105, 54, 255)  # #4a6936
    c_shade = (57, 82, 41, 255)  # #395229
    c_deep = (46, 67, 31, 255)   # #2e431f
    
    # Generate 3 overlapping organic lobes forming a full canopy foliage card
    lobes = [
        (64, 60, 48),  # Main center lobe
        (42, 70, 36),  # Left lower lobe
        (86, 70, 36),  # Right lower lobe
        (64, 40, 34),  # Top crown lobe
    ]
    
    for y in range(0, h, 4):
        for x in range(0, w, 4):
            # Check if point is inside any lobe
            inside = False
            min_dist_norm = 1.0
            for lx, ly, lr in lobes:
                dist = ((x - lx)**2 + (y - ly)**2)**0.5
                # Add jagged retro pixel irregularity
                dist += (random.random() - 0.5) * 8.0
                if dist < lr:
                    inside = True
                    norm = dist / lr
                    if norm < min_dist_norm:
                        min_dist_norm = norm
                        
            if inside:
                # Shade based on vertical position (sunlit top, shaded bottom)
                v_factor = y / float(h)
                if v_factor < 0.35:
                    col = c_high if random.random() < 0.7 else c_base
                elif v_factor < 0.65:
                    col = c_base if random.random() < 0.6 else c_shade
                else:
                    col = c_shade if random.random() < 0.5 else c_deep
                    
                for dy in range(4):
                    for dx in range(4):
                        if 0 <= x + dx < w and 0 <= y + dy < h:
                            pixels[x + dx, y + dy] = col
                            
    img.save(os.path.join(OUTPUT_DIR, "tree_foliage_128.png"))
    print("Saved tree_foliage_128.png")

# -------------------------------------------------------------------------
# 13. BUILDING WINDOW 128x128 (Window module with frame, sill, and retro glass)
# -------------------------------------------------------------------------
def generate_building_window():
    w, h = 128, 128
    c_frame = (190, 175, 154)   # Pale plaster frame (#beaf9a)
    c_sill = (156, 141, 119)    # Dark stone sill
    c_mullion = (55, 60, 68)    # Metal window divider
    c_glass_base = (30, 38, 48) # Dark interior reflection
    c_glass_glint = (78, 105, 135) # Retro stylized sky reflection
    
    img = Image.new("RGB", (w, h), c_frame)
    pixels = img.load()
    
    # Outer frame padding: 16px border
    border = 16
    for y in range(border, h - border):
        for x in range(border, w - border):
            # 4 window panes divided by mullions (center cross 4px wide)
            is_mullion_x = abs(x - 64) < 3
            is_mullion_y = abs(y - 64) < 3
            
            if is_mullion_x or is_mullion_y:
                pixels[x, y] = c_mullion
            else:
                # Diagonal stylized reflection stripe
                diag = (x + y)
                if 80 <= diag <= 100 or 140 <= diag <= 160:
                    pixels[x, y] = c_glass_glint if random.random() < 0.85 else c_glass_base
                else:
                    pixels[x, y] = c_glass_base
                    
    # Heavy stone sill on bottom
    for y in range(h - border, h - 8):
        for x in range(border - 4, w - border + 4):
            pixels[x, y] = c_sill
            
    img.save(os.path.join(OUTPUT_DIR, "building_window_128.png"))
    print("Saved building_window_128.png")

if __name__ == "__main__":
    generate_brick_warm()
    generate_plaster_pale()
    generate_asphalt_road()
    generate_pavement_sidewalk()
    generate_grass_olive()
    generate_soil_rich()
    generate_grass_soil_blend()
    generate_crate_wood()
    generate_barrel_metal()
    generate_debris_fracture()
    generate_tree_bark()
    generate_tree_foliage()
    generate_building_window()
    print("All 13 retro modern textures successfully generated!")
