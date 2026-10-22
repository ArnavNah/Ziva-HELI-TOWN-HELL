
import bpy
import bmesh
from mathutils import Vector

def inspect_mesh_islands(obj_name):
    obj = bpy.data.objects.get(obj_name)
    if not obj:
        print(f"Object {obj_name} not found")
        return
    me = obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    
    # Find connected components (islands)
    visited = set()
    islands = []
    
    for face in bm.faces:
        if face in visited:
            continue
        island_faces = []
        queue = [face]
        visited.add(face)
        while queue:
            f = queue.pop(0)
            island_faces.append(f)
            for edge in f.edges:
                for linked in edge.link_faces:
                    if linked not in visited:
                        visited.add(linked)
                        queue.append(linked)
        islands.append(island_faces)
        
    print(f"\nMesh '{obj_name}' has {len(islands)} islands:")
    for idx, isl in enumerate(islands):
        v_set = set()
        for f in isl:
            for v in f.verts:
                v_set.add(v)
        min_c = Vector((float('inf'), float('inf'), float('inf')))
        max_c = Vector((float('-inf'), float('-inf'), float('-inf')))
        sum_c = Vector((0, 0, 0))
        for v in v_set:
            sum_c += v.co
            min_c.x = min(min_c.x, v.co.x)
            min_c.y = min(min_c.y, v.co.y)
            min_c.z = min(min_c.z, v.co.z)
            max_c.x = max(max_c.x, v.co.x)
            max_c.y = max(max_c.y, v.co.y)
            max_c.z = max(max_c.z, v.co.z)
        center = sum_c / len(v_set)
        dims = max_c - min_c
        print(f"  Island {idx}: {len(v_set)} verts, {len(isl)} faces")
        print(f"    min: ({min_c.x:.4f}, {min_c.y:.4f}, {min_c.z:.4f})")
        print(f"    max: ({max_c.x:.4f}, {max_c.y:.4f}, {max_c.z:.4f})")
        print(f"    center: ({center.x:.4f}, {center.y:.4f}, {center.z:.4f})")
        print(f"    dims: (X={dims.x:.4f}, Y={dims.y:.4f}, Z={dims.z:.4f})")
    bm.free()

import sys
if "Raptor" in bpy.data.filepath:
    inspect_mesh_islands("Gun_Turret")
elif "Desert" in bpy.data.filepath:
    inspect_mesh_islands("Missile_Barrage_Launcher")
