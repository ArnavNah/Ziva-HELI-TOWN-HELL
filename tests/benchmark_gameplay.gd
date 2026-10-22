extends SceneTree
## Reproducible renderer benchmark: 24 active enemies, same flight route and seed.
var game: Node3D
var player: Node3D
var frame_times: Array[float] = []
var process_times: Array[float] = []
var physics_times: Array[float] = []
var draw_calls: Array[float] = []
var primitives: Array[float] = []
var frame := 0
var last_tick := 0
var label := "baseline"
var boot_started := 0
var load_ms := 0.0
var route_size := 65.0
var sample_started := 0

func _init() -> void:
	call_deferred("start")

func start() -> void:
	DisplayServer.window_move_to_foreground()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="):
			label = arg.trim_prefix("--label=")
		if arg == "--expanded":
			route_size = 235.0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	seed(811)
	boot_started = Time.get_ticks_usec()
	game = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	load_ms = (Time.get_ticks_usec() - boot_started) / 1000.0
	root.get_node("CombatDirector").is_wave_active = false
	player = game.get_node("PlayerHelicopter")
	player.is_invulnerable = true
	player.position = Vector3(0, 22, route_size)
	var roles := ["flak_tank", "scout_buggy", "attack_wing", "scout_drone", "attack_gunship", "infantry_squad", "mortar_crawler", "shield_drone"]
	var spawner := game.get_node("EnemySpawner")
	if OS.get_cmdline_user_args().has("--art-load"):
		var candidates: Array[DestructibleBuilding] = []
		for block in game.get_node("CityGenerator").spawned_blocks:
			if block is DestructibleBuilding and block.position.distance_to(Vector3(0, 0, route_size)) < 130:
				candidates.append(block)
		for i in mini(8, candidates.size()):
			var building := candidates[i]
			var affinity: float = GameConstants.DAMAGE_AFFINITY_MATRIX[GameConstants.WeaponType.ROCKET][GameConstants.TargetAffinity.STRUCTURE]
			building.damage_receiver.take_damage(DamageData.new(building.max_building_health * (0.65 if i < 4 else 2.0) / affinity, GameConstants.WeaponType.ROCKET))
	for i in 24:
		var angle := TAU * float(i) / 24.0
		var role: String = roles[i % roles.size()]
		var altitude := 1.0 if EnemyData.VARIANTS[role].family == "ground" else 28.0
		var point := Vector3(cos(angle) * 85, altitude, route_size - 65.0 + sin(angle) * 85)
		point.z = clampf(point.z, -298, 298)
		if altitude < 2:
			point.x = roundf(point.x / 38) * 38
		spawner.spawn_enemy_type(role, point)
	if OS.get_cmdline_user_args().has("--no-shadows"):
		game.get_node("WeatherSystem/DirectionalLight3D").shadow_enabled = false
	last_tick = Time.get_ticks_usec()
	sample_started = last_tick
	process_frame.connect(sample)

func sample() -> void:
	var now := Time.get_ticks_usec()
	var wall_ms := (now - last_tick) / 1000.0
	last_tick = now
	frame += 1
	var elapsed := (now - sample_started) / 1000000.0
	var angle := elapsed * 0.5 * 65.0 / route_size
	player.position = Vector3(sin(angle) * route_size, 22, cos(angle) * route_size)
	player.rotation.y = -angle
	player.velocity = Vector3.ZERO
	if elapsed > 2.0:
		frame_times.append(wall_ms)
		process_times.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000)
		physics_times.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000)
		draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	if elapsed >= 8.0:
		finish.call_deferred()

func average(values: Array[float]) -> float:
	var total := 0.0
	for value in values:
		total += value
	return total / maxf(values.size(), 1)

func finish() -> void:
	process_frame.disconnect(sample)
	var mean := average(frame_times)
	frame_times.sort()
	var result := {
		"label": label, "resolution": str(root.size), "samples": frame_times.size(),
		"mean_frame_ms": mean, "fps": 1000.0 / mean,
		"p95_frame_ms": frame_times[int(frame_times.size() * 0.95)],
		"mean_process_ms": average(process_times), "mean_physics_ms": average(physics_times),
		"mean_draw_calls": average(draw_calls), "mean_primitives": average(primitives),
		"load_ms": load_ms, "scene_nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"enemies": get_nodes_in_group("enemies").size(), "grid": game.get_node("CityGenerator").grid_width,
	}
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var output := FileAccess.open("res://artifacts/performance_" + label + ".json", FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "\t"))
	print("BENCHMARK: ", JSON.stringify(result))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/performance_" + label + ".png")
	quit()
