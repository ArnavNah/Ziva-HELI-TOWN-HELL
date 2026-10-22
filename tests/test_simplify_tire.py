import trimesh
import fast_simplification

mesh = trimesh.load('assets/Enemy/scout_buggy_Game_Asset/Desert_Recon_Buggy_Tire.glb', force='mesh')
print('Loaded tire: vertices =', len(mesh.vertices), 'faces =', len(mesh.faces))

target_faces = 900
target_reduction = 1.0 - (target_faces / len(mesh.faces))
simplified_verts, simplified_faces = fast_simplification.simplify(
    mesh.vertices, mesh.faces, target_reduction=target_reduction
)
print('Simplified: vertices =', len(simplified_verts), 'faces =', len(simplified_faces))
