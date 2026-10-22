@tool
extends SceneTree

func _init() -> void:
	var gltf = GLTFDocument.new()
	var state = GLTFState.new()
	gltf.append_from_file("res://assets/Enemy/scout_buggy_Game_Asset/Desert_Recon_Buggy_Tire.glb", state)
	var root = gltf.generate_scene(state)
	var mi: MeshInstance3D = null
	for c in root.get_children():
		if c is MeshInstance3D:
			mi = c
			break
	var arrays = mi.mesh.surface_get_arrays(0)
	var verts = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var normals = arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
	
	# Check vertices near center (r < 0.25):
	var pos_z_hub = []
	var neg_z_hub = []
	for i in range(verts.size()):
		var p = verts[i]
		var r = sqrt(p.x * p.x + p.y * p.y)
		if r < 0.20:
			if p.z > 0.05:
				pos_z_hub.append(p)
			elif p.z < -0.05:
				neg_z_hub.append(p)
	print("Center hub verts: +Z count =", pos_z_hub.size(), " -Z count =", neg_z_hub.size())
	
	# Let's inspect normal directions of the rim faces
	var pos_z_zmax = -1e9
	for p in pos_z_hub:
		pos_z_zmax = maxf(pos_z_zmax, p.z)
	var neg_z_zmin = 1e9
	for p in neg_z_hub:
		neg_z_zmin = minf(neg_z_zmin, p.z)
	print("+Z hub max z:", pos_z_zmax, "-Z hub min z:", neg_z_zmin)
	
	# Also let's check vertex density or features:
	# Usually the outer hub has lug nuts, brake disc or axle hole on inner side
	print("Outer vs Inner hub analysis completed.")
	quit()
