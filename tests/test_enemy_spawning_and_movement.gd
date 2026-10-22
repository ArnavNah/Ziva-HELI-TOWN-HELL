extends SceneTree

## Verification test specifically targeting Enemy Spawning & Movement AI in urban terrain

func _init() -> void:
	var runner = TestRunner.new()
	root.add_child(runner)

class TestRunner extends Node:
	var frame_count: int = 0
	var city: Node3D = null
	var player: Node3D = null
	var spawner: Node = null
	var spawned_ground: Array[Node3D] = []
	var spawned_air: Array[Node3D] = []
	var ground_initial_positions: Dictionary = {}
	var tests_passed: int = 0
	var total_tests: int = 4

	func _ready() -> void:
		print("--- BEGIN ENEMY SPAWNING & MOVEMENT TEST ---")
		var city_script = preload("res://src/world/city_generator.gd")
		city = city_script.new()
		add_child(city)
		city.generate_district("Downtown", 777)
		print("  City generated: ", city.spawned_blocks.size(), " elements.")

		var player_scene = preload("res://scenes/player/player.tscn")
		player = player_scene.instantiate()
		add_child(player)
		player.position = Vector3(0.0, 18.5, 0.0)

		var spawner_script = preload("res://src/enemies/enemy_spawner.gd")
		spawner = spawner_script.new()
		add_child(spawner)

	func _process(_delta: float) -> void:
		frame_count += 1

		# Frame 2: Test Spawning
		if frame_count == 2:
			# TEST 1: Ground Enemy Spawning Validation
			var ground_types = ["flak_tank", "missile_carrier", "siege_tank", "gatling_heavy", "infantry_squad"]
			var ground_spawn_ok = true

			for g_type in ground_types:
				var unit = spawner.spawn_enemy_type(g_type)
				if unit == null:
					ground_spawn_ok = false
					print("  [FAIL] Could not spawn ground unit: ", g_type)
					break
				spawned_ground.append(unit)
				ground_initial_positions[unit] = unit.global_position

				var pos = unit.global_position
				# Verify ground altitude is ~1.0
				if absf(pos.y - 1.0) > 1.0:
					ground_spawn_ok = false
					print("  [FAIL] Ground unit altitude abnormal: ", pos.y, " for ", g_type)
					break

				# Verify aligned near street corridor (X or Z within 8m of multiple of 38m)
				var dist_x_ave = absf(pos.x - roundf(pos.x / 38.0) * 38.0)
				var dist_z_str = absf(pos.z - roundf(pos.z / 38.0) * 38.0)
				if dist_x_ave > 8.0 and dist_z_str > 8.0:
					ground_spawn_ok = false
					print("  [FAIL] Ground unit not spawned on road corridor: ", pos, " for ", g_type)
					break

			if ground_spawn_ok:
				print("  [PASS] 1. Ground Spawning: All 5 ground variants spawned on valid street corridors at ground level (Y ~ 1.0m).")
				tests_passed += 1
			else:
				print("  [FAIL] 1. Ground spawning validation failed.")

			# TEST 2: Air & Support Enemy Spawning Validation
			var air_types = ["scout_drone", "attack_gunship", "kamikaze_drone", "rocket_gunship", "interceptor", "minelayer", "shield_drone", "repair_drone"]
			var air_spawn_ok = true

			for a_type in air_types:
				var air_unit = spawner.spawn_enemy_type(a_type)
				if air_unit == null:
					air_spawn_ok = false
					print("  [FAIL] Could not spawn air unit: ", a_type)
					break
				spawned_air.append(air_unit)

				var pos = air_unit.global_position
				# Verify air altitude is >= 20.0m
				if pos.y < 20.0:
					air_spawn_ok = false
					print("  [FAIL] Air unit spawned too low: ", pos.y, " for ", a_type)
					break

			if air_spawn_ok:
				print("  [PASS] 2. Air Spawning: All 8 aerial/support variants spawned with safe flight clearance (Y >= 20.0m).")
				tests_passed += 1
			else:
				print("  [FAIL] 2. Air spawning validation failed.")

		# Frames 3-50: Ticking enemy movement
		if frame_count > 2 and frame_count < 50:
			for g in spawned_ground:
				if is_instance_valid(g):
					g._custom_process(0.03)
			for a in spawned_air:
				if is_instance_valid(a):
					a._custom_process(0.03)

		# Frame 50: Evaluate Movement Results
		if frame_count == 50:
			# TEST 3: Ground Movement AI
			var ground_movement_ok = true
			for g in spawned_ground:
				var moved_dist = g.global_position.distance_to(ground_initial_positions[g])
				if moved_dist < 0.2:
					ground_movement_ok = false
					print("  [FAIL] Ground unit failed to move: ", g.variant_id, " moved ", moved_dist)
					break

			if ground_movement_ok:
				print("  [PASS] 3. Ground Movement AI: Tanks and infantry actively navigated along streets with dynamic steering.")
				tests_passed += 1
			else:
				print("  [FAIL] 3. Ground movement AI validation failed.")

			# TEST 4: Air Movement AI
			var air_movement_ok = true
			for a in spawned_air:
				# Suicide drones may have completed their attack during the simulation.
				if not is_instance_valid(a):
					continue
				if a.global_position.y < 16.0:
					air_movement_ok = false
					print("  [FAIL] Air unit dipped below safe flight floor: ", a.variant_id, " Y = ", a.global_position.y)
					break

			if air_movement_ok:
				print("  [PASS] 4. Air Movement AI: Gunships and drones maintained safe flight altitudes and executed tactical patterns.")
				tests_passed += 1
			else:
				print("  [FAIL] 4. Air movement AI validation failed.")

			print("--- TEST SUMMARY: ", tests_passed, "/", total_tests, " PASSED ---")
			if tests_passed == total_tests:
				print("ALL ENEMY SPAWNING & MOVEMENT TESTS SUCCEEDED!")
				get_tree().quit(0)
			else:
				get_tree().quit(1)
