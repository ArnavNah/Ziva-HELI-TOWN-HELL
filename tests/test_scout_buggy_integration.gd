extends SceneTree

const ScoutBuggyWheelController = preload("res://src/enemies/ground/scout_buggy_wheel_controller.gd")
const ScoutBuggyTurret = preload("res://src/enemies/ground/scout_buggy_turret.gd")
const ProceduralRaider = preload("res://src/enemies/procedural_raider.gd")
const EnemyData = preload("res://src/enemies/enemy_data.gd")

var passed: int = 0
var total: int = 0

func assert_true(cond: bool, msg: String) -> void:
	total += 1
	if cond:
		passed += 1
		print("  [PASS] ", msg)
	else:
		print("  [FAIL] ", msg)

func _init() -> void:
	print("\n=== SCOUT BUGGY MODULAR INTEGRATION TEST SUITE ===")
	
	test_assembly_structure()
	
	var runner = LiveDemoRunner.new(self)
	root.add_child(runner)

func test_assembly_structure() -> void:
	print("\n--- 1. Assembly Structure & Geometry Checks ---")
	var scene = load("res://scenes/enemies/scout_buggy_visuals.tscn")
	assert_true(scene != null, "scout_buggy_visuals.tscn loads successfully")
	if not scene:
		return
	
	var rig = scene.instantiate()
	var visuals = rig.get_node_or_null("Visuals")
	var turret = rig.get_node_or_null("Turret")
	assert_true(visuals != null, "Visuals node present in rig")
	assert_true(turret != null, "Turret node present in rig")
	assert_true(visuals.get_script() != null, "Wheel controller script attached to Visuals")
	assert_true(turret.get_script() != null, "Turret controller script attached to Turret")
	
	var body_model = visuals.get_node_or_null("BodyModel")
	assert_true(body_model != null, "BodyModel node present under Visuals")
	var body_mesh = body_model.get_node_or_null("Desert_Recon_Buggy_Body")
	var glass_mesh = body_model.get_node_or_null("Desert_Recon_Buggy_Glass")
	assert_true(body_mesh != null and body_mesh is MeshInstance3D, "Body MeshInstance3D present")
	assert_true(glass_mesh != null and glass_mesh is MeshInstance3D, "Glass MeshInstance3D present")
	
	var wheels = visuals.get_node_or_null("Wheels")
	assert_true(wheels != null, "Wheels container present under Visuals")
	
	var fl_steer = wheels.get_node_or_null("FrontLeftSteer")
	var fr_steer = wheels.get_node_or_null("FrontRightSteer")
	var rl_spin = wheels.get_node_or_null("RearLeftSpin")
	var rr_spin = wheels.get_node_or_null("RearRightSpin")
	assert_true(fl_steer != null, "FrontLeftSteer present")
	assert_true(fr_steer != null, "FrontRightSteer present")
	assert_true(rl_spin != null, "RearLeftSpin present")
	assert_true(rr_spin != null, "RearRightSpin present")
	
	var fl_spin = fl_steer.get_node_or_null("FrontLeftSpin") if fl_steer else null
	var fr_spin = fr_steer.get_node_or_null("FrontRightSpin") if fr_steer else null
	assert_true(fl_spin != null, "FrontLeftSpin present under FrontLeftSteer")
	assert_true(fr_spin != null, "FrontRightSpin present under FrontRightSteer")
	
	var fl_model = fl_spin.get_node_or_null("WheelModel") as MeshInstance3D if fl_spin else null
	var fr_model = fr_spin.get_node_or_null("WheelModel") as MeshInstance3D if fr_spin else null
	var rl_model = rl_spin.get_node_or_null("WheelModel") as MeshInstance3D if rl_spin else null
	var rr_model = rr_spin.get_node_or_null("WheelModel") as MeshInstance3D if rr_spin else null
	assert_true(fl_model != null and fr_model != null and rl_model != null and rr_model != null, "All 4 WheelModels present")
	
	if fl_model and fr_model:
		assert_true(is_equal_approx(fl_model.rotation_degrees.y, -90.0), "FrontLeft wheel hub faces outward (-90 deg Y)")
		assert_true(is_equal_approx(fr_model.rotation_degrees.y, 90.0), "FrontRight wheel hub faces outward (+90 deg Y)")
	
	rig.free()

