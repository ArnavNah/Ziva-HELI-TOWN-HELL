"""
Generate Masterpiece Military Textures for Apache Helicopter.
Produces a bright, highly readable, prominent tactical gunship finish:
- Tactical Sage / Gunship Olive (Luminance ~155, bright & clear against dark asphalt)
- Polarized cyan-blue aviation canopy glass with specular response
- Satin carbon fiber blades with wide, brilliant hazard-yellow safety tips
- Heat-treated titanium engine exhausts with authentic metallic response
- Vibrant gold/amber FLIR nose sensor
- Pure tangent-space clean normal map (zero wrinkles)
- Tuned PBR ORM map (soft specular curves, glossy glass, metallic exhausts)
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

def generate_masterpiece_textures():
    print("Generating High-Visibility Tactical Apache textures...")
    
    # 1. Load original backup to get active UV island mask
    orig_path = "assets/player/textures_backup/player_apache_basecolor.png"
    orig_im = Image.open(orig_path).convert("RGB")
    orig_arr = np.array(orig_im, dtype=np.uint8)
    h, w, _ = orig_arr.shape
    
    lum = np.mean(orig_arr, axis=2)
    active = lum > 5.0
    
    # Base color channels
    base_r = np.zeros((h, w), dtype=np.uint8)
    base_g = np.zeros((h, w), dtype=np.uint8)
    base_b = np.zeros((h, w), dtype=np.uint8)
    
    # High-Visibility Tactical Sage / Gunship Olive: #8eaa82 (RGB: 142, 170, 130)
    # Bright, heroic military green that pops cleanly against dark roads and terrain
    base_r[active] = 142
    base_g[active] = 170
    base_b[active] = 130
    
    # Draw masks for specific components
    # -------------------------------------------------------------------------
    # 1. Canopy Glass Windows & Framing
    # -------------------------------------------------------------------------
    glass_mask_img = Image.new('L', (w, h), 0)
    d_glass = ImageDraw.Draw(glass_mask_img)
    # Left fuselage shell: two side window panes
    d_glass.polygon([(185, 2110), (335, 2125), (325, 2385), (165, 2375)], fill=255)
    d_glass.polygon([(165, 2435), (315, 2435), (275, 2705), (135, 2705)], fill=255)
    # Right fuselage shell: two side window panes
    d_glass.polygon([(575, 3475), (735, 3495), (725, 3715), (585, 3715)], fill=255)
    d_glass.polygon([(595, 3765), (775, 3765), (735, 4015), (625, 4015)], fill=255)
    # Top spine windshield
    d_glass.polygon([(1070, 2020), (1145, 2020), (1155, 2350), (1060, 2350)], fill=255)
    
    glass_mask = (np.array(glass_mask_img) > 128) & active
    # Polarized aviation cyan-blue crystal glass #2a5a87 (RGB: 42, 90, 135)
    base_r[glass_mask] = 42
    base_g[glass_mask] = 90
    base_b[glass_mask] = 135
    
    # Canopy Frame: Tactical dark olive border #374434 (RGB: 55, 68, 52)
    frame_mask_img = glass_mask_img.filter(ImageFilter.MaxFilter(9))
    frame_mask = (np.array(frame_mask_img) > 128) & active & (~glass_mask)
    base_r[frame_mask] = 55
    base_g[frame_mask] = 68
    base_b[frame_mask] = 52
    
    # -------------------------------------------------------------------------
    # 2. Main and Tail Rotor Blades
    # -------------------------------------------------------------------------
    rotor_mask = np.zeros((h, w), dtype=bool)
    # Main rotor 4 blade strips (x: 2350..2900, y: 1300..3500)
    rotor_mask[1300:3500, 2350:2900] = active[1300:3500, 2350:2900]
    # Tail rotor blade strips & hub (x: 2900..3150, y: 1300..3500)
    rotor_mask[1300:3500, 2900:3150] = active[1300:3500, 2900:3150]
    
    # Clean tactical graphite carbon composite #4b5258 (RGB: 75, 82, 88)
    base_r[rotor_mask] = 75
    base_g[rotor_mask] = 82
    base_b[rotor_mask] = 88
    
    # Rotor Hazard Yellow Safety Tips (y: 1300..1520 - wide, bold tip bands)
    tip_mask = np.zeros((h, w), dtype=bool)
    tip_mask[1300:1520, 2350:2900] = rotor_mask[1300:1520, 2350:2900]
    # Brilliant radiant warning yellow #ffdc12 (RGB: 255, 220, 18)
    base_r[tip_mask] = 255
    base_g[tip_mask] = 220
    base_b[tip_mask] = 18
    
    # -------------------------------------------------------------------------
    # 3. Engine Nacelles: Turbines & Exhausts
    # -------------------------------------------------------------------------
    # Engine Intakes (x: 1720..1920, y: 1320..1650)
    intake_mask = np.zeros((h, w), dtype=bool)
    intake_mask[1320:1650, 1720:1920] = active[1320:1650, 1720:1920]
    base_r[intake_mask] = 40
    base_g[intake_mask] = 44
    base_b[intake_mask] = 48
    
    # Turbine Exhausts (x: 1940..2160, y: 1320..1700)
    exhaust_mask = np.zeros((h, w), dtype=bool)
    exhaust_mask[1320:1700, 1940:2160] = active[1320:1700, 1940:2160]
    # Gleaming titanium gunmetal #87919b (RGB: 135, 145, 155)
    base_r[exhaust_mask] = 135
    base_g[exhaust_mask] = 145
    base_b[exhaust_mask] = 155
    
    # -------------------------------------------------------------------------
    # 4. Nose TADS/PNVS Sensor Turret & FLIR Optic
    # -------------------------------------------------------------------------
    sensor_mask = np.zeros((h, w), dtype=bool)
    sensor_mask[1750:2050, 200:450] = active[1750:2050, 200:450]
    base_r[sensor_mask] = 95
    base_g[sensor_mask] = 115
    base_b[sensor_mask] = 88
    
    lens_mask = np.zeros((h, w), dtype=bool)
    lens_mask[1850:1950, 280:380] = sensor_mask[1850:1950, 280:380]
    # Radiant gold/amber FLIR optic #ffd228 (RGB: 255, 210, 40)
    base_r[lens_mask] = 255
    base_g[lens_mask] = 210
    base_b[lens_mask] = 40
    
    # -------------------------------------------------------------------------
    # 5. Weapon Pylons & M230 30mm Chain Gun
    # -------------------------------------------------------------------------
    gun_mask = np.zeros((h, w), dtype=bool)
    gun_mask[800:1300, 100:600] = active[800:1300, 100:600]
    # Tactical light ordnance steel #828a92 (RGB: 130, 138, 146)
    base_r[gun_mask] = 130
    base_g[gun_mask] = 138
    base_b[gun_mask] = 146
    
    # Assemble Base Color
    base_rgb = np.stack([base_r, base_g, base_b], axis=2)
    base_rgb[~active] = 0
    basecolor_im = Image.fromarray(base_rgb, mode="RGB")
    
    # -------------------------------------------------------------------------
    # NORMAL MAP (Flat clean tangent space normal, zero wrinkles)
    # -------------------------------------------------------------------------
    norm_r = np.full((h, w), 128, dtype=np.uint8)
    norm_g = np.full((h, w), 128, dtype=np.uint8)
    norm_b = np.full((h, w), 255, dtype=np.uint8)
    norm_r[~active] = 0
    norm_g[~active] = 0
    norm_b[~active] = 0
    normal_im = Image.fromarray(np.stack([norm_r, norm_g, norm_b], axis=2), mode="RGB")
    
    # -------------------------------------------------------------------------
    # ORM MAP (R = AO, G = Roughness, B = Metallic)
    # -------------------------------------------------------------------------
    orm_r = np.full((h, w), 250, dtype=np.uint8) # Clean Ambient Occlusion
    orm_g = np.full((h, w), 125, dtype=np.uint8) # Body Roughness: 0.49 (vivid specular response)
    orm_b = np.full((h, w), 10, dtype=np.uint8)  # Body Metallic: 0.04 (dielectric)
    
    # Canopy Glass: Mirror-smooth glossy specular reflection
    orm_g[glass_mask] = 15 # Roughness: 0.06
    orm_b[glass_mask] = 60 # Metallic: 0.24 (polarized aviation glass)
    
    # Canopy Frame: Matte structural border
    orm_g[frame_mask] = 160
    orm_b[frame_mask] = 12
    
    # Rotor Blades: Satin carbon composite
    orm_g[rotor_mask] = 100 # Roughness: 0.39
    orm_b[rotor_mask] = 15
    
    # Engine Exhausts: Titanium alloy
    orm_g[exhaust_mask] = 65  # Roughness: 0.25
    orm_b[exhaust_mask] = 215 # Metallic: 0.84
    
    # Engine Intakes: Matte cavity
    orm_g[intake_mask] = 210
    orm_b[intake_mask] = 5
    
    # Sensor Optic Lens: Highly polished glass
    orm_g[lens_mask] = 10
    orm_b[lens_mask] = 110
    
    # Gun & Rails: Machined steel
    orm_g[gun_mask] = 85
    orm_b[gun_mask] = 195
    
    orm_r[~active] = 0
    orm_g[~active] = 0
    orm_b[~active] = 0
    orm_im = Image.fromarray(np.stack([orm_r, orm_g, orm_b], axis=2), mode="RGB")
    
    # -------------------------------------------------------------------------
    # SAVE DESTINATIONS
    # -------------------------------------------------------------------------
    save_list = [
        ("assets/player/player_apache_basecolor.png", basecolor_im),
        ("assets/player/textures/Apache_LowPoly_BaseColor.png", basecolor_im),
        ("assets/player/textures_lowpoly/apache_basecolor.png", basecolor_im),
        ("assets/player/player_apache_normal.png", normal_im),
        ("assets/player/textures/Apache_LowPoly_Normal.png", normal_im),
        ("assets/player/textures_lowpoly/apache_normal.png", normal_im),
        ("assets/player/player_apache_orm.png", orm_im),
        ("assets/player/textures/Apache_LowPoly_ORM.png", orm_im),
        ("assets/player/textures_lowpoly/apache_orm.png", orm_im),
    ]
    
    for path, im in save_list:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        im.save(path)
        print(f"Saved: {path}")
        
    # Save preview thumbnail
    thumb = basecolor_im.copy()
    thumb.thumbnail((512, 512))
    thumb.save("C:/Users/Prime 3/.gemini/antigravity/brain/7fe842b3-2e28-4d17-b446-0deca635b154/masterpiece_basecolor_thumb.png")
    print("Saved bright masterpiece_basecolor_thumb.png")

if __name__ == "__main__":
    generate_masterpiece_textures()
