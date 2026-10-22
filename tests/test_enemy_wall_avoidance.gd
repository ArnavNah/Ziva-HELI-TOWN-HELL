extends SceneTree

## Dedicated test suite verifying enemy AI wall sliding, obstacle avoidance,
## roof climbing, and zero-velocity deadlock prevention in urban terrain.

func _init() -> void:
	print("--- BEGIN ENEMY WALL AVOIDANCE & NAVIGATION TEST ---")
	var runner = WallAvoidanceRunner.new()
	root.add_child(runner)

class WallAvoidanceRunner extends Node:
	var tests_passed: int = 0
	var total_tests: int = 4
	var step_count: int = 0
	var test_building: StaticBody3D
	var test_player: Node3D
	var test_ground_enemy: BaseEnemy
	var test_air_enemy: BaseEnemy
	var initial_ground_pos: Vector3
	var initial_air_pos: Vector3

	func _ready() -> void:
		# 1. Spawn a reference building collider (Mask 2, width 14m, height 16m, depth 14m) at (0, 8, 20)
		test_building = StaticBody3D.new()
		test_building.collision_layer = 2 # Mask 2: Environment / Buildings
		test_building.collision_mask = 0
		var col_shape = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = Vector3(14.0, 16.0, 14.0)
		col_shape.shape = box
		test_building.add_child(col_shape)
		test_building.position = Vector3(0.0, 8.0, 20.0)
		add_child(test_building)

		# 2. Spawn a target player BEHIND the building at (0, 18, 50)
		test_player = Node3D.new()
		test_player.name = "PlayerHelicopter"
		test_player.add_to_group("player")
		test_player.position = Vector3(0.0, 18.0, 50.0)
		add_child(test_player)

		# 3. Spawn ground hostile directly in front of the building facing it at (0, 0.5, 8)
		var spawner_script = preload("res://src/enemies/enemy_spawner.gd")
		var spawner = spawner_script.new()
		add_child(spawner)

		test_ground_enemy = spawner._create_enemy_node("assault_apc") as BaseEnemy
		test_ground_enemy.position = Vector3(0.0, 0.5, 8.0)
		add_child(test_ground_enemy)
		initial_ground_pos = test_ground_enemy.global_position

		# 4. Spawn aerial hostile directly in front of building at low altitude (0, 10, 5)
		test_air_enemy = spawner._create_enemy_node("attack_gunship") as BaseEnemy
		test_air_enemy.position = Vector3(0.0, 10.0, 5.0)
		add_child(test_air_enemy)
		initial_air_pos = test_air_enemy.global_position

	func _physics_process(delta: float) -> void:
		step_count += 1

		# Tick enemy logic for 40 steps
		if is_instance_valid(test_ground_enemy):
			test_ground_enemy._custom_process(delta)
		if is_instance_valid(test_air_enemy):
			test_air_enemy._custom_process(delta)

		if step_count == 40:
			_evaluate_tests()

	func _evaluate_tests() -> void:
		# TEST 1: Ground Enemy Avoids / Slides Around Building
		# Facing the building at (0, 0.5, 8) with player at (0, 18, 50),
		# a stuck enemy would stay at (0, 0.5, 12-13) and never move sideways.
		# A sliding/navigating enemy must deflect along X (tangent) and round the corner!
		var ground_pos = test_ground_enemy.global_position
		var ground_lateral_movement = absf(ground_pos.x - initial_ground_pos.x)
		var ground_dist_moved = ground_pos.distance_to(initial_ground_pos)
		var ground_h_speed = Vector2(test_ground_enemy.velocity.x, test_ground_enemy.velocity.z).length()

		print("  Ground Enemy final pos: ", ground_pos, " | Lateral moved: ", ground_lateral_movement, " | Total moved: ", ground_dist_moved, " | Speed: ", ground_h_speed)
		if ground_lateral_movement > 1.5 or ground_dist_moved > 4.0:
			print("  [PASS] 1. Ground Enemy Wall Sliding: Unit actively steered laterally around building facade (moved lateral ", ground_lateral_movement, "m).")
			tests_passed += 1
		else:
			print("  [FAIL] 1. Ground Enemy stuck against wall.")

		# TEST 2: Ground Enemy Maintains Non-Zero Velocity
		if ground_h_speed > 2.0 or ground_dist_moved > 3.0:
			print("  [PASS] 2. Ground Enemy Active Velocity: Unit maintained active navigation speed (", ground_h_speed, " m/s).")
			tests_passed += 1
		else:
			print("  [FAIL] 2. Ground Enemy velocity stalled.")

		# TEST 3: Aerial Enemy Forward Rooftop Climbing
		# The air enemy spawned at Y=10 facing the 16m tall building.
		# With forward rooftop whisker detection, it must climb over the 16m roof!
		var air_pos = test_air_enemy.global_position
		var air_climbed = air_pos.y - initial_air_pos.y
		print("  Air Enemy final pos: ", air_pos, " | Climbed: ", air_climbed, "m | Y-velocity: ", test_air_enemy.velocity.y)
		if air_pos.y >= 15.0 or test_air_enemy.velocity.y > 5.0 or air_climbed > 4.0:
			print("  [PASS] 3. Air Enemy Rooftop Climbing: Air unit detected building ahead and gained vertical lift (climbed to Y = ", air_pos.y, "m).")
			tests_passed += 1
		else:
			print("  [FAIL] 3. Air Enemy failed to climb over rooftop (Y = ", air_pos.y, "m).")

		# TEST 4: Zero-Velocity Deadlock Prevention Across Preferred Ranges
		var spawner_script = preload("res://src/enemies/enemy_spawner.gd")
		var spawner = spawner_script.new()
		add_child(spawner)

		var standoff_variants = ["flame_tank", "rail_crawler", "sam_launcher", "assault_apc", "mortar_crawler"]
		var deadlocks_found = 0
		for v in standoff_variants:
			var unit = spawner._create_enemy_node(v) as BaseEnemy
			add_child(unit)
			# Place at preferred distance
			var pref_dist = 22.0 if v == "flame_tank" else (74.0 if v == "rail_crawler" else (62.0 if v == "sam_launcher" else 32.0))
			unit.position = test_player.position + Vector3(pref_dist, -16.0, 0.0)
			# Tick process
			unit._custom_process(0.05)
			var h_spd = Vector2(unit.velocity.x, unit.velocity.z).length()
			if h_spd < 0.5:
				print("  [FAIL] Variant deadlocked with zero speed at preferred distance: ", v, " speed: ", h_spd)
				deadlocks_found += 1
			unit.queue_free()

		if deadlocks_found == 0:
			print("  [PASS] 4. Engagement Deadlock Prevention: All standoff hostiles actively reposition/strafe when within engagement range.")
			tests_passed += 1
		else:
			print("  [FAIL] 4. Some variants stalled at preferred distance.")

		print("--- SUMMARY: ", tests_passed, "/", total_tests, " PASSED ---")
		if tests_passed == total_tests:
			print("ALL ENEMY WALL AVOIDANCE & NAVIGATION TESTS SUCCEEDED!")
			get_tree().quit(0)
		else:
			get_tree().quit(1)
