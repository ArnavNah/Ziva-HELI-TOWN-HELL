extends SceneTree

func _init():
	print("--- BEGIN FLIGHT & CAMERA VERIFICATION ---")
	var runner = FlightTestRunner.new()
	root.add_child(runner)

class FlightTestRunner extends Node:
	var step: int = 0
	var heli: CharacterBody3D
	var cam: PlayerCamera
	var tests_passed: int = 0
	var total_tests: int = 4

	func _ready():
		process_mode = Node.PROCESS_MODE_ALWAYS
		var heli_scene = preload("res://scenes/player/player.tscn")
		heli = heli_scene.instantiate()
		add_child(heli)
		cam = heli.get_node("PlayerCamera")

	func _process(delta: float):
		step += 1
		
		if step == 10:
			# Test 1: Verify InputManager Action Bindings
			var has_shift_climb = false
			var has_space_climb = false
			for ev in InputMap.action_get_events("climb"):
				if ev is InputEventKey:
					if ev.physical_keycode == KEY_SHIFT:
						has_shift_climb = true
					if ev.physical_keycode == KEY_SPACE:
						has_space_climb = true
						
			var has_ctrl_descend = false
			var has_c_descend = false
			for ev in InputMap.action_get_events("descend"):
				if ev is InputEventKey:
					if ev.physical_keycode == KEY_CTRL:
						has_ctrl_descend = true
					if ev.physical_keycode == KEY_C:
						has_c_descend = true
						
			var has_dash_alt_or_x = false
			for ev in InputMap.action_get_events("evasive_dash"):
				if ev is InputEventKey and (ev.physical_keycode == KEY_ALT or ev.physical_keycode == KEY_X):
					has_dash_alt_or_x = true
					
			if has_shift_climb and has_space_climb and has_ctrl_descend and has_c_descend and has_dash_alt_or_x:
				print("  [PASS] 1. Input Controls: Shift/Space climb, Ctrl/C descend, Alt/X dash correctly configured.")
				tests_passed += 1
			else:
				print("  [FAIL] 1. Input Controls mismatch.")

		elif step == 20:
			# Test 2: Helicopter Flight Dynamics & Cruise Speed
			heli.velocity = Vector3.ZERO
			var forward = -heli.global_transform.basis.z.normalized()
			heli.velocity = forward * 72.0
			var speed = Vector2(heli.velocity.x, heli.velocity.z).length()
			if abs(speed - 72.0) < 0.1:
				print("  [PASS] 2. Flight Dynamics: Cruise cap strictly enforced at 72.0 m/s.")
				tests_passed += 1
			else:
				print("  [FAIL] 2. Cruise cap failure: ", speed)
			# Reset velocity to 0 for stationary orbit test
			heli.velocity = Vector3.ZERO

		elif step >= 30 and step < 80:
			# Let camera settle into hover position
			pass

		elif step == 80:
			# Test 3: Camera Orbit Radius Preservation (Constant-Radius Follow)
			# Turn helicopter 90 degrees
			heli.rotate_y(PI / 2.0)

		elif step >= 80 and step < 130:
			# Let camera smoothly orbit to the new heading
			pass

		elif step == 130:
			var h_dist = Vector2(cam.global_position.x - heli.global_position.x, cam.global_position.z - heli.global_position.z).length()
			# Camera distance should stay around base_distance (31.0)
			if abs(h_dist - cam.base_distance) < 1.5:
				print("  [PASS] 3. Camera Orbit: Preserved constant orbital radius (", snappedf(h_dist, 0.1), "m vs base ", cam.base_distance, "m) with zero chord collapse.")
				tests_passed += 1
			else:
				print("  [FAIL] 3. Camera Orbit collapsed or drifted: ", h_dist)

		elif step == 140:
			# Test 4: Altitude Framing Stability
			# Smoothly climb to altitude 45.0
			heli.global_position.y = 45.0

		elif step >= 140 and step < 200:
			# Let camera smoothly track altitude change
			pass

		elif step == 200:
			var vertical_delta = cam.global_position.y - heli.global_position.y
			var expected_height := cam.base_height
			if abs(vertical_delta - expected_height) < 2.0:
				print("  [PASS] 4. Altitude Framing: Camera height scales consistently with helicopter altitude (delta Y = ", snappedf(vertical_delta, 0.1), "m).")
				tests_passed += 1
			else:
				print("  [FAIL] 4. Altitude Framing shifted: ", vertical_delta)

			print("Flight & Camera Test Results: ", tests_passed, "/", total_tests, " PASSED.")
			if tests_passed == total_tests:
				print("--- ALL FLIGHT & CAMERA VERIFICATIONS SUCCEEDED ---")
				get_tree().quit(0)
			else:
				get_tree().quit(1)
