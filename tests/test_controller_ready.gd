extends SceneTree
var checks := 0
var failures := 0
const PAD := 7 # Synthetic SDL device, deliberately not controller zero.
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", message)
	if not ok: failures += 1
func frames(count: int = 3) -> void:
	for index in range(count): await process_frame
func capture(name: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args(): return
	await frames(8)
	RenderingServer.force_draw(false) # Works while an embedded modal owns window focus.
	root.get_texture().get_image().save_png("res://artifacts/controller-ready/" + name + ".png")
	print("CAPTURE controller-ready/", name)
func button(code: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = PAD
	event.button_index = code
	event.pressed = pressed
	Input.parse_input_event(event)
	await frames(2)
func tap(code: int) -> void:
	await button(code, true)
	await button(code, false)
func axis(code: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = PAD
	event.axis = code
	event.axis_value = value
	Input.parse_input_event(event)
	await frames(2)
func aim_at(point: Vector2, controls: Node) -> void:
	var player := get_first_node_in_group("player") as Node3D
	var anchor := root.get_camera_3d().unproject_position(player.global_position)
	var stick := (point - anchor).normalized()
	await axis(JOY_AXIS_RIGHT_X,stick.x)
	await axis(JOY_AXIS_RIGHT_Y,stick.y)
	await frames(8)
	await axis(JOY_AXIS_RIGHT_X, 0)
	await axis(JOY_AXIS_RIGHT_Y, 0)
func run() -> void:
	if OS.get_environment("ZIVA_TEST_DATA_DIR").is_empty():
		quit(2)
		return
	print("Physical controllers available: ", Input.get_connected_joypads(), " / tests inject device ", PAD)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/controller-ready"))
	root.gui_embed_subwindows = true
	var controls = root.get_node("InputManager")
	var gm = root.get_node("GameManager")
	var flow = root.get_node("UIFlow")
	var store = root.get_node("SettingsStore")
	var event_count := InputMap.action_get_events("next_weapon").size()
	controls._setup_input_actions()
	check(InputMap.action_get_events("next_weapon").size() == event_count, "input setup is idempotent")
	var menu = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await frames(4)
	check(root.gui_get_focus_owner() == menu.start_btn, "operations center starts with gamepad-accessible focus")
	await tap(JOY_BUTTON_DPAD_DOWN)
	check(root.gui_get_focus_owner() == menu.hangar_btn, "D-pad navigates operations center")
	await tap(JOY_BUTTON_DPAD_UP)
	await tap(JOY_BUTTON_A)
	var selection = menu.get_node("VehicleSelectionMenu")
	check(selection.visible and root.gui_get_focus_owner() == selection.deploy_btn, "gamepad A opens aircraft selection and focuses launch")
	var rotation_before: float = selection.turntable_root.rotation.y
	await axis(JOY_AXIS_RIGHT_X, 0.8)
	await frames(8)
	check(absf(selection.turntable_root.rotation.y - rotation_before) > 0.05, "right stick rotates the aircraft showroom")
	await axis(JOY_AXIS_RIGHT_X, 0)
	await tap(JOY_BUTTON_DPAD_UP)
	check(root.gui_get_focus_owner() == selection.biome_selector, "sortie dropdown is reachable by D-pad")
	await tap(JOY_BUTTON_A)
	await tap(JOY_BUTTON_DPAD_DOWN)
	await tap(JOY_BUTTON_A)
	check(gm.selected_biome == "desert", "gamepad selects a biome through the real dropdown")
	gm.selected_biome = "town" # The controller combat fixture uses the known town arena.
	await tap(JOY_BUTTON_B)
	check(not selection.visible, "B returns from aircraft selection")
	menu.hangar_btn.grab_focus()
	await tap(JOY_BUTTON_A)
	var hangar = menu.get_node("HangarMenu")
	check(hangar.visible and root.gui_get_focus_owner() != null, "gamepad opens hangar with a focused control")
	hangar.tab_buttons[1].grab_focus()
	await tap(JOY_BUTTON_A)
	check(hangar.current_tab == hangar.TabIndex.PERKS, "gamepad switches hangar categories")
	await tap(JOY_BUTTON_B)
	check(not hangar.visible and root.gui_get_focus_owner() == menu.hangar_btn, "B leaves hangar and restores operations focus")
	menu.manual_btn.grab_focus()
	await tap(JOY_BUTTON_A)
	check(menu.manual_dialog.visible, "gamepad opens flight manual")
	await tap(JOY_BUTTON_B)
	check(not menu.manual_dialog.visible, "B dismisses the flight manual window")
	menu.exit_btn.grab_focus()
	await tap(JOY_BUTTON_A)
	check(is_instance_valid(flow.confirmation), "controller quit still requires explicit confirmation")
	await tap(JOY_BUTTON_B)
	check(not is_instance_valid(flow.confirmation), "B cancels a generic confirmation without quitting")
	menu.settings_btn.grab_focus()
	await tap(JOY_BUTTON_A)
	var settings = menu.get_node("SettingsMenu")
	check(settings.visible, "A opens pilot settings")
	settings.tab_controls_btn.grab_focus()
	await tap(JOY_BUTTON_A)
	check(settings.controls_box.visible and root.gui_get_focus_owner() == settings.pad_sensitivity_slider, "controls tab focuses right-stick sensitivity")
	var old: float = store.values.pad_sensitivity
	await tap(JOY_BUTTON_DPAD_RIGHT)
	check(store.values.pad_sensitivity > old and controls.aim_sensitivity == store.values.pad_sensitivity, "D-pad adjusts real persisted aiming sensitivity")
	settings.pad_invert_check.grab_focus()
	await tap(JOY_BUTTON_A)
	check(controls.aim_invert_y == settings.pad_invert_check.button_pressed and controls.aim_invert_y, "gamepad toggles real invert-Y preference")
	await capture("controller-settings")
	store.set_value("pad_invert_y", false)
	store.set_value("pad_sensitivity", 1.0)
	check(store.flush(), "controller settings save to isolated profile")
	store.load_settings()
	check(store.values.has("pad_deadzone") and store.values.pad_sensitivity == 1.0, "controller preferences survive settings reload")
	await tap(JOY_BUTTON_B)
	check(not settings.visible and root.gui_get_focus_owner() == menu.settings_btn, "B closes settings and restores caller focus")
	menu.start_btn.grab_focus()
	await tap(JOY_BUTTON_A)
	await tap(JOY_BUTTON_A)
	var loading_deadline := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < loading_deadline:
		if is_instance_valid(current_scene) and current_scene.has_method("activate_session") and current_scene.session_started and not flow.busy: break
		if is_instance_valid(flow.loader) and flow.loader.phase == flow.loader.Phase.FAILED: break
		OS.delay_msec(1) # Yield CPU to the real background resource-loader thread.
		await process_frame
	check(is_instance_valid(current_scene) and current_scene.has_method("activate_session") and current_scene.session_started, "gamepad launches a complete game session")
	if not is_instance_valid(current_scene) or not current_scene.has_method("activate_session"):
		quit(1)
		return
	var game = current_scene
	var player = game.get_node("PlayerHelicopter")
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	var director = root.get_node("CombatDirector")
	director.stop_wave_director()
	for enemy in get_nodes_in_group("enemies"): enemy.queue_free()
	var mission = game.get_node("MissionManager")
	mission.set_process(false)
	await frames(5)
	check(flow.gameplay_input_allowed(), "launch-confirm input releases before combat arms")
	await axis(JOY_AXIS_LEFT_X, 0.8)
	check(controls.get_flight_input().strafe > 0.5 and is_zero_approx(controls.get_flight_input().yaw), "left stick moves sideways without yaw on a nonzero device")
	await axis(JOY_AXIS_LEFT_X, 0)
	await button(JOY_BUTTON_DPAD_UP, true)
	check(controls.get_flight_input().lift > 0.9, "D-pad up controls collective climb")
	await button(JOY_BUTTON_DPAD_UP, false)
	var turret = player.get_node("Turret")
	var before_aim: Vector2 = controls.get_aim_screen_position()
	var before_world: Vector3 = turret.requested_world_point
	await axis(JOY_AXIS_RIGHT_X, 0.9)
	await frames(8)
	check(controls.get_aim_screen_position().x > before_aim.x + 25, "right stick moves the virtual combat reticle")
	check(turret.requested_world_point.distance_to(before_world) > 0.1, "right stick changes the real turret world aim")
	var hud = game.get_node("UI/CombatHUD")
	hud._update_reticle()
	check(hud.reticle_widget.position.is_equal_approx(controls.get_aim_screen_position() - Vector2(16, 16)), "HUD and gun use exactly the same gamepad cursor")
	await axis(JOY_AXIS_RIGHT_X, 0)
	var held_aim: Vector2 = controls.virtual_aim
	await frames(5)
	check(controls.virtual_aim.distance_to(held_aim) < 5.0, "neutral stick preserves aim direction without snapping to mouse")
	await axis(JOY_AXIS_RIGHT_X, 0.10)
	check(controls.aim_stick().is_zero_approx(), "radial deadzone rejects stick drift")
	await axis(JOY_AXIS_RIGHT_X, 1.0)
	controls.set_process(false)
	controls.aim_initialized = false
	controls.advance_controller_aim(0, Vector2(1280, 720), Vector2(400, 300))
	for step in range(30): controls.advance_controller_aim(1.0 / 60.0, Vector2(1280, 720), Vector2.ZERO)
	var sixty: Vector2 = controls.virtual_aim
	controls.aim_initialized = false
	controls.advance_controller_aim(0, Vector2(1280, 720), Vector2(400, 300))
	for step in range(15): controls.advance_controller_aim(1.0 / 30.0, Vector2(1280, 720), Vector2.ZERO)
	check(controls.virtual_aim.distance_to(sixty) < 0.01, "right-stick cursor speed is independent of frame rate")
	for step in range(200): controls.advance_controller_aim(0.016, Vector2(1280, 720), Vector2.ZERO)
	check(controls.virtual_aim.x <= 1256, "reticle stays inside screen bounds")
	await axis(JOY_AXIS_RIGHT_X, 0)
	controls.advance_controller_aim(0, Vector2(960, 540), Vector2.ZERO)
	check(controls.virtual_aim.x <= 936 and controls.virtual_aim.y <= 516, "resizing keeps controller reticle in bounds")
	controls.set_process(true)
	var weapons = player.get_node("Weapons")
	var weapon: int = weapons.current_weapon_idx
	await tap(JOY_BUTTON_RIGHT_STICK)
	check(weapons.current_weapon_idx == (weapon + 1) % 4, "R3 cycles the actual equipped weapon forward")
	await tap(JOY_BUTTON_LEFT_STICK)
	check(weapons.current_weapon_idx == weapon, "L3 cycles the actual equipped weapon backward")
	var ammo: int = weapons.weapon_states[weapon].ammo
	await axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await frames(5)
	check(weapons.weapon_states[weapon].ammo < ammo, "right trigger fires and consumes actual ammo")
	await axis(JOY_AXIS_TRIGGER_RIGHT, 0)
	await tap(JOY_BUTTON_X)
	check(weapons.weapon_states[weapon].is_reloading, "X starts a real weapon reload")
	var counter = player.get_node("Countermeasures")
	var charges: int = counter.current_charges
	await tap(JOY_BUTTON_LEFT_SHOULDER)
	check(counter.current_charges == charges - 1 and counter.is_decoy_active, "LB deploys a real flare charge")
	var super_controller = player.get_node("DevastationSuper")
	super_controller.add_charge(100)
	await tap(JOY_BUTTON_Y)
	check(super_controller.is_active and super_controller.current_charge == 0, "Y activates the charged real super ability")
	var hull: float = player.current_hull
	player.take_damage(5.0)
	check(player.current_hull == hull and player.get_protection_reasons().has("super"), "super protection participates in authoritative damage gating")
	player.activate_shield(2)
	super_controller._deactivate_super()
	check(player.has_protection(), "super expiry preserves independently owned shields")
	player.shield_timer = 0
	player.update_invulnerability_state()
	var salvo = player.get_node("Salvo")
	var target := StaticBody3D.new()
	target.name = "ControllerPracticeTarget"
	target.collision_layer = 4
	target.collision_mask = 0
	target.position = player.global_position - player.global_basis.z * 32 - Vector3.UP * 4
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(3, 3, 3)
	collision.shape = box
	target.add_child(collision)
	var mesh := MeshInstance3D.new()
	var target_mesh := BoxMesh.new()
	target_mesh.size = Vector3(3, 3, 3)
	mesh.mesh = target_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("c96b56")
	material.roughness = 1.0
	mesh.material_override = material
	target.add_child(mesh)
	var receiver = load("res://src/combat/damage_receiver.gd").new()
	receiver.name = "DamageReceiver"
	receiver.max_health = 10000
	target.add_child(receiver)
	game.add_child(target)
	target.add_to_group("hostile_mission_targets")
	await physics_frame
	await physics_frame
	await aim_at(player.get_node("PlayerCamera").unproject_position(target.global_position), controls)
	await frames(6)
	check(turret.current_target_node == target, "gamepad aim acquires a real visible combat target")
	await capture("controller-aim")
	await axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	await frames(30)
	check(salvo.current_locks.has(target), "left trigger paints actual target locks using right-stick aim")
	await axis(JOY_AXIS_TRIGGER_LEFT, 0)
	var launched := false
	for shot in get_nodes_in_group("combat_projectiles"):
		if shot.is_homing and shot.target_node == target: launched = true
	check(launched and salvo.current_locks.is_empty(), "releasing left trigger launches real homing missiles at painted target")
	target.queue_free()
	for shot in get_nodes_in_group("combat_projectiles"): shot.queue_free()
	salvo.cooldown_timer = 0 # Separate pause-interruption fixture from the preceding launch.
	await axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	check(salvo.is_painting, "left trigger enters the real salvo painter")
	await tap(JOY_BUTTON_START)
	check(paused and gm.current_state == gm.RunState.PAUSED and game.get_node("UI/PauseMenu").visible, "Start opens the real pause menu")
	check(not salvo.is_painting and salvo.current_locks.is_empty(), "pausing cancels painting so release cannot launch stale missiles")
	await axis(JOY_AXIS_TRIGGER_LEFT, 0)
	await axis(JOY_AXIS_TRIGGER_RIGHT, 1)
	var held_ammo: int = weapons.weapon_states[weapon].ammo
	await button(JOY_BUTTON_A, true)
	await frames(4)
	await button(JOY_BUTTON_A, false)
	await frames(4)
	check(not flow.gameplay_input_allowed() and weapons.weapon_states[weapon].ammo == held_ammo, "held trigger cannot leak fire out of a controller menu")
	await axis(JOY_AXIS_TRIGGER_RIGHT, 0)
	await frames(4)
	check(not paused and flow.gameplay_input_allowed(), "gamepad resumes and re-arms after held buttons release")
	var xp = root.get_node("XpManager")
	xp.add_xp(xp.target_xp)
	var ui = game.get_node("UI/LevelUpUi") if game.has_node("UI/LevelUpUi") else get_first_node_in_group("level_up_ui")
	if ui == null: ui = game.find_child("LevelUpUi", true, false)
	for frame in range(120):
		if ui and ui.is_choosing: break
		await process_frame
	check(ui != null and ui.is_choosing and paused, "earned XP opens the real card draft")
	await capture("controller-cards")
	if ui and ui.is_choosing:
		var first = root.gui_get_focus_owner()
		await tap(JOY_BUTTON_DPAD_RIGHT)
		check(root.gui_get_focus_owner() != first and root.gui_get_focus_owner() in ui.card_buttons, "D-pad navigates level-up cards")
		await tap(JOY_BUTTON_A)
		await frames(5)
		check(not ui.is_choosing and xp.queued_level_ups == 0 and not paused, "A applies exactly one real card and resumes combat")
	root.get_node("EventBus").boss_defeated.emit()
	await frames(4)
	var boss_dialog = game.get_node("UI/BossDecisionDialog")
	check(boss_dialog.visible and root.gui_get_focus_owner() == boss_dialog.extract_btn, "boss decision starts with controller focus")
	await tap(JOY_BUTTON_DPAD_RIGHT)
	await tap(JOY_BUTTON_A)
	check(not boss_dialog.visible and gm.current_state == gm.RunState.ACTIVE, "D-pad and A choose real boss overdrive continuation")
	director.stop_wave_director()
	for enemy in get_nodes_in_group("enemies"): enemy.queue_free()
	await tap(JOY_BUTTON_START)
	await tap(JOY_BUTTON_B)
	await frames(4)
	check(not paused, "B resumes from pause without triggering dash")
	player.set_physics_process(true)
	await button(JOY_BUTTON_RIGHT_SHOULDER, true)
	check(player.is_dashing, "RB triggers the real helicopter evasive dash")
	await button(JOY_BUTTON_RIGHT_SHOULDER, false)
	await frames(35)
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	check(not player.is_dashing, "dash completes normally after controller input")
	director.current_wave = 1 # Separate early mission gate fixture from boss overdrive wave 11.
	var tracker = mission.get_node("MissionTracker")
	await tap(JOY_BUTTON_BACK)
	check(is_instance_valid(tracker.tactical_dialog) and paused, "View opens paused mission actions")
	await capture("controller-missions")
	if "--capture" in OS.get_cmdline_user_args():
		print("CONTROLLER_VISUALS: four captures complete; full input path is verified by the headless run")
		if is_instance_valid(tracker.tactical_dialog): tracker.tactical_dialog.hide()
		await frames(2)
		game.queue_free()
		await process_frame
		quit(1 if failures else 0)
		return
	if is_instance_valid(tracker.tactical_dialog):
		check(tracker.tactical_dialog.get_ok_button().disabled, "extraction cannot be requested before wave three")
		var radar = game.find_child("TacticalRadar", true, false)
		var zoom: int = radar.zoom_mode
		for radar_button in tracker.tactical_dialog.find_children("*", "Button", true, false):
			if radar_button.text == "CYCLE RADAR ZOOM":
				radar_button.grab_focus()
				await tap(JOY_BUTTON_A)
				break
		check(radar.zoom_mode != zoom, "tactical panel cycles the real radar zoom")
		await tap(JOY_BUTTON_B)
	await frames(4)
	check(not paused and flow.gameplay_input_allowed(), "cancelling tactical dialog restores flight safely")
	director.current_wave = 3
	await tap(JOY_BUTTON_BACK)
	if is_instance_valid(tracker.tactical_dialog):
		tracker.tactical_dialog.get_ok_button().grab_focus()
		await tap(JOY_BUTTON_A)
	check(mission.is_mission_active and mission.active_mission_id == "sortie_extraction" and not paused, "gamepad requests a real extraction LZ through confirmation")
	if not mission.is_mission_active or mission.active_mission_id != "sortie_extraction":
		print("CONTROLLER_READY: aborting after failed mission dialog routing")
		quit(1)
		return
	# Disconnect the active controller while a trigger is held; no physical hardware required.
	await axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	controls._on_joy_connection_changed(PAD, false)
	check(paused and gm.current_state == gm.RunState.PAUSED and not controls.controller_active, "active-controller disconnect pauses and returns to mouse mode")
	check(not salvo.is_painting and not Input.is_action_pressed("paint_salvo"), "disconnect clears held trigger and cancels salvo")
	await tap(JOY_BUTTON_START)
	await frames(4)
	check(controls.controller_active and not paused, "reconnected controller can resume with Start")
	var mouse := InputEventMouseMotion.new()
	mouse.position = Vector2(400, 280)
	mouse.relative = Vector2(12, 0)
	Input.parse_input_event(mouse)
	await frames(3)
	check(not controls.controller_active and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "intentional mouse movement restores mouse aiming and pointer")
	await axis(JOY_AXIS_RIGHT_Y, -0.8)
	check(controls.controller_active and controls.aim_stick().y < 0, "controller aiming resumes without restarting")
	await axis(JOY_AXIS_RIGHT_Y, 0)
	# A second explicit mission confirmation must occur at the secured LZ.
	player.global_position = mission.objective_site.global_position + Vector3.UP * 12
	player.velocity = Vector3.ZERO
	mission._process_active_mission(5.1)
	await frames(4)
	await tap(JOY_BUTTON_BACK)
	check(is_instance_valid(tracker.tactical_dialog) and mission.phase == "READY", "secured LZ presents a separate end-sortie confirmation")
	if is_instance_valid(tracker.tactical_dialog):
		tracker.tactical_dialog.get_ok_button().grab_focus()
		await tap(JOY_BUTTON_A)
	check(gm.current_state == gm.RunState.RESULTS and game.get_node("UI/DebriefScreen").visible, "gamepad confirms extraction and reaches the real debrief")
	await tap(JOY_BUTTON_A)
	await frames(8)
	check(is_instance_valid(current_scene) and current_scene.has_node("VehicleSelectionMenu") and current_scene.get_node("VehicleSelectionMenu").visible, "gamepad retry returns from debrief to aircraft selection")
	print("CONTROLLER_READY: %d/%d passed" % [checks - failures, checks])
	if is_instance_valid(current_scene): current_scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
