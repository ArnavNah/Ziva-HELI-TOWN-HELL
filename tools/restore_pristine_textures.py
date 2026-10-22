"""
Restore and professionally tone-map the authentic Apache helicopter textures.
Zero AI-drawn polygons, zero fake colored boxes, 100% authentic artist assets
with calibrated gamma curve for rich, authentic US Army CARC olive drab.
"""
import os
import numpy as np
from PIL import Image, ImageEnhance

def restore():
    print("=== Restoring Authentic Apache Textures (Calibrated Tone) ===")
    base_src = "assets/player/extracted_backup_apache_basecolor.png"
    norm_src = "assets/player/extracted_backup_apache_normal.png"
    orm_src = "assets/player/extracted_backup_apache_orm.png"
    
    # 1. BaseColor: Tone-map authentic texture
    orig_im = Image.open(base_src).convert("RGB")
    orig_arr = np.array(orig_im, dtype=np.float32)
    h, w, _ = orig_arr.shape
    
    active = np.mean(orig_arr, axis=2) > 4.0
    
    # Calibrated military tone curve: gamma 0.85, multiplier 1.10
    norm_val = orig_arr / 255.0
    boosted = np.power(norm_val, 0.85) * 1.10
    boosted = np.clip(boosted * 255.0, 0, 255)
    
    final_arr = np.zeros_like(orig_arr)
    final_arr[active] = boosted[active]
    
    final_im = Image.fromarray(final_arr.astype(np.uint8), mode="RGB")
    enhancer = ImageEnhance.Color(final_im)
    final_im = enhancer.enhance(1.08)
    
    contrast_enhancer = ImageEnhance.Contrast(final_im)
    final_im = contrast_enhancer.enhance(1.04)
    
    # Save basecolor
    for target in [
        "assets/player/player_apache_basecolor.png",
        "assets/player/textures/Apache_LowPoly_BaseColor.png",
        "assets/player/textures_lowpoly/apache_basecolor.png"
    ]:
        os.makedirs(os.path.dirname(target), exist_ok=True)
        final_im.save(target, quality=95)
        print(f"Saved BaseColor -> {target}")
        
    # 2. Authentic Normal Map
    norm_im = Image.open(norm_src).convert("RGB")
    for target in [
        "assets/player/player_apache_normal.png",
        "assets/player/textures/Apache_LowPoly_Normal.png",
        "assets/player/textures_lowpoly/apache_normal.png"
    ]:
        norm_im.save(target, quality=95)
        print(f"Saved Normal Map -> {target}")
        
    # 3. Authentic ORM Map
    orm_im = Image.open(orm_src).convert("RGB")
    for target in [
        "assets/player/player_apache_orm.png",
        "assets/player/textures/Apache_LowPoly_ORM.png",
        "assets/player/textures_lowpoly/apache_orm.png"
    ]:
        orm_im.save(target, quality=95)
        print(f"Saved ORM Map -> {target}")

    print("=== Texture Restoration Complete ===")

if __name__ == "__main__":
    restore()
