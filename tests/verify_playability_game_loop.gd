extends SceneTree

var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	call_deferred("run")

func verify(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("  [PASS] %d. %s" % [checks, label])
	else:
		failures.append(label)
		printerr("  [FAIL] %d. %s" % [checks, label])

func ticks(count: int) -> void:
	for i in count:
		await physics_frame

func neutral() -> void:
	for a in ["thrust_forward", "thrust_backward", "strafe_left", "strafe_right", "yaw_left", "yaw_right"]:
		Input.action_release(a)

func run() -> void:
	if OS.get_environment("ZIVA_TEST_DATA_DIR").is_empty():
		quit(1)
		return

	print("==================================================================")
	print("--- BEGIN COMPLETE GAME LOOP & PLAYABILITY VERIFICATION ---")
	print("==================================================================")

	root.size = Vector2i(1280, 720)
	var flow = root.get_node("UIFlow")

	# ------------------------------------------------------------------
	# 1. Menu -> Aircraft Selection -> Loading -> Ready Gameplay
	# ------------------------------------------------------------------
	print("\n>>> STAGE 1: Sortie Deployment & Honest Loading Transition")
	flow.begin_run("apache")
	var loader = flow.loader
	var loader_valid = is_instance_valid(loader)
	verify(loader_valid, "Loading screen instantiated")

	var deadline := Time.get_ticks_msec() + 30000
	var saw_progress_advancing := false
	var last_p := 0.0

	while flow.busy and Time.get_ticks_msec() < deadline:
		await process_frame
		if is_instance_valid(loader) and loader.displayed_progress > last_p:
			saw_progress_advancing = true
			last_p = loader.displayed_progress

	verify(not flow.busy, "Sortie deployment finished without hanging")
	verify(saw_progress_advancing, "Loading progress advanced fluidly throughout preparation")
	var game = current_scene
	verify(is_instance_valid(game) and game.name == "MainGame", "MainGame scene reached and activated")

	var player = game.get_node_or_null("PlayerHelicopter")
	var hud = game.get_node_or_null("UI/CombatHUD")
	var camera = player.get_node_or_null("PlayerCamera") if player else null
	var turret = player.get_node_or_null("Turret") if player else null
	var weapons = player.get_node_or_null("Weapons") if player else null
	var progression = player.get_node_or_null("RunProgression") if player else null

	verify(is_instance_valid(player) and is_instance_valid(camera) and is_instance_valid(turret), "Player, Camera, and Turret fully initialized")
	verify(is_instance_valid(hud) and is_instance_valid(weapons) and is_instance_valid(progression), "HUD, Weapons, and RunProgression active")

	# ------------------------------------------------------------------
	# 2. Flight & Camera Responsiveness
	# ------------------------------------------------------------------
	print("\n>>> STAGE 2: Flight Dynamics, Auto-Braking & Camera Responsiveness")
	player.global_position = Vector3(0, 14, 0)
	player.velocity = Vector3.ZERO
	neutral()

	# Accelerate forward
	Input.action_press("thrust_forward")
	await ticks(60)
	var speed_at_cruise = Vector2(player.velocity.x, player.velocity.z).length()
	verify(speed_at_cruise >= 30.0, "Thrust accelerates helicopter to combat speed (reached %.1f m/s)" % speed_at_cruise)

	# Release thrust: measure stopping distance and speed after 1 second
	Input.action_release("thrust_forward")
	var release_pos = player.global_position
	await ticks(60)

	var stop_dist = (player.global_position - release_pos).length()
	var speed_after_1s = Vector2(player.velocity.x, player.velocity.z).length()
	verify(stop_dist < 8.0, "Hands-off auto-braking distance in 1.0s is under 8.0m (measured %.2fm)" % stop_dist)
	verify(speed_after_1s < 2.0, "Hands-off residual speed after 1.0s is under 2.0 m/s (measured %.2f m/s)" % speed_after_1s)

	# Camera sustained yaw lag
	player.override_flight_input = {"thrust": 1.0, "yaw": 1.0}
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.init_camera(player)
	for i in 60:
		await physics_frame
		camera.update_camera(1.0 / 60.0)

	var forward: Vector3 = -player.global_transform.basis.z
	var actual_yaw := atan2(forward.x, forward.z)
	var yaw_lag_deg = rad_to_deg(absf(angle_difference(camera.current_cam_yaw, actual_yaw)))
	verify(yaw_lag_deg < 5.0, "Camera yaw lag during sustained turn is below 5.0 deg (measured %.2f deg)" % yaw_lag_deg)
	player.override_flight_input.clear()

	# ------------------------------------------------------------------
	# 3. Truthful Aiming, Turret Arc & Zero Sticky Aim
	# ------------------------------------------------------------------
	print("\n>>> STAGE 3: Truthful Aiming, Turret Arc & Zero Sticky Aim")
	neutral()
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(0, 14, 0)
	player.global_rotation = Vector3.ZERO
	camera.update_camera(0.0166)

	root.get_node("CombatDirector").stop_wave_director()
	game.get_node("EnemySpawner").set_process(false)
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	for i in 3:
		await physics_frame
	turret.enemy_query_timer = 0.0
	turret.cached_enemies.clear()

	# A) Free aim at empty ground
	turret.update_aim(camera, Vector2(640, 200), player, 0.0166)
	verify(turret.current_target_node == null, "Free aim at empty ground selects no target")
	verify(turret.is_aim_in_arc == true, "Forward aim is within gimbal arc")

	# B) Target acquisition of enemy
	var spawner = game.get_node("EnemySpawner")
	var enemy1 = spawner.spawn_enemy_type("scout_buggy", Vector3(0, 0.6, -45.0), true)
	await physics_frame
	await physics_frame

	turret.enemy_query_timer = 0.0 # Force immediate enemy cache update
	var enemy1_screen = camera.unproject_position(enemy1.global_position)
	turret.update_aim(camera, enemy1_screen, player, 0.0166)
	verify(turret.current_target_node == enemy1, "Cursor hovering near enemy acquires target lock")

	# C) Move mouse away: MUST instantly release lock (Zero Sticky Aim!)
	turret.update_aim(camera, Vector2(100, 100), player, 0.0166)
	verify(turret.current_target_node == null, "Moving mouse away immediately releases lock (zero sticky aim!)")

	# D) Aim behind aircraft (Out-of-Arc Limits)
	var rear_point := Vector3(0, 0, 40)
	var rear_screen = camera.unproject_position(rear_point)
	turret.update_aim(camera, rear_screen, player, 0.0166)
	verify(turret.is_aim_in_arc == false, "Rearward cursor position triggers out-of-arc indicator")
	var muzzle_t = turret.get_current_muzzle_transform()
	var traj_dir = turret.actual_aim_direction
	var impact_dir = (turret.actual_impact_point - muzzle_t.origin).normalized()
	var agreement = traj_dir.dot(impact_dir)
	verify(agreement > 0.98, "Actual impact marker agrees with physical barrel trajectory (dot = %.4f)" % agreement)

	# ------------------------------------------------------------------
	# 4. Weapons, Alternating Muzzles & Ammo Integrity
	# ------------------------------------------------------------------
	print("\n>>> STAGE 4: Weapons, Alternating Muzzles & Combat Sound/Fire")
	var m1 = turret.get_active_muzzle_transform()
	var m2 = turret.get_active_muzzle_transform()
	verify(m1.origin != m2.origin, "Firing alternates muzzles between left and right chaingun barrels")

	# Re-read without mutating
	var peek1 = turret.get_current_muzzle_transform()
	var peek2 = turret.get_current_muzzle_transform()
	verify(peek1.origin == peek2.origin, "get_current_muzzle_transform() does not corrupt muzzle toggle state")

	# ------------------------------------------------------------------
	# 5. Loot Drops, Elevation Integrity & XP Magnet
	# ------------------------------------------------------------------
	print("\n>>> STAGE 5: Loot Drops, Elevation Integrity & Immediate Magnet")
	var loot_mgr = game.get_node("LootManager")
	var start_xp = progression.current_run_xp

	# Spawn aerial drop at y=25.5
	var air_pickup = loot_mgr.spawn_xp_drop(Vector3(0, 25.5, -20.0), 5)
	await process_frame
	await process_frame
	verify(air_pickup.global_position.y > 20.0, "Air drop preserves elevation and does not snap to y=0 (y=%.2f)" % air_pickup.global_position.y)

	# Move helicopter close to collect
	player.global_position = Vector3(0, 25.0, -20.0)
	air_pickup.start_attraction(player)
	for i in 60:
		await physics_frame
		await process_frame

	var collected_xp = progression.current_run_xp - start_xp
	verify(collected_xp > 0, "XP gem magnetically attracts and collects at 25m altitude (+%d XP)" % collected_xp)

	# ------------------------------------------------------------------
	# 6. Rendered Gameplay Screenshot Capture
	# ------------------------------------------------------------------
	print("\n>>> STAGE 6: Visual Evidence Capture")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var img = root.get_texture().get_image()
		img.save_png("res://artifacts/playability_verified_gameplay.png")
		print("  [INFO] Captured visual proof to artifacts/playability_verified_gameplay.png")

	# Clean up spawned test enemies
	if is_instance_valid(enemy1):
		enemy1.queue_free()

	print("\n==================================================================")
	print("PLAYABILITY VERIFICATION COMPLETE: %d/%d CHECKS PASSED" % [checks - failures.size(), checks])
	if failures.is_empty():
		print(">>> SHORT GAME LOOP SMOKE CHECKS PASSED; SEE SOAK AND EDGE-CASE TESTS <<<")
	else:
		print(">>> FAILURES DETECTED: %s" % str(failures))
	print("==================================================================")

	await load("res://tests/runtime_cleanup.gd").finish(self, 0 if failures.is_empty() else 1)
