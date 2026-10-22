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
	
	# Let's find vertices around front fender:
	# Front fender is around Z = -0.30, X = +/- 0.22, Y = -0.10 to 0.05
	var front_fender = []
	for v in verts:
		if absf(v.x) > 0.16 and v.z < -0.15 and v.z > -0.45:
			front_fender.append(v)
			
	var rear_fender = []
	for v in verts:
		if absf(v.x) > 0.16 and v.z > 0.05 and v.z < 0.40:
			rear_fender.append(v)
			
	print("Front fender verts:", front_fender.size())
	print("Rear fender verts:", rear_fender.size())
	
	# Find min and max for both:
	var f_min = Vector3(1e9, 1e9, 1e9)
	var f_max = Vector3(-1e9, -1e9, -1e9)
	for v in front_fender:
		f_min.x = minf(f_min.x, absf(v.x))
		f_max.x = maxf(f_max.x, absf(v.x))
		f_min.y = minf(f_min.y, v.y)
		f_max.y = maxf(f_max.y, v.y)
		f_min.z = minf(f_min.z, v.z)
		f_max.z = maxf(f_max.z, v.z)
	print("Front fender: |X| in [", f_min.x, "..", f_max.x, "], Y in [", f_min.y, "..", f_max.y, "], Z in [", f_min.z, "..", f_max.z, "]")
	print("Front fender Z opening:", f_max.z - f_min.z)
	
	var r_min = Vector3(1e9, 1e9, 1e9)
	var r_max = Vector3(-1e9, -1e9, -1e9)
	for v in rear_fender:
		r_min.x = minf(r_min.x, absf(v.x))
		r_max.x = maxf(r_max.x, absf(v.x))
		r_min.y = minf(r_min.y, v.y)
		r_max.y = maxf(r_max.y, v.y)
		r_min.z = minf(r_min.z, v.z)
		r_max.z = maxf(r_max.z, v.z)
	print("Rear fender: |X| in [", r_min.x, "..", r_max.x, "], Y in [", r_min.y, "..", r_max.y, "], Z in [", r_min.z, "..", r_max.z, "]")
	print("Rear fender Z opening:", r_max.z - r_min.z)
	
	# Let's find the apex of the wheel arch (highest Y of the arch opening)
	# and the center of the arch:
	# The arch top is typically between Y = -0.05 and 0.02
	var front_arch_center_z = (f_min.z + f_max.z) * 0.5
	var rear_arch_center_z = (r_min.z + r_max.z) * 0.5
	print("Front arch estimated center Z:", front_arch_center_z)
	print("Rear arch estimated center Z:", rear_arch_center_z)
	
	quit()
