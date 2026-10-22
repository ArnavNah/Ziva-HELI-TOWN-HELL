extends "res://tests/test_menu_repair.gd"

func run() -> void:
	if OS.get_environment("ZIVA_TEST_DATA_DIR").is_empty():
		quit(1)
		return
	captures = DisplayServer.get_name() != "headless"
	root.size = Vector2i(1280, 720)
	var flow = root.get_node("UIFlow")
	var gm = root.get_node("GameManager")
	var store = root.get_node("SettingsStore")
	flow.return_to_menu()
	await frames(8)
	var menu = current_scene
	await click(menu.start_btn)
	var selection = menu.get_node("VehicleSelectionMenu")
	await click(selection.card_buttons[2])
	check(selection.current_aircraft_idx == 2, "aircraft card click selects Warlock")
	selection.back_btn.grab_focus()
	await joy(JOY_BUTTON_A)
	check(not selection.visible and not flow.busy, "controller confirm activates focused Back instead of Deploy")
	await click(menu.start_btn)
	check(selection.current_aircraft_idx == 2, "Back retains aircraft selection")
	await click(selection.armory_btn)
	var hangar = menu.get_node("HangarMenu")
	var pm = root.get_node("ProfileManager")
	pm.wallet_credits = 5000
	pm.hangar_ranks.engine = 0
	pm.perk_ranks.magnet_radius = 0
	pm.equipped_mods[0] = 0
	hangar._switch_tab(hangar.TabIndex.SYSTEMS)
	await frames(3)
	var purchase: Button
	for button in hangar.content_container.find_children("*", "Button", true, false):
		if button.get_meta("purchase_key", "") == "system:engine":
			purchase = button
	await click(purchase)
	check(pm.hangar_ranks.engine == 1 and pm.wallet_credits == 4810, "system purchase button charges correct price and changes correct rank")
	hangar._switch_tab(hangar.TabIndex.PERKS)
	await frames(3)
	for button in hangar.content_container.find_children("*", "Button", true, false):
		if button.get_meta("purchase_key", "") == "perk:magnet_radius":
			purchase = button
	await click(purchase)
	check(pm.perk_ranks.magnet_radius == 1 and pm.wallet_credits == 4710, "perk purchase button charges correct price and changes correct rank")
	hangar._switch_tab(hangar.TabIndex.MODS)
	await frames(3)
	for button in hangar.content_container.find_children("*", "Button", true, false):
		if button.get_meta("purchase_key", "") == "mod:0:1":
			purchase = button
	await click(purchase)
	check(pm.equipped_mods[0] == 1, "Equip button updates correct weapon and mod")
	hangar._on_back_pressed()
	await frames(3)
	selection.deploy_btn.grab_focus()
	Input.action_press("climb")
	await click(selection.deploy_btn)
	check(flow.busy and gm.current_state == gm.RunState.LOADING and paused, "actual Deploy button starts protected loading")
	check(not root.get_node("CombatDirector").is_wave_active, "combat waits during loading")
	var loaded := await wait_run()
	check(loaded, "Deploy button reaches ready gameplay")
	check(not flow.gameplay_input_allowed(), "held launch input remains blocked after reveal")
	Input.action_release("climb")
	await frames(4)
	check(flow.gameplay_input_allowed(), "gameplay input arms after held input is released")
	if not loaded:
		quit(1)
		return
	root.get_node("CombatDirector").stop_wave_director()
	var pause = current_scene.get_node("UI/PauseMenu")
	await action("pause")
	await click(pause.restart_btn)
	check(is_instance_valid(flow.confirmation), "actual Restart button opens confirmation")
	var old_id: String = gm.run_id
	flow.confirmation.confirmed.emit()
	flow.confirmation.hide()
	check(await wait_run(), "confirmed Restart uses loading service")
	check(gm.run_id != old_id and gm.selected_aircraft == "warlock" and gm.run_time < 1.0, "Restart initializes one fresh sortie with same aircraft")
	root.get_node("CombatDirector").stop_wave_director()
	# Offer cardinalities, invalid indices, consecutive choices, conflicting boss events.
	var dialog = current_scene.upgrade_dialog
	var rp = current_scene.player.get_node("RunProgression")
	for count in [1, 2, 3]:
		rp.current_offers.assign(["Reinforced Hull", "Field Repair", "Hair Trigger"].slice(0, count))
		rp.queued_level_ups = 1
		gm.change_state(gm.RunState.UPGRADE_CHOICE)
		dialog.show_choices(rp.current_offers)
		var buttons := [dialog.button_1, dialog.button_2, dialog.button_3]
		check(buttons[count - 1].visible and (count == 3 or not buttons[count].visible), "%d upgrade cards hide unavailable slots" % count)
		dialog._choose_card(-1)
		check(dialog.visible, "invalid upgrade index preserves choice")
		dialog._choose_card(0)
	check(gm.current_state == gm.RunState.ACTIVE, "valid card resumes gameplay")
	var xp = root.get_node("XpManager")
	xp.reset_run()
	var draft = current_scene.get_node("UI/LevelUpUi")
	xp.add_xp(88) # Level-one and level-two requirements: 25 + 63.
	var boss = current_scene.get_node("UI/BossDecisionDialog")
	boss._on_boss_defeated()
	check(boss.pending and draft.visible and not boss.visible, "boss decision waits for mandatory upgrade")
	draft.card_buttons[0].pressed.emit()
	check(draft.visible and xp.queued_level_ups == 1, "queued level-up presents next choice")
	draft.card_buttons[0].pressed.emit()
	await frames(3)
	check(boss.visible and gm.current_state == gm.RunState.BOSS_DECISION, "boss decision follows completed upgrade queue")
	await click(boss.extract_btn)
	check(gm.current_state == gm.RunState.RESULTS and paused, "Extract button settles victory and keeps results paused")
	var results = current_scene.debrief_screen
	var settled_run_id: String = gm.run_id
	var earned_wallet: int = pm.wallet_credits
	await click(results.retry_button)
	await frames(12)
	check(current_scene.name == "MainMenu" and not flow.busy and not paused, "Play Again returns to the front end without starting combat")
	selection = current_scene.get_node("VehicleSelectionMenu")
	check(selection.visible and root.gui_get_focus_owner() == selection.deploy_btn, "Play Again opens aircraft selection with Deploy focused")
	check(gm.run_id == settled_run_id and pm.wallet_credits == earned_wallet and not root.get_node("CombatDirector").is_wave_active, "selection does not create another run or pay rewards again")
	await click(selection.card_buttons[1])
	await click(selection.deploy_btn)
	check(await wait_run(), "Deploy after Play Again starts a fresh run through protected loading")
	check(gm.run_id != settled_run_id and gm.selected_aircraft == "nighthawk", "the new run uses the newly selected aircraft")
	root.get_node("CombatDirector").stop_wave_director()
	gm.settle_extraction(false, "Test")
	await create_timer(0.3).timeout
	await screenshot("minimal-game-over")
	await click(current_scene.debrief_screen.quit_button)
	await frames(10)
	check(current_scene.name == "MainMenu" and not current_scene.get_node("VehicleSelectionMenu").visible and not current_scene.get_node("HangarMenu").visible, "Quit returns to the main menu without opening another screen")
	# Preference rollback and timeout; these tests also run with a real display.
	store.preview_display(1)
	check(is_instance_valid(store.display_dialog), "display change offers Keep/Revert")
	store._display_remaining = 0.01
	await frames(3)
	check(not is_instance_valid(store.display_dialog), "display timeout reverts")
	store.preview_display(2)
	store.display_dialog.confirmed.emit()
	check(store.values.window == 2 and not is_instance_valid(store.display_dialog), "display Keep persists chosen mode")
	store.preview_display(0)
	store.display_dialog.confirmed.emit()
	check(store.values.window == 0, "windowed mode can be restored")
	# Screen sizes. Canvas scaling preserves readability at smaller physical windows.
	if captures:
		for viewport_size in [Vector2i(960, 540), Vector2i(1920, 1080), Vector2i(2560, 1080)]:
			root.size = viewport_size
			await frames(4)
			menu = current_scene
			await screenshot("size-%dx%d-main" % [viewport_size.x, viewport_size.y])
			menu._on_settings_pressed()
			await frames(4)
			var settings = menu.get_node("SettingsMenu")
			check(root.get_visible_rect().encloses(settings.close_btn.get_global_rect()), "Done button fits %dx%d" % [viewport_size.x, viewport_size.y])
			await screenshot("size-%dx%d-settings" % [viewport_size.x, viewport_size.y])
			settings._close_settings()
			menu._on_start_pressed()
			await frames(4)
			selection = menu.get_node("VehicleSelectionMenu")
			check(root.get_visible_rect().encloses(selection.deploy_btn.get_global_rect()), "Deploy button fits %dx%d" % [viewport_size.x, viewport_size.y])
			await screenshot("size-%dx%d-aircraft" % [viewport_size.x, viewport_size.y])
			selection._on_back_pressed()
	print("NAVIGATION_EDGES_RESULT checks=", checks, " failures=", JSON.stringify(failures))
	if current_scene:
		current_scene.queue_free()
	await frames(8)
	quit(0 if failures.is_empty() else 1)
