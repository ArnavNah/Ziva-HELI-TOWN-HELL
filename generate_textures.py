import math
import random
from PIL import Image, ImageDraw

random.seed(42)

def make_seamless_noise(width, height, scale, octaves=3):
    """Generate seamless 2D value noise on a torus."""
    grid = [[random.random() for _ in range(height)] for _ in range(width)]
    def sample(x, y):
        x = x % width
        y = y % height
        x0 = int(x)
        y0 = int(y)
        x1 = (x0 + 1) % width
        y1 = (y0 + 1) % height
        fx = x - x0
        fy = y - y0
        sx = fx * fx * (3 - 2 * fx)
        sy = fy * fy * (3 - 2 * fy)
        top = grid[x0][y0] * (1 - sx) + grid[x1][y0] * sx
        bot = grid[x0][y1] * (1 - sx) + grid[x1][y1] * sx
        return top * (1 - sy) + bot * sy

    out = [[0.0 for _ in range(height)] for _ in range(width)]
    for x in range(width):
        for y in range(height):
            val = 0.0
            amp = 1.0
            freq = scale
            total_amp = 0.0
            for _ in range(octaves):
                val += sample(x * freq, y * freq) * amp
                total_amp += amp
                amp *= 0.5
                freq *= 2.0
            out[x][y] = val / total_amp
    return out

