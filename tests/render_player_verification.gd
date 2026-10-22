extends SceneTree

const ARTIFACT_DIR = "C:/Users/Prime 3/.gemini/antigravity/brain/7fe842b3-2e28-4d17-b446-0deca635b154"

func _init() -> void:
	print("--- Starting Player Helicopter Verification & Render ---")
	call_deferred("_setup_and_render")

func _setup_and_render() -> void:
	var root_node = Node3D.new()
	root.add_child(root_node)
	current_scene = root_node

	# World environment & Sun
	var env = WorldEnvironment.new()
	var env_res = Environment.new()
	env_res.background_mode = Environment.BG_COLOR
	env_res.background_color = Color(0.45, 0.62, 0.78, 1.0)
	env_res.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env_res.ambient_light_color = Color(0.65, 0.72, 0.80, 1.0)
	env_res.ambient_light_energy = 1.0
	env_res.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = env_res
	root_node.add_child(env)

	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, 48.0, 0.0)
	sun.light_color = Color(1.0, 0.96, 0.88, 1.0)
	sun.light_energy = 2.2
	sun.shadow_enabled = true
	root_node.add_child(sun)

	# Fill light
	var fill = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(25.0, -135.0, 0.0)
	fill.light_color = Color(0.4, 0.55, 0.7, 1.0)
	fill.light_energy = 0.8
	root_node.add_child(fill)

	# Ground grid plane for realistic shadow & ground reflection
	var ground = MeshInstance3D.new()
	var gmesh = PlaneMesh.new()
	gmesh.size = Vector2(80, 80)
	var gmat = StandardMaterial3D.new()
	gmat.albedo_color = Color(0.22, 0.28, 0.20, 1.0)
	gmat.roughness = 0.95
	ground.mesh = gmesh
	ground.position.y = -2.5
	root_node.add_child(ground)

	# Instantiate Player Helicopter
	var player_scene = load("res://scenes/player/player.tscn")
	var player = player_scene.instantiate()
	root_node.add_child(player)
	player.position = Vector3(0, 1.5, 0)

	# Camera for rendering
	var camera = Camera3D.new()
	camera.current = true
	camera.fov = 42.0
	root_node.add_child(camera)

	# Let the scene settle
	await create_timer(0.4).timeout
	for f in range(20):
		player._process(0.016)
		await process_frame

	# Verify orientation & components
	var visual_hull = player.get_node_or_null("Visuals")
	var body = visual_hull.find_child("Helicopter_Body", true, false) if visual_hull else null
	var main_r = visual_hull.find_child("Main_Rotor", true, false) if visual_hull else null
	var tail_r = visual_hull.find_child("Tail_Rotor", true, false) if visual_hull else null

	print("Visual Hull found: ", visual_hull != null)
	print("Body Mesh found: ", body != null)
	print("Main Rotor found: ", main_r != null)
	print("Tail Rotor found: ", tail_r != null)

	# Angle 1: Close-up 3/4 Front View (Nose, Canopy, Blades, Weapons)
	camera.position = Vector3(4.8, 2.6, -5.8)
	camera.look_at(Vector3(0, 1.4, -0.6), Vector3.UP)
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	_save_viewport_image(ARTIFACT_DIR + "/pristine_heli_front_34.png")
	print("Captured pristine_heli_front_34.png")

	# Angle 2: Close-up Rear-Quarter View (Tail boom, Tail rotor, Exhausts, Spine)
	camera.position = Vector3(-5.2, 3.2, 6.2)
	camera.look_at(Vector3(0, 1.8, 1.8), Vector3.UP)
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	_save_viewport_image(ARTIFACT_DIR + "/pristine_heli_rear_tail.png")
	print("Captured pristine_heli_rear_tail.png")

	# Angle 3: Chase Cam Combat Flight Perspective (Gameplay angle)
	camera.position = Vector3(0.0, 4.2, 9.5)
	camera.look_at(Vector3(0, 1.4, -2.5), Vector3.UP)
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	_save_viewport_image(ARTIFACT_DIR + "/pristine_heli_combat_cam.png")
	print("Captured pristine_heli_combat_cam.png")

	print("--- Verification & Renders Complete ---")
	quit(0)

func _save_viewport_image(path: String) -> void:
	var vp = root.get_viewport()
	var tex = vp.get_texture()
	var img = tex.get_image()
	if img:
		img.save_png(path)
