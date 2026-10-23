extends SceneTree

## Fixed-scene diagnostics: each change is restored before the next sample.
## Run with --rendered --manual-render and an isolated profile.
var game: Node3D
var results: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func measure(label: String) -> void:
	for warm in range(12):
		await process_frame
		RenderingServer.force_draw(false)
	var elapsed: Array[float] = []
	var draws := 0.0
	var triangles := 0.0
	var last := Time.get_ticks_usec()
	for frame in range(60):
		await process_frame
		RenderingServer.force_draw(false)
		var now := Time.get_ticks_usec()
		elapsed.append((now - last) / 1000.0)
		last = now
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		triangles += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var sum := 0.0
	for value in elapsed:
		sum += value
	elapsed.sort()
	results[label] = {"average_ms": sum / elapsed.size(), "p95_ms": elapsed[57], "draws": draws / 60, "triangles": triangles / 60}
	print("RENDER_FACTOR ", label, " ", JSON.stringify(results[label]))

func run() -> void:
	if OS.get_environment("ZIVA_TEST_DATA_DIR").is_empty():
		quit(2)
		return
	seed(20261024)
	root.get_node("UIFlow").busy = true
	game = load("res://scenes/main_game.tscn").instantiate()
	game.session_started = true
	root.add_child(game)
	current_scene = game
	while not game.is_prepared:
		await process_frame
	root.get_node("UIFlow").busy = false
	root.get_node("CombatDirector").stop_wave_director()
	var player: Node3D = game.get_node("PlayerHelicopter")
	player.position = Vector3(0, 24, 55)
	var roles := ["scout_buggy", "assault_apc", "raptor_raider", "desert_barrage_rover", "rail_crawler", "siege_tank", "gatling_heavy", "attack_gunship", "scout_drone", "attack_wing"]
	for index in range(24):
		var id: String = roles[index % roles.size()]
		var angle := TAU * index / 24.0
		var point := Vector3(cos(angle) * 70, 0, sin(angle) * 70)
		if EnemyData.VARIANTS[id].family == "ground":
			point = UrbanPathfinder.get_nearest_road_point(point)
		else:
			point.y = 22
		game.get_node("EnemySpawner").spawn_enemy_type(id, point, true)
	var camera := Camera3D.new()
	game.add_child(camera)
	camera.fov = 50
	camera.look_at_from_position(player.position + Vector3(0, 33, 35), player.position)
	camera.make_current()
	paused = true
	Engine.max_fps = 0
	await measure("full")
	var lights: Array = game.find_children("*", "Light3D", true, false)
	var shadows: Dictionary = {}
	for light in lights:
		shadows[light] = light.shadow_enabled
		light.shadow_enabled = false
	await measure("no_shadows")
	for light in lights:
		light.shadow_enabled = shadows[light]
	var fill: Node3D = game.get_node("WeatherSystem/DirectionalLight3D_Fill")
	fill.hide()
	await measure("no_fill_light")
	fill.show()
	var grade: CanvasLayer = game.get_node("WeatherSystem/BattlefieldGrade")
	grade.hide()
	var post = root.get_node("ShaderManager").post_process_layer
	var post_was_visible: bool = post.visible if post else false
	if post:
		post.hide()
	await measure("no_postprocess")
	grade.show()
	if post:
		post.visible = post_was_visible
	var overlays: Dictionary = {}
	for mesh in game.find_children("*", "MeshInstance3D", true, false):
		if mesh.material_overlay:
			overlays[mesh] = mesh.material_overlay
			mesh.material_overlay = null
	await measure("no_outlines")
	for mesh in overlays:
		mesh.material_overlay = overlays[mesh]
	game.get_node("CityGenerator").hide()
	await measure("no_city")
	game.get_node("CityGenerator").show()
	await measure("full_repeat")
	var file := FileAccess.open("res://artifacts/render-cost-diagnostics.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "\t"))
	file.close()
	paused = false
	game.free()
	current_scene = null
	await process_frame
	quit(0)
