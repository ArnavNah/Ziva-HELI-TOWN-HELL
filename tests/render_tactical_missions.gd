extends SceneTree

func _init() -> void:
	call_deferred("run")

func capture(path: String) -> void:
	for i in range(12): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("CAPTURE ", path)

func run() -> void:
	if OS.get_environment("ZIVA_TEST_DATA_DIR").is_empty():
		push_error("Set ZIVA_TEST_DATA_DIR for mission rendering")
		quit(1)
		return
	seed(231023)
	var game = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.session_started: await process_frame
	await physics_frame
	await physics_frame
	var manager = game.get_node("MissionManager")
	manager.set_process(false)
	var player = game.get_node("PlayerHelicopter")
	player.set_process(false)
	player.set_physics_process(false)
	var camera = player.get_node("PlayerCamera")
	root.get_node("CombatDirector").stop_wave_director()
	root.get_node("CombatDirector").current_wave = 3
	for key in ["medevac", "escort_convoy", "destroy_radar", "sortie_extraction"]:
		if not manager.start_mission(key):
			print("PLACEMENT DEBUG ", manager.placement_diagnostics, " state=", root.get_node("GameManager").current_state, " paused=", paused)
			push_error("Could not place " + key)
			quit(1)
			return
		var framing := Vector3(14, 15, 16) if key in ["escort_convoy", "destroy_radar"] else Vector3(8, 15, 6)
		player.global_position = manager.objective_site.global_position + framing
		camera.init_camera(player)
		manager._process_active_mission(0.1)
		await capture("res://artifacts/mission-pass-20261023/" + key + "-1280.png")
		if key == "medevac":
			root.size = Vector2i(960, 540)
			await capture("res://artifacts/mission-pass-20261023/medevac-960.png")
			root.size = Vector2i(1280, 720)
			manager._process_active_mission(4.1)
			player.global_position = manager.objective_site.global_position + Vector3(0, 15, 8)
			camera.init_camera(player)
			await capture("res://artifacts/mission-pass-20261023/delivery-1280.png")
		if key == "sortie_extraction":
			manager._process_active_mission(5.1)
			await capture("res://artifacts/mission-pass-20261023/extraction-confirm-1280.png")
		manager.cancel_mission("Preview complete", false)
	game.queue_free()
	await process_frame
	quit(0)
