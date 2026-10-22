@tool
extends SceneTree

func _init() -> void:
	var gltf = GLTFDocument.new()
	var state = GLTFState.new()
	var err = gltf.append_from_file("res://assets/Enemy/scout_buggy_Game_Asset/Desert_Recon_Buggy_Body.glb", state)
	var root = gltf.generate_scene(state)
	
	var body_mi: MeshInstance3D = root.get_node("Desert_Recon_Buggy_Body")
	var glass_mi: MeshInstance3D = root.get_node("Desert_Recon_Buggy_Glass")
	
	print("--- BODY ORIENTATION AND WHEEL WELL ANALYSIS ---")
	print("Body AABB:", body_mi.mesh.get_aabb())
	print("Glass AABB:", glass_mi.mesh.get_aabb())
	
	# The glass mesh is the windshield / side windows!
	# Let's inspect where the glass is located along Z:
	var glass_aabb = glass_mi.mesh.get_aabb()
	print("Glass Z range: [", glass_aabb.position.z, " .. ", glass_aabb.end.z, "]")
	# Body Z range:
	var body_aabb = body_mi.mesh.get_aabb()
	print("Body Z range: [", body_aabb.position.z, " .. ", body_aabb.end.z, "]")
	
	# Let's check vertices of glass to see if windshield is sloped towards +Z or -Z
	var g_arrays = glass_mi.mesh.surface_get_arrays(0)
	var g_verts = g_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var z_min = 1e9
	var z_max = -1e9
	for v in g_verts:
		z_min = minf(z_min, v.z)
		z_max = maxf(z_max, v.z)
	print("Glass actual Z min:", z_min, "Z max:", z_max)
	
	# Let's check height at z_min vs z_max for glass
	var y_at_min_z = 0.0
	var count_min = 0
	var y_at_max_z = 0.0
	var count_max = 0
	for v in g_verts:
		if absf(v.z - z_min) < 0.05:
			y_at_min_z += v.y
			count_min += 1
		if absf(v.z - z_max) < 0.05:
			y_at_max_z += v.y
			count_max += 1
	print("Glass avg Y at Z_min:", (y_at_min_z / max(1, count_min)), "avg Y at Z_max:", (y_at_max_z / max(1, count_max)))
	
	# Let's inspect the body vertices at lowest Y (underbody) along Z to find wheel well arches
	var b_arrays = body_mi.mesh.surface_get_arrays(0)
	var b_verts = b_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	
	# Find extreme points along X, Y, Z
	var min_pt = Vector3(1e9, 1e9, 1e9)
	var max_pt = Vector3(-1e9, -1e9, -1e9)
	for v in b_verts:
		min_pt.x = minf(min_pt.x, v.x)
		min_pt.y = minf(min_pt.y, v.y)
		min_pt.z = minf(min_pt.z, v.z)
		max_pt.x = maxf(max_pt.x, v.x)
		max_pt.y = maxf(max_pt.y, v.y)
		max_pt.z = maxf(max_pt.z, v.z)
	print("Body bounds: min=", min_pt, " max=", max_pt)
	
	quit()
