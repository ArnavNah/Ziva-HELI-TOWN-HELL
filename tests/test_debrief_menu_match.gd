extends "res://tests/test_menu_repair.gd"
## Minimal overlay acceptance; real navigation is tested in test_menu_navigation_edges.gd.

func run() -> void:
	if OS.get_environment("ZIVA_TEST_DATA_DIR").is_empty():
		quit(1)
		return
	captures = DisplayServer.get_name() != "headless"
	root.size = Vector2i(1280, 720)
	var results = load("res://src/ui/menus/debrief_screen.gd").new()
	var legacy := VBoxContainer.new()
	legacy.name = "VBox"
	results.add_child(legacy)
	for label_name in ["OutcomeLabel", "BreakdownLabel"]:
		var label := Label.new()
		label.name = label_name
		legacy.add_child(label)
	var old_actions := HBoxContainer.new()
	old_actions.name = "HBox"
	legacy.add_child(old_actions)
	for button_name in ["RetryButton", "HangarButton", "CopyButton"]:
		var button := Button.new()
		button.name = button_name
		old_actions.add_child(button)
	root.add_child(results)
	current_scene = results
	var pm = root.get_node("ProfileManager")
	var wallet_before: int = pm.wallet_credits
	var records_before: Array = pm.high_scores.duplicate(true)
	var summary := {"successful": false, "cause_of_death": "@CharacterBody3D@2583", "score": 3399, "survival_time": 65.0, "kills": 20, "coins_collected": 75, "total_payout": 145}
	results.show_debrief(summary)
	await create_timer(0.3).timeout
	check(results.visible and paused, "game over pauses the battlefield")
	check(results.outcome_label.text == "GAME OVER" and results.outcome_label.get_theme_font_size("font_size") >= 64, "large GAME OVER headline dominates the overlay")
	check(results.backdrop.color.a > 0.5 and results.backdrop.color.a < 0.9 and results.find_children("*", "TextureRect", true, false).is_empty(), "dark translucent overlay preserves gameplay without hangar artwork")
	var visible_buttons: Array[Button] = []
	for button in results.find_children("*", "Button", true, false):
		if button.is_visible_in_tree():
			visible_buttons.append(button)
	check(visible_buttons.size() == 2 and results.retry_button.text == "PLAY AGAIN" and results.quit_button.text == "QUIT", "only Play Again and Quit appear")
	check(not results.breakdown_label.visible and results.find_children("*", "PanelContainer", true, false).is_empty(), "no results panel or scrolling report covers the game")
	check(root.gui_get_focus_owner() == results.retry_button, "Play Again receives initial focus")
	await action("ui_right")
	check(root.gui_get_focus_owner() == results.quit_button, "keyboard navigation reaches Quit")
	await action("ui_left")
	check(root.gui_get_focus_owner() == results.retry_button, "keyboard navigation returns to Play Again")
	check(results.retry_button.get_theme_font("font") == FloatingText.get_pixel_font(), "overlay keeps the game pixel font")
	check(results.breakdown_label.text.contains("Combat Rating Score: 3399 PTS") and results.breakdown_label.text.contains("Coins Collected: 75"), "settled run report remains available internally")
	for dimensions in [Vector2i(960, 540), Vector2i(1920, 1080), Vector2i(2560, 1080)]:
		root.size = dimensions
		await frames(4)
		var bounds: Rect2 = results.get_global_rect()
		check(bounds.encloses(results.outcome_label.get_global_rect()) and bounds.encloses(results.retry_button.get_global_rect()) and bounds.encloses(results.quit_button.get_global_rect()), "headline and both buttons fit %dx%d" % [dimensions.x, dimensions.y])
	root.size = Vector2i(1280, 720)
	summary.successful = true
	results.show_debrief(summary)
	await create_timer(0.25).timeout
	check(results.outcome_label.text == "VICTORY", "successful extraction uses the same minimal layout")
	var error_before: String = pm.last_error
	pm.last_error = "Save unavailable"
	results.show_debrief(summary)
	check(results.save_status_label.visible and results.save_status_label.text.contains("COULD NOT BE SAVED"), "failed reward persistence remains visible")
	pm.last_error = error_before
	results.show_debrief(summary)
	check(not results.save_status_label.visible, "normal results have no extra warning or report")
	check(pm.wallet_credits == wallet_before and pm.high_scores == records_before, "reopening the overlay never settles or pays the run twice")
	results.queue_free()
	paused = false
	await frames(5)
	var audio = root.get_node("AudioManager")
	audio.set_process(false)
	for child in audio.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	await create_timer(0.15).timeout
	print("MINIMAL_GAME_OVER_RESULT checks=", checks, " failures=", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