func test_wheel_dynamics(stage_parent: Node) -> void:
	print("\n--- 2. Wheel Dynamics, Spin Signs, & Stationary Wall-Stop Checks ---")
	var test_stage = Node3D.new()
	stage_parent.add_child(test_stage)
	
	var spawner = load("res://src/enemies/enemy_spawner.gd").new()
	test_stage.add_child(spawner)
	var enemy = spawner.spawn_enemy_type("scout_buggy", Vector3(0, 0, 0))
	assert_true(enemy != null, "Spawned scout_buggy enemy successfully")
	if not enemy:
		test_stage.queue_free()
		return
	enemy.global_position = Vector3(0, 0, 0)
	
	var visuals = enemy.get_node_or_null("Visuals")
	var wheel_ctrl = visuals as ScoutBuggyWheelController
	assert_true(wheel_ctrl != null, "ScoutBuggyWheelController found on Visuals")
	
	var fl_spin = wheel_ctrl.fl_spin
	var fr_spin = wheel_ctrl.fr_spin
	assert_true(fl_spin != null and fr_spin != null, "Spin nodes resolved on controller")
	
	var initial_rx = fl_spin.rotation.x
	
	# Forward displacement
	wheel_ctrl._prev_pos = Vector3(0, 0, 0)
	enemy.global_position = Vector3(0, 0, -1.0)
	wheel_ctrl._physics_process(0.016)
	
	var fwd_rx = fl_spin.rotation.x
	var fwd_spin_delta = fwd_rx - initial_rx
	assert_true(fwd_spin_delta < 0.0, "Forward movement rotates wheels forward (negative angle around local X)")
	
	# Reverse displacement
	wheel_ctrl._prev_pos = Vector3(0, 0, -1.0)
	enemy.global_position = Vector3(0, 0, 0.0)
	wheel_ctrl._physics_process(0.016)
	
	var rev_rx = fl_spin.rotation.x
	var rev_spin_delta = rev_rx - fwd_rx
	assert_true(rev_spin_delta > 0.0, "Reverse movement rotates wheels backward (positive angle around local X)")
	
	# Stationary / wall blocked
	wheel_ctrl._prev_pos = Vector3(0, 0, 0.0)
	enemy.velocity = Vector3(0, 0, -18.0)
	enemy.global_position = Vector3(0, 0, 0.0)
	wheel_ctrl._physics_process(0.016)
	
	var stopped_rx = fl_spin.rotation.x
	assert_true(is_equal_approx(stopped_rx, rev_rx), "Stationary / wall-blocked vehicle does NOT spin wheels")
	
	# Front wheel steering
	wheel_ctrl._prev_yaw = 0.0
	# Right turn (heading turns toward +X, which in Godot is negative Y rotation)
	enemy.rotation.y = deg_to_rad(-30.0)
	wheel_ctrl._physics_process(0.016)
	assert_true(wheel_ctrl.fl_steer.rotation.y < 0.0, "Front wheels steer right when vehicle yaws right")
	assert_true(rad_to_deg(absf(wheel_ctrl.fl_steer.rotation.y)) <= 25.1, "Front wheel steering is bounded within visual max limit (25 deg)")

	# Left turn (heading turns toward -X, which in Godot is positive Y rotation)
	wheel_ctrl._prev_yaw = deg_to_rad(30.0) # previous yaw in atan2 space was +30 deg
	enemy.rotation.y = deg_to_rad(20.0)
	wheel_ctrl._physics_process(0.016)
	assert_true(wheel_ctrl.fl_steer.rotation.y > 0.0, "Front wheels steer left when vehicle yaws left")
	
	test_stage.queue_free()

