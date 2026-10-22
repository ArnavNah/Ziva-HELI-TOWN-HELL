@tool
extends SceneTree

func _init() -> void:
	var gltf = GLTFDocument.new()
	var state = GLTFState.new()
	gltf.append_from_file("res://assets/Enemy/scout_buggy_Game_Asset/Desert_Recon_Buggy_Body.glb", state)
	var root = gltf.generate_scene(state)
	var body_mi: MeshInstance3D = root.get_node("Desert_Recon_Buggy_Body")
	var arrays = body_mi.mesh.surface_get_arrays(0)
	var verts = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	
	# For outer vertices (|x| > 0.18):
	# Let's inspect bottom profile along Z (e.g. min Y for each Z slice):
	var z_slices = {} # z_slice_index -> min_y
	for v in verts:
		if absf(v.x) > 0.18:
			var zi = int(round(v.z * 100.0))
			if not z_slices.has(zi) or v.y > z_slices[zi]: # finding the top of the wheel arch
				# In a wheel arch, the fender cut is higher in Y than the bottom rocker sill!
				pass
	
	# Let's find vertices forming circular/cylindrical arches in the fenders:
	# Fenders are at abs(x) > 0.19.
	# Let's print out all vertices at abs(x) > 0.20 and y between -0.18 and -0.05:
	var fender_verts = []
	for v in verts:
		if absf(v.x) > 0.20 and v.y < 0.0:
			fender_verts.append(v)
	print("Fender vertices count:", fender_verts.size())
	
	# Let's cluster fender verts by Z to find front and rear wheel well centers:
	var front_verts = []
	var rear_verts = []
	for v in fender_verts:
		if v.z < 0.0:
			front_verts.append(v)
		else:
			rear_verts.append(v)
	
	# Fit circle to front_verts (in Y, Z plane):
	var f_z_avg = 0.0
	var f_y_avg = 0.0
	for v in front_verts:
		f_z_avg += v.z
		f_y_avg += v.y
	if front_verts.size() > 0:
		f_z_avg /= front_verts.size()
		f_y_avg /= front_verts.size()
	
	var r_z_avg = 0.0
	var r_y_avg = 0.0
	for v in rear_verts:
		r_z_avg += v.z
		r_y_avg += v.y
	if rear_verts.size() > 0:
		r_z_avg /= rear_verts.size()
		r_y_avg /= rear_verts.size()
		
	print("Front fender cluster: Z avg =", f_z_avg, " Y avg =", f_y_avg, " count =", front_verts.size())
	print("Rear fender cluster: Z avg =", r_z_avg, " Y avg =", r_y_avg, " count =", rear_verts.size())
	
	# Let's inspect min/max Z of the arches:
	var f_z_min = 1e9
	var f_z_max = -1e9
	for v in front_verts:
		f_z_min = minf(f_z_min, v.z)
		f_z_max = maxf(f_z_max, v.z)
	print("Front arch Z range: [", f_z_min, " .. ", f_z_max, "] -> center Z =", (f_z_min + f_z_max) * 0.5, "length =", f_z_max - f_z_min)
	
	var r_z_min = 1e9
	var r_z_max = -1e9
	for v in rear_verts:
		r_z_min = minf(r_z_min, v.z)
		r_z_max = maxf(r_z_max, v.z)
	print("Rear arch Z range: [", r_z_min, " .. ", r_z_max, "] -> center Z =", (r_z_min + r_z_max) * 0.5, "length =", r_z_max - r_z_min)
	
	# Also find Turret mounting surface:
	# Roof surface: vertices around Y > 0.12, abs(x) < 0.10, z between -0.1 and +0.3
	var roof_verts = []
	for v in verts:
		if v.y > 0.12 and absf(v.x) < 0.10:
			roof_verts.append(v)
	print("Roof vertices (Y > 0.12, |x| < 0.10): count =", roof_verts.size())
	var roof_y_max = -1e9
	var roof_highest = Vector3.ZERO
	for v in roof_verts:
		if v.y > roof_y_max:
			roof_y_max = v.y
			roof_highest = v
	print("Roof highest pt:", roof_highest)
	
	quit()
