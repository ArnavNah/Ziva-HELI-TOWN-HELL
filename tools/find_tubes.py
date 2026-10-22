import bpy
import bmesh
from mathutils import Vector

bpy.ops.wm.open_mainfile(filepath=r"assets/Enemy/new ground/Desert_Barrage_Rover/Desert_Barrage_Rover_Separated.blend")
obj = bpy.data.objects.get("Missile_Barrage_Launcher")
me = obj.data

# Find vertices near the front face (X close to minimum X ~ -0.14)
front_verts = [v.co for v in me.vertices if v.co.x < -0.13]
print(f"Total front vertices: {len(front_verts)}")

# Print front vertices grouped by pod (Y > 0 is left pod, Y < 0 is right pod)
left_front = [v for v in front_verts if v.y > 0.05]
right_front = [v for v in front_verts if v.y < -0.05]

print(f"Left pod front verts: {len(left_front)}, Right pod front verts: {len(right_front)}")

# Let's find circular tube centers on each pod front face
# In each pod, there are 4 tubes (e.g. 2x2 grid)
def find_tube_centers(verts, pod_name):
    # Cluster verts into 4 tubes by Y and Z
    # Find min/max Y and Z
    min_y = min(v.y for v in verts)
    max_y = max(v.y for v in verts)
    mid_y = (min_y + max_y) / 2
    
    min_z = min(v.z for v in verts)
    max_z = max(v.z for v in verts)
    mid_z = (min_z + max_z) / 2
    
    quads = {
        "Top-Inner": [],
        "Top-Outer": [],
        "Bottom-Inner": [],
        "Bottom-Outer": []
    }
    
    for v in verts:
        is_top = v.z > mid_z
        # For left pod, positive Y is outer; for right pod, more negative Y is outer
        is_outer = abs(v.y) > abs(mid_y)
        key = ("Top" if is_top else "Bottom") + "-" + ("Outer" if is_outer else "Inner")
        quads[key].append(v)
        
    print(f"\\n--- {pod_name} Tube Outlets ---")
    centers = {}
    for k, qverts in quads.items():
        if qverts:
            c = sum(qverts, Vector((0,0,0))) / len(qverts)
            centers[k] = c
            print(f"  {k}: ({c.x:.4f}, {c.y:.4f}, {c.z:.4f})")
    return centers

left_tubes = find_tube_centers(left_front, "Left Pod")
right_tubes = find_tube_centers(right_front, "Right Pod")
