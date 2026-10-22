extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var root3d = Node3D.new()
	root.add_child(root3d)
	
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 45, 0)
	root3d.add_child(light)
	
	var mount_mesh = load("res://assets/Enemy/scout_buggy_Game_Asset/turret_mount.res")
	var gun_mesh = load("res://assets/Enemy/scout_buggy_Game_Asset/turret_gun.res")
	
	var turret = Node3D.new()
	root3d.add_child(turret)
	
	var mount_mi = MeshInstance3D.new()
	mount_mi.mesh = mount_mesh
	turret.add_child(mount_mi)
	
	var gun_pitch = Node3D.new()
	gun_pitch.position = Vector3(-0.009, 0.0547, -0.0007)
	turret.add_child(gun_pitch)
	
	var recoil = Node3D.new()
	gun_pitch.add_child(recoil)
	
	var gun_mi = MeshInstance3D.new()
	gun_mi.mesh = gun_mesh
	recoil.add_child(gun_mi)
	
	var muzzle = Marker3D.new()
	muzzle.position = Vector3(0.0114, 0.0403, -0.2845)
	recoil.add_child(muzzle)
	
	# Add a red marker ball at the muzzle so we can visually verify muzzle position!
	var ball = MeshInstance3D.new()
	var s_mesh = SphereMesh.new()
	s_mesh.radius = 0.008
	s_mesh.height = 0.016
	var red_mat = StandardMaterial3D.new()
	red_mat.albedo_color = Color.RED
	red_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ball.mesh = s_mesh
	ball.material_override = red_mat
	muzzle.add_child(ball)
	
	var cam = Camera3D.new()
	root3d.add_child(cam)
	cam.position = Vector3(0.35, 0.15, -0.35)
	cam.look_at(Vector3(0, 0.06, 0), Vector3.UP)
	cam.make_current()
	
	# 1. Level pitch
	gun_pitch.rotation_degrees.x = 0
	for i in 4:
		await process_frame
	var img0 = root.get_viewport().get_texture().get_image()
	img0.save_png("res://artifacts/turret_pitch_0.png")
	print("Saved turret_pitch_0.png")
	
	# 2. Elevated pitch (+30 deg)
	gun_pitch.rotation_degrees.x = 30
	for i in 4:
		await process_frame
	var img30 = root.get_viewport().get_texture().get_image()
	img30.save_png("res://artifacts/turret_pitch_30.png")
	print("Saved turret_pitch_30.png")
	
	quit(0)
