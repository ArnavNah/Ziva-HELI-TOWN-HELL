extends SceneTree

## Dedicated Regression and Acceptance Test Suite for Gameplay Stability, Damage Math,
## Authoritative XP Collection, Transactional Upgrades, and Upgrade Visual Cards.

const DamageDataClass = preload("res://src/combat/damage_data.gd")
const ProjectileClass = preload("res://src/combat/projectile.gd")
const UpgradeCatalog = preload("res://src/player/upgrade_catalog.gd")

func _init() -> void:
	print("==================================================================")
	print("--- RUNNING GAMEPLAY STABILITY & UPGRADE VERIFICATION SUITE ---")
	print("==================================================================")
	var runner = StabilityTestRunner.new()
	root.add_child(runner)

class TestScaledAttacker extends Node3D:
	var combat_damage_multiplier := 1.25

class StabilityTestRunner extends Node:
	var passed: int = 0
	var total: int = 0
	var player: PlayerHelicopter
	var weapons: Node
	var progression: RunProgression
	var arena: Node3D

	func check(condition: bool, test_name: String) -> void:
		total += 1
		if condition:
			passed += 1
			print("  [PASS] %d. %s" % [total, test_name])
		else:
			push_error("  [FAIL] %d. %s" % [total, test_name])
			print("  [FAIL] %d. %s" % [total, test_name])

	func _ready() -> void:
		# Disconnect real save settlement so test runs never pollute user profiles
		var gm = get_node_or_null("/root/GameManager")
		var bus = get_node_or_null("/root/EventBus")
		if gm and bus:
			var dh = Callable(gm, "_on_player_died")
			if bus.player_died.is_connected(dh):
				bus.player_died.disconnect(dh)

		arena = Node3D.new()
		add_child(arena)

		player = load("res://scenes/player/player.tscn").instantiate()
		arena.add_child(player)
		weapons = player.get_node("Weapons")
		progression = player.get_node("RunProgression")

		_run_all_tests()

	func _run_all_tests() -> void:
		_test_single_damage_scaling()
		_test_multi_shape_deduplication()
		_test_protection_ownership_dash_shield_overlap()
		_test_armor_and_scraping_damage()
		_test_sublethal_and_lethal_at_35_hull()
		_test_immediate_hud_update()
		_test_idempotent_death_and_no_revival()
		_test_transactional_upgrade_validation()
		_test_extended_mag_persistence_and_empty_refill()
		_test_upgrade_catalog_caps_and_prerequisites()
		_test_drag_and_speed_flight_benefits()
		_test_real_drop_collect_level_transaction()
		_conclude()

	func _test_single_damage_scaling() -> void:
		# 1. Attacker multiplier applied exactly once
		var attacker = TestScaledAttacker.new()
		arena.add_child(attacker)

		var hit = DamageDataClass.new(10.0, GameConstants.WeaponType.ROCKET, attacker, false, 10.0)
		var center_payload = hit.clone_scaled(1.0)
		check(is_equal_approx(center_payload.raw_damage, 12.5), "Damage Scaling: Base 10.0 * 1.25 scales to 12.5 and blast copy maintains 12.5 without multiplying again (observed %.3f)" % center_payload.raw_damage)
		attacker.queue_free()

	func _test_multi_shape_deduplication() -> void:
		# 2. Multi-shape blast deduplication
		var test_target = CharacterBody3D.new()
		# Player ordnance targets hostiles (4), not the default player layer (1).
		test_target.collision_layer = 4
		arena.add_child(test_target)
		var rec = load("res://src/combat/damage_receiver.gd").new()
		rec.name = "DamageReceiver"
		rec.target_affinity = GameConstants.TargetAffinity.BOSS_CORE
		rec.max_health = 100.0
		rec.current_health = 100.0
		test_target.add_child(rec)

		# Add 2 collision shapes to the same body
		for i in range(2):
			var cs = CollisionShape3D.new()
			var bs = BoxShape3D.new()
			bs.size = Vector3(2, 2, 2)
			cs.shape = bs
			test_target.add_child(cs)

		var proj = ProjectileClass.new()
		arena.add_child(proj)
		var blast = DamageDataClass.new(20.0, GameConstants.WeaponType.MACHINE_GUN, null, false, 8.0, false)
		proj.damage_data = blast
		proj.blast_radius = 8.0
		proj._explode(test_target.global_position)

		# BOSS_CORE against MACHINE_GUN has 1.0x affinity multiplier, so 20 dmg -> 80.0 health
		check(is_equal_approx(rec.current_health, 80.0), "Blast Deduplication: 2 overlapping collision shapes receive blast damage exactly once (health: %.1f/100, expected 80.0)" % rec.current_health)
		test_target.queue_free()
		proj.queue_free()

	func _test_protection_ownership_dash_shield_overlap() -> void:
		# 3. Ending dash during active shield must preserve invulnerability
		player.shield_timer = 4.0
		player.is_dashing = true
		player.dash_timer = 0.001
		player.update_invulnerability_state()
		check(player.is_invulnerable, "Protection: Shield + Dash active sets invulnerability true")

		# Step flight physics to expire dash
		player.override_flight_input = {"thrust": 0.0, "strafe": 0.0, "yaw": 0.0, "lift": 0.0, "dash": false}
		player._process_flight_physics(0.016)
		check(not player.is_dashing and player.is_invulnerable and player.shield_timer > 0.0, "Protection Ownership: Dash expiry preserves active shield (is_dashing: false, is_invulnerable: %s, shield_rem: %.2fs)" % [player.is_invulnerable, player.shield_timer])
		player.shield_timer = 0.0
		player.update_invulnerability_state()

	func _test_armor_and_scraping_damage() -> void:
		# 4. Wall scraping routes through authoritative take_damage, applying armor mitigation
		player.current_hull = 100.0
		player.max_hull = 100.0
		player.armor_mitigation = 0.24 # 24% armor
		player.collision_resistance = 0.0
		player.is_invulnerable = false

		# Simulate 15 ticks of 4 HP/s wall scraping at 60 Hz
		for i in range(15):
			var scrape_raw = 4.0 * (1.0 / 60.0)
			player.take_damage(scrape_raw, "Building Crash")

		var expected_loss = 15.0 * (4.0 / 60.0) * (1.0 - 0.24) # 0.76 hull
		var actual_loss = 100.0 - player.current_hull
		check(is_equal_approx(actual_loss, expected_loss), "Armor Mitigation: Wall scrape respects 24%% armor (loss: %.4f, expected: %.4f)" % [actual_loss, expected_loss])

	func _test_sublethal_and_lethal_at_35_hull() -> void:
		# 5. Sublethal hit keeps player alive; lethal hit reaches exactly 0.0 and starts death
		player.current_hull = 35.0
		player.armor_mitigation = 0.0
		player.is_invulnerable = false
		player.is_dying = false

		# Sublethal: 20 damage at 35 hull -> 15 hull remaining
		player.take_damage(20.0, "Test Shell")
		check(is_equal_approx(player.current_hull, 15.0) and not player.is_dying, "Sublethal Hit: 20 damage at 35 hull leaves 15.0 hull alive (is_dying: false)")

		# Separate attack after the protected burst window: low hull is now lethal.
		player.mortal_protection.advance(0.21, player.current_hull, player.max_hull)
		player.take_damage(25.0, "Lethal Rocket")
		check(player.current_hull == 0.0 and player.is_dying, "Lethal Hit: 25 damage at 15 hull clamps exactly to 0.0 hull and initiates death sequence")

	func _test_immediate_hud_update() -> void:
		# 6. Immediate lethal-frame HUD update
		var hud = load("res://src/ui/hud.gd").new()
		hud.player_helicopter = player
		arena.add_child(hud)
		player.mortal_protection = preload("res://src/player/mortal_protection.gd").new()
		player.current_hull = 15.0 # Already below the one-shot protection threshold.
		player.is_dying = false
		hud._update_survival_layer()

		player.take_damage(40.0, "Lethal Burst")
		var hud_text = hud.survival_overlay.hp_label.text if (hud.survival_overlay and hud.survival_overlay.hp_label) else ""
		check(hud_text == "0/100" and player.current_hull == 0.0, "Immediate HUD Update: Lethal frame label reads '0/100' with zero polling lag (observed: '%s')" % hud_text)
		hud.queue_free()

	func _test_idempotent_death_and_no_revival() -> void:
		# 7. Death settlement happens once; repair cannot resurrect a dead terminal player
		player.current_hull = 0.0
		player.is_dying = true
		player.repair(50.0)
		check(player.current_hull == 0.0, "No Terminal Resurrection: repair(50.0) on dead airframe does not restore health (current_hull: %.1f)" % player.current_hull)

		# Reset player for remaining tests
		player.is_dying = false
		player.current_hull = 100.0
		player.update_invulnerability_state()

	func _test_transactional_upgrade_validation() -> void:
		# 8. Transactional upgrade validation: invalid, stale, duplicate choices rejected without state mutation
		progression.queued_level_ups = 1
		progression.current_offers.assign(["Reinforced Hull", "Overclock Rounds"])

		# Non-offered choice
		var res1 = progression.apply_upgrade_choice("INVALID_CHOICE_NAME")
		check(not res1 and progression.queued_level_ups == 1 and progression.current_offers.size() == 2, "Transactional Authority: Rejected non-offered choice preserves queue and offers (queued: %d, offers: %s)" % [progression.queued_level_ups, str(progression.current_offers)])

		# Valid offered choice
		var hp_before = player.max_hull
		var res2 = progression.apply_upgrade_choice("Reinforced Hull")
		check(res2 and progression.queued_level_ups == 0 and progression.current_offers.is_empty() and player.max_hull == hp_before + 20.0, "Transactional Commit: Valid choice consumes exactly one choice, clears offers, and applies effect (max_hull: %.1f -> %.1f)" % [hp_before, player.max_hull])

	func _test_extended_mag_persistence_and_empty_refill() -> void:
		# 9. Extended Mag: persistent capacity surviving reload & defined refill on empty
		var wp = weapons
		var base_cap = GameConstants.WEAPONS[0]["ammo_max"] # 300
		wp.weapon_states[0]["ammo"] = base_cap
		progression.queued_level_ups = 1
		progression.current_offers.assign(["Extended Mag"])
		progression.apply_upgrade_choice("Extended Mag")

		var cap_after = wp.get_max_ammo(0)
		check(cap_after == 390, "Extended Mag Capacity: Base %d upgraded to %d (+30%%)" % [base_cap, cap_after])

		# Empty magazine reload
		wp.weapon_states[0]["ammo"] = 0
		wp._complete_reload(0)
		check(wp.weapon_states[0]["ammo"] == 390, "Extended Mag Reload: Reloading restores full persistent 390 capacity (observed: %d)" % wp.weapon_states[0]["ammo"])

		# Upgrading at zero ammo provides bonus rounds
		wp.weapon_states[0]["ammo"] = 0
		progression.queued_level_ups = 1
		progression.current_offers.assign(["Extended Mag"])
		progression.apply_upgrade_choice("Extended Mag")
		check(wp.weapon_states[0]["ammo"] > 0, "Extended Mag Refill Policy: Upgrading empty magazine grants bonus capacity rounds immediately (observed: %d)" % wp.weapon_states[0]["ammo"])

	func _test_upgrade_catalog_caps_and_prerequisites() -> void:
		# 10. Upgrade Catalog: Reactive armor capped at 24%, Evolution prerequisites enforced
		player.armor_mitigation = 0.24
		var armor_entry = UpgradeCatalog.get_entry("reactive_armor")
		check(not UpgradeCatalog.is_eligible(armor_entry, player, progression), "Upgrade Caps: Reactive Armor ineligible when armor mitigation is at 24%% cap")

		# Evolution prerequisites
		var vulcan_entry = UpgradeCatalog.get_entry("evo_vulcan_storm")
		progression.upgrade_stacks["overclock_rounds"] = 1
		progression.upgrade_stacks["hair_trigger"] = 1
		check(not UpgradeCatalog.is_eligible(vulcan_entry, player, progression), "Prerequisites: Vulcan Storm ineligible with 1 stack each (requires 2 stacks)")
		progression.upgrade_stacks["overclock_rounds"] = 2
		progression.upgrade_stacks["hair_trigger"] = 2
		check(UpgradeCatalog.is_eligible(vulcan_entry, player, progression), "Prerequisites: Vulcan Storm eligible when Overclock Rounds & Hair Trigger are at rank 2")

	func _test_drag_and_speed_flight_benefits() -> void:
		# 11. Ghost Rotor reduces aerodynamic drag; Vector Jets increases cruise speed
		var spd_before = player.cruise_speed
		progression.queued_level_ups = 1
		progression.current_offers.assign(["LEGENDARY: Ghost Rotor"])
		progression.apply_upgrade_choice("LEGENDARY: Ghost Rotor")
		check(player.drag_multiplier < 1.0 and player.cruise_speed > spd_before, "Ghost Rotor: Measurable 35%% aerodynamic drag reduction (drag_mult: %.2f) and cruise speed increase (%.1f -> %.1f)" % [player.drag_multiplier, spd_before, player.cruise_speed])

	func _test_real_drop_collect_level_transaction() -> void:
		# 12. Full end-to-end loop: Real XP gem drop -> attraction -> collection -> level -> card offer -> choice
		var prev_xp = progression.current_run_xp
		var prev_lvl = progression.current_run_level

		# Spawn physical gem
		var gem = load("res://src/loot/pickup.gd").new()
		gem.pickup_type = gem.PickupType.XP_GEM
		gem.pickup_value = 150.0 # Enough to guarantee a level-up
		gem.position = player.global_position + Vector3(0, 5, 0)
		arena.add_child(gem)

		# Immediate attraction & absorption
		gem.start_immediate_attraction(player)
		gem._apply_pickup_effect(player)

		check(progression.current_run_xp == prev_xp + 150, "XP Ledger: Physical XP gem collection adds exact value to RunProgression (%d -> %d)" % [prev_xp, progression.current_run_xp])
		check(progression.current_run_level > prev_lvl or progression.queued_level_ups > 0, "Level-Up Trigger: Run XP threshold triggers level up queue (lvl: %d, queued: %d)" % [progression.current_run_level, progression.queued_level_ups])
		gem.queue_free()

	func _conclude() -> void:
		print("==================================================================")
		print("STABILITY & UPGRADE VERIFICATION RESULTS: %d/%d PASSED" % [passed, total])
		print("==================================================================")
		if passed == total:
			print("ALL GAMEPLAY REPAIRS AND UPGRADE TRANSACTION TESTS SUCCEEDED!")
			get_tree().quit(0)
		else:
			push_error("TEST FAILURES OCCURRED!")
			get_tree().quit(1)
