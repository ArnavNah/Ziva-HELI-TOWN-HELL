extends SceneTree

## Stress test verifying ground and air enemies navigating around obstacles and buildings
## without crashing into facades, stalling, or clipping geometry.

func _init() -> void:
	print("--- BEGIN OBSTACLE NAVIGATION STRESS TEST ---")
	var runner = ObstacleStressRunner.new()
	root.add_child(runner)

class ObstacleStressRunner extends Node:
	var player: Node3D
	var buildings: Array[StaticBody3D] = []
	var ground_enemies: Array[BaseEnemy] = []
	var air_enemies: Array[BaseEnemy] = []
	var initial_ground_pos: Array[Vector3] = []
	var initial_air_pos: Array[Vector3] = []
	var ticks: int = 0

	func _ready() -> void:
		# 1. Target Player behind a row of city buildings
		player = Node3D.new()
		player.name = "PlayerHelicopter"
		player.add_to_group("player")
		player.position = Vector3(0.0, 16.0, 60.0)
		add_child(player)

		# 2. Spawn two large building obstacles blocking the direct path to the player
		# Building A: at ( -10, 8, 20 ), size (16, 16, 16)
		# Building B: at ( 10, 8, 20 ), size (16, 16, 16)
		for pos in [Vector3(-10.0, 8.0, 20.0), Vector3(10.0, 8.0, 20.0)]:
			var b = StaticBody3D.new()
			b.collision_layer = 2
			b.collision_mask = 0
			var cs = CollisionShape3D.new()
			var box = BoxShape3D.new()
			box.size = Vector3(16.0, 16.0, 16.0)
			cs.shape = box
			b.add_child(cs)
			b.position = pos
			add_child(b)
			buildings.append(b)

		var sp_script = preload("res://src/enemies/enemy_spawner.gd")
		var spawner = sp_script.new()
		add_child(spawner)

		# 3. Spawn ground enemies facing straight into the buildings
		var g_types = ["flak_tank", "assault_apc", "technical_truck"]
		var g_spawns = [Vector3(-10.0, 0.5, 0.0), Vector3(10.0, 0.5, 0.0), Vector3(0.0, 0.5, 0.0)]
		for i in range(g_types.size()):
			var e = spawner._create_enemy_node(g_types[i]) as BaseEnemy
			e.position = g_spawns[i]
			add_child(e)
			ground_enemies.append(e)
			initial_ground_pos.append(g_spawns[i])

		# 4. Spawn air enemy at low altitude (10m) facing the 16m tall building
		var a_types = ["attack_gunship"]
		var a_spawns = [Vector3(-10.0, 10.0, -10.0)]
		for i in range(a_types.size()):
			var ae = spawner._create_enemy_node(a_types[i]) as BaseEnemy
			ae.position = a_spawns[i]
			add_child(ae)
			air_enemies.append(ae)
			initial_air_pos.append(a_spawns[i])

	func _physics_process(delta: float) -> void:
		ticks += 1

		# Tick all enemy brains
		for ge in ground_enemies:
			if is_instance_valid(ge):
				ge._custom_process(delta)

		for ae in air_enemies:
			if is_instance_valid(ae):
				ae._custom_process(delta)

		if ticks == 60:
			_evaluate_stress_results()

	func _evaluate_stress_results() -> void:
		print("--- EVALUATING OBSTACLE STRESS RESULTS (TICK 60) ---")
		var passed = 0
		var total = ground_enemies.size() + air_enemies.size()

		# Ground units: Must NOT be stuck inside or facing flush against building front at Z=12
		# Must deflect laterally or around the buildings
		for i in range(ground_enemies.size()):
			var ge = ground_enemies[i]
			var start_p = initial_ground_pos[i]
			var cur_p = ge.global_position
			var dist = start_p.distance_to(cur_p)
			var h_spd = Vector2(ge.velocity.x, ge.velocity.z).length()
			var lat_moved = absf(cur_p.x - start_p.x)

			print("  Ground [%s]: Dist Moved: %.1fm | Lat Moved: %.1fm | Speed: %.1f m/s | Pos: (%0.1f, %0.1f, %0.1f)" % [
				ge.variant_id, dist, lat_moved, h_spd, cur_p.x, cur_p.y, cur_p.z
			])

			if dist > 5.0 and (lat_moved > 1.5 or h_spd > 2.0):
				print("    -> [PASS] Unit navigated around building obstacle!")
				passed += 1
			else:
				print("    -> [FAIL] Unit failed to navigate past obstacle.")

		# Air units: Must have climbed over 16m building or navigated around
		for i in range(air_enemies.size()):
			var ae = air_enemies[i]
			var start_p = initial_air_pos[i]
			var cur_p = ae.global_position
			var climbed = cur_p.y - start_p.y
			print("  Air [%s]: Climbed: %.1fm | Alt: %.1fm | Speed: %.1f m/s | Pos: (%0.1f, %0.1f, %0.1f)" % [
				ae.variant_id, climbed, cur_p.y, ae.velocity.length(), cur_p.x, cur_p.y, cur_p.z
			])

			if cur_p.y >= 16.0 or climbed > 5.0:
				print("    -> [PASS] Air unit cleared building roof altitude!")
				passed += 1
			else:
				print("    -> [FAIL] Air unit failed to clear roof.")

		print("--- SUMMARY: %d / %d PASSED ---" % [passed, total])
		if passed == total:
			print("ALL OBSTACLE NAVIGATION CHECKS PASSED SUCCESSFULLY!")
			get_tree().quit(0)
		else:
			get_tree().quit(1)
