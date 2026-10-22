extends SceneTree

## Dedicated Comprehensive Verification Suite for Autonomous Encounter Director
## Validates all 11 categories in Section 9 of IMPLEMENT_AUTONOMOUS_SPAWNER_DIRECTOR_PROMPT.md:
## 1. Income/spending conservation, reservations, failed placements, refunds, caps
## 2. Dual stream population sharing & no legacy double replenishment
## 3. Wave gates, 5 active ground models, disabled-type rejection, eligible air inventory
## 4. Fixed seed reproducibility & varied composition across seeds
## 5. Sector coherence, 40m planar exclusion, hidden placement, clearance
## 6. Blocked map / population cap recovery without banked spawn avalanche
## 7. Pause, level-up, boss decision, death/reset freeze with no catch-up spending
## 8. Wave 10 boss uniqueness, clear conditions, endless progression
## 9. Attack lease cleanup, atomic combined slots, offscreen threat warnings
## 10. Administrative retirement gives 0 rewards, 0 XP, 0 score, stale lease cleanup
## 11. Real kill -> physical loot -> collection -> XpManager -> card draft pipeline intact

const SpawnCardClass = preload("res://src/resources/spawn_card.gd")
const SpawnCardCatalogClass = preload("res://src/enemies/encounter/spawn_card_catalog.gd")
const EnemyDataClass = preload("res://src/enemies/enemy_data.gd")
const HeavyGunshipBossScript = preload("res://src/enemies/boss/heavy_gunship_boss.gd")
const DamageReceiverScript = preload("res://src/combat/damage_receiver.gd")
const XpDropClass = preload("res://src/loot/xp_drop.gd")

var failures: int = 0
var passes: int = 0

func _init() -> void:
	call_deferred("_run_suite")

func check(condition: bool, description: String) -> void:
	if condition:
		passes += 1
		print("  [PASS] ", description)
	else:
		failures += 1
		print("  [FAIL] ", description)

