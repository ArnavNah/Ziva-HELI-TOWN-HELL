extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", description)
	if not ok:
		failures += 1

func frames(count: int) -> void:
	for i in count:
		await process_frame

func run() -> void:
	if OS.get_environment("ZIVA_TEST_DATA_DIR").is_empty():
		quit(2)
		return
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var deadline := Time.get_ticks_msec() + 30000
	while not game.session_started and Time.get_ticks_msec() < deadline:
		await process_frame
	check(game.session_started, "production town and helicopter are ready")
	if not game.session_started:
		quit(1)
		return
	var manager = game.get_node("MissionManager")
	manager.set_process(false)
	root.get_node("CombatDirector").stop_wave_director()
	root.get_node("CombatDirector").current_wave = 3
	var player = game.get_node("PlayerHelicopter")
	player.set_process(false)
	player.set_physics_process(false)
	var camera: Camera3D = player.get_node("PlayerCamera")
	camera.set_process(false)
	check(manager.start_mission("medevac"), "medevac creates the visible pickup and delivery sites")
	var pickup = manager.pickup_site
	var delivery = manager.delivery_site
	var tracker = manager.get_node("MissionTracker")
	var navigation = tracker.get_child(0).get_node("MissionNavigation")
	player.global_position = pickup.global_position + Vector3(8, 15, 6)
	camera.global_position = pickup.global_position + Vector3(0, 25, 35)
	camera.look_at(pickup.global_position + Vector3.UP * 8)
	await frames(10)
	RenderingServer.force_draw(false)
	check(pickup.beacon.visible and pickup.caption_label.visible and not delivery.beacon.visible, "only the active pickup has a world beacon and caption")
	check("MEDEVAC" in tracker.title.text and manager.phase in tracker.phase_label.text, "mission panel names the real objective and phase")
	check("TO MARKER" in tracker.details.text and tracker.progress_caption.visible, "mission panel shows distance and labeled progress")
	camera.look_at(camera.global_position + (camera.global_position - pickup.get_navigation_anchor()))
	await frames(10)
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://artifacts/mission-pass-20261023/offscreen-guidance-1280.png")
	check(navigation.last_offscreen, "objective behind the camera produces screen-edge guidance")
	check(navigation.last_point.x >= 30 and navigation.last_point.x <= 1250 and navigation.last_point.y >= 75 and navigation.last_point.y <= 645, "screen-edge guidance stays inside the play area")
	manager.phase = "DELIVER"
	manager.objective_site = delivery
	pickup.set_active_marker(false)
	delivery.set_active_marker(true)
	await frames(10)
	RenderingServer.force_draw(false)
	check(not pickup.beacon.visible and not pickup.caption_label.visible and delivery.beacon.visible and delivery.caption_label.visible, "delivery switch removes the stale pickup beacon")
	check(tracker.panel_style.border_color == delivery.marker_color and "DELIVER" in tracker.phase_label.text, "panel changes color and phase with the active delivery site")
	root.size = Vector2i(960, 540)
	await frames(10)
	RenderingServer.force_draw(false)
	var screen_point: Vector2 = navigation.last_point * Vector2(root.size) / navigation.size
	check(screen_point.x >= 20 and screen_point.x <= 940 and screen_point.y >= 55 and screen_point.y <= 485, "guidance remains on-screen at 960 by 540")
	manager.cancel_mission("Visual test complete", false)
	await frames(10)
	RenderingServer.force_draw(false)
	check(not manager.is_mission_active and tracker.title.text == "TACTICAL OPERATIONS", "finished mission clears active visual guidance")
	print("MISSION_VISUALS ", checks - failures, "/", checks)
	game.queue_free()
	await frames(3)
	quit(0 if failures == 0 else 1)
