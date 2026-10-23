extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", message)
	if not ok:
		failures += 1

func run() -> void:
	if OS.get_environment("ZIVA_TEST_DATA_DIR").is_empty():
		quit(2)
		return
	root.size = Vector2i(1280, 720)
	var flow = root.get_node("UIFlow")
	root.get_node("GameManager").selected_biome = "town"
	for phase in ["request", "resources", "roads", "blocks", "dressing", "reveal", "blocks"]:
		# A cold road cache makes the road-generation yield observable even on retry.
		load("res://src/world/city_generator.gd").road_mesh_cache.clear()
		flow.begin_run("apache")
		var deadline := Time.get_ticks_msec() + 30000
		var found := false
		while flow.busy and Time.get_ticks_msec() < deadline:
			await process_frame
			if is_instance_valid(flow.loader) and ((phase == "request" and flow.loader.phase == flow.loader.Phase.REQUESTING) or (phase == "resources" and flow.loader.phase == flow.loader.Phase.RESOURCES)):
				flow.return_to_menu()
				found = true
				break
			var game = current_scene
			var city = game.get_node_or_null("CityGenerator") if game else null
			if city:
				var ratio: float = city.generation_ratio
				found = (phase == "roads" and ratio < 0.22) or (phase == "blocks" and ratio >= 0.22 and ratio < 0.80) or (phase == "dressing" and ratio >= 0.80 and ratio < 1.0) or (phase == "reveal" and is_instance_valid(flow.loader) and flow.loader.phase == flow.loader.Phase.REVEAL)
				if found:
					flow.return_to_menu()
					break
		check(found, "cancellation exercised during " + phase)
		if not found:
			flow.return_to_menu()
		deadline = Time.get_ticks_msec() + 10000
		while flow.busy and Time.get_ticks_msec() < deadline:
			await process_frame
		for i in 10:
			await process_frame
		check(not flow.busy and current_scene.name == "MainMenu" and not paused, "menu recovers after " + phase + " cancellation")
		check(get_nodes_in_group("xp_drops").is_empty() and get_nodes_in_group("combat_projectiles").is_empty(), "no combat transients survive " + phase + " cancellation")
	flow.begin_run("apache")
	var deadline := Time.get_ticks_msec() + 30000
	while flow.busy and Time.get_ticks_msec() < deadline:
		await process_frame
	check(not flow.busy and current_scene.name == "MainGame" and current_scene.is_prepared and current_scene.session_started, "normal deployment succeeds after repeated cancellations")
	flow.return_to_menu()
	for i in 20:
		await process_frame
	print("GENERATION_CANCELLATION ", checks - failures, "/", checks)
	await load("res://tests/runtime_cleanup.gd").finish(self, 0 if failures == 0 else 1)
