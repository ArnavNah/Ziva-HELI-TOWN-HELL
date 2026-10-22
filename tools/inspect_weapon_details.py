import bpy
import bmesh
from mathutils import Vector

def inspect_gun_components(blend_path, obj_name):
    bpy.ops.wm.open_mainfile(filepath=blend_path)
    obj = bpy.data.objects.get(obj_name)
    if not obj:
        print(f"Object {obj_name} not found in {blend_path}")
        return
    me = obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    
    # Analyze faces by normals, positions, connected components
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
    
    print(f"\\n================ {obj_name} ({len(islands)} islands) ================")
    # Sort islands by bounding box
    for idx, isl in enumerate(islands):
        v_set = set(v for f in isl for v in f.verts)
        min_c = Vector((min(v.co.x for v in v_set), min(v.co.y for v in v_set), min(v.co.z for v in v_set)))
        max_c = Vector((max(v.co.x for v in v_set), max(v.co.y for v in v_set), max(v.co.z for v in v_set)))
        center = sum((v.co for v in v_set), Vector((0,0,0))) / len(v_set)
        dims = max_c - min_c
        print(f"  Island {idx:02d}: {len(v_set):3d} verts, {len(isl):3d} faces | X:[{min_c.x:+.4f}, {max_c.x:+.4f}] Y:[{min_c.y:+.4f}, {max_c.y:+.4f}] Z:[{min_c.z:+.4f}, {max_c.z:+.4f}] | Dims: ({dims.x:.4f}, {dims.y:.4f}, {dims.z:.4f})")
    bm.free()

blend_raptor = r"assets/Enemy/new ground/Raptor_Raider/Raptor_Raider_Separated.blend"
blend_desert = r"assets/Enemy/new ground/Desert_Barrage_Rover/Desert_Barrage_Rover_Separated.blend"

inspect_gun_components(blend_raptor, "Gun_Turret")
inspect_gun_components(blend_desert, "Missile_Barrage_Launcher")
