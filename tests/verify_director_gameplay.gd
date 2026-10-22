extends SceneTree

# Runs the real city/camera/controllers with ordinary hull, physical loot and firing.
# Requires isolated persistence and uses no forced wave setup or direct XP grants.
var player_shots := 0
var draft_count := 0
var frames: Array[float] = []

func _init() -> void:
	call_deferred("run")

func run() -> void:
	if OS.get_environment("ZIVA_TEST_DATA_DIR").is_empty():
		push_error("Set ZIVA_TEST_DATA_DIR before running the gameplay fixture")
		quit(1)
		return
	seed(23023) # Reproduce the city and AI inputs as well as director choices in this fixture.
	var cd = root.get_node("CombatDirector")
	cd.set_encounter_seed(23023)
	var game = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.session_started:
		await process_frame
	var player = game.get_node("PlayerHelicopter")
	player.get_node("Weapons").weapon_fired.connect(func(_id, _ammo): player_shots += 1)
	var gm = root.get_node("GameManager")
	var duration := 0.0
	var wall_start := Time.get_ticks_msec()
	var max_population := 0
	var next_log := 10.0
	var captured := false
	var retry_count := 0
	var highest_wave := 1
	var allow_retry := OS.get_cmdline_user_args().has("--retry-cycle")
	while duration < 62.0 and Time.get_ticks_msec() - wall_start < 78000:
		await process_frame
		frames.append(root.get_process_delta_time())
		var ui = game.get_node("UI/LevelUpUi")
		if ui.visible and ui.is_choosing and not ui.current_draft.is_empty():
			ui._on_card_clicked(0)
			draft_count += 1
		if not paused:
			duration += root.get_process_delta_time()
		if player.is_dying or player.current_hull <= 0:
			if allow_retry and retry_count == 0:
				Input.action_release("fire_primary")
				while gm.current_state != gm.RunState.RESULTS:
					await process_frame
				root.get_node("UIFlow").begin_run("apache")
				while root.get_node("UIFlow").busy or current_scene == game:
					await process_frame
				game = current_scene
				player = game.get_node("PlayerHelicopter")
				player.get_node("Weapons").weapon_fired.connect(func(_id, _ammo): player_shots += 1)
				# The real retry flow requires released input for two frames before arming.
				for release_frame in range(3): await process_frame
				retry_count += 1
				continue
			break
		var t := duration
		# Continuous evasive patrol and real held primary fire; no health/stat overrides.
		player.override_flight_input = {"thrust": 0.7, "strafe": 0.35 * sin(t * 0.7), "yaw": 0.38,
			"lift": 1.0 if player.global_position.y < 32.0 else 0.0, "dash": int(t) % 6 == 0}
		# Drive the normal gimbal/LOS/arc aim solver toward an actual visible enemy.
		var camera = root.get_camera_3d()
		var closest: Node3D = null
		var best_distance := INF
		for enemy in get_nodes_in_group("enemies"):
			if enemy.has_node("DamageReceiver") and enemy.get_node("DamageReceiver").is_dead:
				continue
			var distance: float = player.global_position.distance_to(enemy.global_position)
			if camera and camera.is_position_in_frustum(enemy.global_position) and distance < best_distance:
				best_distance = distance
				closest = enemy
		if closest and camera:
			var motion := InputEventMouseMotion.new()
			motion.position = camera.unproject_position(closest.global_position + Vector3.UP)
			motion.global_position = motion.position
			root.push_input(motion, true)
		Input.action_press("fire_primary")
		max_population = maxi(max_population, cd.get_active_enemy_count())
		highest_wave = maxi(highest_wave, cd.current_wave)
		if duration >= next_log:
			print("GAMEPLAY t=%.1f wave=%d hull=%.1f pop=%d shots=%d spawned=%d" % [duration, cd.current_wave, player.current_hull, cd.get_active_enemy_count(), player_shots, cd.cumulative_spawns])
			next_log += 10.0
		if not captured and duration >= 15.0 and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/director-repair-20261023/gameplay.png")
			captured = true
	Input.action_release("fire_primary")
	player.override_flight_input.clear()
	frames.sort()
	var result = {"seconds": duration, "wave": cd.current_wave, "hull": player.current_hull,
		"player_shots": player_shots, "enemy_shots": cd.cumulative_shots_emitted,
		"spawns": cd.cumulative_spawns, "max_population": max_population,
		"drafts": draft_count, "reserved": cd.reserved_population,
		"median_ms": frames[frames.size() / 2] * 1000.0,
		"p95_ms": frames[int(frames.size() * 0.95)] * 1000.0,
		"damage_history": player.damage_history, "kills_current_run": gm.kills_count,
		"highest_wave": highest_wave, "retry_count": retry_count}
	print("GAMEPLAY_RESULT ", JSON.stringify(result))
	var f = FileAccess.open("res://artifacts/director-repair-20261023/gameplay.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(result, "\t"))
	var ok: bool = cd.cumulative_spawns > 0 and player_shots > 0 and cd.reserved_population == 0 and duration >= 60
	# Two short sorties separated by a real death/retry cannot be required to reach
	# wave two. Continuous mode separately requires natural wave advancement.
	if allow_retry: ok = ok and retry_count == 1
	else: ok = ok and highest_wave >= 2
	cd.stop_wave_director()
	game.queue_free()
	await process_frame
	quit(0 if ok else 1)
