extends SceneTree
## Runtime integration checks and real renderer captures. Run with --script.
var failures: Array[String] = []
var check_count := 0

func _init() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	check_count += 1
	if not condition:
		failures.append(message)
		push_error(message)

func frames(count: int) -> void:
	for i in count:
		await process_frame

func capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	check(picture != null and not picture.is_empty(), "Rendered frame is nonempty")
	if picture:
		picture.save_png("res://artifacts/" + filename)

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var menu = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await frames(40)
	if not menu is MainMenu:
		push_error("Main menu script did not load")
		quit(1)
		return
	check(menu.start_btn.has_focus(), "Launch starts with keyboard focus")
	check(menu.start_btn.get_global_rect().end.y < 720.0, "Launch button fits design canvas")
	check(menu.exit_btn.get_global_rect().end.y < 720.0, "All menu actions fit design canvas")
	await capture("menu.png")
	var v_menu_init = menu.get_node_or_null("VehicleSelectionMenu")
	if v_menu_init:
		v_menu_init.select_aircraft(1)
		check(v_menu_init.aircraft_title.text == "RAH-66 NIGHTHAWK", "Aircraft selection updates preview caption")
	menu.settings_btn.pressed.emit()
	check(menu.get_node("SettingsMenu").visible, "Settings action opens settings")
	check(menu.start_btn.disabled, "Settings prevents keyboard deployment behind the overlay")
	await frames(3)
	await capture("settings.png")
	menu.get_node("SettingsMenu").toggle_settings()
	menu.hangar_btn.pressed.emit()
	check(menu.get_node("HangarMenu").visible, "Hangar action opens hangar")
	menu.get_node("HangarMenu").hide()
	check(menu.start_btn.has_focus(), "Closing overlays restores keyboard focus")
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	root.push_input(enter)
	await frames(2)
	enter.pressed = false
	root.push_input(enter)
	await frames(4)

	var v_menu = menu.get_node_or_null("VehicleSelectionMenu")
	if v_menu and v_menu.visible:
		v_menu.select_aircraft(1)
		v_menu.deploy_btn.pressed.emit()

	for w in 150:
		if current_scene.name == "MainGame":
			break
		await process_frame

	var game := current_scene
	check(game.name == "MainGame", "Deploy action loads the game")
	check(root.get_node("GameManager").selected_aircraft == "nighthawk", "Aircraft choice reaches gameplay")
	root.get_node("CombatDirector").is_wave_active = false
	var city := game.get_node("CityGenerator")
	while city.is_generating:
		await process_frame
	var maximum_height := 0.0
	for block in city.spawned_blocks:
		if block is DestructibleBuilding:
			maximum_height = maxf(maximum_height, block.building_height)
	check(maximum_height <= 36.0, "Buildings fit tactical flight scale")
	check(game.get_node("Ground/MeshInstance3D").material_override is ShaderMaterial, "Terrain shader is active")
	check(city.has_node("FieldDressing/PineCrowns"), "Batched foliage is generated")
	var spawner := game.get_node("EnemySpawner")
	var new_units: Array[Node3D] = []
	var initial_positions: Array[Vector3] = []
	# Start beyond each role's engagement range; the mortar is meant to hold still in range.
	var movement_starts := {"scout_buggy": Vector3(-2, 1, -112), "mortar_crawler": Vector3(2, 1, -125), "attack_wing": Vector3(12, 26, -112)}
	for role in ["scout_buggy", "mortar_crawler", "attack_wing"]:
		var unit = spawner.spawn_enemy_type(role, movement_starts[role])
		check(unit != null, "Procedural spawn succeeds: " + role)
		if unit:
			new_units.append(unit)
			initial_positions.append(unit.global_position)
			check(unit.variant_id == role, "Spawn retains role: " + role)
			check(unit.get_node("DamageReceiver").current_health > 0, "Spawn has health: " + role)
			check(unit.has_node("Visuals"), "Spawn has geometry: " + role)
	await physics_frame
	# Exercise normal and edge-of-map ground/air requests against real world collision.
	var edge := GameConstants.BOUNDARY_HARD_RADIUS - 20.0
	var spawn_limit := GameConstants.BOUNDARY_HARD_RADIUS - 12.0
	for center in [Vector3.ZERO, Vector3(edge, 14, edge - 8), Vector3(-edge, 14, -edge + 8)]:
		for family in ["ground", "air"]:
			for i in 12:
				var pos: Vector3 = spawner.find_valid_spawn_position(family, center)
				check(pos != Vector3.INF, "Clear spawn found near " + str(center))
				if pos == Vector3.INF:
					continue
				check(absf(pos.x) <= spawn_limit and absf(pos.z) <= spawn_limit, "Spawn remains inside hard boundary")
				check(Vector2(pos.x - center.x, pos.z - center.z).length() > 45.0, "Spawn leaves player reaction distance")
				if family == "ground":
					var box := BoxShape3D.new()
					box.size = Vector3(4, 2, 7)
					var query := PhysicsShapeQueryParameters3D.new()
					query.shape = box
					query.transform.origin = pos + Vector3.UP
					query.collision_mask = 2
					check(game.get_world_3d().direct_space_state.intersect_shape(query).is_empty(), "Ground spawn clears buildings and floor")
	check(spawner.spawn_enemy_type("unknown_unit") == null, "Unknown role is rejected")
	# A readable mixed encounter close enough to inspect in the real gameplay camera.
	spawner.spawn_enemy_type("scout_buggy", Vector3(-3, 1, -32))
	spawner.spawn_enemy_type("flak_tank", Vector3(4, 1, -45))
	spawner.spawn_enemy_type("attack_wing", Vector3(19, 23, -32))
	await frames(50)
	await capture("gameplay.png")
	for i in 360:
		await physics_frame
	for i in new_units.size():
		var unit := new_units[i]
		check(is_instance_valid(unit), "New role survives the movement smoke test")
		if is_instance_valid(unit):
			check(unit.global_position.distance_to(initial_positions[i]) > 2.0, "New role navigates the world: " + unit.variant_id)
	print("POLISH CHECKS: ", check_count - failures.size(), "/", check_count)
	for message in failures:
		print("FAIL: ", message)
	quit(0 if failures.is_empty() else 1)
