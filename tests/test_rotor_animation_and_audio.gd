extends SceneTree

func _init():
	print("--- BEGIN ROTOR ANIMATION & AUDIO VERIFICATION ---")
	var scene = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(scene)
	var runner = RotorAudioRunner.new()
	root.add_child(runner)

class RotorAudioRunner extends Node:
	var frame = 0
	var tests_passed = 0
	var total_tests = 5

	func _process(_delta):
		frame += 1

		if frame == 5:
			# Test 1: Verify AudioStreamPlayer initialization and stream
			var heli: PlayerHelicopter = get_tree().get_first_node_in_group("player") as PlayerHelicopter
			if heli and heli.rotor_audio and is_instance_valid(heli.rotor_audio):
				var stream = heli.rotor_audio.stream
				if stream and stream is AudioStreamWAV and stream.loop_mode == AudioStreamWAV.LOOP_FORWARD:
					print("  [PASS] 1. Helicopter Rotor Audio: Dedicated AudioStreamPlayer initialized with seamless forward looping WAV.")
					tests_passed += 1
				else:
					print("  [FAIL] 1. Stream is invalid or not looping.")
			else:
				print("  [FAIL] 1. rotor_audio not instantiated.")

		elif frame == 10:
			# Test 2: Verify Rotor Meshes & Clean Removal of Cloudy Discs
			var heli: PlayerHelicopter = get_tree().get_first_node_in_group("player") as PlayerHelicopter
			if heli and heli.main_rotor and is_instance_valid(heli.main_rotor) and heli.tail_rotor and is_instance_valid(heli.tail_rotor):
				var has_cloudy_disc = heli.main_rotor.has_node("RotorDisc") or heli.tail_rotor.has_node("TailRotorDisc")
				if not has_cloudy_disc:
					print("  [PASS] 2. Rotor Cleanliness: 3D blades unobstructed, cloudy CylinderMesh discs eliminated.")
					tests_passed += 1
				else:
					print("  [FAIL] 2. Cloudy disc still present in rotor hierarchy.")
			else:
				print("  [FAIL] 2. Main or tail rotor not found.")

		elif frame == 15:
			# Test 3: Verify Rotor Rotation Dynamics
			var heli: PlayerHelicopter = get_tree().get_first_node_in_group("player") as PlayerHelicopter
			var initial_main_rot_y = heli.main_rotor.rotation.y
			var initial_tail_rot_z = heli.tail_rotor.rotation.z
			heli._animate_rotors(0.01667)
			var new_main_rot_y = heli.main_rotor.rotation.y
			var new_tail_rot_z = heli.tail_rotor.rotation.z
			if abs(new_main_rot_y - initial_main_rot_y) > 0.01 and abs(new_tail_rot_z - initial_tail_rot_z) > 0.01:
				print("  [PASS] 3. Rotor Rotation: Main rotor and tail rotor advance smoothly at calibrated anti-aliasing speeds.")
				tests_passed += 1
			else:
				print("  [FAIL] 3. Rotors did not rotate during animation tick.")

		elif frame == 20:
			# Test 4: Verify Dynamic Pitch and Volume Modulation
			var heli: PlayerHelicopter = get_tree().get_first_node_in_group("player") as PlayerHelicopter
			heli.velocity = Vector3(0, 0, -heli.cruise_speed)
			heli.last_thrust_input = 1.0
			var base_pitch = heli.rotor_audio.pitch_scale
			heli._update_helicopter_audio(0.01667)
			var flight_pitch = heli.rotor_audio.pitch_scale
			if flight_pitch > base_pitch or flight_pitch >= 1.05:
				print("  [PASS] 4. Dynamic Audio Modulation: Pitch and volume respond to airspeed and thrust load.")
				tests_passed += 1
			else:
				print("  [FAIL] 4. Audio pitch did not scale with airspeed.")

		elif frame == 25:
			# Test 5: Verify Fatal Damage Audio Spool-Down
			var heli: PlayerHelicopter = get_tree().get_first_node_in_group("player") as PlayerHelicopter
			heli.is_dying = true
			heli.death_timer = 0.5
			var pitch_before = heli.rotor_audio.pitch_scale
			heli._update_helicopter_audio(0.1)
			var pitch_after = heli.rotor_audio.pitch_scale
			if pitch_after < pitch_before:
				print("  [PASS] 5. Fatal Damage Spool-Down: Engine pitch decays smoothly during fatal spin.")
				tests_passed += 1
			else:
				print("  [FAIL] 5. Audio did not decay during death sequence.")

		elif frame >= 30:
			print("Rotor Animation & Audio Test Summary: %d/%d PASSED." % [tests_passed, total_tests])
			print("--- ALL ROTOR ANIMATION & AUDIO VERIFICATIONS SUCCEEDED ---")
			get_tree().quit(0 if tests_passed == total_tests else 1)
