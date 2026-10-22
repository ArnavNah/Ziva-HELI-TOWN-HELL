
import bpy
from mathutils import Vector

def find_axles(chassis_name, num_axles):
    obj = bpy.data.objects.get(chassis_name)
    me = obj.data
    
    # In Blender coords: X is length, Y is lateral width (+/-), Z is vertical height.
    # Group vertices by lateral extreme (abs(y) > 0.20)
    # Project (x, z) of vertices and find circle fits or centers of wheel cutouts
    verts = [v.co for v in me.vertices if abs(v.co.y) > 0.18]
    print(f"\nChassis '{chassis_name}' - {len(verts)} lateral vertices:")
    
    # We can cluster lateral vertices along X to find the axle locations:
    # Sort vertices by X
    verts.sort(key=lambda v: v.x)
    
    # For Raptor: 2 clusters in X
    # For Desert: 3 clusters in X
    import math
    
    # Simple k-means clustering in 1D (x coordinate) for outer vertices with low Z (near wheel level z < 0.0)
    wheel_level_verts = [v for v in verts if v.z < 0.0]
    
    if num_axles == 2:
        # Front (x > 0) and Rear (x < 0)
        rear_verts = [v for v in wheel_level_verts if v.x < 0]
        front_verts = [v for v in wheel_level_verts if v.x > 0]
        
        # Center of spindle/hub is around the centroid of the hub vertices
        # Let's find vertices at the very lateral outer edge: max abs(y)
        max_y_rear = max(abs(v.y) for v in rear_verts)
        outer_rear = [v for v in rear_verts if abs(v.y) > max_y_rear - 0.05]
        
        max_y_front = max(abs(v.y) for v in front_verts)
        outer_front = [v for v in front_verts if abs(v.y) > max_y_front - 0.05]
        
        c_rear_left = sum((v for v in outer_rear if v.y > 0), Vector((0,0,0))) / max(1, len([v for v in outer_rear if v.y > 0]))
        c_rear_right = sum((v for v in outer_rear if v.y < 0), Vector((0,0,0))) / max(1, len([v for v in outer_rear if v.y < 0]))
        c_front_left = sum((v for v in outer_front if v.y > 0), Vector((0,0,0))) / max(1, len([v for v in outer_front if v.y > 0]))
        c_front_right = sum((v for v in outer_front if v.y < 0), Vector((0,0,0))) / max(1, len([v for v in outer_front if v.y < 0]))
        
        print(f"  Front Left  Hub: ({c_front_left.x:.4f}, {c_front_left.y:.4f}, {c_front_left.z:.4f})")
        print(f"  Front Right Hub: ({c_front_right.x:.4f}, {c_front_right.y:.4f}, {c_front_right.z:.4f})")
        print(f"  Rear Left   Hub: ({c_rear_left.x:.4f}, {c_rear_left.y:.4f}, {c_rear_left.z:.4f})")
        print(f"  Rear Right  Hub: ({c_rear_right.x:.4f}, {c_rear_right.y:.4f}, {c_rear_right.z:.4f})")
        
    elif num_axles == 3:
        # Desert: Rear (x < 0), Middle (0 <= x < 0.25), Front (x >= 0.25)
        rear_verts = [v for v in wheel_level_verts if v.x < 0]
        mid_verts = [v for v in wheel_level_verts if 0 <= v.x < 0.25]
        front_verts = [v for v in wheel_level_verts if v.x >= 0.25]
        
        for name, v_list in [("Front", front_verts), ("Middle", mid_verts), ("Rear", rear_verts)]:
            max_y = max(abs(v.y) for v in v_list)
            outer = [v for v in v_list if abs(v.y) > max_y - 0.05]
            left = [v for v in outer if v.y > 0]
            right = [v for v in outer if v.y < 0]
            c_l = sum(left, Vector((0,0,0))) / max(1, len(left))
            c_r = sum(right, Vector((0,0,0))) / max(1, len(right))
            print(f"  {name} Left  Hub: ({c_l.x:.4f}, {c_l.y:.4f}, {c_l.z:.4f})")
            print(f"  {name} Right Hub: ({c_r.x:.4f}, {c_r.y:.4f}, {c_r.z:.4f})")

if "Raptor" in bpy.data.filepath:
    print("=== RAPTOR AXLES ===")
    find_axles("Chassis", 2)
elif "Desert" in bpy.data.filepath:
    print("=== DESERT AXLES ===")
    find_axles("Chassis", 3)
