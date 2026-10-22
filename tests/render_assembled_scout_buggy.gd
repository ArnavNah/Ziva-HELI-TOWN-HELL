extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var root3d = Node3D.new()
	root.add_child(root3d)
	
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 50, 0)
	root3d.add_child(light)
	
	var ground = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(25, 25)
	var g_mat = StandardMaterial3D.new()
	g_mat.albedo_color = Color(0.22, 0.24, 0.22)
	ground.mesh = plane_mesh
	ground.material_override = g_mat
	root3d.add_child(ground)
	
	var gltf_b = GLTFDocument.new()
	var state_b = GLTFState.new()
	gltf_b.append_from_file("res://assets/Enemy/scout_buggy_Game_Asset/Desert_Recon_Buggy_Body.glb", state_b)
	var body_scene = gltf_b.generate_scene(state_b)
	
	var tire_mesh = load("res://assets/Enemy/scout_buggy_Game_Asset/tire_mesh_reduced.res")
	var mount_mesh = load("res://assets/Enemy/scout_buggy_Game_Asset/turret_mount.res")
	var gun_mesh = load("res://assets/Enemy/scout_buggy_Game_Asset/turret_gun.res")
	
	var buggy = Node3D.new()
	buggy.name = "ScoutBuggyAssembled"
	root3d.add_child(buggy)
	
	var visuals = Node3D.new()
	visuals.name = "Visuals"
	buggy.add_child(visuals)
	
	var scale_val = 4.0
	
	var body_node = Node3D.new()
	body_node.name = "BodyModel"
	body_node.position = Vector3(0, 1.18, 0)
	body_node.scale = Vector3(scale_val, scale_val, scale_val)
	body_node.add_child(body_scene)
	visuals.add_child(body_node)
	
	var wheels = Node3D.new()
	wheels.name = "Wheels"
	visuals.add_child(wheels)
	
	# With wheel radius = 0.50m (diameter 1.0m):
	var wheel_radius = 0.50
	var tire_norm_scale = (wheel_radius * 2.0) / 0.956 # ~1.046
	
	var wheel_configs = [
		{"name": "FrontLeft",  "pos": Vector3(-0.88, wheel_radius, -1.20), "is_front": true,  "is_left": true},
		{"name": "FrontRight", "pos": Vector3( 0.88, wheel_radius, -1.20), "is_front": true,  "is_left": false},
		{"name": "RearLeft",   "pos": Vector3(-0.88, wheel_radius,  0.89), "is_front": false, "is_left": true},
		{"name": "RearRight",  "pos": Vector3( 0.88, wheel_radius,  0.89), "is_front": false, "is_left": false},
	]
	
	for cfg in wheel_configs:
		var steer_or_spin: Node3D
		if cfg["is_front"]:
			var steer = Node3D.new()
			steer.name = cfg["name"] + "Steer"
			steer.position = cfg["pos"]
			wheels.add_child(steer)
			var spin = Node3D.new()
			spin.name = cfg["name"] + "Spin"
			steer.add_child(spin)
			steer_or_spin = spin
		else:
			var spin = Node3D.new()
			spin.name = cfg["name"] + "Spin"
			spin.position = cfg["pos"]
			wheels.add_child(spin)
			steer_or_spin = spin
		
		var wm = MeshInstance3D.new()
		wm.name = "WheelModel"
		wm.mesh = tire_mesh
		wm.scale = Vector3(tire_norm_scale, tire_norm_scale, tire_norm_scale)
		if cfg["is_left"]:
			wm.rotation_degrees.y = -90.0
		else:
			wm.rotation_degrees.y = 90.0
		steer_or_spin.add_child(wm)
	
	# Turret
	var turret = Node3D.new()
	turret.name = "Turret"
	turret.position = Vector3(0.0, 1.764, 0.52)
	turret.scale = Vector3(scale_val, scale_val, scale_val)
	buggy.add_child(turret)
	
	var mount_mi = MeshInstance3D.new()
	mount_mi.name = "MountModel"
	mount_mi.mesh = mount_mesh
	turret.add_child(mount_mi)
	
	var gun_pitch = Node3D.new()
	gun_pitch.name = "GunPitch"
	gun_pitch.position = Vector3(-0.009, 0.0547, -0.0007)
	turret.add_child(gun_pitch)
	
	var recoil = Node3D.new()
	recoil.name = "Recoil"
	gun_pitch.add_child(recoil)
	
	var gun_mi = MeshInstance3D.new()
	gun_mi.name = "GunModel"
	gun_mi.mesh = gun_mesh
	recoil.add_child(gun_mi)
	
	var muzzle = Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0.0114, 0.0403, -0.2845)
	recoil.add_child(muzzle)
	
	var cam = Camera3D.new()
	root3d.add_child(cam)
	
	# 1. Isometric angle
	cam.position = Vector3(4.5, 3.0, -4.5)
	cam.look_at(Vector3(0, 1.0, 0), Vector3.UP)
	cam.make_current()
	for i in 4:
		await process_frame
	var img_iso = root.get_viewport().get_texture().get_image()
	img_iso.save_png("res://artifacts/scout_buggy_assembled_iso.png")
	
	# 2. Side profile
	cam.position = Vector3(5.5, 1.2, 0.0)
	cam.look_at(Vector3(0, 1.0, 0), Vector3.UP)
	for i in 4:
		await process_frame
	var img_side = root.get_viewport().get_texture().get_image()
	img_side.save_png("res://artifacts/scout_buggy_assembled_side.png")
	
	# 3. Front profile
	cam.position = Vector3(0.0, 1.3, -5.5)
	cam.look_at(Vector3(0, 1.0, 0), Vector3.UP)
	for i in 4:
		await process_frame
	var img_front = root.get_viewport().get_texture().get_image()
	img_front.save_png("res://artifacts/scout_buggy_assembled_front.png")
	
	print("Saved updated assembly renders!")
	quit(0)
