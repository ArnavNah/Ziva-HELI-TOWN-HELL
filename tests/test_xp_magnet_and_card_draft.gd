extends SceneTree

## Dedicated Test Suite for XP Collection, Planar Magnet Physics,
## UpgradeCard Resources, and Level-Up Card Draft System.

const XpDropClass = preload("res://src/loot/xp_drop.gd")
const UpgradeCard = preload("res://src/resources/upgrade_card.gd")
const CardDatabase = preload("res://src/resources/upgrade_card_database.gd")
const LevelUpUiClass = preload("res://src/ui/level_up_ui.gd")
const PlayerSubsystemManager = preload("res://src/player/player_subsystem_manager.gd")

func _init() -> void:
	print("==================================================================")
	print("--- RUNNING XP MAGNET PHYSICS & CARD DRAFT ACCEPTANCE SUITE ---")
	print("==================================================================")
	var runner = XpSystemTestRunner.new()
	root.add_child(runner)

class XpSystemTestRunner extends Node:
	var passed: int = 0
	var total: int = 0
	var arena: Node3D
	var player: PlayerHelicopter
	var xp_manager: Node

	func check(condition: bool, test_name: String) -> void:
		total += 1
		if condition:
			passed += 1
			print("  [PASS] %2d. %s" % [total, test_name])
		else:
			push_error("  [FAIL] %2d. %s" % [total, test_name])
			print("  [FAIL] %2d. %s" % [total, test_name])

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

		# Disconnect real save settlement
		var gm = get_node_or_null("/root/GameManager")
		var bus = get_node_or_null("/root/EventBus")
		if gm and bus:
			var dh = Callable(gm, "_on_player_died")
			if bus.player_died.is_connected(dh):
				bus.player_died.disconnect(dh)

		arena = Node3D.new()
		add_child(arena)

		xp_manager = get_node_or_null("/root/XpManager")
		if not xp_manager:
			var xpm_script = load("res://src/player/xp_manager.gd")
			xp_manager = xpm_script.new()
			xp_manager.name = "XpManager"
			get_tree().root.add_child(xp_manager)

		player = load("res://scenes/player/player.tscn").instantiate()
		arena.add_child(player)

		_run_all_tests()

	func _run_all_tests() -> void:
		_test_xp_drop_default_properties()
		_test_planar_magnet_physics_and_collection()
		_test_magnet_anti_overshoot_edge_case()
		_test_player_magnet_sensor_detection_and_scaling()
		_test_xp_manager_exponential_formula()
		_test_xp_manager_multi_level_queueing()
		_test_upgrade_card_resource_contract()
		_test_rarity_weights_and_luck_scaling()
		_test_card_draft_distinct_picks()
		_test_player_subsystem_manager_payloads()
		_test_levelup_ui_pause_and_queue_flow()
		_conclude()

	func _test_xp_drop_default_properties() -> void:
		var drop = XpDropClass.new()
		arena.add_child(drop)
		check(drop.xp_amount == 10, "XpDrop: Default xp_amount is exactly 10 (observed: %d)" % drop.xp_amount)
		check(drop.attract_speed == 0.0, "XpDrop: Initial attract_speed is 0.0 (observed: %.1f)" % drop.attract_speed)
		check(drop.max_attract_speed == 25.0, "XpDrop: Default max_attract_speed is 25.0 (observed: %.1f)" % drop.max_attract_speed)
		check(drop.attraction_acceleration == 40.0, "XpDrop: Default attraction_acceleration is 40.0 (observed: %.1f)" % drop.attraction_acceleration)
		check(drop.is_being_attracted == false and drop.target_player == null, "XpDrop: Initial state is not attracted and target_player is null")
		drop.queue_free()

	func _test_planar_magnet_physics_and_collection() -> void:
		# Test planar XZ distance trigger (ignoring height variations)
		xp_manager.reset_run()
		var drop = XpDropClass.new()
		drop.xp_amount = 15
		# Position drop at X=1.0, Z=0.0, but with a large vertical offset Y=20.0
		drop.position = arena.to_local(player.global_position + Vector3(1.0, 20.0, 0.0))
		arena.add_child(drop)

		drop.start_attraction(player)
		check(drop.is_being_attracted and drop.target_player == player, "Magnet Physics: start_attraction sets target_player and is_being_attracted")

		# Planar distance is 1.0m (which is < 1.5m), even though 3D distance is ~20m!
		drop._physics_process(0.016)

		check(xp_manager.total_xp_collected == 15, "Planar Magnet: Collection triggered based on XZ planar distance < 1.5m despite 20m vertical delta (XP: %d)" % xp_manager.total_xp_collected)
		check(drop.is_collected, "Planar Magnet: Drop marked is_collected and freed upon arrival")

	func _test_magnet_anti_overshoot_edge_case() -> void:
		# Defensive Checklist 1: High player boost speed must not cause overshoot or endless orbiting
		var drop = XpDropClass.new()
		drop.xp_amount = 10
		drop.position = arena.to_local(Vector3(0, 5, 0))
		arena.add_child(drop)

		# Simulate player flying at high boost speed (50 m/s)
		player.velocity = Vector3(50.0, 0.0, 0.0)
		player.global_position = Vector3(25.0, 5.0, 0.0)

		drop.start_attraction(player)

		# Over 1.5 seconds of flight, drop must close distance and collect without orbiting
		for step in range(90): # 90 frames = 1.5s
			player.global_position += player.velocity * 0.016
			drop._physics_process(0.016)
			if drop.is_collected:
				break

		check(drop.is_collected, "Magnet Edge Case: High-speed boosting player (50 m/s) does not cause drops to orbit endlessly; collected successfully")
		player.velocity = Vector3.ZERO

	func _test_player_magnet_sensor_detection_and_scaling() -> void:
		# Verify MagnetSensor Area3D on player
		var sensor = player.get_node_or_null("MagnetSensor") as Area3D
		check(sensor != null, "Player MagnetSensor: Area3D node attached to PlayerHelicopter")

		var shape = sensor.get_node_or_null("CollisionShape3D") as CollisionShape3D
		check(shape != null and shape.shape is SphereShape3D, "Player MagnetSensor: CollisionShape3D with SphereShape3D exists")
		check(is_equal_approx(shape.shape.radius, 12.0), "Player MagnetSensor: Default attraction radius is exactly 12.0 meters")

		# Test sensor area_entered trigger
		var drop = XpDropClass.new()
		arena.add_child(drop)
		check(drop.is_being_attracted == false, "Player MagnetSensor: Drop is not attracted before entering sensor")

		player._on_magnet_sensor_area_entered(drop)
		check(drop.is_being_attracted == true and drop.target_player == player, "Player MagnetSensor: Entering sensor sets target_player and starts attraction")

		# Test scaling via Global Tome
		player.update_magnet_sensor_radius(1.5)
		check(is_equal_approx(shape.shape.radius, 18.0), "Player MagnetSensor: Radius scales dynamically to 18.0m (+50%% via Tome)")
		player.update_magnet_sensor_radius(1.0)
		drop.queue_free()

	func _test_xp_manager_exponential_formula() -> void:
		xp_manager.reset_run()
		check(xp_manager.current_level == 1, "XpManager: Starts at level 1")
		check(xp_manager.current_xp == 0, "XpManager: Starts at 0 XP")
		check(xp_manager.base_xp_requirement == 25, "XpManager: Base XP requirement is 25")
		check(is_equal_approx(xp_manager.xp_exponent, 1.35), "XpManager: XP exponent is 1.35")

		# Formula: target_xp = int(base_xp_requirement * pow(current_level, xp_exponent))
		# Level 1: int(25 * pow(1, 1.35)) = 25
		check(xp_manager.target_xp == 25, "Level Scaling: Level 1 target XP is exactly 25 (observed: %d)" % xp_manager.target_xp)

		# Add 25 XP to reach level 2
		xp_manager.add_xp(25)
		# Level 2: int(25 * pow(2, 1.35)) = int(25 * 2.549) = 63
		var expected_lvl2_target = int(25.0 * pow(2.0, 1.35))
		check(xp_manager.current_level == 2, "XpManager: Reaches Level 2 upon collecting 25 XP")
		check(xp_manager.target_xp == expected_lvl2_target, "Level Scaling: Level 2 target XP matches formula int(25 * 2^1.35) = %d (observed: %d)" % [expected_lvl2_target, xp_manager.target_xp])

	func _test_xp_manager_multi_level_queueing() -> void:
		# Defensive Checklist 3: Massive XP burst causing multiple simultaneous level-ups
		xp_manager.reset_run()
		# Add 500 XP at once
		xp_manager.add_xp(500)
		check(xp_manager.current_level > 3, "Multi-Level Queue: 500 XP raises level multiple times (now Level %d)" % xp_manager.current_level)
		check(xp_manager.queued_level_ups == xp_manager.current_level - 1, "Multi-Level Queue: Queued count (%d) tracks all levels gained without skipping" % xp_manager.queued_level_ups)
		check(xp_manager.has_pending_level_ups(), "Multi-Level Queue: has_pending_level_ups() reports true")

		# Consume one level up from queue
		var remaining = xp_manager.consume_pending_level_up()
		check(remaining == xp_manager.queued_level_ups, "Multi-Level Queue: consume_pending_level_up correctly decrements pending queue")

	func _test_upgrade_card_resource_contract() -> void:
		# Verify @tool Resource script class and enums
		var card = UpgradeCard.create(
			"test_card", "RAPID CANNON", "Fires faster.",
			UpgradeCard.RarityTier.RARE,
			UpgradeCard.SubsystemType.PRIMARY_CANNON,
			{"fire_rate_mult": 0.35, "projectile_count": 2, "heat_reduction": 0.10}
		)
		check(card is Resource, "UpgradeCard: Is a valid Resource instance")
		check(card.card_id == "test_card" and card.title == "RAPID CANNON", "UpgradeCard: Retains card_id and title")
		check(card.rarity == UpgradeCard.RarityTier.RARE, "UpgradeCard: Enums support RARE tier (value %d)" % card.rarity)
		check(card.target_subsystem == UpgradeCard.SubsystemType.PRIMARY_CANNON, "UpgradeCard: Enums support PRIMARY_CANNON subsystem (value %d)" % card.target_subsystem)
		check(card.stat_changes.get("projectile_count") == 2, "UpgradeCard: Stores stat modification payload dictionary")
		check(card.get_rarity_name() == "RARE", "UpgradeCard: Helper returns formatted rarity name 'RARE'")
		check(card.get_subsystem_name() == "PRIMARY CANNON", "UpgradeCard: Helper returns formatted subsystem name 'PRIMARY CANNON'")

	func _test_rarity_weights_and_luck_scaling() -> void:
		var ui = LevelUpUiClass.new()
		arena.add_child(ui)

		# Baseline weights
		var w_base = ui.get_dynamic_rarity_weights(0.0)
		check(is_equal_approx(w_base[UpgradeCard.RarityTier.COMMON], 60.0), "Rarity Weights: COMMON baseline weight is 60.0")
		check(is_equal_approx(w_base[UpgradeCard.RarityTier.UNCOMMON], 25.0), "Rarity Weights: UNCOMMON baseline weight is 25.0")
		check(is_equal_approx(w_base[UpgradeCard.RarityTier.RARE], 10.0), "Rarity Weights: RARE baseline weight is 10.0")
		check(is_equal_approx(w_base[UpgradeCard.RarityTier.EPIC], 4.5), "Rarity Weights: EPIC baseline weight is 4.5")
		check(is_equal_approx(w_base[UpgradeCard.RarityTier.LEGENDARY], 0.5), "Rarity Weights: LEGENDARY baseline weight is 0.5")

		# Modified by Luck Tome level 2.0
		var w_luck = ui.get_dynamic_rarity_weights(2.0)
		check(w_luck[UpgradeCard.RarityTier.LEGENDARY] > w_base[UpgradeCard.RarityTier.LEGENDARY], "Luck Scaling: Global Luck Tome elevates LEGENDARY odds (%.2f -> %.2f)" % [w_base[UpgradeCard.RarityTier.LEGENDARY], w_luck[UpgradeCard.RarityTier.LEGENDARY]])
		check(w_luck[UpgradeCard.RarityTier.EPIC] > w_base[UpgradeCard.RarityTier.EPIC], "Luck Scaling: Global Luck Tome elevates EPIC odds (%.2f -> %.2f)" % [w_base[UpgradeCard.RarityTier.EPIC], w_luck[UpgradeCard.RarityTier.EPIC]])
		check(w_luck[UpgradeCard.RarityTier.COMMON] < w_base[UpgradeCard.RarityTier.COMMON], "Luck Scaling: Global Luck Tome trims COMMON odds (%.2f -> %.2f)" % [w_base[UpgradeCard.RarityTier.COMMON], w_luck[UpgradeCard.RarityTier.COMMON]])
		ui.queue_free()

	func _test_card_draft_distinct_picks() -> void:
		var ui = LevelUpUiClass.new()
		arena.add_child(ui)

		# Generate 3 distinct cards
		var picks = ui.generate_draft_picks(3, 0.0)
		check(picks.size() == 3, "Draft Selection: Generates exactly 3 cards (size: %d)" % picks.size())

		# Ensure zero duplicate cards
		var ids = []
		var has_duplicates = false
		for c in picks:
			if ids.has(c.card_id):
				has_duplicates = true
			ids.append(c.card_id)
		check(not has_duplicates, "Draft Selection: All 3 generated cards are distinct with zero duplicates (%s)" % str(ids))
		ui.queue_free()

	func _test_player_subsystem_manager_payloads() -> void:
		var sm = player.get_node_or_null("SubsystemManager") as PlayerSubsystemManager
		check(sm != null, "PlayerSubsystemManager: Attached to PlayerHelicopter node")

		# 1. PRIMARY_CANNON Payload
		var cannon_card = UpgradeCard.create("test_cannon", "Cannon Boost", "", UpgradeCard.RarityTier.COMMON, UpgradeCard.SubsystemType.PRIMARY_CANNON, {"damage_mult": 0.20, "fire_rate_mult": 0.15})
		sm.apply_upgrade(cannon_card)
		check(is_equal_approx(sm.active_stats["cannon_damage_mult"], 1.20), "Subsystem Cannon: Damage multiplier upgraded to 1.20x (+20%%)")

		# 2. ROCKET_PODS Payload
		var rocket_card = UpgradeCard.create("test_rocket", "Rocket Boost", "", UpgradeCard.RarityTier.COMMON, UpgradeCard.SubsystemType.ROCKET_PODS, {"damage_mult": 0.25, "blast_radius_mult": 0.30})
		sm.apply_upgrade(rocket_card)
		check(is_equal_approx(sm.active_stats["rocket_damage_mult"], 1.25), "Subsystem Rockets: Damage multiplier upgraded to 1.25x (+25%%)")

		# 3. GUIDED_MISSILES Payload
		var missile_card = UpgradeCard.create("test_missile", "Salvo Boost", "", UpgradeCard.RarityTier.UNCOMMON, UpgradeCard.SubsystemType.GUIDED_MISSILES, {"max_locks_add": 2, "damage_mult": 0.35})
		sm.apply_upgrade(missile_card)
		check(sm.active_stats["missile_max_locks"] == 8, "Subsystem Missiles: Maximum salvo locks increased from 6 to 8 (+2)")

		# 4. GLOBAL_TOME Payload (Luck & Magnet)
		var tome_card = UpgradeCard.create("test_tome", "Fortune Tome", "", UpgradeCard.RarityTier.RARE, UpgradeCard.SubsystemType.GLOBAL_TOME, {"luck_level_add": 1.5, "magnet_radius_mult": 0.40})
		sm.apply_upgrade(tome_card)
		check(is_equal_approx(sm.get_luck_level(), 1.5), "Subsystem Tome: Global player Luck Level updated to 1.5")
		check(is_equal_approx(sm.active_stats["magnet_radius_mult"], 1.40), "Subsystem Tome: Planar magnet radius multiplier updated to 1.40x (+40%%)")

	func _test_levelup_ui_pause_and_queue_flow() -> void:
		xp_manager.reset_run()
		var ui = LevelUpUiClass.new()
		arena.add_child(ui)

		# Defensive Requirement 2: process_mode must be PROCESS_MODE_WHEN_PAUSED or ALWAYS
		check(ui.process_mode == Node.PROCESS_MODE_ALWAYS or ui.process_mode == Node.PROCESS_MODE_WHEN_PAUSED, "Process Mode: LevelUpUi process_mode is WHEN_PAUSED or ALWAYS (observed: %d)" % ui.process_mode)

		# Trigger draft
		ui.open_draft(2)
		check(get_tree().paused == true, "UI Execution Flow: Opening draft sets get_tree().paused = true")
		check(ui.visible == true, "UI Execution Flow: LevelUpUi overlay is visible")

		# Simulate selecting card #1 (index 0)
		var chosen = ui.current_draft[0]
		ui._on_card_clicked(0)
		check(get_tree().paused == false, "UI Execution Flow: Selecting upgrade unpauses gameplay tree")
		check(ui.visible == false, "UI Execution Flow: LevelUpUi overlay is dismissed")

		ui.queue_free()

	func _conclude() -> void:
		print("==================================================================")
		print("XP MAGNET & CARD DRAFT SUITE RESULTS: %d/%d PASSED" % [passed, total])
		print("==================================================================")
		if passed == total:
			print("ALL SPECIFICATIONS AND DEFENSIVE CHECKS VERIFIED SUCCESSFULLY!")
			get_tree().quit(0)
		else:
			push_error("TEST FAILURES OCCURRED!")
			get_tree().quit(1)
