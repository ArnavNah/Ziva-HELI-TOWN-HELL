extends SceneTree

func _init() -> void:
	var root_node = Node3D.new()
	root.add_child(root_node)

	var env_node = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("1a2228")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("405060")
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env_node.environment = env
	root_node.add_child(env_node)

	var sun = DirectionalLight3D.new()
	sun.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(45)) * Basis(Vector3.RIGHT, deg_to_rad(-35)), Vector3(5, 10, 5))
	sun.light_color = Color("fff8ee")
	sun.light_energy = 1.5
	sun.shadow_enabled = false
	root_node.add_child(sun)

	var fill = DirectionalLight3D.new()
	fill.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(-135)) * Basis(Vector3.RIGHT, deg_to_rad(-25)), Vector3(-5, 6, -5))
	fill.light_color = Color("8ad4eb")
	fill.light_energy = 0.8
	root_node.add_child(fill)

	var player = load("res://scenes/player/player.tscn").instantiate()
	root_node.add_child(player)
	player.position = Vector3(0, 0, 0)

	var cam = Camera3D.new()
	root_node.add_child(cam)
	cam.position = Vector3(2.4, 1.4, -2.8)
	cam.look_at_from_position(Vector3(2.4, 1.4, -2.8), Vector3(0, 0.4, 0))
	cam.fov = 40.0
	cam.current = true

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img = root.get_texture().get_image()
	img.save_png("res://artifacts/current_player_render.png")
	print("Captured current_player_render.png")
	quit(0)