# 1. TILE GRASS OLIVE (128x128) - Quiet, earthy, military olive turf (#52663D)
def gen_tile_grass():
    w, h = 128, 128
    img = Image.new("RGBA", (w, h))
    noise_macro = make_seamless_noise(w, h, 0.06, 3)
    noise_micro = make_seamless_noise(w, h, 0.16, 2)

    c_base = (82, 102, 61)       # #52663D Olive Base
    c_shadow = (70, 88, 54)     # Softened crevice
    c_high = (92, 112, 68)      # Softened highlight
    c_dirt = (78, 74, 58)       # Quiet earth tone

    pixels = img.load()
    for x in range(w):
        for y in range(h):
            qx = (x // 2) * 2
            qy = (y // 2) * 2
            nm = noise_macro[qx][qy]
            nu = noise_micro[qx][qy]

            if nm < 0.45:
                t = nm / 0.45
                r = int(c_shadow[0] * (1 - t) + c_base[0] * t)
                g = int(c_shadow[1] * (1 - t) + c_base[1] * t)
                b = int(c_shadow[2] * (1 - t) + c_base[2] * t)
            elif nm < 0.75:
                r, g, b = c_base
            else:
                t = (nm - 0.75) / 0.25
                r = int(c_base[0] * (1 - t) + c_high[0] * t)
                g = int(c_base[1] * (1 - t) + c_high[1] * t)
                b = int(c_base[2] * (1 - t) + c_high[2] * t)

            if nu > 0.85:
                r = min(255, int(r * 1.04))
                g = min(255, int(g * 1.04))
                b = min(255, int(b * 1.03))
            elif nu < 0.15:
                r = int(r * 0.96)
                g = int(g * 0.96)
                b = int(b * 0.96)

            pixels[x, y] = (r, g, b, 255)

    img.save("assets/environment/textures/tile_grass_olive.png")
    print("Saved tile_grass_olive.png")

# 2. TILE ROAD ASPHALT (128x128) - Weathered dark slate asphalt
def gen_tile_road():
    w, h = 128, 128
    img = Image.new("RGBA", (w, h))
    noise_asphalt = make_seamless_noise(w, h, 0.12, 3)
    noise_grain = make_seamless_noise(w, h, 0.25, 2)

    c_base = (78, 84, 83)       # #4E5453 Slate Asphalt
    c_dark = (58, 63, 62)       # Shaded Aggregate
    c_fleck = (96, 104, 102)    # Muted Fleck

    pixels = img.load()
    for x in range(w):
        for y in range(h):
            qx = (x // 2) * 2
            qy = (y // 2) * 2
            na = noise_asphalt[qx][qy]
            ng = noise_grain[qx][qy]

            # Gentle longitudinal tire wear along Y
            lane_pos = (x % 64) / 64.0
            track_dist = min(abs(lane_pos - 0.28), abs(lane_pos - 0.72))
            track_wear = max(0.0, 1.0 - (track_dist / 0.18)) * 0.10

            t = na - track_wear
            r = int(c_dark[0] * (1 - t) + c_base[0] * t)
            g = int(c_dark[1] * (1 - t) + c_base[1] * t)
            b = int(c_dark[2] * (1 - t) + c_base[2] * t)

            if ng > 0.82:
                r = int(r * 0.88 + c_fleck[0] * 0.12)
                g = int(r * 0.88 + c_fleck[1] * 0.12)
                b = int(r * 0.88 + c_fleck[2] * 0.12)

            pixels[x, y] = (r, g, b, 255)

    img.save("assets/environment/textures/tile_road_asphalt.png")
    print("Saved tile_road_asphalt.png")

# 3. TILE SIDEWALK PAVING (128x128) - Quiet stone slabs with soft joints
def gen_tile_sidewalk():
    w, h = 128, 128
    img = Image.new("RGBA", (w, h))
    noise = make_seamless_noise(w, h, 0.10, 2)
    slab_size = 64 # Large 2x2 slabs per 128px tile (avoids high-frequency grid noise)

    c_base = (175, 165, 142)    # Warm plaster/stone #AFA58E
    c_shade = (152, 143, 122)
    c_joint = (120, 112, 95)    # Soft, gentle joint line (NOT harsh dark black)
    c_high = (190, 180, 156)

    pixels = img.load()
    for x in range(w):
        for y in range(h):
            lx = x % slab_size
            ly = y % slab_size
            is_joint = (lx == 0 or ly == 0)
            is_bevel = (lx == 1 or ly == 1)

            sx = x // slab_size
            sy = y // slab_size
            slab_hash = ((sx * 37 + sy * 53) % 17) / 17.0

            n = noise[x][y]
            t = n * 0.6 + slab_hash * 0.4
            r = int(c_shade[0] * (1 - t) + c_base[0] * t)
            g = int(c_shade[1] * (1 - t) + c_base[1] * t)
            b = int(c_shade[2] * (1 - t) + c_base[2] * t)

            if is_joint:
                r, g, b = c_joint
            elif is_bevel:
                r = int(r * 0.8 + c_high[0] * 0.2)
                g = int(g * 0.8 + c_high[1] * 0.2)
                b = int(b * 0.8 + c_high[2] * 0.2)

            pixels[x, y] = (r, g, b, 255)

    img.save("assets/environment/textures/tile_sidewalk_paving.png")
    print("Saved tile_sidewalk_paving.png")

# 4. TILE WALL BRICK (128x128) - Warm rich brick with clean mortar
def gen_tile_brick():
    w, h = 128, 128
    img = Image.new("RGBA", (w, h))
    brick_w = 16
    brick_h = 8
    noise = make_seamless_noise(w, h, 0.10, 2)

    c_base = (156, 102, 76)     # #9C664C Warm brick
    c_shade = (134, 84, 60)
    c_high = (180, 120, 92)
    c_mortar = (88, 76, 68)     # Soft mortar seam

    pixels = img.load()
    for y in range(h):
        row = y // brick_h
        ry = y % brick_h
        row_offset = (brick_w // 2) if (row % 2 == 1) else 0

        for x in range(w):
            col_x = (x + row_offset) % w
            rx = col_x % brick_w
            col = (x + row_offset) // brick_w

            is_mortar = (ry == 0 or rx == 0)
            is_brick_bevel = (ry == 1 or rx == 1)

            brick_hash = ((col * 47 + row * 83) % 19) / 19.0
            n = noise[x][y]

            if is_mortar:
                r, g, b = c_mortar
            else:
                t = n * 0.5 + brick_hash * 0.5
                r = int(c_shade[0] * (1 - t) + c_base[0] * t)
                g = int(c_shade[1] * (1 - t) + c_base[1] * t)
                b = int(c_shade[2] * (1 - t) + c_base[2] * t)

                if is_brick_bevel:
                    r = int(r * 0.8 + c_high[0] * 0.2)
                    g = int(g * 0.8 + c_high[1] * 0.2)
                    b = int(b * 0.8 + c_high[2] * 0.2)

            pixels[x, y] = (r, g, b, 255)

    img.save("assets/environment/textures/tile_wall_brick.png")
    print("Saved tile_wall_brick.png")

# 5. TILE WALL CONCRETE (128x128) - Clean architectural concrete panels
def gen_tile_concrete():
    w, h = 128, 128
    img = Image.new("RGBA", (w, h))
    panel_w = 64
    panel_h = 32
    noise = make_seamless_noise(w, h, 0.08, 3)

    c_base = (185, 175, 155)    # High-luminance neutral stone
    c_shade = (162, 152, 134)
    c_seam = (115, 106, 92)
    c_bevel = (208, 198, 178)

    pixels = img.load()
    for x in range(w):
        for y in range(h):
            px = x % panel_w
            py = y % panel_h
            is_seam = (px == 0 or py == 0)
            is_bevel = (px == 1 or py == 1)
            is_tie = ((px in [8, panel_w - 8]) and (py in [8, panel_h - 8]))

            n = noise[x][y]
            r = int(c_shade[0] * (1 - n) + c_base[0] * n)
            g = int(c_shade[1] * (1 - n) + c_base[1] * n)
            b = int(c_shade[2] * (1 - n) + c_base[2] * n)

            if is_seam:
                r, g, b = c_seam
            elif is_tie:
                r, g, b = (95, 88, 76)
            elif is_bevel:
                r = int(r * 0.75 + c_bevel[0] * 0.25)
                g = int(g * 0.75 + c_bevel[1] * 0.25)
                b = int(b * 0.75 + c_bevel[2] * 0.25)

            pixels[x, y] = (r, g, b, 255)

    img.save("assets/environment/textures/tile_wall_concrete.png")
    print("Saved tile_wall_concrete.png")

# 6. TILE WALL INDUSTRIAL (128x128) - Military olive drab corrugated metal
def gen_tile_industrial():
    w, h = 128, 128
    img = Image.new("RGBA", (w, h))
    noise = make_seamless_noise(w, h, 0.12, 2)
    flute_w = 8

    c_base = (82, 94, 76)
    c_shadow = (60, 70, 55)
    c_high = (105, 120, 98)

    pixels = img.load()
    for x in range(w):
        fx = x % flute_w
        if fx == 0:
            rib_factor = 0.0
        elif fx in [1, 7]:
            rib_factor = 0.35
        elif fx == 2:
            rib_factor = 0.75
        elif fx in [3, 4, 5]:
            rib_factor = 1.0
        else:
            rib_factor = 0.65

        for y in range(h):
            n = noise[x][y]
            is_rivet = (y % 32 == 16) and (fx == 4)

            t = rib_factor * 0.7 + n * 0.3
            r = int(c_shadow[0] * (1 - t) + c_high[0] * t)
            g = int(c_shadow[1] * (1 - t) + c_high[1] * t)
            b = int(c_shadow[2] * (1 - t) + c_high[2] * t)

            if is_rivet:
                r, g, b = (130, 148, 120)

            pixels[x, y] = (r, g, b, 255)

    img.save("assets/environment/textures/tile_wall_industrial.png")
    print("Saved tile_wall_industrial.png")

# 7. TILE ROOF SLATE (128x128)
def gen_tile_roof():
    w, h = 128, 128
    img = Image.new("RGBA", (w, h))
    noise = make_seamless_noise(w, h, 0.15, 3)
    seam_spacing = 32

    c_base = (92, 98, 96)
    c_shadow = (72, 78, 76)
    c_high = (112, 120, 118)
    c_tar = (55, 60, 58)

    pixels = img.load()
    for x in range(w):
        for y in range(h):
            is_seam = (y % seam_spacing == 0)
            is_ridge = (y % seam_spacing == 1)

            n = noise[x][y]
            r = int(c_shadow[0] * (1 - n) + c_base[0] * n)
            g = int(c_shadow[1] * (1 - n) + c_base[1] * n)
            b = int(c_shadow[2] * (1 - n) + c_base[2] * n)

            if is_seam:
                r, g, b = c_tar
            elif is_ridge:
                r = int(r * 0.8 + c_high[0] * 0.2)
                g = int(g * 0.8 + c_high[1] * 0.2)
                b = int(b * 0.8 + c_high[2] * 0.2)

            pixels[x, y] = (r, g, b, 255)

    img.save("assets/environment/textures/tile_roof_slate.png")
    print("Saved tile_roof_slate.png")

# 8. TILE HELIPAD (256x256)
def gen_tile_helipad():
    w, h = 256, 256
    img = Image.new("RGBA", (w, h))
    noise = make_seamless_noise(w, h, 0.08, 3)

    c_base = (70, 76, 78)
    c_dark = (54, 58, 60)
    c_yellow = (218, 175, 75)   # #D9AC4A Warm tactical amber
    c_yellow_wear = (175, 140, 60)
    c_white = (220, 224, 220)
    c_white_wear = (175, 180, 175)

    pixels = img.load()
    cx, cy = w / 2.0, h / 2.0
    radius = 82.0
    ring_thick = 12.0

    for x in range(w):
        for y in range(h):
            n = noise[x][y]
            is_joint = (x in [64, 192]) or (y in [64, 192])
            dist_center = math.hypot(x - cx, y - cy)
            soot = max(0.0, 1.0 - (dist_center / 115.0)) * 0.12

            t = n - soot
            r = int(c_dark[0] * (1 - t) + c_base[0] * t)
            g = int(c_dark[1] * (1 - t) + c_base[1] * t)
            b = int(c_dark[2] * (1 - t) + c_base[2] * t)

            if is_joint:
                r, g, b = (42, 46, 48)

            # Circular Yellow Ring with smooth edge
            if abs(dist_center - radius) <= ring_thick:
                edge_factor = 1.0 - (abs(dist_center - radius) / ring_thick)
                yr, yg, yb = c_yellow if n >= 0.26 else c_yellow_wear
                blend = min(1.0, edge_factor * 1.6)
                r = int(r * (1 - blend) + yr * blend)
                g = int(g * (1 - blend) + yg * blend)
                b = int(b * (1 - blend) + yb * blend)

            # Outer border line
            if (x in [16, 239] and 16 <= y <= 239) or (y in [16, 239] and 16 <= x <= 239):
                r = int(r * 0.3 + c_yellow[0] * 0.7)
                g = int(g * 0.3 + c_yellow[1] * 0.7)
                b = int(b * 0.3 + c_yellow[2] * 0.7)

            pixels[x, y] = (r, g, b, 255)

    # Central 'H'
    stem_w = 14
    stem_h = 86
    cross_h = 14
    h_spacing = 46

    for x in range(w):
        for y in range(h):
            in_left = (cx - h_spacing/2 - stem_w <= x <= cx - h_spacing/2) and (cy - stem_h/2 <= y <= cy + stem_h/2)
            in_right = (cx + h_spacing/2 <= x <= cx + h_spacing/2 + stem_w) and (cy - stem_h/2 <= y <= cy + stem_h/2)
            in_cross = (cx - h_spacing/2 <= x <= cx + h_spacing/2 + stem_w) and (cy - cross_h/2 <= y <= cy + cross_h/2)

            if in_left or in_right or in_cross:
                n = noise[x][y]
                wr, wg, wb = c_white if n >= 0.28 else c_white_wear
                pixels[x, y] = (wr, wg, wb, 255)

    img.save("assets/environment/textures/tile_helipad.png")
    print("Saved tile_helipad.png")

# 9. TILE WINDOW GRID (128x128)
def gen_tile_windows():
    w, h = 128, 128
    img = Image.new("RGBA", (w, h))
    win_w = 32
    win_h = 32

    c_glass = (42, 53, 61)
    c_glass_reflect = (58, 74, 84)
    c_frame = (145, 140, 130)
    c_sill = (35, 40, 44)

    pixels = img.load()
    for x in range(w):
        for y in range(h):
            wx = x % win_w
            wy = y % win_h

            is_frame = (wx in [0, 1] or wy in [0, 1])
            is_sill = (wy == win_h - 1 or wy == 2)

            if is_frame:
                r, g, b = c_frame
            elif is_sill:
                r, g, b = c_sill
            else:
                diag = (wx + wy) / float(win_w + win_h)
                if 0.35 <= diag <= 0.65:
                    r, g, b = c_glass_reflect
                else:
                    r, g, b = c_glass

            pixels[x, y] = (r, g, b, 255)

    img.save("assets/environment/textures/tile_window_grid.png")
    print("Saved tile_window_grid.png")

if __name__ == "__main__":
    gen_tile_grass()
    gen_tile_road()
    gen_tile_sidewalk()
    gen_tile_brick()
    gen_tile_concrete()
    gen_tile_industrial()
    gen_tile_roof()
    gen_tile_helipad()
    gen_tile_windows()
    print("All textures regenerated.")
