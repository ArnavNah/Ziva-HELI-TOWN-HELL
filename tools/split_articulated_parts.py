import bpy
import bmesh
import os

def split_raptor():
    blend_path = os.path.abspath(r"assets/Enemy/new ground/Raptor_Raider/Raptor_Raider_Separated.blend")
    out_dir = os.path.abspath(r"assets/Enemy/new ground/Raptor_Raider")
    bpy.ops.wm.open_mainfile(filepath=blend_path)
    
    # 1. Export Chassis
    chassis = bpy.data.objects.get("Chassis")
    bpy.ops.object.select_all(action='DESELECT')
    chassis.select_set(True)
    bpy.context.view_layer.objects.active = chassis
    chassis_out = os.path.join(out_dir, "raptor_chassis.glb")
    bpy.ops.export_scene.gltf(filepath=chassis_out, use_selection=True, export_materials='EXPORT', export_format='GLB')
    print(f"Exported Raptor chassis to {chassis_out}")
    
    # 2. Split Gun_Turret
    turret = bpy.data.objects.get("Gun_Turret")
    bpy.ops.object.select_all(action='DESELECT')
    turret.select_set(True)
    bpy.context.view_layer.objects.active = turret
    
    bm = bmesh.new()
    bm.from_mesh(turret.data)
    visited = set()
    islands = []
    for f in bm.faces:
        if f in visited: continue
        isl = []
        q = [f]
        visited.add(f)
        while q:
            curr = q.pop()
            isl.append(curr)
            for e in curr.edges:
                for lf in e.link_faces:
                    if lf not in visited:
                        visited.add(lf)
                        q.append(lf)
        islands.append(isl)
    
    gun_island_indices = {5, 9, 11, 12, 17, 18, 20, 22}
    base_island_indices = set(range(len(islands))) - gun_island_indices
    
    # Duplicate object for base
    base_obj = turret.copy()
    base_obj.data = turret.data.copy()
    base_obj.name = "raptor_turret_base"
    bpy.context.collection.objects.link(base_obj)
    
    # Duplicate object for gun
    gun_obj = turret.copy()
    gun_obj.data = turret.data.copy()
    gun_obj.name = "raptor_turret_gun"
    bpy.context.collection.objects.link(gun_obj)
    
    # In base_obj, delete gun faces
    bm_base = bmesh.new()
    bm_base.from_mesh(base_obj.data)
    # Find gun faces in bm_base
    del_faces = []
    # Identify by face center match
    gun_centers = set(tuple(round(coord, 4) for coord in f.calc_center_median()) for idx in gun_island_indices for f in islands[idx])
    for f in bm_base.faces:
        c = tuple(round(coord, 4) for coord in f.calc_center_median())
        if c in gun_centers:
            del_faces.append(f)
    bmesh.ops.delete(bm_base, geom=del_faces, context='FACES')
    bm_base.to_mesh(base_obj.data)
    base_obj.data.update()
    bm_base.free()
    
    # In gun_obj, delete base faces
    bm_gun = bmesh.new()
    bm_gun.from_mesh(gun_obj.data)
    del_faces_b = []
    base_centers = set(tuple(round(coord, 4) for coord in f.calc_center_median()) for idx in base_island_indices for f in islands[idx])
    for f in bm_gun.faces:
        c = tuple(round(coord, 4) for coord in f.calc_center_median())
        if c in base_centers:
            del_faces_b.append(f)
    bmesh.ops.delete(bm_gun, geom=del_faces_b, context='FACES')
    bm_gun.to_mesh(gun_obj.data)
    gun_obj.data.update()
    bm_gun.free()
    
    print(f"Raptor base mesh has {len(base_obj.data.polygons)} faces (expected 815)")
    print(f"Raptor gun mesh has {len(gun_obj.data.polygons)} faces (expected 432)")
    assert len(base_obj.data.polygons) == 815
    assert len(gun_obj.data.polygons) == 432
    
    # Export base
    bpy.ops.object.select_all(action='DESELECT')
    base_obj.select_set(True)
    bpy.context.view_layer.objects.active = base_obj
    base_out = os.path.join(out_dir, "raptor_turret_base.glb")
    bpy.ops.export_scene.gltf(filepath=base_out, use_selection=True, export_materials='EXPORT', export_format='GLB')
    print(f"Exported Raptor turret base to {base_out}")
    
    # Export gun
    bpy.ops.object.select_all(action='DESELECT')
    gun_obj.select_set(True)
    bpy.context.view_layer.objects.active = gun_obj
    gun_out = os.path.join(out_dir, "raptor_turret_gun.glb")
    bpy.ops.export_scene.gltf(filepath=gun_out, use_selection=True, export_materials='EXPORT', export_format='GLB')
    print(f"Exported Raptor turret gun to {gun_out}")
    bm.free()