func test_turret_and_muzzle(stage_parent: Node) -> void:
	print("\n--- 3. Turret Articulation, Elevation Clamp, & Muzzle Origin Checks ---")
	var test_stage = Node3D.new()
	stage_parent.add_child(test_stage)
	
	var spawner = load("res://src/enemies/enemy_spawner.gd").new()
	test_stage.add_child(spawner)
	var enemy = spawner.spawn_enemy_type("scout_buggy", Vector3(0, 0, 0))
	assert_true(enemy != null, "Spawned scout_buggy enemy successfully")
	if not enemy:
		test_stage.queue_free()
		return
	
	var turret = enemy.get_node_or_null("Turret") as ScoutBuggyTurret
	assert_true(turret != null, "ScoutBuggyTurret direct child present on enemy")
	assert_true(turret.has_node("MountModel"), "MountModel present under Turret")
	assert_true(turret.gun_pitch != null, "GunPitch elevation node present under Turret")
	
	# Test Muzzle Origin Resolver
	var raider = enemy as ProceduralRaider
	assert_true(raider != null, "Enemy is ProceduralRaider instance")
	var muzzle_origin = raider.get_muzzle_origin()
	var expected_muzzle = turret.get_muzzle_position()
	assert_true(muzzle_origin.is_equal_approx(expected_muzzle), "get_muzzle_origin() returns the exact visible barrel tip")
	assert_true(muzzle_origin.z < turret.global_position.z, "Muzzle marker is at the forward barrel tip (-Z)")
	
	# Aim tracking
	var high_target = enemy.global_position + Vector3(0, 20.0, -30.0)
	turret.track_aim(high_target, 0.5, 360.0, 30.0)
	assert_true(turret.gun_pitch.rotation.x > deg_to_rad(15.0), "Gun pitches up towards elevated target")
	assert_true(is_equal_approx(turret.rotation.x, 0.0), "Pedestal mount remains flat and upright (zero pitch on Turret root)")
	
	# Max elevation clamp
	var vertical_target = enemy.global_position + Vector3(0, 100.0, -1.0)
	turret.track_aim(vertical_target, 1.0, 360.0, 10.0)
	assert_true(rad_to_deg(turret.gun_pitch.rotation.x) <= 60.1, "Gun elevation is strictly clamped to max elevation (+60 deg)")
	
	# Min depression clamp
	var low_target = enemy.global_position + Vector3(0, -50.0, -10.0)
	turret.track_aim(low_target, 1.0, 360.0, 10.0)
	assert_true(rad_to_deg(turret.gun_pitch.rotation.x) >= -15.1, "Gun depression is strictly clamped to min elevation (-15 deg)")
	
	# Recoil
	turret.play_recoil(0.06)
	assert_true(turret.recoil_node.position.z > 0.01, "play_recoil kicks gun model along barrel axis")
	
	test_stage.queue_free()

func test_spawner_and_elite_modifier(stage_parent: Node) -> void:
	print("\n--- 4. Spawner and ELITE Modifier Integration Checks ---")
	var test_stage = Node3D.new()
	stage_parent.add_child(test_stage)
	
	var spawner = load("res://src/enemies/enemy_spawner.gd").new()
	test_stage.add_child(spawner)
	
	var enemy = spawner.spawn_enemy_type("scout_buggy", Vector3(10, 0, 10))
	assert_true(enemy != null, "Standard scout_buggy spawned via EnemySpawner")
	if not enemy:
		test_stage.queue_free()
		return
	assert_true(enemy.has_node("Visuals") and enemy.has_node("Turret"), "Normal enemy has Visuals and Turret direct children")
	
	var elite_enemy = spawner.spawn_enemy_type("scout_buggy", Vector3(20, 0, 20))
	elite_enemy.modifier = EnemyData.ModifierType.ELITE
	elite_enemy._apply_modifiers()
	
	var elite_vis = elite_enemy.get_node("Visuals")
	var elite_turret = elite_enemy.get_node("Turret")
	assert_true(elite_vis.scale.is_equal_approx(Vector3(1.2, 1.2, 1.2)), "Elite modifier scales Visuals by 1.2x")
	assert_true(elite_turret.scale.is_equal_approx(Vector3(4.8, 4.8, 4.8)), "Elite modifier scales Turret scale by 1.2x (4.0 * 1.2 = 4.8)")
	assert_true(is_equal_approx(elite_turret.position.y, 1.764 * 1.2), "Elite modifier repositions Turret along with scaled roof (1.764 * 1.2)")
	
	var found_proc_boxes = 0
	for child in elite_vis.get_children():
		if child is MeshInstance3D and child.mesh is BoxMesh:
			found_proc_boxes += 1
	assert_true(found_proc_boxes == 0, "No duplicate procedural box meshes left under Visuals")
	
	test_stage.queue_free()

