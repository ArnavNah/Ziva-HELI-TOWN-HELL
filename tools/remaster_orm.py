"""
Remaster player_apache_orm.png to give realistic PBR material properties:
- Matte military armor coating (high roughness ~0.75, non-metallic)
- Sleek glossy cockpit glass (low roughness ~0.15)
- Carbon fiber rotor blades (satin roughness ~0.50)
- Metallic engine exhausts (high metallic ~0.75, low roughness ~0.35)
"""
from PIL import Image
import numpy as np

def remaster_orm():
    base_path = "assets/player/player_apache_basecolor.png"
    orm_path = "assets/player/player_apache_orm.png"
    
    base_im = Image.open(base_path).convert("RGB")
    base_arr = np.array(base_im, dtype=np.float32)
    
    orm_im = Image.open(orm_path).convert("RGB")
    orm_arr = np.array(orm_im, dtype=np.uint8)
    
    # R = AO, G = Roughness, B = Metallic
    ao = orm_arr[:, :, 0]
    
    # Target channels
    new_r = ao.copy()
    new_g = np.full_like(ao, 195) # Default: 0.76 matte military armor
    new_b = np.full_like(ao, 15)  # Default: non-metallic paint
    
    # 1. Cockpit glass regions:
    # Left shell: x in [80, 520], y in [2048, 2900]
    # Right shell: x in [560, 950], y in [3100, 3950]
    lum = np.mean(base_arr, axis=2)
    island_mask = lum > 8.0
    
    for (x0, y0, x1, y1) in [(80, 2048, 520, 2900), (560, 3100, 950, 3950)]:
        sub_mask = np.zeros_like(island_mask)
        sub_mask[y0:y1, x0:x1] = island_mask[y0:y1, x0:x1]
        is_glass = sub_mask & (base_arr[:, :, 0] < 30) & (base_arr[:, :, 2] > 32)
        new_g[is_glass] = 38 # Glossy glass (0.15)
        new_b[is_glass] = 55 # Subtle metallic specular reflection
        
    # 2. Rotor blades: x in [2450, 2850], y in [1300, 3400]
    rotor_mask = np.zeros_like(island_mask)
    rotor_mask[1300:3400, 2450:2850] = island_mask[1300:3400, 2450:2850]
    is_blade = rotor_mask & (lum > 15.0)
    new_g[is_blade] = 125 # Satin carbon composite (0.49)
    new_b[is_blade] = 20
    
    # 3. Engine exhausts & turbine nacelles: x in [1700, 2050], y in [1300, 1800]
    engine_mask = np.zeros_like(island_mask)
    engine_mask[1300:1800, 1700:2050] = island_mask[1300:1800, 1700:2050]
    is_engine = engine_mask & (lum > 20.0)
    new_g[is_engine] = 85  # Polished metal (0.33)
    new_b[is_engine] = 185 # High metallic (0.72)
    
    # Zero background
    new_r[~island_mask] = 0
    new_g[~island_mask] = 0
    new_b[~island_mask] = 0
    
    remastered = np.stack([new_r, new_g, new_b], axis=2)
    out_im = Image.fromarray(remastered, mode="RGB")
    out_im.save(orm_path)
    print(f"Saved remastered ORM texture to: {orm_path}")

if __name__ == "__main__":
    remaster_orm()
