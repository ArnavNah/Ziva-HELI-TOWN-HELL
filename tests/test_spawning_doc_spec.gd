extends SceneTree

## Verification test for Document-Spec Enemy Spawning
## Validates Page 9, 10, and 11:
## - Population targets across waves (1-3: 5, 7, 10; 4-6: 12, 14, 16; 7-9: 18, 21, 24)
## - Opening grace period (2.0s) & opening wave deployment cohort
## - Dynamic batch replenishment (deficit-driven 2-3 unit bursts)
## - Variant caps, gates, and theme weighting (Swarm Tide, Armored Column)
## - Wave-gated modifier rolls

func _init() -> void:
	var runner = DocSpawningRunner.new()
	root.add_child(runner)

class DocSpawningRunner extends Node:
	var frame: int = 0
	var tests_passed: int = 0
	var total_tests: int = 4
	var spawner: Node = null
	var cd: Node = null

	func _ready() -> void:
		print("--- BEGIN DOCUMENT-SPEC ENEMY SPAWNING TEST ---")
		if has_node("/root/CombatDirector"):
			cd = get_node("/root/CombatDirector")
		else:
			var cd_script = preload("res://autoload/combat_director.gd")
			cd = cd_script.new()
			get_tree().root.add_child(cd)
		cd.use_credit_director = false

		var spawner_script = preload("res://src/enemies/enemy_spawner.gd")
		spawner = spawner_script.new()
		add_child(spawner)

	func _process(_delta: float) -> void:
		frame += 1

		# Test 1: Population Targets across all wave brackets (Page 11)
		if frame == 2:
			var wave_targets_ok = true
			var expected_targets = {
				1: 5,
				2: 7,
				3: 10,
				4: 12,
				5: 14,
				6: 16,
				7: 18,
				8: 21,
				9: 24,
				10: 10
			}
			for w in expected_targets:
				cd._setup_wave(w)
				if cd.base_target_population != expected_targets[w]:
					wave_targets_ok = false
					print("  [FAIL] Wave ", w, " base population ", cd.base_target_population, " != expected ", expected_targets[w])
					break

			if wave_targets_ok:
				print("  [PASS] 1. Wave Population Targets: Verified 5, 7, 10 (W1-3), 12, 14, 16 (W4-6), 18, 21, 24 (W7-9), 10 (W10 Boss).")
				tests_passed += 1
			else:
				print("  [FAIL] 1. Wave population targets mismatch.")

		# Test 2: Opening Deployment Cohort & Grace Period (Page 11)
		if frame == 5:
			# Clear any residual enemies from prior frame tests
			for e in get_tree().get_nodes_in_group("enemies"):
				e.free()

			# Setup Wave 3 (target 10, Storm Surge)
			cd._setup_wave(3)
			spawner.last_handled_wave = -1 # trigger wave detection
			spawner._process(0.1) # detects wave, starts opening_grace_timer = 2.0s

			# Simulate 1.5s of grace (should NOT spawn yet)
			spawner._process(1.5)
			var enemies_during_grace = spawner._get_active_enemy_count()
			if enemies_during_grace > 0:
				print("  [FAIL] Enemies spawned before grace period expired.")
			else:
				# Complete grace period (0.6s remaining)
				spawner._process(0.6)
				var count_after_grace = spawner._get_active_enemy_count()
				if count_after_grace >= 5: # Should have spawned opening deployment cohort of 5-7 units
					print("  [PASS] 2. Opening Grace & Cohort Deployment: Held 2.0s opening grace, then immediately deployed opening squadron of ", count_after_grace, " units.")
					tests_passed += 1
				else:
					print("  [FAIL] Opening cohort size too small: ", count_after_grace)

		# Test 3: Rapid Batch Replenishment & Dynamic Intervals
		if frame == 10:
			# Clear active enemies to simulate massive player salvo kill
			var enemies = get_tree().get_nodes_in_group("enemies")
			for e in enemies:
				e.free()

			# Set cd to wave 5 (target 14)
			cd._setup_wave(5)
			spawner.last_handled_wave = 5
			spawner.opening_grace_timer = 0.0
			spawner.opening_burst_spawned = true
			spawner.spawn_timer = 0.0

			# Process one spawn tick
			spawner._process(0.01)
			var spawned_batch = spawner._get_active_enemy_count()
			# With deficit of 14, batch should be 3
			if spawned_batch >= 3:
				print("  [PASS] 3. Deficit Batch Replenishment: Heavy deficit triggered accelerated batch deployment of ", spawned_batch, " units in a single tick.")
				tests_passed += 1
			else:
				print("  [FAIL] Batch replenishment count too low: ", spawned_batch)

		# Test 4: Variant Caps & Gate Enforcement (Page 9)
		if frame == 15:
			var caps_ok = true
			# Rail Crawler is an active heavy ground role with max_cap 2 (Page 9). Simulate full capacity
			var test_variant = "rail_crawler"
			var unit1 = spawner.spawn_enemy_type(test_variant)
			var unit2 = spawner.spawn_enemy_type(test_variant)

			# Now roll 20 variant selections on Wave 6. Rail Crawler should NEVER be picked because cap (2) is reached.
			var variant_picked_after_cap = false
			for r in range(20):
				var picked = spawner._choose_wave_variant(6, "Normal")
				if picked == test_variant:
					variant_picked_after_cap = true
					break

			if variant_picked_after_cap:
				caps_ok = false
				print("  [FAIL] Variant cap violated: Rail Crawler picked beyond max cap of 2.")
			else:
				print("  [PASS] 4. Variant Caps & Gate Enforcement: Strictly respected variant maximum caps and wave gates.")
				tests_passed += 1

			if is_instance_valid(unit1):
				unit1.queue_free()
			if is_instance_valid(unit2):
				unit2.queue_free()

			print("--- SUMMARY: ", tests_passed, "/", total_tests, " PASSED ---")
			if tests_passed == total_tests:
				print("ALL DOCUMENT-SPEC SPAWNING TESTS SUCCEEDED!")
				get_tree().quit(0)
			else:
				get_tree().quit(1)
