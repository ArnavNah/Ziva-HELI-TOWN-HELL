
import bpy
import bmesh
from mathutils import Vector

def find_wheel_hubs(obj_name, expected_count):
    obj = bpy.data.objects.get(obj_name)
    me = obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    
    # In both models, the wheel hubs/spindles are circular/cylindrical features or vertices at lateral extremes (+Y and -Y in Blender)
    # Let's inspect the mesh islands of the Chassis to see if the brake discs / wheel hubs are distinct islands!
    visited = set()
    islands = []
    for face in bm.faces:
        if face in visited:
            continue
        isl = []
        q = [face]
        visited.add(face)
        while q:
            f = q.pop(0)
            isl.append(f)
            for edge in f.edges:
                for lf in edge.link_faces:
                    if lf not in visited:
                        visited.add(lf)
                        q.append(lf)
        islands.append(isl)
    
    print(f"\nChassis '{obj_name}' has {len(islands)} islands.")
    # Check islands that are symmetrically positioned along Y (left and right)
    for idx, isl in enumerate(islands):
        v_set = set(v for f in isl for v in f.verts)
        min_c = Vector((min(v.co.x for v in v_set), min(v.co.y for v in v_set), min(v.co.z for v in v_set)))
        max_c = Vector((max(v.co.x for v in v_set), max(v.co.y for v in v_set), max(v.co.z for v in v_set)))
        center = sum((v.co for v in v_set), Vector((0,0,0))) / len(v_set)
        dims = max_c - min_c
        # Look for hub-like features (moderate size, lateral position)
        if abs(center.y) > 0.15: # lateral
            print(f"  Lateral Island {idx}: {len(v_set)} verts, center=({center.x:.4f}, {center.y:.4f}, {center.z:.4f}), dims=({dims.x:.4f}, {dims.y:.4f}, {dims.z:.4f})")
    bm.free()

if "Raptor" in bpy.data.filepath:
    print("=== RAPTOR HUBS ===")
    find_wheel_hubs("Chassis", 4)
elif "Desert" in bpy.data.filepath:
    print("=== DESERT HUBS ===")
    find_wheel_hubs("Chassis", 6)
