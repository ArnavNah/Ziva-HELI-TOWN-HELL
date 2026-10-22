@tool
extends SceneTree

func _init() -> void:
	var gltf = GLTFDocument.new()
	var state = GLTFState.new()
	var err = gltf.append_from_file("res://assets/Enemy/scout_buggy_Game_Asset/Desert_Recon_Buggy_Tire.glb", state)
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
	var uvs = arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
	
	print("Tire vertices:", verts.size(), "triangles:", indices.size() / 3)
	
	# Let's inspect the radii of vertices from the center (X, Y)
	# Since thin axis is Z:
	# r = sqrt(x^2 + y^2)
	var r_min = 1e9
	var r_max = -1e9
	for p in verts:
		var r = sqrt(p.x * p.x + p.y * p.y)
		r_min = minf(r_min, r)
		r_max = maxf(r_max, r)
	print("Tire radius from center: min r =", r_min, "max r =", r_max)
	print("Tire Z thickness: min z =", mi.mesh.get_aabb().position.z, "max z =", mi.mesh.get_aabb().end.z, "thickness =", mi.mesh.get_aabb().size.z)
	
	quit()
