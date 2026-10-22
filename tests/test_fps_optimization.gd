extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	print("--- TESTING REFINED SETTINGS FOR 60+ FPS ---")

	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0 # Uncapped to measure raw headroom

	var game = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game

	# Verify built-in optimizations are baked into the scene
	var sun: DirectionalLight3D = game.get_node_or_null("WeatherSystem/DirectionalLight3D")
	assert(sun != null, "WeatherSystem light should exist")
	assert(sun.directional_shadow_max_distance <= 120.0, "Directional shadow max distance should be optimized (<= 120m)")

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

	# Simulate 120 frames of flight along route
	var times: Array[float] = []
	var prims: Array[float] = []
	var last = Time.get_ticks_usec()
	for f in 120:
		var angle := float(f) * 0.05
		player.position = Vector3(sin(angle) * 65.0, 22, cos(angle) * 65.0)
		player.rotation.y = -angle
		await process_frame
		var now = Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
		prims.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))

	var avg_ms = 0.0
	for t in times:
		avg_ms += t
	avg_ms /= float(times.size())
	times.sort()
	var p95_ms = times[int(times.size() * 0.95)]
	var avg_prims = 0.0
	for p in prims:
		avg_prims += p
	avg_prims /= float(prims.size())

	print("RAW HEADROOM RESULTS (UNCAPPED):")
	print("  Average FPS: %.1f FPS" % [1000.0 / avg_ms])
	print("  Average Frame Time: %.2f ms" % [avg_ms])
	print("  P95 Frame Time: %.2f ms" % [p95_ms])
	print("  Average Primitives: %d" % [int(avg_prims)])

	# Now test with 60 FPS cap
	Engine.max_fps = 60
	for w in 5:
		await process_frame

	times.clear()
	last = Time.get_ticks_usec()
	for f in 60:
		await process_frame
		var now = Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now

	avg_ms = 0.0
	for t in times:
		avg_ms += t
	avg_ms /= float(times.size())
	print("\nLOCKED 60 FPS RESULTS:")
	print("  Locked FPS: %.1f FPS" % [1000.0 / avg_ms])
	print("  Locked Frame Time: %.2f ms (Target: 16.66 ms)" % [avg_ms])

	assert(avg_ms <= 17.5, "Frame time must be within 60 FPS pacing budget (<17.5ms)")
	print("PASS: Solid 60 FPS frame pacing verified!\n")

	quit(0)
