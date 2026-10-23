extends SceneTree

var rows: Array = []
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
	print("PASS " if ok else "FAIL ", label)

func ticks(count: int) -> void:
	for i in count:
		await physics_frame

func reset_flight(player: Node3D) -> void:
	player.global_position = Vector3(0, 40, 0)
	player.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	player.angular_velocity = 0.0
	player.override_flight_input = {"thrust": 0.0, "yaw": 0.0, "strafe": 0.0}
	player.reset_physics_interpolation()
	player.get_node("PlayerCamera").init_camera(player)

func run() -> void:
	if OS.get_environment("ZIVA_TEST_DATA_DIR").is_empty():
		quit(2)
		return
	var gm = root.get_node("GameManager")
	root.get_node("UIFlow").busy = false
	root.get_node("UIFlow").input_armed = true
	gm.change_state(gm.RunState.ACTIVE)
	var original_fps := Engine.max_fps
	for aircraft in ["apache", "nighthawk", "warlock"]:
		for upgraded in [false, true]:
			for fps in [30, 60, 120]:
				Engine.max_fps = fps
				gm.selected_aircraft = aircraft
				var player = load("res://scenes/player/player.tscn").instantiate()
				root.add_child(player)
				if upgraded:
					root.get_node("XpManager").reset_run()
					root.get_node("XpManager").add_xp(2000)
					for card in load("res://src/resources/upgrade_card_database.gd").get_master_deck():
						if card.stat_changes.get("drag_mult", 0.0) < 0.0:
							check(player.get_node("SubsystemManager").apply_upgrade(card), "real Ghost Rotor card applies to " + aircraft)
				reset_flight(player)
				player.override_flight_input = {"thrust": 1.0}
				await ticks(60)
				var speed: float = Vector2(player.velocity.x, player.velocity.z).length()
				player.override_flight_input = {"thrust": 0.0}
				var release: Vector3 = player.global_position
				await ticks(30)
				var residual: float = Vector2(player.velocity.x, player.velocity.z).length()
				await ticks(30)
				var coast: float = (player.global_position - release).length()
				var residual_one_second: float = Vector2(player.velocity.x, player.velocity.z).length()
				reset_flight(player)
				player.override_flight_input = {"thrust": 1.0, "yaw": 1.0}
				await ticks(60)
				await process_frame
				var camera = player.get_node("PlayerCamera")
				# process_frame is emitted before node _process callbacks. Sample
				# the pose used for drawing/aiming after the camera's current update.
				camera.update_camera(camera.get_process_delta_time())
				var forward: Vector3 = -player.get_global_transform_interpolated().basis.z
				var lag := rad_to_deg(absf(angle_difference(camera.current_cam_yaw, atan2(forward.x, forward.z))))
				reset_flight(player)
				player.override_flight_input = {"dash": true, "thrust": 1.0}
				await ticks(2)
				var dash_started: bool = player.is_dashing
				player.override_flight_input = {"dash": false}
				var dash_frames := 2
				while player.is_dashing and dash_frames < 90:
					await ticks(1)
					dash_frames += 1
				var row := {"aircraft": aircraft, "ghost_rotor_card": upgraded, "render_fps_cap": fps, "physics_hz": Engine.physics_ticks_per_second, "speed_after_1s": speed, "speed_after_half_second_release": residual, "coast_1s_m": coast, "camera_lag_deg": lag, "dash_physics_frames": dash_frames}
				rows.append(row)
				print("FLIGHT_MATRIX ", JSON.stringify(row))
				var label := "%s upgraded=%s fps=%d" % [aircraft, upgraded, fps]
				check(speed > 25.0, "responsive acceleration " + label)
				# Ghost Rotor deliberately reduces drag by 35% and raises cruise by
				# 25%; retain that tradeoff while bounding final speed and drift.
				check(residual < (4.5 if upgraded else 2.0) and residual_one_second < 1.0 and coast < (11.0 if upgraded else 8.0), "bounded braking " + label)
				check(lag < 5.0, "camera yaw lag below five degrees " + label)
				check(dash_started and dash_frames >= 15 and dash_frames < 40, "dash ends on physics time " + label)
				player.queue_free()
				await process_frame
	for aircraft in ["apache", "nighthawk", "warlock"]:
		for upgraded in [false, true]:
			var subset: Array = rows.filter(func(row): return row.aircraft == aircraft and row.ghost_rotor_card == upgraded)
			var low := INF
			var high := 0.0
			for row in subset:
				low = minf(low, row.coast_1s_m)
				high = maxf(high, row.coast_1s_m)
			check(high - low < 0.75, "render-rate-independent braking %s upgraded=%s" % [aircraft, upgraded])
	Engine.max_fps = original_fps
	var file := FileAccess.open("res://artifacts/playability-fixes-20261024/flight-matrix.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"rows": rows, "checks": checks, "failures": failures}, "  "))
	file.close()
	print("FLIGHT_MATRIX_RESULTS ", checks - failures.size(), "/", checks)
	await load("res://tests/runtime_cleanup.gd").finish(self, 0 if failures.is_empty() else 1)
