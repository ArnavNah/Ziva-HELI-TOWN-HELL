import trimesh
import fast_simplification
import numpy as np
import os

src_path = 'assets/Enemy/scout_buggy_Game_Asset/Desert_Recon_Buggy_Tire.glb'
dst_path = 'assets/Enemy/scout_buggy_Game_Asset/Desert_Recon_Buggy_Tire_Reduced.glb'

scene = trimesh.load(src_path)
mesh = list(scene.geometry.values())[0] if isinstance(scene, trimesh.Scene) else scene

orig_verts = np.asarray(mesh.vertices, dtype=np.float32)
orig_faces = np.asarray(mesh.faces, dtype=np.int32)
orig_uvs = np.asarray(mesh.visual.uv, dtype=np.float32)

target_reduction = 1.0 - (850.0 / len(orig_faces))
dec_pts, dec_faces, collapses = fast_simplification.simplify(
    orig_verts, orig_faces, target_reduction=target_reduction, return_collapses=True, agg=7.0
)

pts, tris, mapping = fast_simplification.replay_simplification(orig_verts, orig_faces, collapses)

new_uvs = np.zeros((len(pts), 2), dtype=np.float32)
for old_idx, new_idx in enumerate(mapping):
    if new_idx >= 0 and new_idx < len(pts):
        new_uvs[new_idx] = orig_uvs[old_idx]

# Create simplified mesh
simplified_mesh = trimesh.Trimesh(
    vertices=pts,
    faces=tris,
    visual=trimesh.visual.TextureVisuals(uv=new_uvs, material=mesh.visual.material if hasattr(mesh.visual, 'material') else None)
)

print(f"Exporting reduced tire: {len(pts)} vertices, {len(tris)} triangles to {dst_path}")
simplified_mesh.export(dst_path)
print("Export complete. File size:", os.path.getsize(dst_path), "bytes")
