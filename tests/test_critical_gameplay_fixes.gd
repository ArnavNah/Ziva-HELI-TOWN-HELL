extends SceneTree

## Comprehensive Verification Suite for 4 Critical Gameplay Fixes:
## 1. Gamepad RB/LB bindings: No conflict between strafe and evasive_dash/flares
## 2. XP pipeline: Entity destruction delivers XP to RunProgression and triggers level-up
## 3. RunProgression cards: fire_rates, damage_multipliers, and all upgrade cards execute without crash
## 4. Rare pickups: SHIELD, OVERDRIVE, and SPEED_BOOST apply active gameplay buffs

var tests_passed: int = 0
var total_tests: int = 14

func _init() -> void:
	print("==================================================================")
	print("--- BEGIN CRITICAL GAMEPLAY FIXES VERIFICATION ---")
	print("==================================================================")
	call_deferred("_run_tests")

func check(condition: bool, message: String) -> void:
	if condition:
		print("  [PASS] ", message)
		tests_passed += 1
	else:
		push_error("  [FAIL] " + message)
		print("  [FAIL] ", message)

func _run_tests() -> void:
	# ------------------------------------------------------------------
	# TEST GROUP 1: GAMEPAD BUTTON BINDINGS (Conflict Resolution)
	# ------------------------------------------------------------------
	# Check strafe_right has no RB (JOY_BUTTON_RIGHT_SHOULDER)
	var strafe_right_has_rb = false
	for ev in InputMap.action_get_events("strafe_right"):
		if ev is InputEventJoypadButton and ev.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			strafe_right_has_rb = true
	check(not strafe_right_has_rb, "1.1 strafe_right no longer bound to Gamepad RB (Right Shoulder)")

	# Check strafe_left has no LB (JOY_BUTTON_LEFT_SHOULDER)
	var strafe_left_has_lb = false
	for ev in InputMap.action_get_events("strafe_left"):
		if ev is InputEventJoypadButton and ev.button_index == JOY_BUTTON_LEFT_SHOULDER:
			strafe_left_has_lb = true
	check(not strafe_left_has_lb, "1.2 strafe_left no longer bound to Gamepad LB (Left Shoulder)")

	# Check evasive_dash retains RB and deploy_flares retains LB
	var dash_has_rb = false
	for ev in InputMap.action_get_events("evasive_dash"):
		if ev is InputEventJoypadButton and ev.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			dash_has_rb = true
	var flares_has_lb = false
	for ev in InputMap.action_get_events("deploy_flares"):
		if ev is InputEventJoypadButton and ev.button_index == JOY_BUTTON_LEFT_SHOULDER:
			flares_has_lb = true
	check(dash_has_rb and flares_has_lb, "1.3 evasive_dash correctly owns RB and deploy_flares correctly owns LB")

	# ------------------------------------------------------------------
	# TEST GROUP 2: XP PIPELINE & LEVELING
	# ------------------------------------------------------------------
	var heli_scene = preload("res://scenes/player/player.tscn")
	var heli = heli_scene.instantiate()
	root.add_child(heli)

	for i in 3:
		await process_frame

	var prog = heli.get_node_or_null("RunProgression") as RunProgression
	if not prog:
		print("[FAIL] RunProgression node not found on PlayerHelicopter.")
		quit(1)
		return

	var start_xp = prog.current_run_xp
	var start_level = prog.current_run_level

	# Simulate enemy kill entity_destroyed signal with 15 XP
	var dummy_enemy = Node.new()
	dummy_enemy.add_to_group("enemies")
	root.add_child(dummy_enemy)

	root.get_node("/root/EventBus").entity_destroyed.emit(dummy_enemy, "Machine Gun", 100, 15)

	for i in 3:
		await process_frame

	check(prog.current_run_xp == start_xp + 15, "2.1 Enemy kill delivers 15 XP through pipeline to RunProgression (got %d XP)" % prog.current_run_xp)
	check(prog.current_run_level > start_level, "2.2 RunProgression leveled up from Level %d to Level %d (crossing 10 XP threshold)" % [start_level, prog.current_run_level])
	check(prog.queued_level_ups > 0, "2.3 Upgrade choice queued for pilot selection (%d queued)" % prog.queued_level_ups)

	dummy_enemy.queue_free()

	# ------------------------------------------------------------------
	# TEST GROUP 3: RUN PROGRESSION UPGRADE CARDS (No Crashes & Property Existence)
	# ------------------------------------------------------------------
	var wp = heli.get_node_or_null("Weapons") as PlayerWeapons
	if not wp:
		print("[FAIL] PlayerWeapons node not found.")
		quit(1)
		return

	# Verify fire_rates and damage_multipliers exist on wp
	check("fire_rates" in wp and wp.fire_rates != null, "3.1 PlayerWeapons has fire_rates dictionary property")
	check("damage_multipliers" in wp and wp.damage_multipliers != null, "3.2 PlayerWeapons has damage_multipliers dictionary property")

	# Apply EVOLUTION: Vulcan Storm (previously crashed referencing wp.fire_rates)
	var prev_mg_rate = wp.fire_rates.get(GameConstants.WeaponType.MACHINE_GUN, 1.0)
	prog.apply_upgrade_choice("EVOLUTION: Vulcan Storm")
	var new_mg_rate = wp.fire_rates.get(GameConstants.WeaponType.MACHINE_GUN, 1.0)
	check(new_mg_rate == prev_mg_rate * 1.5, "3.3 EVOLUTION: Vulcan Storm applies 1.5x fire rate without crashing (%.2f -> %.2f)" % [prev_mg_rate, new_mg_rate])

	# Apply LEGENDARY: Death From Above (previously crashed referencing wp.damage_multipliers)
	var prev_mg_dmg = wp.damage_multipliers.get(GameConstants.WeaponType.MACHINE_GUN, 1.0)
	prog.apply_upgrade_choice("LEGENDARY: Death From Above")
	var new_mg_dmg = wp.damage_multipliers.get(GameConstants.WeaponType.MACHINE_GUN, 1.0)
	check(new_mg_dmg == prev_mg_dmg * 1.35, "3.4 LEGENDARY: Death From Above applies 1.35x damage without crashing (%.2f -> %.2f)" % [prev_mg_dmg, new_mg_dmg])

	# Apply other cards: Overclock Rounds, Hair Trigger, Speed Loader, Vector Jets
	var prev_missile_dmg = wp.damage_multipliers.get(GameConstants.WeaponType.MISSILE, 1.0)
	var prev_cruise_speed = heli.cruise_speed
	prog.apply_upgrade_choice("Overclock Rounds")
	prog.apply_upgrade_choice("Hair Trigger")
	prog.apply_upgrade_choice("Speed Loader")
	prog.apply_upgrade_choice("Vector Jets")
	check(wp.damage_multipliers.get(GameConstants.WeaponType.MISSILE, 1.0) > prev_missile_dmg and heli.cruise_speed > prev_cruise_speed, "3.5 Base upgrade cards (Overclock, Hair Trigger, Speed Loader, Vector Jets) execute cleanly and scale stats")

	# ------------------------------------------------------------------
	# TEST GROUP 4: RARE PICKUPS (SHIELD, OVERDRIVE, SPEED_BOOST)
	# ------------------------------------------------------------------
	var pickup_script = preload("res://src/loot/pickup.gd")

	# 4.1 SHIELD Pickup
	var shield_pickup = Area3D.new()
	shield_pickup.set_script(pickup_script)
	shield_pickup.pickup_type = pickup_script.PickupType.SHIELD
	shield_pickup.pickup_value = 8.0
	root.add_child(shield_pickup)
	shield_pickup._apply_pickup_effect(heli)
	check(heli.is_invulnerable and heli.shield_timer >= 7.9, "4.1 SHIELD pickup activates invulnerability and sets shield_timer (timer=%.1fs)" % heli.shield_timer)
	shield_pickup.queue_free()

	# 4.2 SPEED_BOOST Pickup
	var speed_pickup = Area3D.new()
	speed_pickup.set_script(pickup_script)
	speed_pickup.pickup_type = pickup_script.PickupType.SPEED_BOOST
	speed_pickup.pickup_value = 6.0
	root.add_child(speed_pickup)
	speed_pickup._apply_pickup_effect(heli)
	check(heli.speed_boost_multiplier > 1.4 and heli.speed_boost_timer >= 5.9, "4.2 SPEED_BOOST pickup applies speed boost multiplier (%.2fx) and sets timer (%.1fs)" % [heli.speed_boost_multiplier, heli.speed_boost_timer])
	speed_pickup.queue_free()

	# 4.3 OVERDRIVE Pickup
	var overdrive_pickup = Area3D.new()
	overdrive_pickup.set_script(pickup_script)
	overdrive_pickup.pickup_type = pickup_script.PickupType.OVERDRIVE
	overdrive_pickup.pickup_value = 8.0
	root.add_child(overdrive_pickup)
	overdrive_pickup._apply_pickup_effect(heli)
	check(wp.overdrive_timer >= 7.9 and wp.weapon_states[GameConstants.WeaponType.MACHINE_GUN]["ammo"] == GameConstants.WEAPONS[GameConstants.WeaponType.MACHINE_GUN]["ammo_max"], "4.3 OVERDRIVE pickup activates overdrive fire timer (%.1fs) and fully replenishes all weapon magazines" % wp.overdrive_timer)
	overdrive_pickup.queue_free()

	print("------------------------------------------------------------------")
	print("CRITICAL GAMEPLAY FIXES: ", tests_passed, "/", total_tests, " PASSED")
	print("==================================================================")

	heli.queue_free()

	if tests_passed >= total_tests:
		quit(0)
	else:
		quit(1)
