extends SceneTree

func _init() -> void:
	var root_node = Node3D.new()
	root.add_child(root_node)

	var env_node = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0a1014")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("202c34")
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env_node.environment = env
	root_node.add_child(env_node)

	var sun = DirectionalLight3D.new()
	sun.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(45)) * Basis(Vector3.RIGHT, deg_to_rad(-35)), Vector3(5, 10, 5))
	sun.light_color = Color("fff8ee")
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	root_node.add_child(sun)

	var fill = DirectionalLight3D.new()
	fill.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(-135)) * Basis(Vector3.RIGHT, deg_to_rad(-25)), Vector3(-5, 6, -5))
	fill.light_color = Color("8ad4eb")
	fill.light_energy = 0.6
	root_node.add_child(fill)

	# Floor
	var floor_m = MeshInstance3D.new()
	var p = PlaneMesh.new()
	p.size = Vector2(20, 20)
	floor_m.mesh = p
	var fmat = StandardMaterial3D.new()
	fmat.albedo_color = Color("12181c")
	floor_m.material_override = fmat
	root_node.add_child(floor_m)

	# Load model
	var heli = load("res://assets/player/player_backup.glb").instantiate()
	root_node.add_child(heli)
	heli.scale = Vector3.ONE * 0.38
	# Rotate to 3/4 front view
	heli.rotation.y = deg_to_rad(-45.0)

	# Apply original 4K textures
	var base_tex = load("res://assets/player/player_backup_apache_basecolor.png")
	var norm_tex = load("res://assets/player/player_backup_apache_normal.png")
	var orm_tex = load("res://assets/player/player_backup_apache_orm.png")

	var mat = StandardMaterial3D.new()
	mat.albedo_texture = base_tex
	mat.normal_enabled = true
	mat.normal_texture = norm_tex
	mat.normal_scale = 1.0
	mat.orm_texture = orm_tex
	mat.metallic = 0.5
	mat.roughness = 0.6
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	var meshes = heli.find_children("", "MeshInstance3D", true, false)
	for m in meshes:
		m.material_override = mat

	var cam = Camera3D.new()
	root_node.add_child(cam)
	cam.position = Vector3(0, 2.0, 5.0)
	cam.look_at_from_position(Vector3(0, 2.0, 5.0), Vector3(0, 0.4, 0))
	cam.fov = 35.0
	cam.current = true

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img = root.get_texture().get_image()
	img.save_png("res://artifacts/test_original_textures_render.png")
	print("Captured test_original_textures_render.png")
	quit(0)
