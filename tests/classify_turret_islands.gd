@tool
extends SceneTree

func _init() -> void:
	var gltf = GLTFDocument.new()
	var state = GLTFState.new()
	var err = gltf.append_from_file("res://assets/Enemy/scout_buggy_Game_Asset/Desert_Recon_Buggy_Turret.glb", state)
	var root = gltf.generate_scene(state)
	var mi: MeshInstance3D = null
	for child in root.get_children():
		if child is MeshInstance3D:
			mi = child
			break
	var mesh = mi.mesh
	var arrays = mesh.surface_get_arrays(0)
	var verts = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var indices = arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	
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
	
	print("--- DETAILED ISLAND CLASSIFICATION ---")
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
		var center = (min_p + max_p) * 0.5
		var desc = ""
		if max_p.y <= 0.055 and min_p.y <= 0.02:
			desc = "MOUNT / PEDESTAL BASE"
		elif min_p.z < -0.15:
			desc = "GUN BARREL / FLASH HIDER"
		elif min_p.x < -0.04:
			desc = "AMMO CRADLE / BOX"
		elif center.y > 0.06:
			desc = "GUN RECEIVER / SIGHT / HANDLE"
		else:
			desc = "INTERMEDIATE / PIVOT"
		print("Island %02d: %s | tris=%d, Y=[%0.3f..%0.3f], Z=[%0.3f..%0.3f], X=[%0.3f..%0.3f]" % [
			i, desc, itris.size(), min_p.y, max_p.y, min_p.z, max_p.z, min_p.x, max_p.x
		])
	
	quit()
