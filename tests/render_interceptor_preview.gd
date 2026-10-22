extends SceneTree

func _init() -> void:
	call_deferred("_setup_and_render")

func _setup_and_render() -> void:
	print("--- RENDERING REFINED INTERCEPTOR IN-ENGINE PREVIEW ---")
	
	var bg_col = Color(0.86, 0.87, 0.89)
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
	env.ambient_light_energy = 0.55
	
	var world_env = WorldEnvironment.new()
	world_env.environment = env
	scene.add_child(world_env)

	# Key Light (Front-left elevated studio sun)
	var sun = DirectionalLight3D.new()
	scene.add_child(sun)
	sun.position = Vector3(-9.0, 15.0, -11.0)
	sun.look_at(Vector3.ZERO, Vector3.UP)
	sun.light_energy = 0.85
	sun.shadow_enabled = false
	
	# Fill Light (Right studio fill)
	var fill_light = DirectionalLight3D.new()
	scene.add_child(fill_light)
	fill_light.position = Vector3(12.0, 10.0, 10.0)
	fill_light.look_at(Vector3.ZERO, Vector3.UP)
	fill_light.light_energy = 0.40
	fill_light.light_color = Color(0.88, 0.90, 0.93)
	
	# Under Fill Light (Simulate subtle bounce under wings)
	var bounce_light = DirectionalLight3D.new()
	scene.add_child(bounce_light)
	bounce_light.position = Vector3(0, -10.0, 0)
	bounce_light.look_at(Vector3.ZERO, Vector3.FORWARD)
	bounce_light.light_energy = 0.25
	bounce_light.light_color = Color(0.85, 0.86, 0.88)
	
	# Load modular visuals scene
	var rig_scene = load("res://scenes/enemies/interceptor_visuals.tscn")
	var rig = rig_scene.instantiate()
	scene.add_child(rig)
	rig.position = Vector3.ZERO
	
	# Check hierarchy
	var airframe = rig.get_node_or_null("Airframe")
	var delta_wings = airframe.get_node_or_null("DeltaWings") if airframe else null
	var weapons = airframe.get_node_or_null("Weapons") if airframe else null
	var tail = airframe.get_node_or_null("VerticalTailFin") if airframe else null
	var exhaust = airframe.get_node_or_null("RearJetExhaust") if airframe else null
	
	print("Airframe: ", airframe != null)
	print("DeltaWings: ", delta_wings != null)
	print("Weapons: ", weapons != null)
	print("VerticalTailFin: ", tail != null)
	print("RearJetExhaust: ", exhaust != null)
	
	# Camera: Front-left three-quarter elevated view (matching concept render)
	var camera = Camera3D.new()
	scene.add_child(camera)
	camera.fov = 29.0
	camera.position = Vector3(-8.8, 6.2, -9.8)
	camera.look_at(Vector3(0, 0.72, -0.45), Vector3.UP)
	camera.current = true
	
	# Wait for frames to render
	for i in range(12):
		await process_frame
	
	# Capture screenshot
	var image = root.get_viewport().get_texture().get_image()
	var output_path = "C:/Users/Prime 3/.gemini/antigravity/brain/246bfbd5-df79-41ad-b1db-2ff3804610f7/interceptor_inengine_render.png"
	var err = image.save_png(output_path)
	if err == OK:
		print("Successfully saved in-engine preview to: ", output_path)
		image.save_png("res://artifacts/interceptor_inengine_render.png")
	else:
		printerr("Failed to save image, error code: ", err)
	
	quit(0)
