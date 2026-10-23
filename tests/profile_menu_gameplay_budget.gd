extends SceneTree

## Repeatable rendered benchmark with active roster, real AI and isolated saves.
var game: Node3D
var player: CharacterBody3D
var report: Dictionary = {}
var timed_ai: Node

class TimedAI extends Node:
	var units: Array[Node] = []
	var totals: Dictionary = {}
	var active := true
	func _physics_process(delta: float) -> void:
		if not active:
			return
		for unit in units:
			if not is_instance_valid(unit) or unit.is_queued_for_deletion():
				continue
			var begin := Time.get_ticks_usec()
			unit._physics_process(delta)
			var duration := Time.get_ticks_usec() - begin
			var id: String = unit.variant_id
			if not totals.has(id):
				totals[id] = {"calls": 0, "total_usec": 0, "max_usec": 0}
			totals[id].calls += 1
			totals[id].total_usec += duration
			totals[id].max_usec = maxi(totals[id].max_usec, duration)

func _initialize() -> void:
	call_deferred("run")

func sample(label: String, frames: int, travel: bool = false) -> void:
	var times: Array[float] = []
	var draw_calls := 0.0
	var primitives := 0.0
	var process_ms := 0.0
	var physics_ms := 0.0
	var last := Time.get_ticks_usec()
	for frame in range(frames):
		if travel:
			player.position = Vector3(sin(float(frame) * 0.025) * 55, 24, cos(float(frame) * 0.025) * 55)
		await process_frame
		# Windows may suppress rendering for the hidden offscreen test window.
		# Force actual draws so these are rendered frame costs, not idle CPU ticks.
		RenderingServer.force_draw(false)
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
		draw_calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		primitives += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		process_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		physics_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var sum := 0.0
	for value in times:
		sum += value
	times.sort()
	var average := sum / frames
	report[label] = {"average_ms": average, "fps": 1000.0 / average,
		"p95_ms": times[int(frames * 0.95)], "draw_calls": draw_calls / frames,
		"primitives": primitives / frames, "process_ms": process_ms / frames,
		"physics_ms": physics_ms / frames,
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"enemies": get_nodes_in_group("enemies").size()}
	print("BENCHMARK ", label, " ", JSON.stringify(report[label]))

func run() -> void:
	if OS.get_environment("ZIVA_TEST_DATA_DIR").is_empty():
		quit(2)
		return
	seed(20261023)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var flow: Node = root.get_node("UIFlow")
	flow.busy = true
	game = load("res://scenes/main_game.tscn").instantiate()
	game.session_started = true
	root.add_child(game)
	current_scene = game
	while not game.is_prepared:
		await process_frame
	flow.busy = false
	var manager: Node = root.get_node("GameManager")
	manager.current_state = 2
	manager.set_process(false)
	var director: Node = root.get_node("CombatDirector")
	director.stop_wave_director()
	director.current_wave = 12
	director.is_wave_active = true
	director.set_process(false)
	game.get_node("MissionManager").set_process(false)
	game.get_node("CargoManager").set_process(false)
	player = game.get_node("PlayerHelicopter")
	player.set_physics_process(false)
	player.is_invulnerable = true
	player.position = Vector3(0, 24, 55)
	var spawner: Node = game.get_node("EnemySpawner")
	spawner.set_process(false)
	var roles := ["scout_buggy", "assault_apc", "raptor_raider", "desert_barrage_rover", "rail_crawler", "siege_tank", "gatling_heavy", "attack_gunship", "scout_drone", "attack_wing"]
	for index in range(24):
		var id: String = roles[index % roles.size()]
		var angle := TAU * float(index) / 24.0
		var point := Vector3(cos(angle) * 70, 0, sin(angle) * 70)
		if EnemyData.VARIANTS[id].family == "ground":
			point = UrbanPathfinder.get_nearest_road_point(point)
		else:
			point.y = 22
		spawner.spawn_enemy_type(id, point, true)
	Engine.max_fps = 0
	if OS.get_environment("ZIVA_AI_TIMING") == "1":
		timed_ai = TimedAI.new()
		for unit in get_nodes_in_group("enemies"):
			unit.set_physics_process(false)
			timed_ai.units.append(unit)
		game.add_child(timed_ai)
	for frame in range(45):
		await process_frame
		RenderingServer.force_draw(false)
	await sample("combat_stationary", 90)
	await sample("combat_flight", 120, true)
	if timed_ai:
		print("AI_TIMINGS ", JSON.stringify(timed_ai.totals))
		timed_ai.active = false
	# Diagnose CPU and rendering independently without modifying production assets.
	for unit in get_nodes_in_group("enemies"):
		unit.set_physics_process(false)
	await sample("ai_disabled_diagnostic", 60)
	var city: Node3D = game.get_node("CityGenerator")
	city.visible = false
	await sample("city_hidden_diagnostic", 60)
	city.visible = true
	var label := OS.get_environment("ZIVA_BENCH_LABEL")
	if label.is_empty():
		label = "current"
	var file := FileAccess.open("res://artifacts/runtime-budget-%s.json" % label, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	director.stop_wave_director()
	game.free()
	current_scene = null
	await process_frame
	quit(0)
