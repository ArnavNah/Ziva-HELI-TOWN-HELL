@tool
extends SceneTree

func _init() -> void:
	print("--- EXTRACTING TANK MESHES AND MATERIALS ---")
	var tanks = [
		{
			"folder": "azure_siege_tank",
			"assembled_glb": "res://assets/Enemy/enemy_tanks/azure_siege_tank/tank_assembled.glb",
			"out_dir": "res://assets/Enemy/enemy_tanks/azure_siege_tank/"
		},
		{
			"folder": "desert_ironclad",
			"assembled_glb": "res://assets/Enemy/enemy_tanks/desert_ironclad/tank_assembled.glb",
			"out_dir": "res://assets/Enemy/enemy_tanks/desert_ironclad/"
		},
		{
			"folder": "ironclad_sentinel",
			"assembled_glb": "res://assets/Enemy/enemy_tanks/ironclad_sentinel/tank_assembled.glb",
			"out_dir": "res://assets/Enemy/enemy_tanks/ironclad_sentinel/"
		}
	]
	
	for t in tanks:
		var scene = load(t["assembled_glb"]) as PackedScene
		if not scene:
			print("ERROR loading ", t["assembled_glb"])
			continue
		var root = scene.instantiate()
		
		# Find Body, Turret_Mesh, Gun_Mesh
		var body_node = root.find_child("Body", true, false) as MeshInstance3D
		var turret_node = root.find_child("Turret_Mesh", true, false) as MeshInstance3D
		var gun_node = root.find_child("Gun_Mesh", true, false) as MeshInstance3D
		
		print("Tank: ", t["folder"])
		print("  Body mesh: ", body_node.mesh.resource_name if body_node else "null")
		print("  Turret mesh: ", turret_node.mesh.resource_name if turret_node else "null")
		print("  Gun mesh: ", gun_node.mesh.resource_name if gun_node else "null")
		
		# Check shared material
		var mat = body_node.mesh.surface_get_material(0)
		print("  Shared Material: ", mat.resource_name if mat else "null")
		if mat is StandardMaterial3D:
			print("    Albedo texture: ", mat.albedo_texture.resource_path if mat.albedo_texture else "none")
			print("    Normal texture: ", mat.normal_texture.resource_path if mat.normal_texture else "none")
			print("    ORM texture: ", mat.metallic_texture.resource_path if mat.metallic_texture else "none")
		
		# Save shared material
		var mat_path = t["out_dir"] + "tank_material.tres"
		var err = ResourceSaver.save(mat, mat_path)
		print("  Saved material: ", mat_path, " (err=", err, ")")
		
		# Save body mesh
		var body_mesh = body_node.mesh
		body_mesh.surface_set_material(0, mat)
		var body_path = t["out_dir"] + "body_mesh.res"
		err = ResourceSaver.save(body_mesh, body_path)
		print("  Saved body mesh: ", body_path, " (err=", err, ")")
		
		# Save turret mesh
		var turret_mesh = turret_node.mesh
		turret_mesh.surface_set_material(0, mat)
		var turret_path = t["out_dir"] + "turret_mesh.res"
		err = ResourceSaver.save(turret_mesh, turret_path)
		print("  Saved turret mesh: ", turret_path, " (err=", err, ")")
		
		# Save gun mesh
		var gun_mesh = gun_node.mesh
		gun_mesh.surface_set_material(0, mat)
		var gun_path = t["out_dir"] + "gun_mesh.res"
		err = ResourceSaver.save(gun_mesh, gun_path)
		print("  Saved gun mesh: ", gun_path, " (err=", err, ")")
		
		root.free()
		
	# For Sentinel, also extract gun_housing and gun_barrels meshes
	var sentinel_housing_scene = load("res://assets/Enemy/enemy_tanks/ironclad_sentinel/gun_housing.glb") as PackedScene
	var sentinel_barrels_scene = load("res://assets/Enemy/enemy_tanks/ironclad_sentinel/gun_barrels.glb") as PackedScene
	var sentinel_mat = load("res://assets/Enemy/enemy_tanks/ironclad_sentinel/tank_material.tres") as Material
	
	if sentinel_housing_scene:
		var h_root = sentinel_housing_scene.instantiate()
		var h_mesh_inst = h_root.find_child("*", true, false) as MeshInstance3D
		if h_mesh_inst:
			var h_mesh = h_mesh_inst.mesh
			h_mesh.surface_set_material(0, sentinel_mat)
			var h_path = "res://assets/Enemy/enemy_tanks/ironclad_sentinel/gun_housing_mesh.res"
			var err = ResourceSaver.save(h_mesh, h_path)
			print("Saved Sentinel gun_housing_mesh.res (err=", err, ")")
		h_root.free()
		
	if sentinel_barrels_scene:
		var b_root = sentinel_barrels_scene.instantiate()
		var b_mesh_inst = b_root.find_child("*", true, false) as MeshInstance3D
		if b_mesh_inst:
			var b_mesh = b_mesh_inst.mesh
			b_mesh.surface_set_material(0, sentinel_mat)
			var b_path = "res://assets/Enemy/enemy_tanks/ironclad_sentinel/gun_barrels_mesh.res"
			var err = ResourceSaver.save(b_mesh, b_path)
			print("Saved Sentinel gun_barrels_mesh.res (err=", err, ")")
		b_root.free()

	print("--- EXTRACTION COMPLETE ---")
	quit(0)
