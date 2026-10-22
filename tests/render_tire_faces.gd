extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var root3d = Node3D.new()
	root.add_child(root3d)
	
	# Load tire
	var gltf = GLTFDocument.new()
	var state = GLTFState.new()
	gltf.append_from_file("res://assets/Enemy/scout_buggy_Game_Asset/Desert_Recon_Buggy_Tire.glb", state)
	var tire_node = gltf.generate_scene(state)
	root3d.add_child(tire_node)
	
	# Add light
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 45, 0)
	root3d.add_child(light)
	
	# Add Camera looking from +Z
	var cam = Camera3D.new()
	cam.position = Vector3(0, 0, 1.8)
	cam.look_at(Vector3.ZERO, Vector3.UP)
	root3d.add_child(cam)
	cam.make_current()
	
	# Wait 3 frames
	for i in 4:
		await process_frame
	
	DirAccess.make_dir_absolute("res://artifacts")
	var img_pos = root.get_viewport().get_texture().get_image()
	img_pos.save_png("res://artifacts/tire_pos_z.png")
	print("Saved tire_pos_z.png")
	
	# Move camera to -Z
	cam.position = Vector3(0, 0, -1.8)
	cam.look_at(Vector3.ZERO, Vector3.UP)
	for i in 4:
		await process_frame
	var img_neg = root.get_viewport().get_texture().get_image()
	img_neg.save_png("res://artifacts/tire_neg_z.png")
	print("Saved tire_neg_z.png")
	
	quit(0)
