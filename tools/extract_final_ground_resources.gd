@tool
extends SceneTree

func _init() -> void:
	print("--- EXTRACTING FINAL GROUND VEHICLE MESHES AND MATERIALS ---")

	# 1. RAPTOR MATERIAL
	var raptor_mat = StandardMaterial3D.new()
	raptor_mat.resource_name = "Raptor_PBR"
	raptor_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	raptor_mat.albedo_texture = load("res://assets/Enemy/new ground/Raptor_Raider/textures/Image_0.jpg")
	raptor_mat.metallic = 1.0
	raptor_mat.metallic_texture = load("res://assets/Enemy/new ground/Raptor_Raider/textures/Image_1.jpg")
	raptor_mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	raptor_mat.roughness_texture = load("res://assets/Enemy/new ground/Raptor_Raider/textures/Image_1.jpg")
	raptor_mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	raptor_mat.normal_enabled = true
	raptor_mat.normal_texture = load("res://assets/Enemy/new ground/Raptor_Raider/textures/Image_2.jpg")
	var err = ResourceSaver.save(raptor_mat, "res://assets/Enemy/new ground/Raptor_Raider/raptor_material.tres")
	print("Saved Raptor material (err=", err, ")")

	# 2. DESERT MATERIAL
	var desert_mat = StandardMaterial3D.new()
	desert_mat.resource_name = "Desert_PBR"
	desert_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	desert_mat.albedo_texture = load("res://assets/Enemy/new ground/Desert_Barrage_Rover/textures/Image_0.jpg")
	desert_mat.metallic = 1.0
	desert_mat.metallic_texture = load("res://assets/Enemy/new ground/Desert_Barrage_Rover/textures/Image_1.jpg")
	desert_mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	desert_mat.roughness_texture = load("res://assets/Enemy/new ground/Desert_Barrage_Rover/textures/Image_1.jpg")
	desert_mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	desert_mat.normal_enabled = true
	desert_mat.normal_texture = load("res://assets/Enemy/new ground/Desert_Barrage_Rover/textures/Image_2.jpg")
	err = ResourceSaver.save(desert_mat, "res://assets/Enemy/new ground/Desert_Barrage_Rover/desert_material.tres")
	print("Saved Desert material (err=", err, ")")

	# Helper to extract mesh from GLTF file
	var extract_mesh = func(glb_path: String, out_res_path: String, mat: Material):
		var doc = GLTFDocument.new()
		var state = GLTFState.new()
		var load_err = doc.append_from_file(glb_path, state)
		if load_err != OK:
			printerr("Failed to load GLTF: ", glb_path)
			return
		var root = doc.generate_scene(state)
		if not root:
			printerr("Failed to generate scene: ", glb_path)
			return
		var mesh_inst = _find_first_mesh_instance(root)
		if not mesh_inst or not mesh_inst.mesh:
			printerr("No mesh found in: ", glb_path)
			root.free()
			return
		var mesh: ArrayMesh = mesh_inst.mesh.duplicate(true)
		for s in range(mesh.get_surface_count()):
			mesh.surface_set_material(s, mat)
		var save_err = ResourceSaver.save(mesh, out_res_path)
		print("Saved ", out_res_path, " aabb=", mesh.get_aabb(), " (err=", save_err, ")")
		root.free()

	# Extract Raptor meshes
	extract_mesh.call("res://assets/Enemy/new ground/Raptor_Raider/raptor_chassis.glb",
		"res://assets/Enemy/new ground/Raptor_Raider/raptor_chassis_mesh.res", raptor_mat)
	extract_mesh.call("res://assets/Enemy/new ground/Raptor_Raider/raptor_turret_base.glb",
		"res://assets/Enemy/new ground/Raptor_Raider/raptor_turret_base_mesh.res", raptor_mat)
	extract_mesh.call("res://assets/Enemy/new ground/Raptor_Raider/raptor_turret_gun.glb",
		"res://assets/Enemy/new ground/Raptor_Raider/raptor_turret_gun_mesh.res", raptor_mat)

	# Extract Desert meshes
	extract_mesh.call("res://assets/Enemy/new ground/Desert_Barrage_Rover/desert_chassis.glb",
		"res://assets/Enemy/new ground/Desert_Barrage_Rover/desert_chassis_mesh.res", desert_mat)
	extract_mesh.call("res://assets/Enemy/new ground/Desert_Barrage_Rover/desert_launcher_base.glb",
		"res://assets/Enemy/new ground/Desert_Barrage_Rover/desert_launcher_base_mesh.res", desert_mat)
	extract_mesh.call("res://assets/Enemy/new ground/Desert_Barrage_Rover/desert_launcher_pods.glb",
		"res://assets/Enemy/new ground/Desert_Barrage_Rover/desert_launcher_pods_mesh.res", desert_mat)

	print("--- EXTRACTION FINISHED ---")
	quit(0)

func _find_first_mesh_instance(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var found = _find_first_mesh_instance(c)
		if found:
			return found
	return null
