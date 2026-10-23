extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func capture(path: String) -> void:
	for i in range(12): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("CAPTURE ", path)
func run() -> void:
	if OS.get_environment("ZIVA_TEST_DATA_DIR").is_empty():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/feature-expansion"))
	var gm = root.get_node("GameManager")
	var director = root.get_node("CombatDirector")
	for biome in ["town", "desert", "harbor"]:
		gm.selected_biome = biome
		var game = load("res://scenes/main_game.tscn").instantiate()
		root.add_child(game)
		current_scene = game
		while not game.session_started: await process_frame
		director.stop_wave_director()
		for enemy in get_nodes_in_group("enemies"): enemy.queue_free()
		await process_frame
		var player = game.get_node("PlayerHelicopter")
		player.set_physics_process(false)
		player.velocity = Vector3.ZERO
		var mission = game.get_node("MissionManager")
		mission.set_process(false)
		mission.cancel_mission("Visual fixture", false)
		var camera = player.get_node("PlayerCamera")
		if biome == "town":
			director.current_wave = 2
			await physics_frame
			if not mission.start_mission("rooftop_supply"):
				push_error("No rooftop supply site for render")
				quit(1)
				return
			player.global_position = mission.objective_site.global_position + Vector3(0, 12, 12)
			camera.init_camera(player)
			await capture("res://artifacts/feature-expansion/rooftop-supply.png")
			mission.cancel_mission("visual fixture", false)
			player.current_hull = 35
			player.max_hull = 100
			player.take_damage(100.0)
			var missile = load("res://scenes/combat/projectile.tscn").instantiate()
			game.add_child(missile)
			missile.is_homing = true
			missile.target_node = player
			missile.global_position = player.global_position + Vector3(20, 0, -8)
			missile.velocity = Vector3(-40, 0, 0)
			missile.set_physics_process(false)
			game.get_node("UI/CombatHUD").missile_scan_timer = 0
			game.get_node("UI/CombatHUD")._update_missile_warnings(0.1)
			await capture("res://artifacts/feature-expansion/emergency-missile.png")
			if "--emergency-only" in OS.get_cmdline_user_args():
				game.queue_free()
				await process_frame
				quit(0)
				return
		else:
			var boss = load("res://src/enemies/boss/modular_fortress_boss.gd").new()
			boss.fortress_kind = "ground" if biome == "desert" else "air"
			boss.position = Vector3(0, 0.5 if biome == "desert" else 26, 0)
			game.add_child(boss)
			boss.set_process(false)
			player.global_position = Vector3(0, 15 if biome == "desert" else 36, 32)
			camera.init_camera(player)
			# Allow lighting preset transition to settle, using the rendered game's clock.
			for i in range(190): await process_frame
			await capture("res://artifacts/feature-expansion/" + biome + "-boss.png")
			if biome == "desert":
				var weather = game.get_node("WeatherSystem")
				weather.biome_clock = 46
				weather.sandstorm_active = true
				weather._apply_biome_weather()
				for i in range(190): await process_frame
				await capture("res://artifacts/feature-expansion/desert-sandstorm.png")
			else:
				player.global_position = Vector3(76, 20, 30)
				camera.init_camera(player)
				await capture("res://artifacts/feature-expansion/harbor-docks.png")
		game.queue_free()
		await process_frame
		for missile in get_nodes_in_group("combat_projectiles"): missile.queue_free()
	gm.selected_biome = "town"
	var selection = load("res://src/ui/menus/vehicle_selection_menu.gd").new()
	selection.size = Vector2(root.size)
	root.add_child(selection)
	await capture("res://artifacts/feature-expansion/sortie-selection.png")
	root.size = Vector2i(960, 540)
	await capture("res://artifacts/feature-expansion/sortie-selection-960.png")
	selection.queue_free()
	await process_frame
	quit(0)
