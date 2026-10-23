extends SceneTree

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures.append(label)

func frames(count: int) -> void:
	for index in range(count):
		await process_frame

func capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	RenderingServer.force_draw(false)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/" + filename)

func run() -> void:
	if OS.get_environment("ZIVA_TEST_DATA_DIR").is_empty():
		quit(2)
		return
	var pm: Node = root.get_node("ProfileManager")
	pm.wallet_credits = 100898
	pm.salvage = 25
	pm.high_score = 18000
	var menu: Control = load("res://scenes/ui/vehicle_selection_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await frames(30)
	for dimensions in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(1920, 1080), Vector2i(2560, 1080)]:
		root.size = dimensions
		await frames(5)
		for index in range(3):
			menu.select_aircraft(index)
			await create_timer(0.4).timeout
			var dossier: Control = menu.get_node("UIOverlay/RightDossierCard")
			var wallet: Control = menu.get_node("UIOverlay/TopRightStatus")
			var cards: Control = menu.get_node("UIOverlay/BottomRow")
			var bounds: Rect2 = menu.get_global_rect()
			var all_inside := true
			for widget in [dossier, wallet, cards, menu.deploy_btn, menu.armory_btn, menu.back_btn]:
				all_inside = all_inside and bounds.grow(1).encloses(widget.get_global_rect())
			check(all_inside, "%dx%d aircraft %d primary widgets fit viewport" % [dimensions.x, dimensions.y, index])
			check(not dossier.get_global_rect().intersects(cards.get_global_rect()), "dossier and carousel never overlap")
			var previous_end := 0.0
			var rows: Control = menu.find_child("PerformanceRows", true, false)
			var aligned := true
			for row in rows.get_children():
				aligned = aligned and row.position.y >= previous_end
				previous_end = row.position.y + row.size.y
			check(aligned, "performance rows reserve separate vertical space")
		if dimensions == Vector2i(1280, 720):
			await capture("aircraft-selection-repaired.png")
		if dimensions == Vector2i(960, 540):
			await capture("aircraft-selection-repaired-960.png")
	root.size = Vector2i(1280, 720)
	menu.select_aircraft(0)
	await create_timer(0.5).timeout
	check(menu.stage_viewport.render_target_update_mode != SubViewport.UPDATE_ALWAYS, "idle showroom does not render continuously")
	var holder := Control.new()
	root.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.reparent(holder)
	holder.hide()
	await frames(3)
	check(menu.stage_viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "hiding an ancestor disables showroom rendering")
	holder.show()
	await frames(4)
	check(menu.stage_viewport.render_target_update_mode != SubViewport.UPDATE_DISABLED, "showroom redraws when ancestor becomes visible")
	menu.hide()
	var result: Control = load("res://src/ui/menus/debrief_screen.gd").new()
	root.add_child(result)
	var summary := {"score": 3399, "high_score": 18000, "previous_high_score": 18000,
		"survival_time": 65, "kills": 20, "coins_collected": 75, "wave_reached": 2,
		"is_new_high_score": false, "successful": false}
	result.show_debrief(summary)
	await create_timer(0.3).timeout
	check(result.run_score_label.is_visible_in_tree() and result.run_score_label.text == "3399", "game-over run score is visibly displayed")
	check(result.high_score_label.is_visible_in_tree() and result.high_score_label.text == "18000", "game-over high score is visibly displayed")
	check(result.run_stats_label.text.contains("01:05") and result.run_stats_label.text.contains("KILLS 20"), "game-over compact stats come from settled summary")
	check(not result.record_badge_label.visible, "lower score does not claim a record")
	await capture("game-over-score-repaired.png")
	summary.score = 24000
	summary.high_score = 24000
	summary.is_new_high_score = true
	result.show_debrief(summary)
	await frames(3)
	check(result.high_score_label.text == "24000" and result.record_badge_label.visible, "new high score is visible immediately")
	for dimensions in [Vector2i(960, 540), Vector2i(1920, 1080), Vector2i(2560, 1080)]:
		root.size = dimensions
		await frames(4)
		var bounds: Rect2 = result.get_global_rect()
		check(bounds.grow(1).encloses(result.run_score_label.get_global_rect()) and bounds.grow(1).encloses(result.high_score_label.get_global_rect()), "both scores fit resized results screen")
	paused = false
	result.free()
	holder.free()
	current_scene = null
	await frames(3)
	if DisplayServer.get_name() != "headless":
		var flow: Node = root.get_node("UIFlow")
		flow.busy = true
		var game: Node3D = load("res://scenes/main_game.tscn").instantiate()
		game.session_started = true
		root.add_child(game)
		current_scene = game
		while not game.is_prepared:
			await process_frame
		flow.busy = false
		root.size = Vector2i(1280, 720)
		var overlay: Control = game.get_node("UI/DebriefScreen")
		summary.score = 3399
		summary.high_score = 18000
		summary.is_new_high_score = false
		overlay.show_debrief(summary)
		await create_timer(0.3).timeout
		await capture("game-over-score-gameplay.png")
		check(overlay.run_score_label.text == "3399" and overlay.high_score_label.text == "18000", "scores remain correct over the actual paused battlefield")
		paused = false
		game.free()
		current_scene = null
		await frames(3)
	print("LAYOUT_AND_RESULTS ", checks - failures.size(), "/", checks, " failures=", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
