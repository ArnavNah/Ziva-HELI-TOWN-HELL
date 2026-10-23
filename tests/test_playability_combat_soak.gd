extends "res://tests/test_menu_repair.gd"

## Five real minutes of automated rendered combat, followed by five actual deaths
## and Play Again deployments. Hull/fuel/ammo are supplied by the fixture so this
## tests stability and integration rather than survival difficulty or balance.
var combat_seconds := 300.0
var snapshots: Array = []
var frame_ms: Array[float] = []
var shot_counts := [0, 0, 0, 0]
var stats := {"salvo_missiles": 0, "super_activations": 0, "card_choices": 0}

func run() -> void:
	if OS.get_environment("ZIVA_TEST_DATA_DIR").is_empty():
		quit(2)
		return
	root.size = Vector2i(1280, 720)
	if not OS.get_environment("ZIVA_SOAK_SECONDS").is_empty():
		combat_seconds = maxf(8.0, float(OS.get_environment("ZIVA_SOAK_SECONDS")))
	captures = DisplayServer.get_name() != "headless"
	var flow = root.get_node("UIFlow")
	var gm = root.get_node("GameManager")
	gm.selected_biome = "town"
	flow.return_to_menu()
	await frames(12)
	await click(current_scene.start_btn)
	await click(current_scene.get_node("VehicleSelectionMenu").deploy_btn)
	check(await wait_run(), "main menu and aircraft selection deploy ready combat")
	if not current_scene or current_scene.name != "MainGame":
		await load("res://tests/runtime_cleanup.gd").finish(self, 1)
		return
	var game = current_scene
	var player = game.player
	var weapons = player.get_node("Weapons")
	var camera = player.get_node("PlayerCamera")
	var salvo = player.get_node("Salvo")
	var super_controller = player.get_node("DevastationSuper")
	var ui = game.get_node("UI/LevelUpUi")
	var bus = root.get_node("EventBus")
	bus.run_state_changed.connect(func(state: int, previous: int): print("SOAK_STATE ", previous, " -> ", state))
	ui.tree_exiting.connect(func():
		print("SOAK_UI_EXIT state=", gm.current_state, " flow_busy=", flow.busy, " quit_requested=", flow._quit_requested)
		print_stack()
	)
	bus.weapon_fired.connect(func(weapon: int, _ammo: int): shot_counts[weapon] += 1)
	bus.salvo_launched.connect(func(count: int): stats.salvo_missiles += count)
	bus.super_activated.connect(func(): stats.super_activations += 1)
	player.max_hull = 100000.0
	player.current_hull = player.max_hull
	player.max_fuel = 1000.0
	player.current_fuel = player.max_fuel
	var waypoints := [Vector3(0, 14, -152), Vector3(152, 14, -152), Vector3(152, 14, 152), Vector3(-152, 14, 152), Vector3(-152, 14, -152)]
	var waypoint := 0
	var started := Time.get_ticks_usec()
	var last := started
	var next_sample := 0.0
	var next_supply := 0.0
	var next_super := minf(30.0, combat_seconds * 0.5)
	var tick := 0
	Input.action_press("fire_primary")
	while float(Time.get_ticks_usec() - started) / 1000000.0 < combat_seconds:
		await process_frame
		if not is_instance_valid(ui):
			check(false, "combat scene unexpectedly replaced; state=%d scene=%s" % [gm.current_state, str(current_scene)])
			await load("res://tests/runtime_cleanup.gd").finish(self, 1)
			return
		var now := Time.get_ticks_usec()
		var elapsed := float(now - started) / 1000000.0
		if not paused:
			frame_ms.append(float(now - last) / 1000.0)
		last = now
		if ui.is_choosing:
			ui._on_card_clicked(0)
			stats.card_choices += 1
		if gm.current_state == gm.RunState.BOSS_DECISION:
			game.get_node("UI/BossDecisionDialog")._on_overdrive_pressed()
		if player.is_dying or gm.current_state == gm.RunState.RESULTS:
			check(false, "combat fixture survives the full sample")
			break
		var to_waypoint: Vector3 = waypoints[waypoint] - player.global_position
		to_waypoint.y = 0
		if to_waypoint.length() < 8.0:
			waypoint = (waypoint + 1) % waypoints.size()
		var forward: Vector3 = -player.global_basis.z
		var direction := to_waypoint.normalized()
		var yaw_error := atan2(forward.cross(direction).y, forward.dot(direction))
		player.override_flight_input = {"thrust": clampf(1.0 - absf(yaw_error), 0.0, 0.9), "yaw": clampf(-yaw_error * 2.0, -1.0, 1.0), "lift": clampf((14.0 - player.global_position.y) * 0.3, -1.0, 1.0), "dash": int(elapsed) % 20 == 15}
		weapons.switch_weapon(int(elapsed / minf(15.0, combat_seconds / 16.0)) % 4)
		# Simulate releasing held controls after an upgrade/loading handoff.
		# UIFlow intentionally refuses held fire until the player releases it.
		var painting: bool = flow.input_armed and (int(elapsed) % 6 in [2, 3])
		if painting:
			Input.action_release("fire_primary")
			Input.action_press("paint_salvo")
			for enemy in get_nodes_in_group("enemies"):
				if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and enemy.global_position.distance_to(player.global_position) < 80.0:
					salvo.add_target_lock(enemy)
					break
		else:
			Input.action_release("paint_salvo")
			if flow.input_armed:
				Input.action_press("fire_primary")
			else:
				Input.action_release("fire_primary")
		if elapsed >= next_supply:
			weapons.refill_all_ammo()
			next_supply += 8.0
		if elapsed >= next_super:
			super_controller.add_charge(100.0)
			super_controller.try_activate_super()
			next_super += 45.0
		if tick % 6 == 0:
			var aim := Vector2(640, 330)
			var nearest := 140.0
			for enemy in get_nodes_in_group("enemies"):
				if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or camera.is_position_behind(enemy.global_position):
					continue
				var distance: float = enemy.global_position.distance_to(player.global_position)
				var screen: Vector2 = camera.unproject_position(enemy.global_position)
				if distance < nearest and Rect2(Vector2.ZERO, Vector2(root.size)).has_point(screen):
					aim = screen
					nearest = distance
			var motion := InputEventMouseMotion.new()
			motion.position = aim
			motion.global_position = aim
			Input.parse_input_event(motion)
			root.warp_mouse(Vector2i(aim))
		tick += 1
		if elapsed >= next_sample:
			var director = root.get_node("CombatDirector")
			var sample := {"wall_seconds": elapsed, "game_seconds": gm.run_time, "wave": director.current_wave, "enemies": get_nodes_in_group("enemies").size(), "xp_drops": get_nodes_in_group("xp_drops").size(), "projectiles": get_nodes_in_group("combat_projectiles").size(), "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT), "static_memory_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, "kills": gm.kills_count, "xp_collected": root.get_node("XpManager").total_xp_collected, "enemy_shots": director.cumulative_shots_emitted, "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "position": player.global_position}
			snapshots.append(sample)
			print("SOAK_SAMPLE ", JSON.stringify(sample))
			# Off-screen windows can skip frame_post_draw while a modal is idle.
			# Do not suspend the bot waiting for a presentation-only capture.
			if captures:
				root.get_texture().get_image().save_png("res://artifacts/menu-repair-tests/soak-%03d.png" % int(next_sample))
			next_sample += 60.0
	Input.action_release("fire_primary")
	Input.action_release("paint_salvo")
	player.override_flight_input = {"thrust": 0, "yaw": 0, "lift": 0, "dash": false}
	check(float(Time.get_ticks_usec() - started) / 1000000.0 >= combat_seconds, "%d real seconds of combat completed" % combat_seconds)
	for weapon in 4:
		check(shot_counts[weapon] > 0, "weapon %d fired real projectiles" % weapon)
	check(stats.salvo_missiles > 0, "painted salvo launched missiles")
	check(stats.super_activations > 0, "Super activated during combat")
	check(gm.kills_count > 0 and root.get_node("XpManager").total_xp_collected > 0, "combat produces enemy kills and physically collected XP")
	var combat_summary := {"kills": gm.kills_count, "xp": root.get_node("XpManager").total_xp_collected, "game_seconds": gm.run_time, "enemy_shots": root.get_node("CombatDirector").cumulative_shots_emitted}
	# Five deaths use the real crash -> results -> Play Again -> selection route.
	for cycle in 5:
		player.override_flight_input = {"thrust": 0, "yaw": 0, "lift": 0, "dash": false}
		player.is_invulnerable = false
		player.debug_invulnerable = false
		player.spawn_grace_timer = 0.0
		player.mortal_protection.grace_left = 0.0
		player.shield_timer = 0.0
		player.shield_capacity = 0
		player.current_hull = 100
		player.is_dashing = false
		player.get_node("DevastationSuper").is_active = false
		# A fatal environmental crash intentionally bypasses the existing
		# one-hit combat protection; do not change that gameplay safeguard.
		player.take_damage(1000000.0, "Ground Impact")
		var deadline := Time.get_ticks_msec() + 15000
		while not game.debrief_screen.visible and Time.get_ticks_msec() < deadline:
			if game.get_node("UI/LevelUpUi").is_choosing:
				game.get_node("UI/LevelUpUi")._on_card_clicked(0)
			await process_frame
		check(game.debrief_screen.visible and gm.current_state == gm.RunState.RESULTS, "death reaches results cycle %d" % cycle)
		if not game.debrief_screen.visible:
			break
		await click(game.debrief_screen.retry_button)
		await frames(12)
		check(current_scene.name == "MainMenu" and current_scene.get_node("VehicleSelectionMenu").visible, "Play Again opens aircraft selection cycle %d" % cycle)
		var selection = current_scene.get_node("VehicleSelectionMenu")
		await click(selection.card_buttons[(cycle + 1) % 3])
		await click(selection.deploy_btn)
		check(await wait_run(), "ready gameplay after death/retry cycle %d" % cycle)
		game = current_scene
		player = game.player
		root.get_node("CombatDirector").stop_wave_director()
		check(root.get_node("XpManager").total_xp_collected == 0, "retry has no previous-run XP cycle %d" % cycle)
	frame_ms.sort()
	var report := {"duration_wall_seconds": combat_seconds, "fixture": "autopilot, boosted hull/fuel, periodic ammo resupply, automatic real card choices", "renderer": RenderingServer.get_current_rendering_method(), "resolution": root.size, "samples": frame_ms.size(), "median_frame_ms": frame_ms[int(frame_ms.size() * 0.50)], "p95_frame_ms": frame_ms[int(frame_ms.size() * 0.95)], "worst_frame_ms": frame_ms[-1], "shots_by_weapon": shot_counts, "abilities_and_cards": stats, "combat": combat_summary, "snapshots": snapshots, "checks": checks, "failures": failures}
	var file := FileAccess.open("res://artifacts/playability-fixes-20261024/combat-soak.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("COMBAT_SOAK_RESULT ", JSON.stringify(report))
	await load("res://tests/runtime_cleanup.gd").finish(self, 0 if failures.is_empty() else 1)
