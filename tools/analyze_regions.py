"""
Analyze the UV map islands by testing bounding boxes and color samples.
"""
from PIL import Image
import numpy as np

base = Image.open("assets/player/textures_backup/player_apache_basecolor.png").convert("RGB")
arr = np.array(base)
w, h, _ = arr.shape

lum = np.mean(arr, axis=2)
active = lum > 5.0

print(f"Total active pixels: {np.sum(active)} ({np.mean(active)*100:.1f}%)")

# Check cockpit regions in detail
for name, (x0, y0, x1, y1) in [
    ("Cockpit Left", (80, 2048, 520, 2900)),
    ("Cockpit Right", (560, 3100, 950, 3950)),
    ("Top Fuselage", (950, 2400, 1350, 3800)),
    ("Tail Boom", (1350, 2400, 1750, 3800)),
    ("Wings", (1750, 2000, 2300, 3400)),
    ("Rotors", (2400, 1300, 2900, 3500)),
]:
    sub = active[y0:y1, x0:x1]
    print(f"Region {name}: active={np.sum(sub)}")
