@tool
extends SceneTree

func _init() -> void:
	print("--- INSPECTING SCOUT BUGGY ASSETS ---")
	var paths = {
		"Body": "res://assets/Enemy/scout_buggy_Game_Asset/Desert_Recon_Buggy_Body.glb",
		"Tire": "res://assets/Enemy/scout_buggy_Game_Asset/Desert_Recon_Buggy_Tire.glb",
		"Turret": "res://assets/Enemy/scout_buggy_Game_Asset/Desert_Recon_Buggy_Turret.glb"
	}
	
	for key in paths:
		var path: String = paths[key]
		print("\n====================", key, "====================")
		print("Path:", path)
		if not FileAccess.file_exists(path):
			print("ERROR: File does not exist:", path)
			continue
		
		var inst: Node = null
		if ResourceLoader.exists(path):
			var packed_scene = ResourceLoader.load(path) as PackedScene
			if packed_scene:
				inst = packed_scene.instantiate()
		
		if not inst:
			var gltf = GLTFDocument.new()
			var state = GLTFState.new()
			var err = gltf.append_from_file(path, state)
			if err != OK:
				print("ERROR: Failed to load GLTF via GLTFDocument, code:", err)
				continue
			inst = gltf.generate_scene(state)
		
		if not inst:
			print("ERROR: Could not instantiate node for:", path)
			continue
		
		_inspect_node(inst, "")
		inst.free()
	
	quit()

func _inspect_node(node: Node, indent: String) -> void:
	var info = indent + "- " + node.name + " (" + node.get_class() + ")"
	if node is Node3D:
		info += " Pos: " + str(node.position) + " Rot: " + str(node.rotation_degrees) + " Scale: " + str(node.scale)
	print(info)
	
	if node is MeshInstance3D:
		var mesh = node.mesh
		if mesh:
			print(indent + "  Mesh class: " + mesh.get_class() + ", AABB: " + str(mesh.get_aabb()) + ", Size: " + str(mesh.get_aabb().size))
			var total_tris = 0
			var total_verts = 0
			for s in range(mesh.get_surface_count()):
				var p_count = mesh.surface_get_primitive_type(s)
				var arrays = mesh.surface_get_arrays(s)
				var verts = arrays[Mesh.ARRAY_VERTEX] if arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] != null else PackedVector3Array()
				var indices = arrays[Mesh.ARRAY_INDEX] if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				var normals = arrays[Mesh.ARRAY_NORMAL] if arrays.size() > Mesh.ARRAY_NORMAL and arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
				var uvs = arrays[Mesh.ARRAY_TEX_UV] if arrays.size() > Mesh.ARRAY_TEX_UV and arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
				var tri_count = indices.size() / 3 if indices.size() > 0 else verts.size() / 3
				total_tris += tri_count
				total_verts += verts.size()
				var mat = node.get_surface_override_material(s)
				if not mat:
					mat = mesh.surface_get_material(s)
				var mat_info = "null"
				if mat:
					mat_info = mat.resource_name + " (" + mat.get_class() + ")"
					if mat is StandardMaterial3D:
						var tex_name = "none"
						if mat.albedo_texture:
							tex_name = mat.albedo_texture.resource_path
							if tex_name.is_empty():
								tex_name = mat.albedo_texture.resource_name
							if tex_name.is_empty():
								tex_name = "embedded(" + str(mat.albedo_texture.get_width()) + "x" + str(mat.albedo_texture.get_height()) + ")"
						mat_info += " Albedo: " + str(mat.albedo_color) + " Tex: " + tex_name
						mat_info += " Roughness: " + str(mat.roughness) + " Metallic: " + str(mat.metallic)
				print(indent + "  Surface " + str(s) + ": " + str(tri_count) + " tris, " + str(verts.size()) + " verts, Normals: " + str(normals.size()) + ", UVs: " + str(uvs.size()) + ", Material: " + mat_info)
			print(indent + "  TOTAL: " + str(total_tris) + " tris, " + str(total_verts) + " verts")
	
	for child in node.get_children():
		_inspect_node(child, indent + "  ")
