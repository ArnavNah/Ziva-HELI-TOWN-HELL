extends SceneTree
const PACK := [
	["Iron Viper", "iron_viper_visuals", "attack_gunship"],
	["Crimson Desert", "crimson_desert_visuals", "rocket_gunship"],
	["Desert Rotorblade", "desert_rotorblade_boss_visuals", "heavy_gunship_boss"],
	["Crimson Skyblade", "crimson_skyblade_visuals", "interceptor"],
	["Astra Viper", "astra_viper_visuals", "escort_fighter"],
	["Ironclad Skyrunner", "ironclad_skyrunner_visuals", "attack_wing"],
	["Ironclad Skycarrier", "ironclad_skycarrier_visuals", "heavy_bomber"],
	["Viperhawk", "viperhawk_gunship_visuals", "torpedo_vtol / stealth_vtol / minelayer"]
]
var inventory: Array = []
func _initialize() -> void: call_deferred("run")
func nodes(node: Node, result: Array, prefix: String = "") -> void:
	result.append(prefix + str(node.name) + " : " + node.get_class())
	for child in node.get_children(): nodes(child, result, prefix + "  ")
func bounds(node: Node, points: Array[Vector3], relative: Node3D) -> void:
	if node is MeshInstance3D:
		var box: AABB = node.get_aabb()
		for i in range(8): points.append(relative.to_local(node.to_global(box.get_endpoint(i))))
	for child in node.get_children(): bounds(child, points, relative)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/air-model-review"))
	root.size = Vector2i(1600, 1000)
	root.content_scale_size = Vector2i(1600, 1000)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	root.add_child(grid)
	for entry in PACK:
		var column := VBoxContainer.new()
		column.custom_minimum_size = Vector2(400, 495)
		grid.add_child(column)
		var label := Label.new()
		label.text = entry[0]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 21)
		column.add_child(label)
		var sub := Label.new()
		sub.text = entry[2]
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.add_theme_font_size_override("font_size", 12)
		column.add_child(sub)
		var holder := SubViewportContainer.new()
		holder.custom_minimum_size = Vector2(400, 430)
		column.add_child(holder)
		var viewport := SubViewport.new()
		viewport.size = Vector2i(400, 430)
		viewport.own_world_3d = true
		holder.add_child(viewport)
		var world := Node3D.new()
		viewport.add_child(world)
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.background_color = Color("25313b")
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color = Color.WHITE
		environment.environment.ambient_light_energy = 0.65
		world.add_child(environment)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-40, -25, 0)
		light.light_energy = 1.2
		world.add_child(light)
		var rig = load("res://scenes/enemies/air/" + entry[1] + ".tscn").instantiate()
		world.add_child(rig)
		var tree: Array = []
		nodes(rig, tree)
		var points: Array[Vector3] = []
		bounds(rig, points, world)
		var box := AABB(points[0], Vector3.ZERO)
		for point in points: box = box.expand(point)
		var record := {"name":entry[0], "scene":entry[1], "role":entry[2], "tree":tree, "size": [box.size.x, box.size.y, box.size.z], "center":[box.get_center().x, box.get_center().y, box.get_center().z]}
		var rotor = rig.get_node_or_null("RotorController")
		if rotor:
			record["rotor_bindings"] = {}
			record["spin_probe"] = {}
			var before := {}
			for key in ["main_rotor", "tail_rotor", "upper_rotor", "lower_rotor"]:
				record.rotor_bindings[key] = str(rig.get_path_to(rotor.get(key))) if is_instance_valid(rotor.get(key)) else "UNBOUND"
				if is_instance_valid(rotor.get(key)): before[key] = rotor.get(key).transform
			rotor._process(0.03125)
			for key in before:
				var part: Node3D = rotor.get(key)
				var old: Transform3D = before[key]
				var delta_basis: Basis = old.basis.inverse() * part.basis
				record.spin_probe[key] = {"changed": not old.basis.is_equal_approx(part.basis), "pivot_shift":old.origin.distance_to(part.position), "local_delta_degrees":delta_basis.get_euler() * (180.0 / PI)}
				part.transform = old
			rotor.set_process(false)
		inventory.append(record)
		print(entry[0], " size=", box.size, " bindings=", record.get("rotor_bindings", {}))
		var extent := maxf(box.size.x, maxf(box.size.y, box.size.z))
		rig.position -= box.get_center()
		rig.scale *= 7.0 / extent
		rig.position *= 7.0 / extent
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.position = Vector3(8, 6, -10)
		camera.look_at(Vector3.ZERO)
		camera.fov = 40
		camera.current = true
	var file := FileAccess.open("res://artifacts/air-model-review/runtime-inventory.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(inventory, "  "))
	file.close()
	for frame in range(8): await process_frame
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://artifacts/air-model-review/model-contact-sheet.png")
		print("Saved contact sheet")
	quit(0)
