extends SceneTree

## Dedicated test suite verifying ground enemy unstick mechanics,
## corner / wedge reverse recovery, off-road lot return, and outer grid pathfinding.

const UrbanPathfinder = preload("res://src/world/urban_pathfinder.gd")

func _init() -> void:
	print("--- BEGIN GROUND UNSTICK & WEDGING VERIFICATION TEST ---")
	var runner = UnstickRunner.new()
	root.add_child(runner)

class UnstickRunner extends Node:
	var tests_passed: int = 0
	var total_tests: int = 4
	var step_count: int = 0

	var corner_tank: BaseEnemy
	var initial_corner_pos: Vector3
	var offroad_apc: BaseEnemy
	var initial_offroad_pos: Vector3

	var corner_wall_n: StaticBody3D
	var corner_wall_e: StaticBody3D
	var test_player: Node3D

	func _ready() -> void:
		# 1. Target Player at (-40, 16, -40)
		test_player = Node3D.new()
		test_player.name = "PlayerHelicopter"
		test_player.add_to_group("player")
		test_player.position = Vector3(-40.0, 16.0, -40.0)
		add_child(test_player)

		# 2. Build tight inside L-corner
		# Wall North at Z = 15 (width 30, thickness 4)
		corner_wall_n = StaticBody3D.new()
		corner_wall_n.collision_layer = 2
		corner_wall_n.collision_mask = 0
		var csn = CollisionShape3D.new()
		var bn = BoxShape3D.new()
		bn.size = Vector3(30.0, 8.0, 4.0)
		csn.shape = bn
		corner_wall_n.add_child(csn)
		corner_wall_n.position = Vector3(0.0, 4.0, 15.0)
		add_child(corner_wall_n)

		# Wall East at X = 15 (depth 30, thickness 4)
		corner_wall_e = StaticBody3D.new()
		corner_wall_e.collision_layer = 2
		corner_wall_e.collision_mask = 0
		var cse = CollisionShape3D.new()
		var be = BoxShape3D.new()
		be.size = Vector3(4.0, 8.0, 30.0)
		cse.shape = be
		corner_wall_e.add_child(cse)
		corner_wall_e.position = Vector3(15.0, 4.0, 0.0)
		add_child(corner_wall_e)

		var spawner_script = preload("res://src/enemies/enemy_spawner.gd")
		var spawner = spawner_script.new()
		add_child(spawner)

		# 3. Spawn heavy tank wedged inside the corner at (12.0, 0.5, 12.0)
		# Facing directly into the corner vertex (+X, +Z)
		corner_tank = spawner._create_enemy_node("siege_tank") as BaseEnemy
		corner_tank.position = Vector3(12.0, 0.5, 12.0)
		corner_tank.rotation.y = atan2(-1.0, -1.0) # Pointing into (+X, +Z) corner
		add_child(corner_tank)
		initial_corner_pos = corner_tank.global_position

		# 4. Spawn off-road APC in the center of an off-road lot at (19.0, 0.5, 19.0)
		offroad_apc = spawner._create_enemy_node("assault_apc") as BaseEnemy
		offroad_apc.position = Vector3(19.0, 0.5, 19.0)
		add_child(offroad_apc)
		initial_offroad_pos = offroad_apc.global_position

	func _physics_process(delta: float) -> void:
		step_count += 1

		if is_instance_valid(corner_tank):
			corner_tank._custom_process(delta)

		if is_instance_valid(offroad_apc):
			offroad_apc._custom_process(delta)

		if step_count == 70:
			_evaluate_all_tests()

	func _evaluate_all_tests() -> void:
		print("--- EVALUATING UNSTICK & WEDGING RESULTS (STEP 70) ---")

		# TEST 1: Corner / Wedge Escape
		var corner_p = corner_tank.global_position
		var corner_dist = initial_corner_pos.distance_to(corner_p)
		var corner_speed = Vector2(corner_tank.velocity.x, corner_tank.velocity.z).length()
		print("  Test 1: Corner Tank: Initial: %s | Final: %s | Dist: %.2fm | Speed: %.1f m/s" % [
			str(initial_corner_pos), str(corner_p), corner_dist, corner_speed
		])
		# The tank was wedged at (12, 12) touching walls at X=13 and Z=13.
		# It must back up away from the corner into open space (X < 12 and Z < 12)
		if corner_dist > 3.0 and (corner_p.x < 11.5 or corner_p.z < 11.5):
			print("  [PASS] 1. Corner / Wedge Escape: Tank engaged unstick reverse, backed away from corner pocket, and gained clearance.")
			tests_passed += 1
		else:
			print("  [FAIL] 1. Corner / Wedge Escape: Tank stayed wedged in corner.")

		# TEST 2: Off-road Lot Return
		var offroad_p = offroad_apc.global_position
		var road_dist_initial = UrbanPathfinder.distance_to_nearest_road(initial_offroad_pos)
		var road_dist_final = UrbanPathfinder.distance_to_nearest_road(offroad_p)
		print("  Test 2: Off-road APC: Initial Road Dist: %.2fm | Final Road Dist: %.2fm | Final Pos: %s" % [
			road_dist_initial, road_dist_final, str(offroad_p)
		])
		if road_dist_final < road_dist_initial and road_dist_final < 6.0:
			print("  [PASS] 2. Off-Road Lot Return: Vehicle prioritized and navigated directly back toward street corridor (road dist reduced to %.2fm)." % road_dist_final)
			tests_passed += 1
		else:
			print("  [FAIL] 2. Off-Road Lot Return: Vehicle failed to steer towards street network.")

		# TEST 3: Displacement Watchdog
		# Verifies that corner_tank's spatial displacement watchdog properly reset after recovery
		print("  Test 3: Spatial Watchdog: Phase = %d | Spatial Timer = %.2f" % [
			corner_tank.stuck_recovery_phase, corner_tank.spatial_stuck_timer
		])
		if corner_tank.spatial_stuck_timer < 0.38 and corner_speed > 1.0:
			print("  [PASS] 3. Displacement Watchdog: Unit active and moving with healthy watchdog state.")
			tests_passed += 1
		else:
			print("  [FAIL] 3. Displacement Watchdog in stalled state.")

		# TEST 4: Outer Grid (228m) Street Pathfinding
		var p_start = Vector3(228.0, 0.5, 152.0)
		var p_goal = Vector3(0.0, 0.5, 0.0)
		var outer_path = UrbanPathfinder.find_street_path(p_start, p_goal)
		print("  Test 4: Outer Grid Pathfinding: Start %s -> Goal %s | Waypoints: %d" % [
			str(p_start), str(p_goal), outer_path.size()
		])
		if outer_path.size() > 10 and outer_path[outer_path.size() - 1].distance_to(p_goal) < 2.0:
			print("  [PASS] 4. Outer Grid Pathfinding: Full street navigation coverage across outer 16x16 district.")
			tests_passed += 1
		else:
			print("  [FAIL] 4. Outer Grid Pathfinding incomplete.")

		print("--- SUMMARY: %d / %d PASSED ---" % [tests_passed, total_tests])
		if tests_passed == total_tests:
			print("ALL GROUND UNSTICK & WEDGING TESTS SUCCEEDED!")
			get_tree().quit(0)
		else:
			get_tree().quit(1)