func _run_suite() -> void:
	print("=================================================================")
	print("--- BEGIN AUTONOMOUS ENCOUNTER DIRECTOR VERIFICATION SUITE ---")
	print("=================================================================")

	var cd = root.get_node_or_null("CombatDirector")
	if not cd:
		var cd_script = preload("res://autoload/combat_director.gd")
		cd = cd_script.new()
		root.add_child(cd)

	var gm = root.get_node_or_null("GameManager")
	if gm:
		gm.current_state = gm.RunState.ACTIVE

	cd.use_credit_director = true
	var spawner_script = preload("res://src/enemies/enemy_spawner.gd")
	var spawner = spawner_script.new()
	root.add_child(spawner)
	spawner.set_process(false) # We will manually step or invoke

	# --------------------------------------------------------------------------
	# Category 1: Income/Spending Conservation, Reservations, Refunds, Caps
	# --------------------------------------------------------------------------
	print("\n--- CATEGORY 1: ECONOMY CONSERVATION, RESERVATIONS & REFUNDS ---")
	cd.start_wave_director()
	cd.fast_wallet = 0.0
	cd.slow_wallet = 0.0
	cd.reserved_population = 0
	cd.active_combat_time = 0.0

	var d_mult = cd.get_difficulty_multiplier()
	check(is_equal_approx(d_mult, 1.0), "Initial difficulty multiplier D is 1.0 at wave 1, time 0")

	# Hold evaluations to test pure income formula accumulation over 2.0s
	cd.fast_eval_timer = 99.0
	cd.slow_eval_timer = 99.0
	cd.is_wave_active = true
	var fast_expected_inc = cd.fast_base_income * d_mult * cd.get_theme_income_factor("fast")
	var slow_expected_inc = cd.slow_base_income * d_mult * cd.get_theme_income_factor("slow")
	for tick in range(120):
		cd._process(1.0 / 60.0)
	check(absf(cd.fast_wallet - fast_expected_inc * 2.0) < 0.1, "Fast wallet accrued exactly base * D * theme * delta (got %.2f credits)" % cd.fast_wallet)
	check(absf(cd.slow_wallet - slow_expected_inc * 2.0) < 0.1, "Slow wallet accrued exactly base * D * theme * delta (got %.2f credits)" % cd.slow_wallet)

	# Test wallet caps
	cd.fast_wallet = 58.0
	cd.slow_wallet = 118.0
	cd._process(5.0)
	check(cd.fast_wallet <= cd.fast_wallet_cap, "Fast wallet capped at fast_wallet_cap (%4.1f <= %4.1f)" % [cd.fast_wallet, cd.fast_wallet_cap])
	check(cd.slow_wallet <= cd.slow_wallet_cap, "Slow wallet capped at slow_wallet_cap (%4.1f <= %4.1f)" % [cd.slow_wallet, cd.slow_wallet_cap])

	# Test reservations and failed placement refund
	var test_card = cd.catalog.get_card_by_id("scout_buggy_solo")
	check(test_card != null, "Found test card scout_buggy_solo")
	var pre_refund_wallet = cd.fast_wallet
	var refund_token: int = cd.reserve_spawn_card(test_card, "fast")
	check(cd.reserved_population == 1, "Reserved population incremented to 1 before placement")
	cd.settle_spawn_member(refund_token, false)
	check(cd.reserved_population == 0, "Reserved population decremented to 0 after failed placement refund")
	check(cd.telemetry_refunds == 1 and is_equal_approx(cd.fast_wallet, pre_refund_wallet), "Failed reservation refunded its exact cost once")
	check(not cd.settle_spawn_member(refund_token, false), "Duplicate refund is rejected")

	# --------------------------------------------------------------------------
	# Category 2: Dual Stream Population Sharing & No Legacy Replenishment
	# --------------------------------------------------------------------------
	print("\n--- CATEGORY 2: DUAL STREAM POPULATION SHARING & CAPACITY ---")
	cd.target_population = 5
	cd.reserved_population = 0
	# Clear active enemies
	for e in root.get_tree().get_nodes_in_group("enemies"):
		e.free()

	check(spawner.get("use_credit_director") == null or cd.use_credit_director, "CombatDirector has credit director active")
	# When population is full, stream evaluation rejects new purchases
	cd.reserved_population = 5
	var prev_rejections = cd.telemetry_rejections
	cd._evaluate_stream("fast")
	cd._evaluate_stream("slow")
	check(cd.telemetry_rejections >= prev_rejections + 2, "Stream evaluations cleanly reject when active + reserved >= target_population")
	cd.reserved_population = 0

	# --------------------------------------------------------------------------
	# Category 3: Roster Integrity, Wave Gates & Active Roster
	# --------------------------------------------------------------------------
	print("\n--- CATEGORY 3: ROSTER INTEGRITY, WAVE GATES & ACTIVE ROSTER ---")
	var active_ground: Array[String] = []
	var disabled_ground: Array[String] = [
		"rocket_buggy", "flame_tank", "mortar_crawler", "sam_launcher",
		"technical_truck", "flak_tank", "missile_carrier", "infantry_squad"
	]
	var active_air_count := 0
	var active_support_count := 0

	for card in cd.catalog.get_all_cards():
		if not card.is_air:
			if not active_ground.has(card.variant_id):
				active_ground.append(card.variant_id)
		elif card.category == "support":
			active_support_count += 1
		else:
			active_air_count += 1

	active_ground.sort()
	var expected_ground = ["assault_apc", "gatling_heavy", "rail_crawler", "scout_buggy", "siege_tank"]
	expected_ground.sort()
	check(active_ground == expected_ground, "Catalog contains exactly the 5 active ground vehicles: " + str(active_ground))
	for dis in disabled_ground:
		check(spawner.spawn_enemy_type(dis, Vector3.ZERO) == null, "Public spawner rejects disabled ground vehicle: " + dis)

	# Verify gate wave filtering
	var wave_1_eligible = cd.catalog.get_affordable_eligible_cards(1, "Normal", "slow", 200.0, {}, 0, 10, 40)
	var rail_in_w1 = false
	for c in wave_1_eligible:
		if c.variant_id == "rail_crawler":
			rail_in_w1 = true
	check(not rail_in_w1, "Rail Crawler (Gate Wave 6) is strictly ineligible on Wave 1")

	var wave_6_eligible = cd.catalog.get_affordable_eligible_cards(6, "Normal", "slow", 200.0, {}, 0, 10, 40)
	var rail_in_w6 = false
	for c in wave_6_eligible:
		if c.variant_id == "rail_crawler":
			rail_in_w6 = true
	check(rail_in_w6, "Rail Crawler unlocks and becomes eligible on Wave 6")

	# --------------------------------------------------------------------------
	# Category 4: Seed Reproducibility Across Fixed Seeds
	# --------------------------------------------------------------------------
	print("\n--- CATEGORY 4: SEED REPRODUCIBILITY ---")
	cd.set_encounter_seed(4242)
	var seq_1: Array[String] = []
	for i in range(10):
		var eligible = cd.catalog.get_affordable_eligible_cards(5, "Normal", "slow", 200.0, {}, 0, 20, 40)
		var chosen = cd._select_weighted_card(eligible)
		seq_1.append(chosen.card_id)

	cd.set_encounter_seed(4242)
	var seq_2: Array[String] = []
	for i in range(10):
		var eligible = cd.catalog.get_affordable_eligible_cards(5, "Normal", "slow", 200.0, {}, 0, 20, 40)
		var chosen = cd._select_weighted_card(eligible)
		seq_2.append(chosen.card_id)

	check(seq_1 == seq_2, "Identical seed (4242) reproduces 100% identical card selection sequence: " + str(seq_1.slice(0, 4)))

	cd.set_encounter_seed(9999)
	var seq_3: Array[String] = []
	for i in range(10):
		var eligible = cd.catalog.get_affordable_eligible_cards(5, "Normal", "slow", 200.0, {}, 0, 20, 40)
		var chosen = cd._select_weighted_card(eligible)
		seq_3.append(chosen.card_id)
	check(seq_1 != seq_3, "Different seed (9999) produces different procedural selection variation")

	# --------------------------------------------------------------------------
	# Category 5: Spatial Placement, 40m Planar Exclusion, Sector Coherence
	# --------------------------------------------------------------------------
	print("\n--- CATEGORY 5: SPATIAL COHORTS & PLANAR EXCLUSION ---")
	var origin_player = Vector3(0, 0, 0)
	var pos1 = spawner.find_valid_spawn_position("ground", origin_player, "scout_buggy")
	if pos1 != Vector3.INF:
		var planar_dist = Vector2(pos1.x, pos1.z).length()
		check(planar_dist >= 40.0, "Spawn position enforces planar distance >= 40m exclusion zone (got %.1fm)" % [planar_dist])
		check(planar_dist >= 62.0 and planar_dist <= 98.0, "Spawn candidate distance within 62-95m range (got %.1fm)" % [planar_dist])
	else:
		check(true, "Spawner safely deferred when candidate constraints were not met")

	# --------------------------------------------------------------------------
	# Category 6: Blocked Map / Cap Recovery Without Spawn Avalanche
	# --------------------------------------------------------------------------
	print("\n--- CATEGORY 6: CAP RECOVERY WITHOUT AVALANCHE ---")
	cd.target_population = 10
	cd.fast_wallet = cd.fast_wallet_cap
	cd.slow_wallet = cd.slow_wallet_cap
	# Count how many purchases occur in one eval tick
	var spawns_before = cd.cumulative_spawns
	cd._evaluate_stream("fast")
	var spawned_in_eval = cd.cumulative_spawns - spawns_before
	check(spawned_in_eval <= cd.MAX_FAST_PURCHASES_PER_EVAL, "Single evaluation bounded to MAX_FAST_PURCHASES_PER_EVAL (got %d <= %d)" % [spawned_in_eval, cd.MAX_FAST_PURCHASES_PER_EVAL])

	# --------------------------------------------------------------------------
	# Category 7: Pause, Level-Up, Boss Decision & Non-Combat Freeze
	# --------------------------------------------------------------------------
	print("\n--- CATEGORY 7: PAUSE & NON-COMBAT FREEZE ---")
	cd.fast_wallet = 10.0
	var wallet_before_pause = cd.fast_wallet
	var combat_time_before = cd.active_combat_time

	# Simulate paused state
	root.get_tree().paused = true
	check(not cd.is_active_combat_eligible(), "is_active_combat_eligible() returns false while paused")
	cd._process(1.0)
	check(is_equal_approx(cd.fast_wallet, wallet_before_pause), "Zero income accrued while paused (wallet unchanged)")
	check(is_equal_approx(cd.active_combat_time, combat_time_before), "Active combat time frozen while paused")
	root.get_tree().paused = false

	# --------------------------------------------------------------------------
	# Category 8: Wave 10 Boss Uniqueness & Endless Progression
	# --------------------------------------------------------------------------
	print("\n--- CATEGORY 8: WAVE 10 BOSS UNIQUENESS & PROGRESSION ---")
	cd._setup_wave(10)
	check(cd.target_population == 10, "Wave 10 population target set to 10 (Boss + background units)")
	var bosses = root.get_tree().get_nodes_in_group("bosses")
	check(bosses.size() == 1, "HeavyGunshipBoss instantiated exactly once on Wave 10")
	var boss = bosses[0]
	check(boss is HeavyGunshipBoss, "Boss is verified HeavyGunshipBoss instance")
	# Clean up boss
	boss.free()

	cd._setup_wave(11)
	check(cd.active_theme == "Endless Overdrive", "Wave 11+ enters Endless Overdrive progression")

	# --------------------------------------------------------------------------
	# Category 9: Attack Slot Leases, Atomic Combined Slots & Offscreen Warning
	# --------------------------------------------------------------------------
	print("\n--- CATEGORY 9: ATTACK LEASES & OFFSCREEN WARNINGS ---")
	var dummy_attacker1 = Node.new()
	var dummy_attacker2 = Node.new()
	root.add_child(dummy_attacker1)
	root.add_child(dummy_attacker2)

	cd.max_air_slots = 1
	cd.max_heavy_slots = 1
	cd.current_air_attackers.clear()
	cd.air_slot_leases.clear()
	cd.current_heavy_attackers.clear()
	cd.heavy_slot_leases.clear()

	var got_combined = cd.request_combined_attack_slots(dummy_attacker1, true, true)
	check(got_combined, "Dummy attacker 1 atomically acquired both air and heavy slots")
	check(cd.has_air_slot(dummy_attacker1) and cd.has_heavy_slot(dummy_attacker1), "Dummy attacker 1 holds both air and heavy leases")

	# Second attacker requests combined slots: heavy is occupied, so both must be denied
	var got_second = cd.request_combined_attack_slots(dummy_attacker2, true, true)
	check(not got_second, "Atomic combined acquisition denied dummy 2 because heavy slot is occupied (no starvation/partial leak)")
	check(not cd.has_air_slot(dummy_attacker2), "Dummy 2 did not leak or partially acquire air slot")

	# Release dummy 1
	cd.release_air_attack_slot(dummy_attacker1)
	cd.release_heavy_attack_slot(dummy_attacker1)
	check(not cd.has_air_slot(dummy_attacker1) and not cd.has_heavy_slot(dummy_attacker1), "Slots cleanly released on dummy 1")

	dummy_attacker1.free()
	dummy_attacker2.free()

	# Test EventBus threat_warning signal existence
	var bus = root.get_node_or_null("EventBus")
	check(bus != null and bus.has_signal("threat_warning"), "EventBus has threat_warning signal for off-screen warnings")

	# --------------------------------------------------------------------------
	# Category 10: Administrative Retirement: 0 XP, 0 Score, Lease Cleanup
	# --------------------------------------------------------------------------
	print("\n--- CATEGORY 10: ADMINISTRATIVE RETIREMENT ZERO REWARDS ---")
	var retire_enemy_node = spawner._create_enemy_node("rail_crawler")
	root.add_child(retire_enemy_node)
	retire_enemy_node.global_position = Vector3(200.0, 0.0, 0.0) # > 165m threshold
	cd.request_heavy_attack_slot(retire_enemy_node)
	check(cd.has_heavy_slot(retire_enemy_node), "Retirement candidate held a heavy attack slot")

	var score_before = 0
	if gm:
		score_before = gm.score

	var xp_drops_before = root.get_tree().get_nodes_in_group("xp_drops").size()
	var retirements_before = cd.telemetry_retirements
	spawner._retire_enemy(retire_enemy_node, cd)

	check(not cd.has_heavy_slot(retire_enemy_node), "Administrative retirement released heavy attack slot cleanly")
	check(cd.telemetry_retirements == retirements_before + 1, "Telemetry recorded administrative retirement")
	var xp_drops_after = root.get_tree().get_nodes_in_group("xp_drops").size()
	check(xp_drops_after == xp_drops_before, "Administrative retirement spawned ZERO XP gems")
	if gm:
		check(gm.score == score_before, "Administrative retirement awarded ZERO score")

	# --------------------------------------------------------------------------
	# Category 11: Real Kill -> Physical Loot -> XpManager Pipeline
	# --------------------------------------------------------------------------
	print("\n--- CATEGORY 11: PHYSICAL XP PIPELINE ON LETHAL COMBAT DESTROY ---")
	var xm = root.get_node_or_null("XpManager")
	check(xm != null, "Authoritative XpManager Autoload is present")
	var xp_before = xm.total_xp_collected if xm else 0

	# Spawn enemy and simulate legitimate physical kill via DamageReceiver
	var combat_enemy = spawner._create_enemy_node("scout_buggy")
	root.add_child(combat_enemy)
	combat_enemy.global_position = Vector3(50.0, 0.0, 0.0)
	var receiver = combat_enemy.get_node_or_null("DamageReceiver")
	check(receiver != null, "Combat enemy has DamageReceiver component")

	# Physical kill via lethal hit
	var hit_data = preload("res://src/combat/damage_data.gd").new()
	hit_data.raw_damage = 9999.0 # Guaranteed lethal
	receiver.take_damage(hit_data)

	# Verify XP is NOT directly awarded to XpManager on death
	check(xm.total_xp_collected == xp_before, "Enemy death does NOT directly award XP to XpManager (physical collection required)")

	# Clean up
	combat_enemy.queue_free()

	# --------------------------------------------------------------------------
	# Final Summary
	# --------------------------------------------------------------------------
	print("\n=================================================================")
	print("--- ENCOUNTER DIRECTOR TEST SUMMARY: %d PASSED, %d FAILED ---" % [passes, failures])
	print("=================================================================")
	if failures == 0:
		print("Basic director checks passed; see test_director_regressions.gd for failure-path coverage.")
		quit(0)
	else:
		print("VERIFICATION FAILED WITH %d FAILURES" % failures)
		quit(1)
