extends SceneTree
## Behavior tests. The launcher MUST supply ZIVA_TEST_DATA_DIR before autoload initialization.
var checks: int = 0
var failures: Array[String] = []
var captures: bool = false
var timings: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	print("PASS " if condition else "FAIL ", message)
	if not condition:
		failures.append(message)

func frames(count: int = 3) -> void:
	for i in count:
		await process_frame

func screenshot(name: String) -> void:
	if not captures:
		return
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://artifacts/menu-repair-tests/" + name + ".png")

func click(button: BaseButton) -> void:
	await frames(2)
	# Uses actual GUI routing, including screen-space hitboxes and button focus.
	var center := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = center
	motion.global_position = center
	Input.parse_input_event(motion)
	# Let GUI hover routing consume the synthetic motion before button-down.
	await frames(1)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = center
		event.global_position = center
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames(1)
	await frames(2)

func action(name: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = name
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames(1)
	await frames(2)

func joy(button: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames(1)
	await frames(2)

func wait_run() -> bool:
	var deadline := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline:
		var flow = root.get_node("UIFlow")
		if not flow.busy and current_scene and current_scene.name == "MainGame":
			await frames(3)
			return true
		if is_instance_valid(flow.loader) and flow.loader.phase == flow.loader.Phase.FAILED:
			print("LOADER FAILURE: ", flow.loader.progress_label.text)
			return false
		await process_frame
	return false

func run() -> void:
	if OS.get_environment("ZIVA_TEST_DATA_DIR").is_empty():
		push_error("Refusing to modify the real profile. Use tools/run_menu_checks.py.")
		quit(1)
		return
	captures = DisplayServer.get_name() != "headless"
	root.size = Vector2i(1280, 720)
	var gm = root.get_node("GameManager")
	var pm = root.get_node("ProfileManager")
	var store = root.get_node("SettingsStore")
	var flow = root.get_node("UIFlow")
	await frames()
	check(pm.SAVE_PATH.begins_with(OS.get_environment("ZIVA_TEST_DATA_DIR")), "isolated profile path")
	# Settings survive re-reading disk and update both owners.
	for key in ["master", "sfx", "music"]:
		store.set_value(key, 0.0)
	check(root.get_node("AudioManager").master_volume == 0.0, "master mute applied")
	store.set_value("fps", 120)
	store.set_value("shake", 0)
	store.set_value("flashes", true)
	store.set_value("telemetry", false)
	store.set_value("vsync", true)
	check(gm.target_fps == 120 and Engine.max_fps == 120, "FPS owner and engine synchronized")
	check(store.flush(), "settings saved")
	store.values = store.DEFAULTS.duplicate()
	store.load_settings()
	store.apply_all(false)
	check(store.values.shake == 0 and store.values.flashes and not gm.show_fps_telemetry, "settings survive disk reload")
	store.set_value("fps", 60)
	store.set_value("vsync", false)
	# Profile validation, exact-once transactions, all rank keys, all mod IDs.
	pm.wallet_credits = 0
	check(not pm.buy_hangar_upgrade("engine"), "unaffordable purchase refused")
	pm.wallet_credits = 100000
	for key in pm.hangar_ranks:
		pm.hangar_ranks[key] = 0
		check(pm.buy_hangar_upgrade(key), "buy system " + key)
		check(not pm.buy_hangar_upgrade(key), "same-frame duplicate system purchase refused")
		await frames(1)
	for key in pm.perk_ranks:
		pm.perk_ranks[key] = 0
		check(pm.buy_perk(key), "buy perk " + key)
		await frames(1)
	pm.hangar_ranks.engine = 5
	check(not pm.buy_hangar_upgrade("engine"), "maximum rank refused")
	pm.hangar_ranks.engine = 1
	check(not pm.buy_perk("invalid") and not pm.equip_mod(0, 999), "invalid purchase and mod IDs rejected")
	for weapon in 4:
		for mod in [0, weapon * 2 + 1, weapon * 2 + 2]:
			check(pm.equip_mod(weapon, mod), "equip valid weapon/mod %s/%s" % [weapon, mod])
	pm.save_profile()
	pm.load_profile()
	check(pm.hangar_ranks.engine == 1 and pm.perk_ranks.emp_rounds == 1, "purchases survive disk reload")
	# Boot and actual menu hitboxes.
	flow.return_to_menu()
	await frames(8)
	var menu = current_scene
	await screenshot("01-main-menu")
	await click(menu.settings_btn)
	var settings = menu.get_node("SettingsMenu")
	check(settings.visible and menu.start_btn.disabled, "Settings mouse click opens modal and blocks main menu")
	await screenshot("02-settings")
	await click(settings.tab_controls_btn)
	check(settings.controls_box.visible, "controls tab works")
	await screenshot("03-controls")
	await action("ui_cancel")
	check(not settings.visible, "Back closes settings")
	await click(menu.manual_btn)
	check(menu.manual_dialog.visible, "flight manual opens")
	await screenshot("03b-flight-manual")
	menu.manual_dialog.hide()
	await frames()
	await click(menu.exit_btn)
	check(is_instance_valid(flow.confirmation), "Exit asks for confirmation")
	if is_instance_valid(flow.confirmation):
		flow.confirmation.canceled.emit()
		flow.confirmation.hide()
	await frames()
	check(root.gui_get_focus_owner() == menu.exit_btn, "quit cancellation restores initiating focus")
	await click(menu.start_btn)
	var selection = menu.get_node("VehicleSelectionMenu")
	check(selection.visible, "Play opens aircraft selection")
	selection.select_aircraft(0)
	await frames(3)
	await click(selection.next_btn)
	check(selection.current_aircraft_idx == 1, "Next selects Nighthawk")
	await click(selection.prev_btn)
	check(selection.current_aircraft_idx == 0, "Previous selects Apache")
	selection.select_aircraft(1)
	await click(selection.armory_btn)
	var hangar = menu.get_node("HangarMenu")
	check(hangar.visible and not selection.visible, "selection opens Hangar")
	for tab in 4:
		await click(hangar.tab_buttons[tab])
		check(int(hangar.current_tab) == tab, "Hangar tab %d" % tab)
		await screenshot("04-hangar-" + str(tab))
	await click(hangar.back_button)
	check(selection.visible and selection.current_aircraft_idx == 1, "Hangar returns to selected aircraft")
	await screenshot("05-aircraft")
	# Five complete transitions cover all aircraft plus retries and cleanup.
	for cycle in 5:
		var aircraft: String = ["apache", "nighthawk", "warlock"][cycle % 3]
		var started := Time.get_ticks_msec()
		check(flow.begin_run(aircraft), "deployment accepted " + aircraft)
		check(not flow.begin_run(aircraft), "duplicate deployment refused")
		await frames(2)
		if cycle == 0:
			await screenshot("06-loading")
		var loaded := await wait_run()
		check(loaded, "gameplay readiness handoff cycle %d" % cycle)
		if not loaded:
			break
		timings.append({"cycle": cycle, "aircraft": aircraft, "load_ms": Time.get_ticks_msec() - started, "animation": flow.last_loading_metrics})
		var game = current_scene
		var player = game.player
		root.get_node("CombatDirector").stop_wave_director()
		player.is_invulnerable = true
		check(player.aircraft_type == aircraft and game.session_started, "correct aircraft and initialized session")
		var stats: Dictionary = pm.preview_stats(aircraft)
		check(is_equal_approx(player.max_hull, stats.hull) and is_equal_approx(player.cruise_speed, stats.speed), "permanent hull/speed applied")
		pm.apply_loadout(player)
		check(is_equal_approx(player.cruise_speed, stats.speed), "loadout never stacks twice")
		check(player.pickup_radius_multiplier > 1 and player.fuel_drain_rate < GameConstants.FUEL_DRAIN_PER_SECOND, "magnet and fuel perks connected")
		check(player.handling_multiplier > 1 and player.thrust_multiplier > 1 and player.collision_resistance > 0, "rotor, thrust and collision bonuses connected")
		check(player.get_node("Weapons").permanent_emp_chance > 0 and player.get_node("Weapons").weapon_states[0].active_mod == 2, "weapon mods and EMP perk connected")
		check(player.get_node("Countermeasures").max_charges > GameConstants.FLARE_BASE_CHARGES and player.get_node("DevastationSuper").charge_multiplier > 1, "flares and Super perks connected")
		check(player.get_node("Salvo").paint_speed_multiplier > 1 and player.get_node("Salvo").lock_range_multiplier > 1, "targeting and salvo range connected")
		var pause = game.get_node("UI/PauseMenu")
		if cycle == 0:
			await joy(JOY_BUTTON_START)
		else:
			await action("pause")
		check(paused and gm.current_state == gm.RunState.PAUSED and pause.visible, "pause state and simulation agree")
		if cycle == 0:
			await screenshot("07-pause")
		await click(pause.settings_btn)
		check(game.get_node("UI/SettingsMenu").visible, "pause Settings opens")
		await action("ui_cancel")
		check(paused and pause.panel.visible and gm.current_state == gm.RunState.PAUSED, "Settings Back returns to pause")
		pause._on_restart_pressed()
		check(is_instance_valid(flow.confirmation), "Restart requires confirmation")
		if is_instance_valid(flow.confirmation):
			flow.confirmation.hide()
		await frames()
		pause._on_resume_pressed()
		check(not paused and gm.current_state == gm.RunState.ACTIVE, "Resume restores active state")
		# Mandatory modal cannot be dismissed by pause.
		var xp = root.get_node("XpManager")
		var draft = game.get_node("UI/LevelUpUi")
		xp.add_xp(ceili(float(xp.target_xp - xp.current_xp) / xp.xp_multiplier))
		var draft_deadline := Time.get_ticks_msec() + 5000
		while not draft.visible and Time.get_ticks_msec() < draft_deadline:
			await process_frame
		check(draft.visible, "production upgrade offered")
		pause.toggle_pause()
		check(paused and gm.current_state == gm.RunState.UPGRADE_CHOICE, "pause cannot bypass upgrade")
		if cycle == 0:
			await screenshot("08-upgrade")
		await click(draft.card_buttons[0])
		check(xp.queued_level_ups == 0 and gm.current_state == gm.RunState.ACTIVE, "production upgrade applies once")
		if cycle == 0:
			var boss = game.get_node("UI/BossDecisionDialog")
			boss._on_boss_defeated()
			var boss_credit: int = gm.banked_credits
			boss._on_boss_defeated()
			check(gm.banked_credits == boss_credit and paused, "boss reward is granted once")
			pause.toggle_pause()
			check(gm.current_state == gm.RunState.BOSS_DECISION and paused, "pause cannot bypass boss decision")
			await screenshot("09-boss")
			boss._on_overdrive_pressed()
			root.get_node("CombatDirector").stop_wave_director()
			check(gm.current_state == gm.RunState.ACTIVE and not paused, "Continue activates Overdrive and resumes")
		gm.score = 500 + cycle
		gm.run_time = 15.0
		var wallet_before: int = pm.wallet_credits
		var summary: Dictionary = gm.settle_extraction(cycle % 2 == 0, "Test")
		gm.settle_extraction(true)
		pm.record_run(summary)
		check(pm.wallet_credits == wallet_before + summary.total_payout, "settlement paid exactly once")
		pause.toggle_pause()
		check(paused and gm.current_state == gm.RunState.RESULTS, "pause cannot bypass results")
		if cycle == 0:
			await screenshot("10-results")
			if captures:
				game.debrief_screen._on_copy_pressed()
				await frames(2)
				var clip_val: String = DisplayServer.clipboard_get().replace("\r\n", "\n")
				var expected_val: String = String(game.debrief_screen.breakdown_label.text).replace("\r\n", "\n")
				print("DEBUG CLIP LEN: ", clip_val.length(), " EXPECTED LEN: ", expected_val.length())
				check(clip_val == expected_val, "scorecard copies actual report")
		flow.return_to_menu("hangar" if cycle == 0 else "")
		await frames(10)
		check(not paused and gm.current_state == gm.RunState.MENU and not flow.busy, "return menu cleans transition state")
		check(get_nodes_in_group("combat_projectiles").is_empty(), "root projectiles cleaned")
		if cycle == 0:
			check(current_scene.get_node("HangarMenu").visible, "Return to Hangar opens actual Hangar")
	# Failed load -> retry -> back.
	flow.load_destination("res://scenes/no_such_scene.tscn")
	await frames(8)
	check(flow.loader.phase == flow.loader.Phase.FAILED and flow.loader.retry_button.visible, "invalid destination shows Retry and Back")
	await screenshot("11-loading-error")
	flow.loader._retry()
	await frames(8)
	check(flow.loader.phase == flow.loader.Phase.FAILED, "failed retry remains usable")
	flow.loader._back()
	await frames(10)
	check(current_scene.name == "MainMenu" and not flow.busy and not paused, "failed-load Back recovers")
	var result := {"checks": checks, "failures": failures, "rendered": captures, "transitions": timings}
	var report := FileAccess.open("res://artifacts/menu-repair-tests/results-" + ("rendered" if captures else "headless") + ".json", FileAccess.WRITE)
	report.store_string(JSON.stringify(result, "\t"))
	report.close()
	print("MENU_REPAIR_RESULT ", JSON.stringify(result))
	if current_scene:
		current_scene.queue_free()
	root.get_node("UIFlow")._clear_transients()
	await frames(8)
	await load("res://tests/runtime_cleanup.gd").finish(self, 0 if failures.is_empty() else 1)
