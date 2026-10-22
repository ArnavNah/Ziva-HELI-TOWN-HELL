@tool
extends SceneTree

# Separates Desert_Recon_Buggy_Turret into MountMesh and GunMesh
func _init() -> void:
	print("--- SEPARATING SCOUT BUGGY TURRET MESHES ---")
	var gltf = GLTFDocument.new()
	var state = GLTFState.new()
	var err = gltf.append_from_file("res://assets/Enemy/scout_buggy_Game_Asset/Desert_Recon_Buggy_Turret.glb", state)
	if err != OK:
		print("Failed to load Turret GLB:", err)
		quit(1)
		return
	
	var root = gltf.generate_scene(state)
	var mi: MeshInstance3D = null
	for c in root.get_children():
		if c is MeshInstance3D:
			mi = c
			break
	if not mi or not mi.mesh:
		print("No MeshInstance3D in turret GLB")
		quit(1)
		return
	
	var mesh = mi.mesh
	var mat = mi.get_surface_override_material(0)
	if not mat:
		mat = mesh.surface_get_material(0)
	
	var arrays = mesh.surface_get_arrays(0)
	var verts = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var indices = arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	var normals = arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
	var uvs = arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
	
	# Topology island classification
	var tri_count = indices.size() / 3
	var pos_to_tris: Dictionary = {}
	for t in range(tri_count):
		for vi in range(3):
			var idx = indices[t * 3 + vi]
			var p = verts[idx]
			var key = "%0.3f_%0.3f_%0.3f" % [p.x, p.y, p.z]
			if not pos_to_tris.has(key):
				pos_to_tris[key] = []
			pos_to_tris[key].append(t)
	
	var tri_adj: Array = []
	tri_adj.resize(tri_count)
	for t in range(tri_count):
		tri_adj[t] = []
	for key in pos_to_tris:
		var t_list = pos_to_tris[key]
		for t1 in t_list:
			for t2 in t_list:
				if t1 != t2:
					tri_adj[t1].append(t2)
	
	var visited = {}
	var islands = []
	for t in range(tri_count):
		if visited.has(t):
			continue
		var queue = [t]
		visited[t] = true
		var island_tris = []
		while queue.size() > 0:
			var curr = queue.pop_back()
			island_tris.append(curr)
			for neighbor in tri_adj[curr]:
				if not visited.has(neighbor):
					visited[neighbor] = true
					queue.append(neighbor)
		islands.append(island_tris)
	
	# Islands that belong to mount (pedestal, base ring, lower yoke/fork):
	# Islands 0, 11, 13, 18, 27, 30, 32
	var mount_islands = [0, 11, 13, 18, 27, 30, 32]
	var mount_tris_set = {}
	for isl_idx in mount_islands:
		for t in islands[isl_idx]:
			mount_tris_set[t] = true
	
	# Mount base center in source coords: (0.0158, 0.0, -0.0107)
	# Trunnion center in source coords: (0.0068, 0.0547, -0.0114)
	var mount_center = Vector3(0.0158, 0.0, -0.0107)
	var trunnion_center = Vector3(0.0068, 0.0547, -0.0114)
	
	# Build Mount ArrayMesh (centered at mount_center)
	var mount_verts = PackedVector3Array()
	var mount_normals = PackedVector3Array()
	var mount_uvs = PackedVector2Array()
	var mount_indices = PackedInt32Array()
	
	var gun_verts = PackedVector3Array()
	var gun_normals = PackedVector3Array()
	var gun_uvs = PackedVector2Array()
	var gun_indices = PackedInt32Array()
	
	for t in range(tri_count):
		var is_mount = mount_tris_set.has(t)
		for vi in range(3):
			var idx = indices[t * 3 + vi]
			var v = verts[idx]
			var n = normals[idx] if normals.size() > idx else Vector3.UP
			var uv = uvs[idx] if uvs.size() > idx else Vector2.ZERO
			
			if is_mount:
				# Offset so mount yaw pivot is at (0, 0, 0)
				mount_verts.append(v - mount_center)
				mount_normals.append(n)
				mount_uvs.append(uv)
				mount_indices.append(mount_verts.size() - 1)
			else:
				# Offset so gun pitch pivot is at (0, 0, 0)
				gun_verts.append(v - trunnion_center)
				gun_normals.append(n)
				gun_uvs.append(uv)
				gun_indices.append(gun_verts.size() - 1)
	
	print("Mount mesh: tris =", mount_indices.size() / 3, "verts =", mount_verts.size())
	print("Gun mesh: tris =", gun_indices.size() / 3, "verts =", gun_verts.size())
	
	var mount_mesh = ArrayMesh.new()
	var mount_arrays = []
	mount_arrays.resize(Mesh.ARRAY_MAX)
	mount_arrays[Mesh.ARRAY_VERTEX] = mount_verts
	mount_arrays[Mesh.ARRAY_NORMAL] = mount_normals
	mount_arrays[Mesh.ARRAY_TEX_UV] = mount_uvs
	mount_arrays[Mesh.ARRAY_INDEX] = mount_indices
	mount_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mount_arrays)
	mount_mesh.surface_set_material(0, mat)
	
	var gun_mesh = ArrayMesh.new()
	var gun_arrays = []
	gun_arrays.resize(Mesh.ARRAY_MAX)
	gun_arrays[Mesh.ARRAY_VERTEX] = gun_verts
	gun_arrays[Mesh.ARRAY_NORMAL] = gun_normals
	gun_arrays[Mesh.ARRAY_TEX_UV] = gun_uvs
	gun_arrays[Mesh.ARRAY_INDEX] = gun_indices
	gun_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, gun_arrays)
	gun_mesh.surface_set_material(0, mat)
	
	# Save meshes to resources
	ResourceSaver.save(mount_mesh, "res://assets/Enemy/scout_buggy_Game_Asset/turret_mount.res")
	ResourceSaver.save(gun_mesh, "res://assets/Enemy/scout_buggy_Game_Asset/turret_gun.res")
	print("Successfully saved turret_mount.res and turret_gun.res")
	
	# Check Muzzle position relative to trunnion_center:
	# Barrel tip in source: (0.0182, 0.0950, -0.2959)
	var muzzle_local = Vector3(0.0182, 0.0950, -0.2959) - trunnion_center
	print("Muzzle position relative to GunPitch:", muzzle_local)
	
	# Trunnion position relative to mount_center:
	var trunnion_rel_mount = trunnion_center - mount_center
	print("Trunnion position relative to TurretMount:", trunnion_rel_mount)
	
	quit()
