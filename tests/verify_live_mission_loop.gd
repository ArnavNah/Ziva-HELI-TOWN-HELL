extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	if OS.get_environment("ZIVA_TEST_DATA_DIR").is_empty():
		push_error("Set ZIVA_TEST_DATA_DIR")
		quit(1)
		return
	var game = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.session_started: await process_frame
	var gm = root.get_node("GameManager")
	var initial_time: float = gm.run_time
	while gm.run_time - initial_time < 7.0 and gm.current_state == gm.RunState.ACTIVE:
		await process_frame
	var manager = game.get_node("MissionManager")
	var ok: bool = manager.is_mission_active and manager.active_mission_id == "rescue_crew" and manager.owned_sites.size() == 2 and manager.has_node("MissionTracker")
	print("LIVE_MISSION_LOOP: active=", manager.is_mission_active, " id=", manager.active_mission_id, " sites=", manager.owned_sites.size(), " seconds=", gm.run_time - initial_time)
	if not ok: push_error("Automatic mission loop did not create a real rescue and delivery objective")
	root.get_node("CombatDirector").stop_wave_director()
	game.queue_free()
	await process_frame
	quit(0 if ok else 1)
