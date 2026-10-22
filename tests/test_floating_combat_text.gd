extends SceneTree

## TestFloatingCombatText — Automated verification for floating damage numbers and kill compliments.

const FloatingText = preload("res://src/effects/floating_text.gd")

func _init() -> void:
	print("--- BEGIN FLOATING COMBAT TEXT & KILL COMPLIMENTS VERIFICATION ---")
	var runner = FCTTestRunner.new()
	root.add_child(runner)

class FCTTestRunner extends Node:
	var step: int = 0
	var tests_passed: int = 0
	const TOTAL_TESTS: int = 5
	var test_dummy: CharacterBody3D
	var damage_receiver: DamageReceiver

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(_delta: float) -> void:
		step += 1

		if step == 5:
			# Test 1: Direct Normal Damage Number Spawning
			var fx = get_node_or_null("/root/FXManager")
			if fx:
				fx.spawn_damage_number(Vector3(0, 5, 0), 37.0, false)
				var found = false
				for child in get_tree().root.get_children():
					if child is FloatingText and child.text == "37":
						found = true
						break
				if found:
					print("  [PASS] 1. Normal Damage Number: Successfully spawned '37' arcade floating text.")
					tests_passed += 1
				else:
					print("  [FAIL] 1. Normal Damage Number was not found in scene tree.")
			else:
				print("  [FAIL] 1. FXManager missing.")

		elif step == 10:
			# Test 2: Critical Hit Spawning ("CRIT!\n114")
			var fx = get_node_or_null("/root/FXManager")
			if fx:
				fx.spawn_damage_number(Vector3(10, 5, 0), 114.0, true)
				var found_crit = false
				for child in get_tree().root.get_children():
					if child is FloatingText:
						if child.text == "CRIT!\n114" or (child.text.begins_with("CRIT!") and "114" in child.text):
							found_crit = true
							break
				if found_crit:
					print("  [PASS] 2. Critical Hit Popups: Successfully spawned unified 'CRIT!\n114' label.")
					tests_passed += 1
				else:
					print("  [FAIL] 2. Critical hit label missing.")
			else:
				print("  [FAIL] 2. FXManager missing.")

		elif step == 15:
			# Test 3: Compliment and Bounty Popup Spawning
			var fx = get_node_or_null("/root/FXManager")
			if fx:
				fx.spawn_compliment(Vector3(-10, 5, 0))
				fx.spawn_bounty_popup(Vector3(-10, 5, 0), 255)
				var found_comp = false
				var found_bounty = false
				for child in get_tree().root.get_children():
					if child is FloatingText:
						if child.text in fx.KILL_COMPLIMENTS or child.text in ["DOUBLE KILL!", "TRIPLE KILL!", "MULTI KILL!", "RAMPAGE!", "UNSTOPPABLE!"]:
							found_comp = true
						elif child.text == "$255":
							found_bounty = true
				if found_comp and found_bounty:
					print("  [PASS] 3. Compliment & Bounty: Animated compliment and '$255' popup spawned successfully.")
					tests_passed += 1
				else:
					print("  [FAIL] 3. Compliment or bounty missing. found_comp=", found_comp, " found_bounty=", found_bounty)
			else:
				print("  [FAIL] 3. FXManager missing.")

		elif step == 20:
			# Test 4: Live DamageReceiver Integration (Simulated combat hit & kill)
			test_dummy = CharacterBody3D.new()
			test_dummy.name = "TestEnemy"
			test_dummy.add_to_group("enemies")
			get_tree().root.add_child(test_dummy)
			test_dummy.global_position = Vector3(20, 2, 20)

			damage_receiver = DamageReceiver.new()
			damage_receiver.max_health = 100.0
			damage_receiver.current_health = 100.0
			test_dummy.add_child(damage_receiver)

			# Deal 45 normal damage
			var d_data = DamageData.new(45.0, GameConstants.WeaponType.MACHINE_GUN, null, false)
			damage_receiver.take_damage(d_data)

			var found_hit = false
			for child in get_tree().root.get_children():
				if child is FloatingText and child.text == "50":
					found_hit = true
					break
			if found_hit:
				print("  [PASS] 4. DamageReceiver Pipeline: '50' damage text popped up on hit (45 base * 1.10 light affinity).")
				tests_passed += 1
			else:
				print("  [FAIL] 4. DamageReceiver did not trigger damage number popup.")

		elif step == 25:
			# Test 5: Lethal Hit & Kill Compliment Settlement
			var lethal_data = DamageData.new(120.0, GameConstants.WeaponType.ROCKET, null, false)
			damage_receiver.take_damage(lethal_data)

			var found_death_compliment = false
			for child in get_tree().root.get_children():
				if child is FloatingText:
					if child.text in FXManager.KILL_COMPLIMENTS or child.text.ends_with("KILL!") or child.text == "RAMPAGE!":
						found_death_compliment = true
						break
			if found_death_compliment:
				print("  [PASS] 5. Enemy Destruction Pipeline: Kill compliment popped up on enemy death.")
				tests_passed += 1
			else:
				print("  [FAIL] 5. Kill compliment failed to spawn on enemy destruction.")

			test_dummy.queue_free()

		elif step == 35:
			print("--- FCT TEST SUMMARY: ", tests_passed, "/", TOTAL_TESTS, " PASSED ---")
			if tests_passed == TOTAL_TESTS:
				print("ALL FLOATING COMBAT TEXT & KILL COMPLIMENT VERIFICATIONS SUCCEEDED!")
				get_tree().quit(0)
			else:
				print("SOME TESTS FAILED.")
				get_tree().quit(1)
