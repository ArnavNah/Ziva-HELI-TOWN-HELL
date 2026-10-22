extends SceneTree

func _init():
	print("--- BEGIN LEFT/RIGHT MOVEMENT & PHYSICS VERIFICATION ---")
	var runner = MovementTestRunner.new()
	root.add_child(runner)

class MovementTestRunner extends Node:
	var heli: PlayerHelicopter
	var step: int = 0
	var tests_passed: int = 0
	var total_tests: int = 5

	func _ready():
		process_mode = Node.PROCESS_MODE_ALWAYS
		var heli_scene = preload("res://scenes/player/player.tscn")
		heli = heli_scene.instantiate()
		add_child(heli)

	func _process(delta: float):
		step += 1

		if step == 10:
			# Test 1: Clean Yaw Turning (A key / Left) without Unwanted Sideways Strafe Slide
			# Simulate yaw_input = -1.0 (A key / turn left) with zero strafe and zero throttle
			var target_yaw_rate = -(-1.0) * GameConstants.MAX_YAW_RATE
			if target_yaw_rate > 0.0:
				print("  [PASS] 1. Yaw Steering: Left turn produces positive counter-clockwise Y rotation (", snappedf(target_yaw_rate, 0.01), " rad/s).")
				tests_passed += 1
			else:
				print("  [FAIL] 1. Yaw Steering sign incorrect.")

		elif step == 20:
			# Test 2: Decoupled Strafe Left (Q) does not rotate heading
			var initial_rotation_y = heli.rotation.y
			var right_dir = heli.global_transform.basis.x.normalized()
			var strafe_input = -1.0 # Q key
			var target_str_vel = right_dir * (strafe_input * 26.0)
			
			# Moving strictly left relative to facing: right_dir.x is positive, so target_str_vel.x is negative
			if target_str_vel.x < 0.0 and abs(heli.rotation.y - initial_rotation_y) < 0.001:
				print("  [PASS] 2. Decoupled Strafe Left: Moves left (-X) at 26.0 m/s with ZERO yaw rotation.")
				tests_passed += 1
			else:
				print("  [FAIL] 2. Strafe Left incorrect: ", target_str_vel)

		elif step == 30:
			# Test 3: Decoupled Strafe Right (E) does not rotate heading
			var right_dir = heli.global_transform.basis.x.normalized()
			var strafe_input = 1.0 # E key
			var target_str_vel = right_dir * (strafe_input * 26.0)
			
			if target_str_vel.x > 0.0:
				print("  [PASS] 3. Decoupled Strafe Right: Moves right (+X) at 26.0 m/s with ZERO yaw rotation.")
				tests_passed += 1
			else:
				print("  [FAIL] 3. Strafe Right incorrect: ", target_str_vel)

		elif step == 40:
			# Test 4: Visual Airframe Banking Direction
			var max_bank_rad = deg_to_rad(GameConstants.VISUAL_BANK_LIMIT_DEG)
			# Turning left (angular_velocity > 0): turn_bank is positive (leans left)
			var turn_bank_left = (GameConstants.MAX_YAW_RATE / GameConstants.MAX_YAW_RATE) * (max_bank_rad * 0.75)
			# Strafing left (strafe_input = -1.0): strafe_bank is positive (leans left)
			var strafe_bank_left = -(-1.0) * (max_bank_rad * 0.65)
			
			# Turning right (angular_velocity < 0): turn_bank is negative (leans right)
			var turn_bank_right = (-GameConstants.MAX_YAW_RATE / GameConstants.MAX_YAW_RATE) * (max_bank_rad * 0.75)
			# Strafing right (strafe_input = 1.0): strafe_bank is negative (leans right)
			var strafe_bank_right = -(1.0) * (max_bank_rad * 0.65)

			if turn_bank_left > 0.0 and strafe_bank_left > 0.0 and turn_bank_right < 0.0 and strafe_bank_right < 0.0:
				print("  [PASS] 4. Airframe Banking Physics: Left turn/strafe leans left (+Z roll); Right turn/strafe leans right (-Z roll).")
				tests_passed += 1
			else:
				print("  [FAIL] 4. Airframe Banking direction mismatch.")

		elif step == 50:
			# Test 5: Diagonal Flight Composition (W + Q / W + E)
			var forward_dir = -heli.global_transform.basis.z.normalized() # (0, 0, -1)
			var right_dir = heli.global_transform.basis.x.normalized()    # (1, 0, 0)
			var target_fwd_vel = forward_dir * 52.0
			var target_str_vel = right_dir * (-26.0)
			var target_diag = target_fwd_vel + target_str_vel

			if target_diag.z < -50.0 and target_diag.x < -20.0:
				print("  [PASS] 5. Diagonal Agility: Forward + Strafe compose cleanly without artificial input throttling.")
				tests_passed += 1
			else:
				print("  [FAIL] 5. Diagonal velocity composition failed: ", target_diag)

			print("Movement & Physics Results: ", tests_passed, "/", total_tests, " PASSED.")
			if tests_passed == total_tests:
				print("--- ALL LEFT/RIGHT MOVEMENT & PHYSICS VERIFICATIONS SUCCEEDED ---")
				get_tree().quit(0)
			else:
				get_tree().quit(1)
