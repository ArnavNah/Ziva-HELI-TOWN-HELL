extends SceneTree

## Verification only: exercise the production scene without editing game behavior.
const Card = preload("res://src/resources/upgrade_card.gd")
const Deck = preload("res://src/resources/upgrade_card_database.gd")
var results: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func record(label: String, ok: bool, observed: Variant) -> void:
	results.append({"check": label, "passed": ok, "observed": observed})
	print("PASS " if ok else "FAIL ", label, " | ", observed)

func wait_for_draft(ui: Node) -> void:
	var deadline := Time.get_ticks_msec() + 5000
	while not ui.is_choosing and Time.get_ticks_msec() < deadline:
		await process_frame

func run() -> void:
	if OS.get_environment("ZIVA_TEST_DATA_DIR").is_empty():
		quit(2)
		return
	root.size = Vector2i(1280, 720)
	var scene = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var deadline := Time.get_ticks_msec() + 30000
	while not scene.session_started and Time.get_ticks_msec() < deadline:
		await process_frame
	if not scene.session_started:
		printerr("Scene preparation timed out")
		quit(2)
		return
	root.get_node("CombatDirector").stop_wave_director()
	var player = get_first_node_in_group("player")
	player.set_physics_process(false)
	var xp = root.get_node("XpManager")
	var gm = root.get_node("GameManager")
	var ui = scene.get_node("UI/LevelUpUi")
	var progression = player.get_node("RunProgression")
	var sm = player.get_node("SubsystemManager")
	var weapons = player.get_node("Weapons")
	var salvo = player.get_node("Salvo")
	var loot = scene.get_node("LootManager")
	var hud = scene.find_child("SurvivalHUD", true, false)
	xp.reset_run()
	var legacy_before: int = progression.current_run_xp
	# Loot adds up to half a meter of scatter. Keep the fixture safely inside
	# the 1.5m collection radius for every scatter direction.
	var drop = loot.spawn_xp_drop(player.global_position + Vector3(0.25, -20, 0), 25)
	drop.start_attraction(player)
	drop._physics_process(0.016)
	record("Production XP drop awards 25 XP exactly once", xp.total_xp_collected == 25, xp.total_xp_collected)
	drop._trigger_collection()
	record("Duplicate collection is ignored", xp.total_xp_collected == 25, xp.total_xp_collected)
	record("Earned draft respects presentation delay", not ui.visible and not paused, ui.presentation_delay_remaining)
	await wait_for_draft(ui)
	record("25 XP opens a paused level-two draft", xp.current_level == 2 and ui.visible and paused, {"level": xp.current_level, "visible": ui.visible, "paused": paused})
	hud.refresh(gm, player)
	record("HUD level follows authoritative XP manager", hud.level_label.text.begins_with("LVL 2"), {"hud": hud.level_label.text, "xp_level": xp.current_level, "legacy_xp": progression.current_run_xp - legacy_before})
	var distinct: Dictionary = {}
	for card in ui.current_draft:
		distinct[card.card_id] = true
	record("Real overlay presents three distinct cards", ui.current_draft.size() == 3 and distinct.size() == 3, distinct.keys())
	var borders_match := true
	for index in range(ui.current_draft.size()):
		var button = ui.card_buttons[index]
		var border = button.get_node_or_null("BorderRect")
		var color: Color = border.border_color if border else button.get_theme_stylebox("normal").border_color
		if not color.is_equal_approx(ui.current_draft[index].get_rarity_color()):
			borders_match = false
	record("Card borders reflect their rarity colors", borders_match, borders_match)
	var icons := 0
	for card in Deck.get_master_deck():
		if card.icon != null:
			icons += 1
	record("Master deck has assigned card icons", icons == Deck.get_master_deck().size(), {"icons": icons, "cards": Deck.get_master_deck().size()})
	if DisplayServer.get_name() != "headless":
		await create_timer(0.3, true).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/xp-spec-integration-overlay.png")

	# Use a known safe card so unrelated payload errors cannot hide queue results.
	var safe_card = Card.create("audit_luck", "Audit Luck", "", Card.RarityTier.COMMON, Card.SubsystemType.GLOBAL_TOME, {"luck_level_add": 0.0})
	var selections := 0
	while ui.is_choosing and selections < 8:
		ui.current_draft[0] = safe_card
		ui.card_buttons[0].pressed.emit()
		selections += 1
	record("One level gained awards exactly one card selection", selections == 1, selections)
	record("Completing all choices resumes gameplay", not paused and not ui.visible, {"paused": paused, "visible": ui.visible})
	xp.reset_run()
	xp.add_xp(500)
	var levels_gained: int = xp.current_level - 1
	selections = 0
	while xp.has_pending_level_ups() and selections < 12:
		await wait_for_draft(ui)
		if not ui.is_choosing:
			break
		ui.current_draft[0] = safe_card
		ui.card_buttons[0].pressed.emit()
		selections += 1
		if xp.has_pending_level_ups():
			record("Queued choice gives a combat breather", not paused and not ui.visible and ui.presentation_delay_remaining >= 2.49, ui.presentation_delay_remaining)
	record("Burst XP awards exactly one card per gained level", selections == levels_gained, {"levels": levels_gained, "selections": selections})

	var damage_before: float = weapons.damage_multipliers[GameConstants.WeaponType.MACHINE_GUN]
	var fire_before: float = weapons.fire_rates[GameConstants.WeaponType.MACHINE_GUN]
	var damage_card = Card.create("audit_damage", "Audit Damage", "", Card.RarityTier.COMMON, Card.SubsystemType.PRIMARY_CANNON, {"damage_mult": 0.20, "fire_rate_mult": 0.15})
	sm.apply_upgrade(damage_card)
	record("Cannon card changes real weapon damage", weapons.damage_multipliers[GameConstants.WeaponType.MACHINE_GUN] > damage_before, {"before": damage_before, "after": weapons.damage_multipliers[GameConstants.WeaponType.MACHINE_GUN], "ledger": sm.active_stats.cannon_damage_mult})
	record("Cannon card changes real fire rate", weapons.fire_rates[GameConstants.WeaponType.MACHINE_GUN] > fire_before, {"before": fire_before, "after": weapons.fire_rates[GameConstants.WeaponType.MACHINE_GUN]})
	var cooldown_before: float = salvo.cooldown_duration
	sm.apply_upgrade(Card.create("audit_missile", "Audit Missile", "", Card.RarityTier.COMMON, Card.SubsystemType.GUIDED_MISSILES, {"cooldown_reduction": 0.25}))
	record("Missile cooldown card changes real salvo cooldown", salvo.cooldown_duration < cooldown_before, {"before": cooldown_before, "after": salvo.cooldown_duration})
	var bonus_before: float = xp.xp_multiplier
	sm.apply_upgrade(Card.create("audit_xp", "Audit XP", "", Card.RarityTier.COMMON, Card.SubsystemType.GLOBAL_TOME, {"xp_gain_mult": 0.20}))
	record("XP tome changes authoritative XP multiplier", xp.xp_multiplier > bonus_before, {"before": bonus_before, "after": xp.xp_multiplier})
	player.update_magnet_sensor_radius(1.0)
	sm.apply_upgrade(Card.create("audit_magnet", "Audit Magnet", "", Card.RarityTier.COMMON, Card.SubsystemType.GLOBAL_TOME, {"magnet_radius_mult": 0.40}))
	var radius: float = player.get_node("MagnetSensor/CollisionShape3D").shape.radius
	record("Magnet tome changes real sensor radius", is_equal_approx(radius, 16.8), radius)

	# Starting a fresh run should reset the autoload without an explicit test reset.
	gm.start_new_run("apache")
	record("New run resets XP manager level and total", xp.current_level == 1 and xp.total_xp_collected == 0, {"level": xp.current_level, "total_xp": xp.total_xp_collected})
	paused = false
	var file = FileAccess.open("res://artifacts/xp-spec-integration-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "\t"))
	file.close()
	var failed := 0
	for result in results:
		if not result.passed:
			failed += 1
	print("XP_SPEC_INTEGRATION: ", results.size() - failed, "/", results.size(), " passed; ", failed, " gaps")
	await load("res://tests/runtime_cleanup.gd").finish(self, 1 if failed > 0 else 0)
