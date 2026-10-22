extends SceneTree

## Dedicated test suite verifying Enemy Combat Intelligence:
## 1. Predictive lead interception math across projectile speeds.
## 2. Stationary target lead fallback.
## 3. Smooth turret tracking and angular alignment verification.
## 4. Multi-unit tactical flanking sector distribution.
## 5. Aerial reactive jinking when targeted by player.
## 6. Heavy gunship boss predictive bracketing volleys.

func _init() -> void:
	print("--- BEGIN ENEMY COMBAT INTELLIGENCE TEST SUITE ---")
	var runner = CombatIntelligenceRunner.new()
	root.add_child(runner)

class CombatIntelligenceRunner extends Node:
	var passed: int = 0
	var total: int = 6
	var spawner: EnemySpawner

	func _ready() -> void:
		var spawner_script = preload("res://src/enemies/enemy_spawner.gd")
		spawner = spawner_script.new()
		add_child(spawner)

		_test_predictive_lead_intercept()
		_test_stationary_target_lead()
		_test_turret_smooth_tracking()
		_test_flanking_sector_distribution()
		_test_air_reactive_jinking()
		_test_boss_predictive_volleys()
		_conclude()

	func _test_predictive_lead_intercept() -> void:
		var test_tank = spawner._create_enemy_node("siege_tank") as BaseEnemy
		add_child(test_tank)
		test_tank.global_position = Vector3(0.0, 1.0, 0.0)

		# Moving target: player flying eastward (+X) at 40.0 m/s at 100m distance along Z
		var player_node = CharacterBody3D.new()
		add_child(player_node)
		player_node.global_position = Vector3(0.0, 20.0, 100.0)
		player_node.velocity = Vector3(40.0, 0.0, 0.0)

		var muzzle: Vector3 = test_tank.global_position + Vector3(0.0, 1.5, 0.0)
		var proj_speed := 110.0 # Siege tank shell speed
		var predicted := test_tank.get_predicted_target_position(muzzle, player_node, proj_speed, 1.0, 0.0)

		# At ~100m and 110m/s speed, flight time is ~0.95s, so X should lead by ~38m (+-5m)
		print("  Predictive Lead Test (Target Pos: ", player_node.global_position, " | Predicted: ", predicted, ")")
		if predicted.x >= 30.0 and predicted.x <= 48.0 and absf(predicted.z - 100.0) < 5.0:
			print("  [PASS] 1. Predictive Lead Intercept: Shell accurately leads moving player flight vector (+", predicted.x, "m on X).")
			passed += 1
		else:
			print("  [FAIL] 1. Predictive Lead Intercept mismatch: X = ", predicted.x)

		test_tank.queue_free()
		player_node.queue_free()

	func _test_stationary_target_lead() -> void:
		var test_tank = spawner._create_enemy_node("flak_tank") as BaseEnemy
		add_child(test_tank)
		test_tank.global_position = Vector3(10.0, 1.0, 10.0)

		var player_node = CharacterBody3D.new()
		add_child(player_node)
		player_node.global_position = Vector3(50.0, 15.0, 50.0)
		player_node.velocity = Vector3.ZERO # Stationary hover

		var muzzle: Vector3 = test_tank.global_position + Vector3(0.0, 1.5, 0.0)
		var predicted := test_tank.get_predicted_target_position(muzzle, player_node, 140.0, 0.90, 0.0)

		var diff = predicted.distance_to(player_node.global_position)
		if diff < 0.1:
			print("  [PASS] 2. Stationary Target Handling: Zero velocity leads accurately to current target position (diff: ", diff, "m).")
			passed += 1
		else:
			print("  [FAIL] 2. Stationary target lead produced offset: diff = ", diff)

		test_tank.queue_free()
		player_node.queue_free()

	func _test_turret_smooth_tracking() -> void:
		var test_tank = spawner._create_enemy_node("flak_tank") as BaseEnemy
		add_child(test_tank)
		test_tank.global_position = Vector3.ZERO
		test_tank.rotation.y = 0.0

		var turret = test_tank.get_node_or_null("Turret") as Node3D
		if not turret:
			turret = Node3D.new()
			turret.name = "Turret"
			test_tank.add_child(turret)

		# Target is 90 degrees to the right (+X)
		var target_pos = Vector3(50.0, 0.0, 0.0)

		# One small frame tick: turret should advance towards target angle smoothly, not snap instantly
		var aligned_step1 = test_tank.track_turret(turret, target_pos, 0.016, 90.0, 15.0)
		var yaw_after_1_frame = rad_to_deg(absf(turret.rotation.y))

		# Multiple ticks: turret should eventually align within tolerance
		var aligned_step_n = false
		for i in range(120):
			aligned_step_n = test_tank.track_turret(turret, target_pos, 0.016, 120.0, 15.0)
			if aligned_step_n:
				break

		if yaw_after_1_frame < 80.0 and aligned_step_n:
			print("  [PASS] 3. Smooth Turret Tracking: Turret rotates with angular inertia and achieves alignment (frame 1 turn: ", yaw_after_1_frame, " deg, final aligned: ", aligned_step_n, ").")
			passed += 1
		else:
			print("  [FAIL] 3. Turret tracking error: frame 1 turn = ", yaw_after_1_frame, " deg, aligned = ", aligned_step_n)

		test_tank.queue_free()

	func _test_flanking_sector_distribution() -> void:
		var angles: Array[float] = []

		# Spawn 5 distinct tanks and record their flank offsets
		for i in range(5):
			var tank = spawner._create_enemy_node("flak_tank") as BaseEnemy
			add_child(tank)
			angles.append(tank.get_flank_angle_offset())
			tank.queue_free()

		# Check that we have at least 2 distinct tactical flank angles (e.g. frontal, left, right)
		var distinct_angles: Dictionary = {}
		for a in angles:
			distinct_angles[roundf(a * 100.0)] = true

		if distinct_angles.size() >= 2:
			print("  [PASS] 4. Multi-Unit Tactical Flanking: Enemies distribute across distinct approach sectors (", distinct_angles.size(), " distinct tactical quadrants).")
			passed += 1
		else:
			print("  [FAIL] 4. Insufficient flank angle variety: ", angles)

	func _test_air_reactive_jinking() -> void:
		var player = CharacterBody3D.new()
		player.name = "PlayerHelicopter"
		player.add_to_group("player")
		add_child(player)
		player.global_position = Vector3(0.0, 20.0, 0.0)
		# Player looking straight down +Z
		player.rotation.y = PI

		var gunship = spawner._create_enemy_node("attack_gunship") as AttackGunship
		add_child(gunship)
		gunship.global_position = Vector3(0.0, 22.0, 35.0) # Directly in front of player

		# Put gunship into ATTACK state
		gunship.current_state = BaseEnemy.EnemyState.ATTACK
		gunship.target_player = player
		gunship._custom_process(0.05)

		# Check lateral velocity: with reactive jinking, gunship dodges off-center laterally (|vx| > 1.0)
		var lateral_speed = absf(gunship.velocity.x)
		print("  Gunship Reactive Evasion (Lateral velocity: ", gunship.velocity.x, " m/s)")
		if lateral_speed > 1.5:
			print("  [PASS] 5. Aerial Reactive Jinking: Hostile aircraft detects player aim and executes lateral evasion (", lateral_speed, " m/s).")
			passed += 1
		else:
			print("  [FAIL] 5. Aerial reactive jinking did not trigger lateral dodge: ", lateral_speed)

		player.queue_free()
		gunship.queue_free()

	func _test_boss_predictive_volleys() -> void:
		var boss_script = preload("res://src/enemies/boss/heavy_gunship_boss.gd")
		var boss = boss_script.new()
		add_child(boss)
		boss.global_position = Vector3(0.0, 30.0, 0.0)

		var player = CharacterBody3D.new()
		player.name = "PlayerHelicopter"
		player.add_to_group("player")
		add_child(player)
		player.global_position = Vector3(0.0, 24.0, 60.0)
		player.velocity = Vector3(36.0, 0.0, 0.0) # Player flying east at 36 m/s

		boss.target_player = player

		var aim_lead = boss._predict_lead_point(boss.global_position, player, 115.0)
		print("  Boss Lead Calculation (Player Pos: ", player.global_position, " | Boss Lead Aim: ", aim_lead, ")")

		# With 60m distance and 115m/s rocket speed, t ~ 0.52s, player moves ~18.8m east (+X)
		if aim_lead.x >= 12.0 and aim_lead.x <= 25.0:
			print("  [PASS] 6. Heavy Gunship Boss Predictive Volleys: Boss computes lead intercept vector (+", aim_lead.x, "m on X).")
			passed += 1
		else:
			print("  [FAIL] 6. Boss lead calculation mismatch: aim_lead.x = ", aim_lead.x)

		boss.queue_free()
		player.queue_free()

	func _conclude() -> void:
		print("--- SUMMARY: ", passed, "/", total, " PASSED ---")
		if passed == total:
			print("ALL ENEMY COMBAT INTELLIGENCE TESTS SUCCEEDED!")
			get_tree().quit(0)
		else:
			print("SOME TESTS FAILED.")
			get_tree().quit(1)
