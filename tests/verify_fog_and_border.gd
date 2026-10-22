extends SceneTree

var failures: Array[String] = []
var checks := 0
var warning_received: bool = false
var warning_edge_dist: float = 0.0

func _init() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)
	print("PASS: " if condition else "FAIL: ", description)

func capture(path: String) -> Image:
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	frame.save_png(path)
	return frame

func run() -> void:
	seed(4281)
	var game = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game

	var director := root.get_node("CombatDirector")
	director.is_wave_active = false
	director.stop_wave_director()
	var gm := root.get_node("GameManager")
	gm.set_process(false)

	var weather = game.get_node("WeatherSystem")
	var env: Environment = weather.world_env.environment
	check(env != null, "World environment exists")
	check(env.fog_enabled == true, "Distance fog is enabled")
	check(env.fog_mode == Environment.FOG_MODE_DEPTH, "Fog mode is depth fog")
	check(env.fog_depth_begin >= 100.0 and env.fog_depth_begin <= 130.0, "Fog begin distance is configured for clear local airspace (120m)")
	check(env.fog_depth_end >= 240.0 and env.fog_depth_end <= 280.0, "Fog end distance hides distant horizon structures (260m)")

	var area: PlayableArea = game.get_node("PlayableArea")
	check(area != null, "PlayableArea node exists")
	var border_vis = area.get_node_or_null("BorderVisuals")
	check(border_vis != null, "BorderVisuals node created")
	check(border_vis.get_node_or_null("WarningTowers") != null, "Warning towers multi-mesh exists")
	check(border_vis.get_node_or_null("WarningBeacons") != null, "Warning beacons multi-mesh exists")

	var player = game.get_node("PlayerHelicopter")
	player.set_physics_process(false)
	player.is_invulnerable = false
	var initial_hull = player.current_hull

	# Test 1: In safe zone (250m), no damage
	player.global_position = Vector3(0, 14, 250)
	area._process(0.3)
	check(player.current_hull == initial_hull, "Player takes no damage within safe radius (250m <= 280m)")

	# Test 2: In warning/damage zone (295m), receives border damage
	warning_received = false
	var bus = root.get_node("EventBus")
	bus.border_warning_changed.connect(func(is_w: bool, _dir: Vector3, dist_e: float):
		if is_w:
			warning_received = true
			warning_edge_dist = dist_e
	)

	player.global_position = Vector3(0, 14, 295)
	area._process(0.3)
	check(warning_received, "EventBus emits border warning when beyond safe radius")
	check(player.current_hull < initial_hull, "Player takes proximity hazard damage when near border (current: %.1f < %.1f)" % [player.current_hull, initial_hull])

	# Visual captures
	if DisplayServer.get_name() != "headless":
		await create_timer(0.5).timeout

		# 1. Capture far distance fog looking over the city
		player.global_position = Vector3(0, 24, 0)
		var cam = player.get_node("PlayerCamera")
		cam.init_camera(player)
		cam.update_camera(0.016)
		await create_timer(0.4).timeout
		await capture("res://artifacts/fog_far_distance.png")

		# 2. Capture player approaching the glowing border and warning towers in danger zone
		player.global_position = Vector3(0, 18, -292)
		cam.init_camera(player)
		cam.update_camera(0.016)
		area._process(0.3)
		await create_timer(0.4).timeout
		await capture("res://artifacts/border_hazard_view.png")

	print("\nFOG & BORDER VERIFICATION SUMMARY: %d/%d CHECKS PASSED." % [checks - failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
