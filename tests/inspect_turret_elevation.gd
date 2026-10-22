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
	
	# Let's inspect vertices by Y height:
	# What parts are below Y = 0.05 vs above Y = 0.05?
	print("--- TURRET VERTICES DISTRIBUTION ---")
	var y_buckets = {}
	for p in verts:
		var b = int(p.y * 100.0) / 100.0
		y_buckets[b] = y_buckets.get(b, 0) + 1
	var sorted_keys = y_buckets.keys()
	sorted_keys.sort()
	for k in sorted_keys:
		print("Y [", k, " to ", k + 0.01, "]: ", y_buckets[k], " verts")
	
	quit()
