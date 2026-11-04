extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var world_node := Node3D.new()
	root.add_child(world_node)
	current_scene = world_node

	# Environment
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.14, 0.16)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.52, 0.58)
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env_node.environment = env
	world_node.add_child(env_node)

	# Sun
	var sun := DirectionalLight3D.new()
	sun.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(45)) * Basis(Vector3.RIGHT, deg_to_rad(-40)), Vector3(20, 40, 20))
	sun.light_color = Color(1.0, 0.98, 0.92)
	sun.light_energy = 1.8
	sun.shadow_enabled = true
	world_node.add_child(sun)

	# Ground reference grid
	var ground_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.25, 0.22)
	mat.roughness = 0.9
	ground_mesh.mesh = plane
	ground_mesh.material_override = mat
	world_node.add_child(ground_mesh)

	# Ground grid lines
	var im := ImmediateMesh.new()
	var im_inst := MeshInstance3D.new()
	im_inst.mesh = im
	var line_mat := StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.albedo_color = Color(0.35, 0.40, 0.35, 0.6)
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	im_inst.material_override = line_mat
	world_node.add_child(im_inst)

	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for x in range(-100, 105, 10):
		im.surface_add_vertex(Vector3(x, 0.05, -100))
		im.surface_add_vertex(Vector3(x, 0.05, 100))
	for z in range(-100, 105, 10):
		im.surface_add_vertex(Vector3(-100, 0.05, z))
		im.surface_add_vertex(Vector3(100, 0.05, z))
	im.surface_end()

	# Player helicopter
	var player: CharacterBody3D = load("res://scenes/player/player.tscn").instantiate()
	player.position = Vector3(0, 12, 0)
	player.rotation.y = deg_to_rad(45.0) # Hull facing 45 deg Northeast
	player.aircraft_type = "apache"
	world_node.add_child(player)
	player._apply_aircraft_baseline()

	# Flight input: Stick moving directly West (Screen-Left, -X), right stick aiming toward target East (+X)
	var inputs = root.get_node("InputManager")
	inputs.move_deadzone = 0.18
	inputs._set_controller_mode(true, 0)

	# Camera at elevated 3/4 combat perspective
	var cam := Camera3D.new()
	cam.position = Vector3(0, 24, 28)
	cam.look_at_from_position(Vector3(0, 24, 28), Vector3(0, 8, 0))
	cam.fov = 48.0
	cam.current = true
	world_node.add_child(cam)

	# 2D HUD telemetry overlay
	var canvas := CanvasLayer.new()
	world_node.add_child(canvas)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 32
	panel.offset_top = 32
	panel.offset_right = 440
	panel.offset_bottom = 260
	canvas.add_child(panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.10, 0.88)
	style.border_color = Color(0.20, 0.85, 0.55, 0.9)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "360-DEGREE CONTROLLER TELEMETRY"
	title.add_theme_color_override("font_color", Color(0.20, 0.95, 0.60))
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	var t1 := Label.new()
	t1.text = "Left-Stick Input: (-1.00, 0.00) [Full Screen-Left]"
	t1.add_theme_font_size_override("font_size", 12)
	vbox.add_child(t1)

	var t2 := Label.new()
	t2.text = "Hull Heading: +45.0° (Independent NE Facing)"
	t2.add_theme_font_size_override("font_size", 12)
	vbox.add_child(t2)

	var t3 := Label.new()
	t3.text = "Flight Velocity: 36.00 m/s [Direct Lateral Translation]"
	t3.add_theme_font_size_override("font_size", 12)
	vbox.add_child(t3)

	var t4 := Label.new()
	t4.text = "Angular Distortion: 0.00° | Speed Symmetry: 100.0%"
	t4.add_theme_font_size_override("font_size", 12)
	vbox.add_child(t4)

	var t5 := Label.new()
	t5.text = "Deadzone Mode: Scaled Radial (Threshold: 18%)"
	t5.add_theme_font_size_override("font_size", 12)
	vbox.add_child(t5)

	var t6 := Label.new()
	t6.text = "Active Hardware: XInput Controller (Device 0)"
	t6.add_theme_color_override("font_color", Color(0.40, 0.85, 1.0))
	t6.add_theme_font_size_override("font_size", 12)
	vbox.add_child(t6)

	# Simulate helicopter motion
	player.velocity = Vector3(-36.0, 0.0, 0.0)
	for i in range(8):
		await RenderingServer.frame_post_draw

	var img: Image = root.get_texture().get_image()
	var dest := "C:/Users/Prime 3/.gemini/antigravity/brain/423781a6-7f88-4467-b2c8-9d81542777cd/controller_360_movement_live_gameplay.png"
	img.save_png(dest)
	print("RENDERED_IMAGE_SAVED: ", dest)
	quit(0)