class LiveDemoRunner extends Node:
	var _tree: SceneTree
	var _frame: int = 0
	var _scene_root: Node3D
	var _cam: Camera3D
	var _buggy_norm: Node3D
	var _buggy_elite: Node3D
	var _player: Node3D
	
	func _init(t: SceneTree) -> void:
		_tree = t
	
	func _ready() -> void:
		call_deferred("_start_suite")
	
	func _start_suite() -> void:
		_tree.test_wheel_dynamics(self)
		_tree.test_turret_and_muzzle(self)
		_tree.test_spawner_and_elite_modifier(self)
		
		print("\n--- 5. Live In-Game Drive, Aim, & Fire Render Demonstration ---")
		_scene_root = Node3D.new()
		add_child(_scene_root)
		
		var light = DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-45, 45, 0)
		_scene_root.add_child(light)
		
		var ground = MeshInstance3D.new()
		var pm = PlaneMesh.new()
		pm.size = Vector2(80, 80)
		ground.mesh = pm
		var g_mat = StandardMaterial3D.new()
		g_mat.albedo_color = Color(0.25, 0.28, 0.24)
		ground.material_override = g_mat
		_scene_root.add_child(ground)
		
		_player = Node3D.new()
		_player.name = "PlayerHelicopter"
		_player.add_to_group("player")
		_player.position = Vector3(8.0, 16.0, 15.0)
		_scene_root.add_child(_player)
		
		_cam = Camera3D.new()
		_scene_root.add_child(_cam)
		_cam.look_at_from_position(Vector3(0.0, 12.0, -22.0), Vector3(0.0, 1.5, 0.0), Vector3.UP)
		_cam.make_current()
		
		var spawner = load("res://src/enemies/enemy_spawner.gd").new()
		_scene_root.add_child(spawner)
		_buggy_norm = spawner.spawn_enemy_type("scout_buggy", Vector3(-4.0, 0.0, 0.0))
		_buggy_elite = spawner.spawn_enemy_type("scout_buggy", Vector3(4.0, 0.0, 2.0))
		_buggy_elite.modifier = EnemyData.ModifierType.ELITE
		_buggy_elite._apply_modifiers()
	
	func _process(delta: float) -> void:
		if not _scene_root:
			return
		_frame += 1
		if _frame < 20:
			if _buggy_norm:
				_buggy_norm.position.z += 0.05
				var t_norm = _buggy_norm.get_node_or_null("Turret") as ScoutBuggyTurret
				if t_norm and _player:
					t_norm.track_aim(_player.global_position, delta * 3.0)
			if _buggy_elite:
				_buggy_elite.position.z += 0.04
				var t_elite = _buggy_elite.get_node_or_null("Turret") as ScoutBuggyTurret
				if t_elite and _player:
					t_elite.track_aim(_player.global_position, delta * 3.0)
		elif _frame == 20:
			var raider_norm = _buggy_norm as ProceduralRaider
			if raider_norm and _player:
				raider_norm.start_telegraph(1.0, 0.7, Color("ef8b49"))
				raider_norm.update_telegraph(raider_norm.get_muzzle_origin(), _player.global_position, 0.016)
		elif _frame == 25:
			DirAccess.make_dir_absolute("res://artifacts")
			var img = get_viewport().get_texture().get_image()
			var save_path = "res://artifacts/live_scout_buggy_combat_demonstration.png"
			var err = img.save_png(save_path)
			_tree.assert_true(err == OK, "Saved live combat demonstration screenshot to: " + save_path)
			
			print("\n=== FINAL TEST SUMMARY: %d/%d PASSED ===" % [_tree.passed, _tree.total])
			if _tree.passed == _tree.total:
				print("ALL SCOUT BUGGY INTEGRATION CHECKS PASSED SUCCESSFULLY!\n")
				_tree.quit(0)
			else:
				print("SOME CHECKS FAILED!\n")
				_tree.quit(1)
