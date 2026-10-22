extends "res://tests/test_menu_repair.gd"

func run() -> void:
	if OS.get_environment("ZIVA_TEST_DATA_DIR").is_empty():
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	var flow = root.get_node("UIFlow")
	var gm = root.get_node("GameManager")
	var pm = root.get_node("ProfileManager")
	flow.begin_run()
	check(await wait_run(), "guard test gameplay ready")
	root.get_node("CombatDirector").stop_wave_director()
	var rp = current_scene.player.get_node("RunProgression")
	var dialog = current_scene.upgrade_dialog
	rp.current_offers.assign(["Reinforced Hull"])
	rp.queued_level_ups = 1
	gm.change_state(gm.RunState.UPGRADE_CHOICE)
	var stale: Array[String] = ["Hair Trigger"]
	dialog.show_choices(stale)
	dialog._choose_card(0)
	check(dialog.visible and rp.queued_level_ups == 1, "stale card cannot dismiss current offer")
	dialog.show_choices(rp.current_offers)
	dialog._choose_card(0)
	check(rp.queued_level_ups == 0, "current offer still works after stale attempt")
	var pause_menu = current_scene.get_node("UI/PauseMenu")
	pause_menu.toggle_pause()
	await click(pause_menu.main_menu_btn)
	check(is_instance_valid(flow.confirmation), "Pause Main Menu requires confirmation")
	if is_instance_valid(flow.confirmation):
		flow.confirmation.hide()
	await frames(3)
	check(paused and pause_menu.visible, "Cancel Main Menu keeps the run paused")
	await click(pause_menu.quit_btn)
	check(is_instance_valid(flow.confirmation), "Pause Quit requires confirmation")
	if is_instance_valid(flow.confirmation):
		flow.confirmation.hide()
	await frames(3)
	check(paused and root.gui_get_focus_owner() == pause_menu.quit_btn, "Cancel Quit restores pause focus")
	pause_menu._on_resume_pressed()
	pm.high_score = 1000
	gm.run_starting_high_score = 1000
	gm.score = 1000
	var summary: Dictionary = gm.settle_extraction(false)
	var results = current_scene.debrief_screen
	check(not summary.is_new_high_score and not results.breakdown_label.text.contains("NEW ALL-TIME"), "tied score is not advertised as a new record")
	pm.record_run({"score": 5000, "total_payout": 0})
	pm.record_run({"score": 2500, "total_payout": 0})
	var ranked := true
	for i in pm.high_scores.size():
		if pm.high_scores[i].rank != i + 1:
			ranked = false
	check(ranked, "leaderboard updates every displayed rank")
	await click(results.quit_button)
	await frames(10)
	check(current_scene.name == "MainMenu" and not current_scene.get_node("HangarMenu").visible, "Results Quit button opens main menu without overlays")
	var settings = current_scene.get_node("SettingsMenu")
	current_scene._on_settings_pressed()
	var credits: int = pm.wallet_credits
	var ranks: Dictionary = pm.hangar_ranks.duplicate()
	root.get_node("SettingsStore").set_value("shake", 0)
	var restore: Button
	for button in settings.find_children("*", "Button", true, false):
		if button.text == "Restore settings defaults":
			restore = button
	# The control is in a scroll panel; scroll into view before GUI activation.
	for candidate in settings.find_children("*", "ScrollContainer", true, false):
		if candidate.is_ancestor_of(restore):
			candidate.ensure_control_visible(restore)
	await frames(3)
	await click(restore)
	check(is_instance_valid(flow.confirmation), "Restore defaults button requests scoped confirmation")
	if is_instance_valid(flow.confirmation):
		flow.confirmation.confirmed.emit()
		flow.confirmation.hide()
	await frames(3)
	check(root.get_node("SettingsStore").values.shake == 2 and pm.wallet_credits == credits and pm.hangar_ranks == ranks, "Restore defaults changes preferences only")
	settings._close_settings()
	check(not settings.visible, "Done closes restored preferences")
	print("MENU_GUARDS_RESULT checks=", checks, " failures=", JSON.stringify(failures))
	current_scene.queue_free()
	await frames(8)
	quit(0 if failures.is_empty() else 1)
