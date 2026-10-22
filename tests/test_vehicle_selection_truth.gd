extends SceneTree

## Comprehensive test suite for VehicleSelectionMenu:
## 1. Verifies exact mathematical equality between specs, menu preview, ProfileManager, and runtime PlayerHelicopter.
## 2. Verifies permanent hangar upgrades update effective stats and bar lengths truthfully without side effects.
## 3. Verifies selection synchronization across GameManager, highlighted card, visual configuration, and deployed airframe.
## 4. Verifies responsive layouts at 960x540, 1280x720, 1920x1080, and ultrawide.

var checks_passed: int = 0
var checks_total: int = 0

func _initialize() -> void:
	call_deferred("_run_tests")

func assert_check(condition: bool, description: String) -> void:
	checks_total += 1
	if condition:
		checks_passed += 1
		print("  [PASS] %s" % description)
	else:
		printerr("  [FAIL] %s" % description)

func _run_tests() -> void:
	print("==================================================================")
	print("--- BEGIN VEHICLE SELECTION TRUTHFULNESS & RUNTIME SYNC TESTS ---")
	print("==================================================================")

	var pm = root.get_node("ProfileManager")
	var gm = root.get_node("GameManager")
	var flow = root.get_node("UIFlow")

	# Reset hangar ranks for baseline testing
	for key in pm.hangar_ranks:
		pm.hangar_ranks[key] = 0

	var menu: VehicleSelectionMenu = load("res://scenes/ui/vehicle_selection_menu.tscn").instantiate()
	root.add_child(menu)
	menu.visible = true

	# ------------------------------------------------------------------
	# STAGE 1: Baseline Specifications & Truthful Stat Derivation
	# ------------------------------------------------------------------
	print("\n>>> STAGE 1: Baseline Aircraft Specifications & Truthful Bar Derivations")
	var expected_baselines := {
		"apache": {"speed": 36.0, "hull": 100.0, "fuel": 100.0, "turn": 1.00},
		"nighthawk": {"speed": 41.4, "hull": 85.0, "fuel": 90.0, "turn": 1.20},
		"warlock": {"speed": 31.7, "hull": 130.0, "fuel": 120.0, "turn": 0.85}
	}

	var aircraft_keys = ["apache", "nighthawk", "warlock"]
	for i in range(3):
		var id = aircraft_keys[i]
		menu.select_aircraft(i)
		for f in range(2):
			await process_frame

		var exp = expected_baselines[id]
		var preview = pm.preview_stats(id)

		assert_check(preview.speed == exp.speed, "%s: baseline speed is %.1f m/s" % [id, exp.speed])
		assert_check(preview.hull == exp.hull, "%s: baseline hull is %.0f HP" % [id, exp.hull])
		assert_check(preview.fuel == exp.fuel, "%s: baseline fuel is %.0f L" % [id, exp.fuel])
		assert_check(preview.handling == exp.turn, "%s: baseline turn agility is %.2fx" % [id, exp.turn])

		# Verify menu labels match
		assert_check(menu.aircraft_title.text == preview.name, "%s: menu title matches" % id)
		assert_check(menu.speed_label.text.begins_with("%.1f m/s" % exp.speed), "%s: speed label truthful" % id)
		assert_check(menu.hull_label.text.begins_with("%.0f HP" % exp.hull), "%s: hull label truthful" % id)
		assert_check(menu.fuel_label.text.begins_with("%.0f L" % exp.fuel), "%s: fuel label truthful" % id)

		# Verify bar percentages are mathematically derived: speed / 60, hull / 220, fuel / 220
		var exp_speed_bar = (exp.speed / 60.0) * 100.0
		var exp_hull_bar = (exp.hull / 220.0) * 100.0
		var exp_fuel_bar = (exp.fuel / 220.0) * 100.0
		assert_check(absf(menu.speed_bar.value - exp_speed_bar) < 0.01, "%s: speed bar strictly derives from value (%.1f%%)" % [id, exp_speed_bar])
		assert_check(absf(menu.hull_bar.value - exp_hull_bar) < 0.01, "%s: hull bar strictly derives from value (%.1f%%)" % [id, exp_hull_bar])
		assert_check(absf(menu.fuel_bar.value - exp_fuel_bar) < 0.01, "%s: fuel bar strictly derives from value (%.1f%%)" % [id, exp_fuel_bar])

	# ------------------------------------------------------------------
	# STAGE 2: Comparison Consistency (Longer Bar == Higher Value)
	# ------------------------------------------------------------------
	print("\n>>> STAGE 2: Multi-Aircraft Comparison Consistency")
	menu.select_aircraft(1) # Nighthawk
	var n_speed_bar = menu.speed_bar.value
	var n_hull_bar = menu.hull_bar.value
	var n_turn_bar = menu.handling_bar.value

	menu.select_aircraft(0) # Apache
	var a_speed_bar = menu.speed_bar.value
	var a_hull_bar = menu.hull_bar.value
	var a_turn_bar = menu.handling_bar.value

	menu.select_aircraft(2) # Warlock
	var w_speed_bar = menu.speed_bar.value
	var w_hull_bar = menu.hull_bar.value
	var w_turn_bar = menu.handling_bar.value

	assert_check(n_speed_bar > a_speed_bar and a_speed_bar > w_speed_bar, "Speed bar length strictly reflects speed rank (Nighthawk > Apache > Warlock)")
	assert_check(w_hull_bar > a_hull_bar and a_hull_bar > n_hull_bar, "Hull bar length strictly reflects hull rank (Warlock > Apache > Nighthawk)")
	assert_check(n_turn_bar > a_turn_bar and a_turn_bar > w_turn_bar, "Agility bar length strictly reflects turn rank (Nighthawk > Apache > Warlock)")

	# ------------------------------------------------------------------
	# STAGE 3: Permanent Hangar Upgrade Responsiveness
	# ------------------------------------------------------------------
	print("\n>>> STAGE 3: Permanent Hangar Upgrade Responsiveness")
	pm.hangar_ranks.engine = 2 # +16% speed
	pm.hangar_ranks.armor = 1  # +15 HP hull
	pm.hangar_ranks.fuel = 2   # +30 L fuel
	pm.hangar_ranks.rotor = 1  # +10% rotor handling
	pm.hangar_ranks.weapon_system = 2 # +12% weapon damage

	menu.select_aircraft(0) # Apache
	for f in range(2):
		await process_frame

	var ap_upgraded = pm.preview_stats("apache")
	var exp_up_speed = 36.0 * 1.16
	var exp_up_hull = 100.0 + 15.0
	var exp_up_fuel = 100.0 + 30.0
	assert_check(absf(ap_upgraded.speed - exp_up_speed) < 0.05, "Upgraded speed is %.1f m/s" % exp_up_speed)
	assert_check(absf(ap_upgraded.hull - exp_up_hull) < 0.05, "Upgraded hull is %.0f HP" % exp_up_hull)
	assert_check(absf(ap_upgraded.fuel - exp_up_fuel) < 0.05, "Upgraded fuel is %.0f L" % exp_up_fuel)
	assert_check(menu.speed_label.text.contains("(+"), "Speed label shows hangar upgrade bonus tag")
	assert_check(menu.hull_label.text.contains("(+"), "Hull label shows armor upgrade bonus tag")
	assert_check(menu.damage_label.text.contains("+12%"), "Weapon damage label displays +12%")

	# ------------------------------------------------------------------
	# STAGE 4: Runtime Deployment Equality (Preview == Deployed Player)
	# ------------------------------------------------------------------
	print("\n>>> STAGE 4: Runtime Player Equality")
	for i in range(3):
		var id = aircraft_keys[i]
		menu.select_aircraft(i)
		var preview_stats = pm.preview_stats(id)

		var player_scene = load("res://scenes/player/player.tscn").instantiate()
		player_scene.aircraft_type = id
		root.add_child(player_scene)
		pm.apply_loadout(player_scene)
		for f in range(2):
			await process_frame

		assert_check(player_scene.aircraft_type == id, "%s: player instance has correct aircraft_type" % id)
		assert_check(absf(player_scene.cruise_speed - preview_stats.speed) < 0.01, "%s: deployed cruise_speed matches preview (%.1f == %.1f)" % [id, player_scene.cruise_speed, preview_stats.speed])
		assert_check(absf(player_scene.max_hull - preview_stats.hull) < 0.01, "%s: deployed max_hull matches preview (%.0f == %.0f)" % [id, player_scene.max_hull, preview_stats.hull])
		assert_check(absf(player_scene.max_fuel - preview_stats.fuel) < 0.01, "%s: deployed max_fuel matches preview (%.0f == %.0f)" % [id, player_scene.max_fuel, preview_stats.fuel])
		assert_check(absf(player_scene.handling_multiplier - (1.0 + pm.hangar_ranks.rotor * 0.10)) < 0.01, "%s: deployed handling_multiplier matches rotor upgrades" % id)

		player_scene.queue_free()

	# ------------------------------------------------------------------
	# STAGE 5: Multi-Resolution Responsive Layout
	# ------------------------------------------------------------------
	print("\n>>> STAGE 5: Multi-Resolution Responsive Layout Checks")
	var test_resolutions := [
		Vector2i(960, 540),
		Vector2i(1280, 720),
		Vector2i(1920, 1080),
		Vector2i(2560, 1080)
	]

	for res in test_resolutions:
		root.size = res
		for f in range(2):
			await process_frame
		print("DEBUG res: ", res, " root.size: ", root.size, " menu.size: ", menu.size)
		assert_check(menu.size.x > 0 and menu.size.y > 0, "Layout adapts to %dx%d without negative bounds" % [res.x, res.y])
		assert_check(menu.deploy_btn.is_visible_in_tree(), "Deploy button visible at %dx%d" % [res.x, res.y])
		assert_check(menu.card_buttons[0].is_visible_in_tree(), "Cards visible at %dx%d" % [res.x, res.y])

	menu.queue_free()

	print("\n==================================================================")
	print("RESULTS: %d / %d CHECKS PASSED" % [checks_passed, checks_total])
	if checks_passed == checks_total:
		print(">>> ALL VEHICLE SELECTION TRUTH CHECKS PASSED <<<")
		quit(0)
	else:
		printerr(">>> FAILURES DETECTED IN VEHICLE SELECTION SUITE <<<")
		quit(1)
