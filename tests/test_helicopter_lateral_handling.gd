extends SceneTree

var results: Dictionary = {}
var failed := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failed += 1

func reset_player(player: Node3D) -> void:
	player.position = Vector3(0, 60, 0)
	player.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	player.angular_velocity = 0.0
	player.bank_angle = 0.0
	player.bank_velocity = 0.0
	player.pitch_angle = 0.0
	player.pitch_velocity = 0.0
	if "lateral_acceleration" in player:
		player.lateral_acceleration = 0.0
	player.override_flight_input = {"thrust": 0.0, "strafe": 0.0, "yaw": 0.0, "lift": 0.0, "dash": false}

func simulate(player: Node3D, seconds: float, thrust: float, strafe: float, yaw: float, hz: int = 60) -> void:
	player.override_flight_input = {"thrust": thrust, "strafe": strafe, "yaw": yaw, "lift": 0.0, "dash": false}
	for frame in range(roundi(seconds * hz)):
		player._process_flight_physics(1.0 / hz)

func run() -> void:
	if OS.get_environment("ZIVA_TEST_DATA_DIR").is_empty():
		quit(2)
		return
	var player = load("res://scenes/player/player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	player.debug_invulnerable = true
	reset_player(player)
	simulate(player, 1.0, 0, 1, 0)
	var right_speed: float = player.velocity.x
	reset_player(player)
	simulate(player, 1.0, 0, -1, 0)
	var left_speed: float = -player.velocity.x
	results.strafe_speed = right_speed
	check(right_speed > 20.0 and absf(right_speed - left_speed) < 0.05, "Left and right acceleration are responsive and symmetric")
	check(player.bank_angle > 0.0, "Left strafe banks the helicopter left")
	var coast_distances: Array[float] = []
	for forward in [0.0, 1.0]:
		reset_player(player)
		player.velocity.x = 24.0
		var distance := 0.0
		for frame in range(60):
			simulate(player, 1.0 / 60.0, forward, 0, 0)
			distance += absf(player.velocity.x) / 60.0
		coast_distances.append(distance)
		check(absf(player.velocity.x) < 0.4, "Sideways movement stops cleanly with forward input %.0f" % forward)
	results.side_stopping_distances = coast_distances
	check(absf(coast_distances[0] - coast_distances[1]) < 0.65, "Lateral braking stays consistent while forward movement is held")
	check(coast_distances.max() < 5.5, "Sideways coasting stays under 5.5 meters")
	reset_player(player)
	player.velocity.x = 24.0
	var peak_accel := 0.0
	var reversal_time := -1.0
	for frame in range(60):
		var before: float = player.velocity.x
		simulate(player, 1.0 / 60.0, 0, -1, 0)
		peak_accel = maxf(peak_accel, absf(player.velocity.x - before) * 60.0)
		if reversal_time < 0.0 and player.velocity.x <= 0.0:
			reversal_time = float(frame + 1) / 60.0
	results.reversal_peak_acceleration = peak_accel
	results.reversal_time = reversal_time
	check(peak_accel <= 100.0, "Direction reversals avoid sudden lateral acceleration spikes")
	check(reversal_time > 0.0 and reversal_time <= 0.45 and player.velocity.x < -20.0, "Direction reversals remain responsive and reach the opposite strafe")
	reset_player(player)
	simulate(player, 1.0 / 60.0, 0, 0, 1)
	var yaw_accel: float = absf(rad_to_deg(player.angular_velocity)) * 60.0
	results.initial_yaw_acceleration = yaw_accel
	check(yaw_accel <= 300.0, "Turning builds at a controlled angular acceleration")
	simulate(player, 1.0, 0, 0, 1)
	var hover_bank: float = absf(rad_to_deg(player.bank_angle))
	results.hover_turn_bank = hover_bank
	check(hover_bank < 6.0, "Turning in place keeps the airframe close to level")
	var heading: float = player.rotation.y
	simulate(player, 1.0, 0, 0, 0)
	var yaw_overshoot: float = absf(rad_to_deg(wrapf(player.rotation.y - heading, -PI, PI)))
	results.yaw_release_overshoot = yaw_overshoot
	check(absf(player.angular_velocity) < 0.01 and yaw_overshoot < 12.0, "Releasing turn settles heading without continued spinning")
	reset_player(player)
	simulate(player, 1.0, 1, 1, 0)
	check(Vector2(player.velocity.x, player.velocity.z).length() <= player.cruise_speed + 0.01, "Diagonal controls respect the aircraft speed limit")
	var speed_samples: Array[float] = []
	for hz in [30, 60, 120]:
		reset_player(player)
		simulate(player, 0.4, 0, 1, 0, hz)
		speed_samples.append(player.velocity.x)
	results.strafe_speed_by_30_60_120_hz = speed_samples
	check(speed_samples.max() - speed_samples.min() < 0.75, "Strafe response remains consistent at 30, 60, and 120 physics ticks")
	for aircraft in ["apache", "nighthawk", "warlock"]:
		reset_player(player)
		player.aircraft_type = aircraft
		simulate(player, 1.0, 1, 0, 1)
		check(is_finite(player.velocity.x) and is_finite(player.bank_angle) and player.angular_velocity < 0.0, aircraft + " turns right predictably during forward flight")
	var file = FileAccess.open("res://artifacts/helicopter-lateral-handling-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "\t"))
	file.close()
	player.free()
	await process_frame
	print("FLIGHT_METRICS ", JSON.stringify(results))
	print("LATERAL_HANDLING ", checks - failed, "/", checks, " passed")
	quit(1 if failed else 0)
