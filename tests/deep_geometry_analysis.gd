@tool
extends SceneTree

func _init() -> void:
	print("--- DEEP GEOMETRY ANALYSIS ---")
	_analyze_turret()
	_analyze_body()
	_analyze_tire()
	quit()

func _analyze_turret() -> void:
	print("\n--- TURRET GEOMETRY ANALYSIS ---")
	var gltf = GLTFDocument.new()
	var state = GLTFState.new()
	var err = gltf.append_from_file("res://assets/Enemy/scout_buggy_Game_Asset/Desert_Recon_Buggy_Turret.glb", state)
	if err != OK:
		print("Failed to load turret GLB")
		return
	var root = gltf.generate_scene(state)
	var mi: MeshInstance3D = null
	for child in root.get_children():
		if child is MeshInstance3D:
			mi = child
			break
	if not mi:
		print("No MeshInstance3D found in turret")
		return
	
	var mesh = mi.mesh
	var arrays = mesh.surface_get_arrays(0)
	var verts = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var indices = arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	
	print("Turret vertices:", verts.size(), "Indices:", indices.size(), "Triangles:", indices.size() / 3)
	
	# Connected components (islands)
	# Build adjacency graph
	var tri_count = indices.size() / 3
	var vert_to_tris: Dictionary = {} # vert_idx -> Array of tri_idx
	for t in range(tri_count):
		var i0 = indices[t * 3 + 0]
		var i1 = indices[t * 3 + 1]
		var i2 = indices[t * 3 + 2]
		for v in [i0, i1, i2]:
			if not vert_to_tris.has(v):
				vert_to_tris[v] = []
			vert_to_tris[v].append(t)
	
	# But vertices with identical positions should be welded for topological island finding!
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
	
	# BFS for islands
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
	
	print("Found", islands.size(), "mesh islands (disconnected parts):")
	for i in range(islands.size()):
		var itris = islands[i]
		var min_p = Vector3(1e9, 1e9, 1e9)
		var max_p = Vector3(-1e9, -1e9, -1e9)
		for t in itris:
			for vi in range(3):
				var p = verts[indices[t * 3 + vi]]
				min_p.x = minf(min_p.x, p.x)
				min_p.y = minf(min_p.y, p.y)
				min_p.z = minf(min_p.z, p.z)
				max_p.x = maxf(max_p.x, p.x)
				max_p.y = maxf(max_p.y, p.y)
				max_p.z = maxf(max_p.z, p.z)
		print(" Island #", i, ": tris=", itris.size(), " Bounds min=", min_p, " max=", max_p, " size=", max_p - min_p)
	
	# Find barrel tip (lowest Z, since barrel points towards -Z)
	var min_z = 1e9
	var barrel_tip = Vector3.ZERO
	for p in verts:
		if p.z < min_z:
			min_z = p.z
			barrel_tip = p
	print("Turret most forward point (-Z):", barrel_tip)
	
	# Find mount ring center at lowest Y (around Y=0)
	var base_ring_verts = []
	for p in verts:
		if p.y < 0.01:
			base_ring_verts.append(p)
	var base_center = Vector3.ZERO
	if base_ring_verts.size() > 0:
		for p in base_ring_verts:
			base_center += p
		base_center /= base_ring_verts.size()
	print("Turret base ring center (Y < 0.01):", base_center, "count:", base_ring_verts.size())

func _analyze_body() -> void:
	print("\n--- BODY GEOMETRY ANALYSIS ---")
	var gltf = GLTFDocument.new()
	var state = GLTFState.new()
	var err = gltf.append_from_file("res://assets/Enemy/scout_buggy_Game_Asset/Desert_Recon_Buggy_Body.glb", state)
	if err != OK:
		return
	var root = gltf.generate_scene(state)
	for child in root.get_children():
		if child is MeshInstance3D:
			var aabb = child.mesh.get_aabb()
			print("Child:", child.name, "AABB:", aabb, "Size:", aabb.size)

func _analyze_tire() -> void:
	print("\n--- TIRE GEOMETRY ANALYSIS ---")
	var gltf = GLTFDocument.new()
	var state = GLTFState.new()
	var err = gltf.append_from_file("res://assets/Enemy/scout_buggy_Game_Asset/Desert_Recon_Buggy_Tire.glb", state)
	if err != OK:
		return
	var root = gltf.generate_scene(state)
	for child in root.get_children():
		if child is MeshInstance3D:
			var aabb = child.mesh.get_aabb()
			print("Child:", child.name, "AABB:", aabb, "Size:", aabb.size)
