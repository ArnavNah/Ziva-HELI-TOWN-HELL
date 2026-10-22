extends SceneTree

func _init() -> void:
	call_deferred("_setup_and_render")

func _setup_and_render() -> void:
	print("--- RENDERING CALIBRATED GATLING HEAVY IN-ENGINE PREVIEW ---")
	
	var bg_col = Color(0.85, 0.86, 0.88)
	RenderingServer.set_default_clear_color(bg_col)
	
	# Create root 3D scene
	var scene = Node3D.new()
	root.add_child(scene)
	
	# Environment with plain neutral light-gray background & soft studio lighting
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = bg_col
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.80, 0.83)
	env.ambient_light_energy = 0.45
	
	var world_env = WorldEnvironment.new()
	world_env.environment = env
	scene.add_child(world_env)
	
	# Ground Plane for soft contact shadow
	var ground_mesh = PlaneMesh.new()
	ground_mesh.size = Vector2(300.0, 300.0)
	var ground_mat = StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.80, 0.81, 0.83)
	ground_mat.roughness = 1.0
	var ground_inst = MeshInstance3D.new()
	ground_inst.mesh = ground_mesh
	ground_inst.material_override = ground_mat
	ground_inst.position = Vector3(0, 0, 0)
	scene.add_child(ground_inst)

	# Key Light (Elevated front-left sun with soft shadow)
	var sun = DirectionalLight3D.new()
	scene.add_child(sun)
	sun.position = Vector3(10.0, 15.0, -10.0)
	sun.look_at(Vector3.ZERO, Vector3.UP)
	sun.light_energy = 0.72
	sun.shadow_enabled = true
	sun.shadow_blur = 1.8
	
	# Fill Light (Subtle right fill)
	var fill_light = DirectionalLight3D.new()
	scene.add_child(fill_light)
	fill_light.position = Vector3(-10.0, 8.0, 8.0)
	fill_light.look_at(Vector3.ZERO, Vector3.UP)
	fill_light.light_energy = 0.25
	fill_light.light_color = Color(0.88, 0.90, 0.93)
	
	# Load modular visuals scene directly
	var rig_scene = load("res://scenes/enemies/gatling_heavy_visuals.tscn")
	var rig = rig_scene.instantiate()
	scene.add_child(rig)
	rig.position = Vector3.ZERO
	
	# Turret slight yaw to emphasize 3D depth and profile
	var turret = rig.get_node_or_null("Turret")
	if turret:
		turret.rotation_degrees.y = -7.0
	
	# Elevated front three-quarter camera centered on the entire vehicle
	var camera = Camera3D.new()
	scene.add_child(camera)
	camera.fov = 30.0
	camera.position = Vector3(9.8, 7.2, -10.8)
	camera.look_at(Vector3(0, 1.15, -0.9), Vector3.UP)
	camera.current = true
	
	# Wait for frames to render and shadows to update
	for i in range(12):
		await process_frame
	
	# Capture screenshot
	var image = root.get_viewport().get_texture().get_image()
	var output_path = "C:/Users/Prime 3/.gemini/antigravity/brain/7fe842b3-2e28-4d17-b446-0deca635b154/gatling_heavy_inengine_render.png"
	var err = image.save_png(output_path)
	if err == OK:
		print("Successfully saved in-engine preview to: ", output_path)
	else:
		printerr("Failed to save image, error code: ", err)
	
	quit(0)
