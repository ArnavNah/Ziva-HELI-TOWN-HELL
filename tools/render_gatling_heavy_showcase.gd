extends SceneTree

func _init() -> void:
	print("--- Rendering Gatling Heavy 3D Showcase ---")
	var runner = ShowcaseRunner.new()
	root.add_child(runner)

class ShowcaseRunner extends Node:
	var frame: int = 0
	var vehicle: Node3D = null

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

		# Plain Light-Gray Environment
		var world_env := WorldEnvironment.new()
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.86, 0.87, 0.89) # Plain light-gray background
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.82, 0.83, 0.85)
		env.ambient_light_energy = 0.65
		world_env.environment = env
		add_child(world_env)

		# Soft Neutral Key Light
		var key_light := DirectionalLight3D.new()
		key_light.rotation_degrees = Vector3(-38.0, 42.0, 0.0)
		key_light.light_energy = 1.05
		key_light.light_color = Color(1.0, 0.99, 0.97)
		key_light.shadow_enabled = true
		key_light.shadow_bias = 0.03
		add_child(key_light)

		# Soft Fill Light
		var fill_light := DirectionalLight3D.new()
		fill_light.rotation_degrees = Vector3(-25.0, -135.0, 0.0)
		fill_light.light_energy = 0.45
		fill_light.light_color = Color(0.85, 0.88, 0.92)
		fill_light.shadow_enabled = false
		add_child(fill_light)

		# Instantiate Vehicle
		var scene_res = load("res://scenes/enemies/gatling_heavy_visuals.tscn")
		vehicle = scene_res.instantiate()
		add_child(vehicle)

		# Camera: Front Three-Quarter View, viewed slightly from above
		var cam := Camera3D.new()
		cam.fov = 38.0 # Medium-telephoto perspective for clear orthographic-like silhouette
		cam.position = Vector3(6.8, 5.0, -8.2)
		cam.current = true
		add_child(cam)
		var look_target := Vector3(0.0, 1.4, -0.2)
		cam.look_at(look_target, Vector3.UP)

		DirAccess.make_dir_recursive_absolute("res://artifacts")

	func _process(_delta: float) -> void:
		frame += 1
		if frame == 12:
			var img = get_viewport().get_texture().get_image()
			if img and not img.is_empty():
				img.save_png("res://artifacts/gatling_heavy_3d_render.png")
				print("Saved res://artifacts/gatling_heavy_3d_render.png")
			get_tree().quit(0)
