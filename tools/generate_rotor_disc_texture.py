"""
Generate high-fidelity radial motion blur textures for helicopter main rotor and tail rotor.
Features soft hub clearance, realistic blade sweep density, tip velocity blur, and soft feathered edges.
"""
import numpy as np
from PIL import Image

def generate_blur_disc(size=256, output_path="assets/player/rotor_blur_disc.png"):
    img = np.zeros((size, size, 4), dtype=np.uint8)
    center = (size - 1) / 2.0
    y, x = np.ogrid[:size, :size]
    dist = np.sqrt((x - center)**2 + (y - center)**2) / center # 0.0 at center, 1.0 at outer edge
    
    # Base dark aerodynamic tint (charcoal/dark graphite)
    img[:, :, 0] = 28 # R
    img[:, :, 1] = 32 # G
    img[:, :, 2] = 30 # B
    
    # Radial alpha profile
    alpha = np.zeros((size, size), dtype=np.float32)
    
    # 1. Inner hub clearance (r < 0.18): alpha 0 to 0.15
    inner_mask = dist < 0.20
    alpha[inner_mask] = np.clip((dist[inner_mask] - 0.08) / 0.12, 0.0, 1.0) * 0.15
    
    # 2. Main blade sweep zone (0.20 <= r < 0.85): smooth disc density
    mid_mask = (dist >= 0.20) & (dist < 0.85)
    # Slight progressive density towards tips where linear velocity is higher
    prog = (dist[mid_mask] - 0.20) / 0.65
    alpha[mid_mask] = 0.15 + (prog * 0.12)
    
    # 3. High-velocity blade tip ring (0.85 <= r < 0.95): slightly denser tip vortex
    tip_mask = (dist >= 0.85) & (dist < 0.95)
    alpha[tip_mask] = 0.27
    
    # 4. Soft feathered edge (0.95 <= r <= 1.0)
    edge_mask = (dist >= 0.95) & (dist <= 1.0)
    alpha[edge_mask] = 0.27 * (1.0 - (dist[edge_mask] - 0.95) / 0.05)
    
    # Clamp and assign
    img[:, :, 3] = np.clip(alpha * 255.0, 0.0, 255.0).astype(np.uint8)
    
    pil_img = Image.fromarray(img, mode="RGBA")
    pil_img.save(output_path)
    print(f"Saved rotor blur disc texture to: {output_path}")

if __name__ == "__main__":
    generate_blur_disc()
