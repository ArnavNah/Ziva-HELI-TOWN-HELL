@tool
extends SceneTree

func _init() -> void:
	var gltf_orig = GLTFDocument.new()
	var state_orig = GLTFState.new()
	gltf_orig.append_from_file("res://assets/Enemy/scout_buggy_Game_Asset/Desert_Recon_Buggy_Tire.glb", state_orig)
	var orig_root = gltf_orig.generate_scene(state_orig)
	var orig_mi: MeshInstance3D = null
	for c in orig_root.get_children():
		if c is MeshInstance3D:
			orig_mi = c
			break
	var tire_mat = orig_mi.mesh.surface_get_material(0)
	print("Original Tire Material:", tire_mat)
	if tire_mat is StandardMaterial3D:
		print("Albedo tex:", tire_mat.albedo_texture)
		print("Normal tex:", tire_mat.normal_texture)
		print("ORM tex:", tire_mat.roughness_texture)
	
	# Load reduced tire
	var gltf_red = GLTFDocument.new()
	var state_red = GLTFState.new()
	gltf_red.append_from_file("res://assets/Enemy/scout_buggy_Game_Asset/Desert_Recon_Buggy_Tire_Reduced.glb", state_red)
	var red_root = gltf_red.generate_scene(state_red)
	var red_mi: MeshInstance3D = null
	for c in red_root.get_children():
		if c is MeshInstance3D:
			red_mi = c
			break
	if not red_mi and red_root is MeshInstance3D:
		red_mi = red_root
	
	# Apply material
	red_mi.mesh.surface_set_material(0, tire_mat)
	ResourceSaver.save(red_mi.mesh, "res://assets/Enemy/scout_buggy_Game_Asset/tire_mesh_reduced.res")
	print("Saved tire_mesh_reduced.res with original PBR material!")
	quit()
