
import bpy
from mathutils import Vector

def analyze_model(vehicle_name):
    print(f"\n================ {vehicle_name} ================")
    chassis = bpy.data.objects.get("Chassis")
    if chassis:
        print(f"Chassis location: {chassis.location}")
        bb = [chassis.matrix_world @ Vector(c) for c in chassis.bound_box]
        min_c = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
        max_c = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
        print(f"Chassis World Bounds: min={min_c}, max={max_c}, size={max_c - min_c}")
    
    weapon = None
    for obj in bpy.data.objects:
        if obj != chassis and obj.type == 'MESH':
            weapon = obj
            break
    if weapon:
        print(f"Weapon object: {weapon.name}, location: {weapon.location}, parent: {weapon.parent.name if weapon.parent else 'None'}")
        bb = [weapon.matrix_world @ Vector(c) for c in weapon.bound_box]
        min_c = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
        max_c = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
        print(f"Weapon World Bounds: min={min_c}, max={max_c}, size={max_c - min_c}")
        
    # Analyze materials and textures
    for mat in bpy.data.materials:
        print(f"Material: {mat.name}")
        if mat.use_nodes:
            for node in mat.node_tree.nodes:
                if node.type == 'TEX_IMAGE' and node.image:
                    print(f"  Texture: {node.name} -> {node.image.name} ({node.image.filepath})")

if "Raptor" in bpy.data.filepath:
    analyze_model("Raptor Raider")
elif "Desert" in bpy.data.filepath:
    analyze_model("Desert Barrage Rover")