def split_desert():
    blend_path = os.path.abspath(r"assets/Enemy/new ground/Desert_Barrage_Rover/Desert_Barrage_Rover_Separated.blend")
    out_dir = os.path.abspath(r"assets/Enemy/new ground/Desert_Barrage_Rover")
    bpy.ops.wm.open_mainfile(filepath=blend_path)
    
    # 1. Export Chassis
    chassis = bpy.data.objects.get("Chassis")
    bpy.ops.object.select_all(action='DESELECT')
    chassis.select_set(True)
    bpy.context.view_layer.objects.active = chassis
    chassis_out = os.path.join(out_dir, "desert_chassis.glb")
    bpy.ops.export_scene.gltf(filepath=chassis_out, use_selection=True, export_materials='EXPORT', export_format='GLB')
    print(f"Exported Desert chassis to {chassis_out}")
    
    # 2. Split Launcher
    launcher = bpy.data.objects.get("Missile_Barrage_Launcher")
    bm = bmesh.new()
    bm.from_mesh(launcher.data)
    visited = set()
    islands = []
    for f in bm.faces:
        if f in visited: continue
        isl = []
        q = [f]
        visited.add(f)
        while q:
            curr = q.pop()
            isl.append(curr)
            for e in curr.edges:
                for lf in e.link_faces:
                    if lf not in visited:
                        visited.add(lf)
                        q.append(lf)
        islands.append(isl)
        
    base_islands = {2, 5, 6, 7, 8, 9, 10, 11, 13, 14, 20, 22, 24, 27, 30}
    pod_islands = set(range(len(islands))) - base_islands
    
    base_obj = launcher.copy()
    base_obj.data = launcher.data.copy()
    base_obj.name = "desert_launcher_base"
    bpy.context.collection.objects.link(base_obj)
    
    pod_obj = launcher.copy()
    pod_obj.data = launcher.data.copy()
    pod_obj.name = "desert_launcher_pods"
    bpy.context.collection.objects.link(pod_obj)
    
    # In base_obj, delete pod faces
    bm_base = bmesh.new()
    bm_base.from_mesh(base_obj.data)
    pod_centers = set(tuple(round(coord, 4) for coord in f.calc_center_median()) for idx in pod_islands for f in islands[idx])
    del_faces_p = [f for f in bm_base.faces if tuple(round(coord, 4) for coord in f.calc_center_median()) in pod_centers]
    bmesh.ops.delete(bm_base, geom=del_faces_p, context='FACES')
    bm_base.to_mesh(base_obj.data)
    base_obj.data.update()
    bm_base.free()
    
    # In pod_obj, delete base faces
    bm_pod = bmesh.new()
    bm_pod.from_mesh(pod_obj.data)
    base_centers = set(tuple(round(coord, 4) for coord in f.calc_center_median()) for idx in base_islands for f in islands[idx])
    del_faces_b = [f for f in bm_pod.faces if tuple(round(coord, 4) for coord in f.calc_center_median()) in base_centers]
    bmesh.ops.delete(bm_pod, geom=del_faces_b, context='FACES')
    bm_pod.to_mesh(pod_obj.data)
    pod_obj.data.update()
    bm_pod.free()
    
    print(f"Desert base mesh has {len(base_obj.data.polygons)} faces (expected 664)")
    print(f"Desert pod mesh has {len(pod_obj.data.polygons)} faces (expected 1812)")
    assert len(base_obj.data.polygons) == 664
    assert len(pod_obj.data.polygons) == 1812
    
    # Export base
    bpy.ops.object.select_all(action='DESELECT')
    base_obj.select_set(True)
    bpy.context.view_layer.objects.active = base_obj
    base_out = os.path.join(out_dir, "desert_launcher_base.glb")
    bpy.ops.export_scene.gltf(filepath=base_out, use_selection=True, export_materials='EXPORT', export_format='GLB')
    print(f"Exported Desert launcher base to {base_out}")
    
    # Export pods
    bpy.ops.object.select_all(action='DESELECT')
    pod_obj.select_set(True)
    bpy.context.view_layer.objects.active = pod_obj
    pod_out = os.path.join(out_dir, "desert_launcher_pods.glb")
    bpy.ops.export_scene.gltf(filepath=pod_out, use_selection=True, export_materials='EXPORT', export_format='GLB')
    print(f"Exported Desert launcher pods to {pod_out}")
    bm.free()

if __name__ == '__main__':
    split_raptor()
    split_desert()
    print("ALL ARTICULATED GLBS EXPORTED SUCCESSFULLY")
