extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	print("=== PROFILING PERFORMANCE FACTORS ===")
	# Test 1: Full current game
	var res1 = await measure_config("Full Current Game", func(game): pass)

	# Test 2: Without BattlefieldGrade ColorRect
	var res2 = await measure_config("Without BattlefieldGrade Shader", func(game):
		var grade = game.find_child("BattlefieldGrade", true, false)
		if grade:
			grade.queue_free()
	)

	# Test 3: With Building visibility_range_end = 150m (matching fog end)
	var res3 = await measure_config("Visibility Range 150m (Match Fog)", func(game):
		var grade = game.find_child("BattlefieldGrade", true, false)
		if grade:
			grade.queue_free()
		for b in game.find_children("", "DestructibleBuilding", true, false):
			var mi = b.get_node_or_null("MeshInstance3D")
			if mi:
				mi.visibility_range_end = 150.0
	)

	# Test 4: Directional shadow max distance 100m (instead of 155m)
	var res4 = await measure_config("Shadow Dist 90m + Vis 150m", func(game):
		var grade = game.find_child("BattlefieldGrade", true, false)
		if grade:
			grade.queue_free()
		for b in game.find_children("", "DestructibleBuilding", true, false):
			var mi = b.get_node_or_null("MeshInstance3D")
			if mi:
				mi.visibility_range_end = 150.0
		var sun = game.get_node_or_null("WeatherSystem/DirectionalLight3D")
		if sun:
			sun.directional_shadow_max_distance = 90.0
	)

	print("\n=== SUMMARY COMPARISON ===")
	print("1. Full Current:        %.1f FPS  (%.2f ms)  [%d prims]" % [res1.fps, res1.ms, res1.prims])
	print("2. No Grade Shader:     %.1f FPS  (%.2f ms)  [%d prims]" % [res2.fps, res2.ms, res2.prims])
	print("3. Vis Range 150m:      %.1f FPS  (%.2f ms)  [%d prims]" % [res3.fps, res3.ms, res3.prims])
	print("4. Shadow 90m + Vis150: %.1f FPS  (%.2f ms)  [%d prims]" % [res4.fps, res4.ms, res4.prims])
	quit(0)

func measure_config(config_name: String, modifier: Callable) -> Dictionary:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var game = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	modifier.call(game)

	# Spawn 24 enemies
	var player = game.get_node("PlayerHelicopter")
	player.position = Vector3(0, 22, 65.0)
	var spawner = game.get_node("EnemySpawner")
	var roles := ["flak_tank", "scout_buggy", "attack_wing", "scout_drone", "attack_gunship", "infantry_squad", "mortar_crawler", "shield_drone"]
	for i in 24:
		var angle := TAU * float(i) / 24.0
		var role: String = roles[i % roles.size()]
		var altitude := 1.0 if EnemyData.VARIANTS[role].family == "ground" else 28.0
		var point := Vector3(cos(angle) * 85, altitude, sin(angle) * 85)
		spawner.spawn_enemy_type(role, point)

	# Warm up 1 second
	var warm_end = Time.get_ticks_msec() + 1000
	while Time.get_ticks_msec() < warm_end:
		await process_frame

	# Measure 100 frames
	var times: Array[float] = []
	var prims: Array[float] = []
	var last = Time.get_ticks_usec()
	for f in 100:
		await process_frame
		var now = Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
		prims.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))

	var avg_ms = 0.0
	for t in times:
		avg_ms += t
	avg_ms /= float(times.size())
	var avg_prims = 0.0
	for p in prims:
		avg_prims += p
	avg_prims /= float(prims.size())

	game.queue_free()
	await process_frame
	return {"fps": 1000.0 / avg_ms, "ms": avg_ms, "prims": int(avg_prims)}
