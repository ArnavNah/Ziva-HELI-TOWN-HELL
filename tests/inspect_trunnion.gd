@tool
extends SceneTree

func _init() -> void:
	var gltf = GLTFDocument.new()
	var state = GLTFState.new()
	gltf.append_from_file("res://assets/Enemy/scout_buggy_Game_Asset/Desert_Recon_Buggy_Turret.glb", state)
	var root = gltf.generate_scene(state)
	var mi: MeshInstance3D = null
	for c in root.get_children():
		if c is MeshInstance3D:
			mi = c
			break
	var arrays = mi.mesh.surface_get_arrays(0)
	var verts = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var indices = arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	
	print("--- INSPECTING TRUNNION GEOMETRY ---")
	# Find vertices around Y = 0.05 to 0.06, X between -0.02 and 0.05, Z between -0.04 and 0.02
	var trunnion_verts = []
	for v in verts:
		if v.y >= 0.048 and v.y <= 0.062 and absf(v.z - (-0.010)) < 0.03:
			trunnion_verts.append(v)
	print("Trunnion region verts:", trunnion_verts.size())
	if trunnion_verts.size() > 0:
		var avg = Vector3.ZERO
		for v in trunnion_verts:
			avg += v
		avg /= trunnion_verts.size()
		print("Trunnion estimated center:", avg)
	quit()
