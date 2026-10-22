
import bpy

print("--- BLENDER SCENE INSPECTION ---")
for obj in bpy.data.objects:
    print(f"Object: {obj.name}, type: {obj.type}, parent: {obj.parent.name if obj.parent else 'None'}")
    if obj.type == 'MESH':
        print(f"  Vertices: {len(obj.data.vertices)}, Polygons: {len(obj.data.polygons)}")
        # Check vertex groups / loose parts
