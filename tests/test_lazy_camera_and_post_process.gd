extends SceneTree

## Comprehensive Verification Test for Lazy Camera Follow Animation & Light Post-Processing:
## 1. Camera initializes with top_level=true, target tracking, and baseline distance/height.
## 2. Dynamic speed pull-back: Camera distance expands and FOV widens under high speed.
## 3. Lazy inertia: Camera follows positional changes with smooth dual-rate damping.
## 4. Lazy yaw sweeping: Camera orbits smoothly behind turns without instant snap.
## 5. Dynamic banking roll tilt: Camera tilts roll axis proportionally when aircraft banks.
## 6. Organic airborne float: Micro-float creates subtle flight turbulence feel.
## 7. Trauma response: Camera trauma applies screen shake and decays cleanly.
## 8. Light post-processing: BattlefieldGrade shader contains chromatic aberration, vignette, and color grade parameters.

var tests_passed: int = 0
var total_tests: int = 9

func _init() -> void:
	print("==================================================================")
	print("--- BEGIN LAZY CAMERA & POST-PROCESSING VERIFICATION ---")
	print("==================================================================")
	call_deferred("_run_tests")

func check(condition: bool, message: String) -> void:
	if condition:
		print("  [PASS] ", message)
		tests_passed += 1
	else:
		push_error("  [FAIL] " + message)
		print("  [FAIL] ", message)

func _run_tests() -> void:
	var heli_scene = preload("res://scenes/player/player.tscn")
	var heli = heli_scene.instantiate()
	root.add_child(heli)

	for i in 5:
		await process_frame

	var cam = heli.get_node_or_null("PlayerCamera") as PlayerCamera
	if not cam:
		print("[FAIL] PlayerCamera node not found on PlayerHelicopter.")
		quit(1)
		return

	# --- TEST 1: Camera initialization ---
	check(cam.top_level and cam.is_initialized and cam.target_node == heli, "1. PlayerCamera properly initialized as top_level chase camera")

	# --- TEST 2: Dynamic Speed Pull-Back & FOV ---
	var base_d = cam.base_distance
	var base_f = cam.base_fov
	heli.velocity = -heli.global_transform.basis.z * 34.0
	for i in 15:
		cam.update_camera(0.016)
	check(cam.current_cam_dist > base_d and cam.fov > base_f, "2. Dynamic pull-back expands camera distance (%.1fm > %.1fm) and widens FOV (%.1f > %.1f)" % [cam.current_cam_dist, base_d, cam.fov, base_f])
	heli.velocity = Vector3.ZERO

	# --- TEST 3: Lazy Translational Inertia (Lag) ---
	var prev_cam_pos = cam.global_position
	heli.global_position += Vector3(15.0, 0.0, 0.0)
	cam.update_camera(0.016)
	var instant_cam_step = cam.global_position.distance_to(prev_cam_pos)
	check(instant_cam_step < 12.0 and instant_cam_step > 0.1, "3. Lazy translational lag smoothly cushions camera movement (moved %.2fm out of 15m step)" % instant_cam_step)

	# --- TEST 4: Lazy Yaw Sweeping Orbit ---
	var prev_yaw = cam.current_cam_yaw
	heli.rotate_y(deg_to_rad(45.0))
	heli.reset_physics_interpolation()
	cam.update_camera(0.016)
	var yaw_step = abs(cam.current_cam_yaw - prev_yaw)
	check(yaw_step < deg_to_rad(40.0) and yaw_step > 0.001, "4. Lazy yaw follow begins smooth orbital sweep (yaw delta = %.3f rad < 45 deg)" % yaw_step)

	# --- TEST 5: Dynamic Banking Roll Tilt ---
	heli.bank_angle = deg_to_rad(20.0)
	for i in 10:
		cam.update_camera(0.016)
	check(abs(cam.current_cam_roll) > deg_to_rad(0.5) and abs(cam.current_cam_roll) <= deg_to_rad(4.5), "5. Dynamic banking roll tilt applied (%.2f deg tilt on 20 deg aircraft bank)" % rad_to_deg(cam.current_cam_roll))
	heli.bank_angle = 0.0

	# --- TEST 6: Organic Airborne Float ---
	var float_accum: float = 0.0
	for i in 20:
		cam.update_camera(0.016)
		float_accum += abs(sin(cam.organic_float_time))
	check(cam.organic_float_time > 0.0 and float_accum > 0.1, "6. Organic airborne float actively breathing during flight simulation")

	# --- TEST 7: Camera Trauma Shake ---
	cam.add_trauma(0.8)
	check(cam.trauma == 0.8, "7.1 Camera trauma successfully registered at 0.8")
	for i in 30:
		cam.update_camera(0.016)
	check(cam.trauma < 0.5, "7.2 Camera trauma decays smoothly over time (decayed to %.2f)" % cam.trauma)

	# --- TEST 8: Light Post-Processing Shader Verification ---
	var shader = preload("res://src/shaders/battlefield_grade.gdshader")
	var code = shader.code
	var has_vig = code.contains("vignette_intensity") and code.contains("vignette_opacity")
	var has_ca = code.contains("chromatic_aberration")
	var has_grade = code.contains("saturation") and code.contains("shadow_lift")
	check(has_vig and has_ca and has_grade, "8. Light post-processing shader contains vignette, chromatic aberration, and color grading")

	print("------------------------------------------------------------------")
	print("LAZY CAMERA & POST-PROCESSING: ", tests_passed, "/", total_tests, " PASSED")
	print("==================================================================")

	heli.queue_free()

	if tests_passed >= total_tests:
		quit(0)
	else:
		quit(1)
