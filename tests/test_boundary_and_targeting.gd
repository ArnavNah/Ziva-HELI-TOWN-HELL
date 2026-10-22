extends SceneTree

const PlayableAreaScript = preload("res://src/world/playable_area.gd")

func _init():
	print("\n--- BEGIN BOUNDARY & TARGETING OVERLAY VERIFICATION ---")
	var runner = BoundaryTestRunner.new()
	root.add_child(runner)

class BoundaryTestRunner extends Node:
	var step: int = 0
	var tests_passed: int = 0
	var total_tests: int = 5

	var area_inst: Node3D = null
	var dummy_player: CharacterBody3D = null
	var heli: CharacterBody3D = null
	var hud_node: CanvasLayer = null
	var test_target: Node3D = null

	var warning_received: bool = false
	var warning_dir: Vector3 = Vector3.ZERO
	var edge_dist: float = 0.0

	func _ready():
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(_delta: float):
		step += 1

		if step == 5:
			# Test 1: PlayableArea Initialization & Hard Boundary Walls
			var playable_scene = load("res://scenes/environment/boundary/playable_area.tscn")
			area_inst = playable_scene.instantiate()
			add_child(area_inst)

			var hard_body = area_inst.get_node_or_null("HardBoundary") as StaticBody3D
			if hard_body != null and hard_body.collision_layer == 2 and hard_body.get_child_count() >= 4:
				print("  [PASS] 1. Playable Area & Hard Boundary: 4 collision walls on Layer 2 at +/-", GameConstants.BOUNDARY_HARD_RADIUS, "m.")
				tests_passed += 1
			else:
				print("  [FAIL] 1. HardBoundary setup failed.")

		elif step == 10:
			# Test 2: Boundary Warning Signal Logic
			var event_bus = get_node("/root/EventBus")
			event_bus.border_warning_changed.connect(func(is_warn: bool, r_dir: Vector3, dist: float):
				warning_received = is_warn
				warning_dir = r_dir
				edge_dist = dist
			)

			dummy_player = CharacterBody3D.new()
			dummy_player.name = "TestPlayer"
			add_child(dummy_player)
			area_inst.set("player_node", dummy_player)

			# Position dummy in warning zone (140m on Z axis)
			dummy_player.global_position = Vector3(0, 14, GameConstants.BOUNDARY_SAFE_RADIUS + 15.0)
			area_inst._process(0.016)

			if warning_received and warning_dir.z < -0.8 and edge_dist > 10.0:
				print("  [PASS] 2. Soft Warning Emission: Detected exit from the expanded safe zone and signaled inward return.")
				tests_passed += 1
			else:
				print("  [FAIL] 2. Soft warning emission failed: warn=%s dir=%s dist=%.1f" % [warning_received, warning_dir, edge_dist])

		elif step == 15:
			# Test 3: Helicopter Inward Steering & Clamp
			var heli_scene = load("res://scenes/player/player.tscn")
			heli = heli_scene.instantiate()
			add_child(heli)
			heli.global_position = Vector3(0, 14, GameConstants.BOUNDARY_SAFE_RADIUS + 10.0)
			heli.velocity = Vector3(0, 0, 30)

			for i in range(10):
				heli._process_flight_physics(0.016)

			var resisted = (heli.velocity.z < 30.0)

			# Test clamp past 155m
			heli.global_position = Vector3(0, 14, GameConstants.BOUNDARY_HARD_RADIUS + 5.0)
			heli._process_flight_physics(0.016)
			var clamped = (heli.global_position.z <= GameConstants.BOUNDARY_HARD_RADIUS + 0.05)

			if resisted and clamped:
				print("  [PASS] 3. Airframe Dynamics & Hard Clamp: Inward resistance and expanded perimeter clamp verified.")
				tests_passed += 1
			else:
				print("  [FAIL] 3. Airframe dynamics/clamp failed: resisted=%s clamped=%s (z=%.2f)" % [resisted, clamped, heli.global_position.z])

		elif step == 20:
			# Test 4: HUD Boundary Banner & Targeting Overlay Instantiation
			var hud_script = load("res://src/ui/hud.gd")
			hud_node = CanvasLayer.new()
			hud_node.set_script(hud_script)
			hud_node.player_helicopter = heli
			add_child(hud_node)

			var has_banner = (hud_node.get_node_or_null("BorderWarningBanner") != null)
			var has_overlay = (hud_node.get_node_or_null("TargetingOverlay") != null)

			if has_banner and has_overlay:
				print("  [PASS] 4. HUD Overlays: BorderWarningBanner and TargetingOverlay active in CanvasLayer.")
				tests_passed += 1
			else:
				print("  [FAIL] 4. HUD overlay creation failed.")

		elif step == 25:
			# Test 5: Target Lock Authority & Salvo Locks
			test_target = Node3D.new()
			test_target.name = "TestEnemyTank"
			test_target.set("variant_id", "flak_tank")
			add_child(test_target)
			test_target.global_position = Vector3(0, 0, -25)

			if heli.turret:
				heli.turret.current_target_node = test_target

			var salvo = heli.get_node_or_null("Salvo")
			if salvo:
				salvo.current_locks.append(test_target)
				salvo.current_locks.append(test_target)

			var count_ok = (salvo != null and salvo._count_locks_for_target(test_target) == 2)
			var turret_ok = (heli.turret != null and heli.turret.current_target_node == test_target)

			if count_ok and turret_ok:
				print("  [PASS] 5. Target Lock Authority: Chin-turret target and 2 salvo missile locks registered on hostile.")
				tests_passed += 1
			else:
				print("  [FAIL] 5. Target lock authority failed.")

		elif step == 30:
			if area_inst: area_inst.queue_free()
			if dummy_player: dummy_player.queue_free()
			if heli: heli.queue_free()
			if hud_node: hud_node.queue_free()
			if test_target: test_target.queue_free()

			print("SUMMARY: %d/%d PASSED." % [tests_passed, total_tests])
			if tests_passed == total_tests:
				print("--- ALL BOUNDARY & TARGETING OVERLAY TESTS SUCCEEDED ---\n")
				get_tree().quit(0)
			else:
				print("--- SOME TESTS FAILED ---\n")
				get_tree().quit(1)
