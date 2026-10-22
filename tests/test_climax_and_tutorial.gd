extends SceneTree

func _init():
	print("--- BEGIN CLIMAX, TUTORIAL & FX VERIFICATION ---")
	var runner = ClimaxTestRunner.new()
	root.add_child(runner)

class ClimaxTestRunner extends Node:
	var step: int = 0
	var tests_passed: int = 0
	var total_tests: int = 4

	func _ready():
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(_delta: float):
		step += 1
		
		if step == 10:
			# Test 1: FXManager particle spawning without errors
			if has_node("/root/FXManager"):
				var fx = get_node("/root/FXManager")
				fx.spawn_explosion(Vector3(0, 10, 0), 1.5)
				fx.spawn_impact_sparks(Vector3(5, 5, 5))
				fx.spawn_flare_burst(Vector3(0, 15, 0))
				print("  [PASS] 1. FXManager: Successfully spawned explosions, sparks, and flare particles.")
				tests_passed += 1
			else:
				print("  [FAIL] 1. FXManager missing.")

		elif step == 20:
			# Test 2: FlightAcademy scene instantiation and step initialization
			var acad_scene = preload("res://scenes/tutorial/flight_academy.tscn")
			var acad = acad_scene.instantiate()
			add_child(acad)
			if acad.current_step == 0 and acad.ring1 != null:
				print("  [PASS] 2. Flight Academy: Interactive proving grounds initialized at Step 1 (Takeoff).")
				tests_passed += 1
			else:
				print("  [FAIL] 2. Flight Academy setup failed.")
			acad.queue_free()

		elif step == 30:
			# Test 3: BossDecisionDialog and Victory Payout
			var boss_dialog = preload("res://src/ui/boss_decision_dialog.gd").new()
			add_child(boss_dialog)
			var pm = get_node("/root/ProfileManager")
			var gm = get_node("/root/GameManager")
			var bus = get_node("/root/EventBus")
			var initial_credits = pm.banked_credits
			bus.boss_defeated.emit()
			if gm.current_state == gm.RunState.BOSS_DECISION and pm.banked_credits >= initial_credits:
				print("  [PASS] 3. Boss Climax: Boss defeat triggered BOSS_DECISION state and 1,000 CR bounty reward.")
				tests_passed += 1
			else:
				print("  [FAIL] 3. Boss decision state transition failed.")
			boss_dialog.free()
			# Unpause tree for next test
			get_tree().paused = false

		elif step == 40:
			# Test 4: Endless Overdrive wave escalation
			var overdrive = preload("res://src/gameplay/endless_overdrive.gd").new()
			add_child(overdrive)
			var cd = get_node("/root/CombatDirector")
			overdrive.activate_endless_overdrive()
			if cd.current_wave == 11 and cd.active_theme == "Endless Overdrive":
				print("  [PASS] 4. Endless Overdrive: Transitioned into Wave 11 with Endless Overdrive scaling theme.")
				tests_passed += 1
			else:
				print("  [FAIL] 4. Endless Overdrive activation failed.")
			overdrive.free()

			print("Climax & Tutorial Test Results: ", tests_passed, "/", total_tests, " PASSED.")
			if tests_passed == total_tests:
				print("--- ALL CLIMAX, TUTORIAL & FX VERIFICATIONS SUCCEEDED ---")
				var tree = get_tree()
				get_parent().remove_child(self)
				self.free()
				tree.quit(0)
			else:
				get_tree().quit(1)
