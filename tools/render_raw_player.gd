extends SceneTree

func _initialize() -> void:
	call_deferred("_render")

func _render() -> void:
	root.size = Vector2i(1280, 720)
	var scene = Node3D.new()
	root.add_child(scene)

	var env = WorldEnvironment.new()
	var e = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.2, 0.2, 0.2)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.WHITE
	env.environment = e
	scene.add_child(env)

	var cam = Camera3D.new()
	cam.position = Vector3(0, 0, 5)
	scene.add_child(cam)

	var p = load("res://assets/player/player.glb").instantiate()
	scene.add_child(p)
	p.scale = Vector3.ONE * 2.0

	for _i in range(5):
		await process_frame
	await RenderingServer.frame_post_draw

	var img = root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://artifacts/raw_player_glb.png"))
	print("Saved raw_player_glb.png")
	quit(0)
