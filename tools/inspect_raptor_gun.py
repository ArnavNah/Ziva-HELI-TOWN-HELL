import bpy
from mathutils import Vector

bpy.ops.wm.open_mainfile(filepath=r"assets/Enemy/new ground/Raptor_Raider/Raptor_Raider_Separated.blend")
obj = bpy.data.objects.get("Gun_Turret")
me = obj.data

print("--- RAPTOR GUN TURRET GEOMETRY ANALYSIS ---")
# Let's inspect the barrels (vertices with X < -0.05)
barrel_verts = [v.co for v in me.vertices if v.co.x < -0.05]
print(f"Total barrel vertices (X < -0.05): {len(barrel_verts)}")
# Find minimum X (tips of the barrels)
min_x = min(v.co.x for v in me.vertices)
tip_verts = [v.co for v in me.vertices if v.co.x < min_x + 0.02]
print(f"Barrel tip minimum X: {min_x:.4f}, tip vertices count: {len(tip_verts)}")
for v in tip_verts:
    print(f"  Tip vert: ({v.x:.4f}, {v.y:.4f}, {v.z:.4f})")

# Center of the barrel tip(s)
tip_center = sum(tip_verts, Vector((0,0,0))) / len(tip_verts)
print(f"Barrel tip center: ({tip_center.x:.4f}, {tip_center.y:.4f}, {tip_center.z:.4f})")

# Let's inspect the trunnion / elevation hinge (where does the gun pitch relative to the turret cab?)
# The turret cab / armor housing rotates on the base ring (Z=0.0688)
# The gun pivots around an elevation axis in Y
print(f"Turret base ring center is around X=0.0720, Y=0.0000, Z=0.0688")
