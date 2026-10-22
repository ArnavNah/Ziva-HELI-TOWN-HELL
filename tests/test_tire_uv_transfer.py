import trimesh
import fast_simplification
import numpy as np

# Load original tire GLB
scene = trimesh.load('assets/Enemy/scout_buggy_Game_Asset/Desert_Recon_Buggy_Tire.glb')
# scene can be a Scene or Trimesh
if isinstance(scene, trimesh.Scene):
    mesh = list(scene.geometry.values())[0]
else:
    mesh = scene

orig_verts = np.asarray(mesh.vertices, dtype=np.float32)
orig_faces = np.asarray(mesh.faces, dtype=np.int32)
orig_uvs = np.asarray(mesh.visual.uv, dtype=np.float32)

print(f"Original tire: {len(orig_verts)} verts, {len(orig_faces)} faces, {len(orig_uvs)} uvs")

# Target ~850 faces
target_faces = 850
reduction = 1.0 - (target_faces / len(orig_faces))

dec_pts, dec_faces, collapses = fast_simplification.simplify(
    orig_verts, orig_faces, target_reduction=reduction, return_collapses=True
)

# Replay to get index mapping
pts, tris, mapping = fast_simplification.replay_simplification(orig_verts, orig_faces, collapses)

print(f"Decimated: {len(pts)} verts, {len(tris)} faces, mapping shape: {mapping.shape}")

# Transfer UVs
new_uvs = np.zeros((len(pts), 2), dtype=np.float32)
for old_idx, new_idx in enumerate(mapping):
    if new_idx >= 0 and new_idx < len(pts):
        new_uvs[new_idx] = orig_uvs[old_idx]

# Create simplified trimesh
dec_mesh = trimesh.Trimesh(
    vertices=pts,
    faces=tris,
    visual=trimesh.visual.TextureVisuals(uv=new_uvs, image=mesh.visual.material.image if hasattr(mesh.visual, 'material') and hasattr(mesh.visual.material, 'image') else None)
)

print("Simplified mesh bounds:", dec_mesh.bounds)
print("Simplified mesh extents:", dec_mesh.extents)
print("Original mesh extents:", mesh.extents)
