@tool
extends SceneTree

func _init() -> void:
	print("--- VERIFYING REDUCED TIRE GLB ---")
	var gltf = GLTFDocument.new()
	var state = GLTFState.new()
	var err = gltf.append_from_file("res://assets/Enemy/scout_buggy_Game_Asset/Desert_Recon_Buggy_Tire_Reduced.glb", state)
	if err != OK:
		print("ERROR loading reduced tire GLTF:", err)
		quit(1)
		return
	var root = gltf.generate_scene(state)
	var mi: MeshInstance3D = null
	for c in root.get_children():
		if c is MeshInstance3D:
			mi = c
			break
	if not mi:
		# Maybe root itself or child
		print("Looking for MeshInstance3D...")
	print("Reduced tire node:", mi.name if mi else "null")
	if mi and mi.mesh:
		print("Reduced tire mesh class:", mi.mesh.get_class())
		print("Reduced tire AABB:", mi.mesh.get_aabb())
		print("Surface count:", mi.mesh.get_surface_count())
		var arrays = mi.mesh.surface_get_arrays(0)
		var verts = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var indices = arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		var uvs = arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
		print("Verts:", verts.size(), "Indices:", indices.size(), "Tris:", indices.size() / 3, "UVs:", uvs.size())
	quit()
