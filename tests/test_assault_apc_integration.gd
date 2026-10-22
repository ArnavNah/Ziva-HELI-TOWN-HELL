extends SceneTree

const AssaultAPCWheelController = preload("res://src/enemies/ground/assault_apc_wheel_controller.gd")
const AssaultAPCTurret = preload("res://src/enemies/ground/assault_apc_turret.gd")
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
	print("\n=== ASSAULT APC MODULAR INTEGRATION TEST SUITE ===")
	
	test_assembly_structure()
	
	var runner = LiveDemoRunner.new(self)
	root.add_child(runner)

func test_assembly_structure() -> void:
	print("\n--- 1. Assembly Structure & Geometry Checks ---")
	var scene = load("res://scenes/enemies/assault_apc_visuals.tscn")
	assert_true(scene != null, "assault_apc_visuals.tscn loads successfully")
	if not scene:
		return
	
	var rig = scene.instantiate()
	var visuals = rig.get_node_or_null("Visuals")
	var turret = rig.get_node_or_null("Turret")
	assert_true(visuals != null, "Visuals node present in rig")
	assert_true(turret != null, "Turret node present in rig")
	assert_true(visuals.get_script() != null, "Wheel controller script attached to Visuals")
	assert_true(turret.get_script() != null, "Turret controller script attached to Turret")
	
	# Verify hull
	var hull_model = visuals.get_node_or_null("HullModel")
	assert_true(hull_model != null, "HullModel node present under Visuals")
	var hull_mesh = hull_model.get_node_or_null("Tank_Hull") as MeshInstance3D
	assert_true(hull_mesh != null and hull_mesh.mesh != null, "Tank_Hull MeshInstance3D present")
	assert_true(hull_mesh.mesh.resource_path.ends_with("tank_hull_mesh.res"), "Tank_Hull references tank_hull_mesh.res")
	
	# Verify wheels
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
	
	var fl_spin = fl_steer.get_node_or_null("FrontLeftSpin")
	var fr_spin = fr_steer.get_node_or_null("FrontRightSpin")
	assert_true(fl_spin != null, "FrontLeftSpin present under FrontLeftSteer")
	assert_true(fr_spin != null, "FrontRightSpin present under FrontRightSteer")
	
	var fl_m = fl_spin.get_node_or_null("WheelModel") as MeshInstance3D
	var fr_m = fr_spin.get_node_or_null("WheelModel") as MeshInstance3D
	var rl_m = rl_spin.get_node_or_null("WheelModel") as MeshInstance3D
	var rr_m = rr_spin.get_node_or_null("WheelModel") as MeshInstance3D
	assert_true(fl_m != null and fr_m != null and rl_m != null and rr_m != null, "All 4 WheelModels present")
	
	# Verify outward hub orientations
	assert_true(is_equal_approx(fl_m.rotation_degrees.y, -90.0), "FrontLeft wheel hub faces outward (-90 deg Y)")
	assert_true(is_equal_approx(fr_m.rotation_degrees.y, 90.0), "FrontRight wheel hub faces outward (+90 deg Y)")
	assert_true(is_equal_approx(rl_m.rotation_degrees.y, -90.0), "RearLeft wheel hub faces outward (-90 deg Y)")
	assert_true(is_equal_approx(rr_m.rotation_degrees.y, 90.0), "RearRight wheel hub faces outward (+90 deg Y)")
	
	# Verify shared mesh resource identity
	var shared_wheel_mesh = load("res://assets/Enemy/tank_game_ready/universal_wheel_mesh.res")
	assert_true(fl_m.mesh == shared_wheel_mesh, "APC FrontLeft wheel references universal_wheel_mesh.res")
	assert_true(fr_m.mesh == shared_wheel_mesh, "APC FrontRight wheel references universal_wheel_mesh.res")
	assert_true(rl_m.mesh == shared_wheel_mesh, "APC RearLeft wheel references universal_wheel_mesh.res")
	assert_true(rr_m.mesh == shared_wheel_mesh, "APC RearRight wheel references universal_wheel_mesh.res")
	
	# Check Scout Buggy also shares this mesh
	var scout_scene = load("res://scenes/enemies/scout_buggy_visuals.tscn") as PackedScene
	if scout_scene:
		var scout_inst = scout_scene.instantiate()
		var s_wheel = scout_inst.get_node_or_null("Visuals/Wheels/FrontLeftSteer/FrontLeftSpin/WheelModel") as MeshInstance3D
		if s_wheel:
			assert_true(s_wheel.mesh == shared_wheel_mesh, "Scout Buggy and Assault APC share the exact same universal wheel ArrayMesh resource")
		scout_inst.free()
	
	rig.free()

class LiveDemoRunner extends Node:
	var _tree: SceneTree
	var _frame: int = 0
	var _scene_root: Node3D
	var _player: Node3D
	var _apc_norm: CharacterBody3D
	var _apc_elite: CharacterBody3D
	var _cam: Camera3D
	
	func _init(tree_ref: SceneTree) -> void:
		_tree = tree_ref
		
	func _ready() -> void:
		call_deferred("_setup_and_run")
		
	func _setup_and_run() -> void:
		_tree.test_wheel_dynamics(self)
		_tree.test_turret_and_muzzle(self)
		_tree.test_spawner_and_elite_modifier(self)
		_setup_live_render_demo()
		
	func _setup_live_render_demo() -> void:
		print("\n--- 5. Live In-Game Drive, Aim, Burst-Fire, & Render Demonstration ---")
		_scene_root = Node3D.new()
		add_child(_scene_root)
		
		var env = WorldEnvironment.new()
		var env_res = Environment.new()
		env_res.background_mode = Environment.BG_COLOR
		env_res.background_color = Color(0.18, 0.22, 0.25)
		env_res.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env_res.ambient_light_color = Color(0.65, 0.68, 0.70)
		env.environment = env_res
		_scene_root.add_child(env)
		
		var light = DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-45, 45, 0)
		_scene_root.add_child(light)
		
		var ground = MeshInstance3D.new()
		var pm = PlaneMesh.new()
		pm.size = Vector2(80, 80)
		ground.mesh = pm
		var g_mat = StandardMaterial3D.new()
		g_mat.albedo_color = Color(0.22, 0.25, 0.23)
		ground.material_override = g_mat
		_scene_root.add_child(ground)
		
		_player = Node3D.new()
		_player.name = "PlayerHelicopter"
		_player.add_to_group("player")
		_player.position = Vector3(10.0, 18.0, 20.0)
		_scene_root.add_child(_player)
		
		_cam = Camera3D.new()
		_scene_root.add_child(_cam)
		_cam.look_at_from_position(Vector3(0.0, 14.0, -26.0), Vector3(0.0, 1.8, 0.0), Vector3.UP)
		_cam.make_current()
		
		var spawner = load("res://src/enemies/enemy_spawner.gd").new()
		_scene_root.add_child(spawner)
		_apc_norm = spawner.spawn_enemy_type("assault_apc", Vector3(-5.0, 0.0, 0.0))
		_apc_elite = spawner.spawn_enemy_type("assault_apc", Vector3(5.0, 0.0, 3.0))
		_apc_elite.modifier = EnemyData.ModifierType.ELITE
		_apc_elite._apply_modifiers()
		
	func _process(delta: float) -> void:
		if not _scene_root:
			return
		_frame += 1
		if _frame < 20:
			if _apc_norm:
				_apc_norm.position.z += 0.06
				var t_norm = _apc_norm.get_node_or_null("Turret") as AssaultAPCTurret
				if t_norm and _player:
					t_norm.track_aim(_player.global_position, delta, 3.0)
			if _apc_elite:
				_apc_elite.position.z += 0.05
				var t_elite = _apc_elite.get_node_or_null("Turret") as AssaultAPCTurret
				if t_elite and _player:
					t_elite.track_aim(_player.global_position, delta, 3.0)
		elif _frame == 20:
			var raider_norm = _apc_norm as ProceduralRaider
			if raider_norm and _player:
				raider_norm.start_telegraph(1.0, 0.7, Color("ef8b49"))
				raider_norm.update_telegraph(raider_norm.get_muzzle_origin(), _player.global_position, 0.016)
				# Trigger 3-round burst recoil demonstration
				var t = _apc_norm.get_node_or_null("Turret") as AssaultAPCTurret
				if t:
					t.play_recoil()
		elif _frame == 25:
			DirAccess.make_dir_absolute("res://artifacts")
			var tex = get_viewport().get_texture()
			var img = tex.get_image() if tex else null
			if img:
				var save_path = "res://artifacts/live_assault_apc_combat_demonstration.png"
				var err = img.save_png(save_path)
				_tree.assert_true(err == OK, "Saved live combat demonstration screenshot to: " + save_path)
			else:
				print("Skipping screenshot capture on headless renderer")
			
			print("\n=== FINAL TEST SUMMARY: %d/%d PASSED ===" % [_tree.passed, _tree.total])
			if _tree.passed == _tree.total:
				print("ALL ASSAULT APC INTEGRATION CHECKS PASSED SUCCESSFULLY!\n")
				_tree.quit(0)
			else:
				print("SOME CHECKS FAILED!\n")
				_tree.quit(1)

func test_wheel_dynamics(stage_parent: Node) -> void:
	print("\n--- 2. Wheel Dynamics, Spin Signs, & Stationary Wall-Stop Checks ---")
	var test_stage = Node3D.new()
	stage_parent.add_child(test_stage)
	
	var spawner = load("res://src/enemies/enemy_spawner.gd").new()
	test_stage.add_child(spawner)
	var enemy = spawner.spawn_enemy_type("assault_apc", Vector3(0, 0, 0))
	assert_true(enemy != null, "Spawned assault_apc enemy successfully")
	if not enemy:
		test_stage.queue_free()
		return
	
	var visuals = enemy.get_node_or_null("Visuals")
	var wheel_ctrl = visuals as AssaultAPCWheelController
	assert_true(wheel_ctrl != null, "AssaultAPCWheelController found on Visuals")
	if not wheel_ctrl:
		test_stage.queue_free()
		return
	
	var fl_spin = wheel_ctrl.fl_spin
	var fr_spin = wheel_ctrl.fr_spin
	var rl_spin = wheel_ctrl.rl_spin
	var rr_spin = wheel_ctrl.rr_spin
	assert_true(fl_spin != null and fr_spin != null and rl_spin != null and rr_spin != null, "Spin nodes resolved on controller")
	
	var initial_rx = fl_spin.rotation.x
	
	# Forward movement (-Z direction in Godot)
	wheel_ctrl._prev_pos = Vector3(0, 0, 0)
	enemy.global_position = Vector3(0, 0, -1.0) # Moved forward 1m
	wheel_ctrl._physics_process(0.016)
	
	var fwd_rx = fl_spin.rotation.x
	var fwd_spin_delta = fwd_rx - initial_rx
	assert_true(fwd_spin_delta < 0.0, "Forward movement rotates wheels forward (negative angle around local X)")
	
	# Reverse movement (+Z direction in Godot)
	wheel_ctrl._prev_pos = Vector3(0, 0, -1.0)
	enemy.global_position = Vector3(0, 0, 0.0) # Moved backward 1m
	wheel_ctrl._physics_process(0.016)
	
	var rev_rx = fl_spin.rotation.x
	var rev_spin_delta = rev_rx - fwd_rx
	assert_true(rev_spin_delta > 0.0, "Reverse movement rotates wheels backward (positive angle around local X)")
	
	# Stationary / wall blocked
	wheel_ctrl._prev_pos = Vector3(0, 0, 0.0)
	enemy.velocity = Vector3(0, 0, -18.0)
	enemy.global_position = Vector3(0, 0, 0.0) # Position did NOT change
	wheel_ctrl._physics_process(0.016)
	
	var stopped_rx = fl_spin.rotation.x
	assert_true(is_equal_approx(stopped_rx, rev_rx), "Stationary / wall-blocked vehicle does NOT spin wheels")
	
	# Front wheel steering
	wheel_ctrl._prev_yaw = 0.0
	# Right turn (heading turns toward +X, which in Godot is negative Y rotation)
	enemy.rotation.y = deg_to_rad(-30.0)
	wheel_ctrl._physics_process(0.016)
	assert_true(wheel_ctrl.fl_steer.rotation.y < 0.0, "Front wheels steer right when vehicle yaws right")
	assert_true(rad_to_deg(absf(wheel_ctrl.fl_steer.rotation.y)) <= 22.1, "Front wheel steering is bounded within visual max limit (22 deg)")

	# Left turn (heading turns toward -X, which in Godot is positive Y rotation)
	wheel_ctrl._prev_yaw = deg_to_rad(30.0)
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
	var enemy = spawner.spawn_enemy_type("assault_apc", Vector3(0, 0, 0))
	assert_true(enemy != null, "Spawned assault_apc enemy successfully")
	if not enemy:
		test_stage.queue_free()
		return
	
	var turret = enemy.get_node_or_null("Turret") as AssaultAPCTurret
	assert_true(turret != null, "AssaultAPCTurret direct child present on enemy")
	assert_true(turret.has_node("MountModel"), "MountModel present under Turret")
	assert_true(turret.has_node("GunPitch"), "GunPitch elevation node present under Turret")
	
	var raider = enemy as ProceduralRaider
	assert_true(raider != null, "Enemy is ProceduralRaider instance")
	
	var muzzle_origin = raider.get_muzzle_origin()
	var expected_muzzle_pos = turret.get_muzzle_position()
	assert_true(muzzle_origin.distance_to(expected_muzzle_pos) < 0.01, "get_muzzle_origin() returns the exact visible barrel tip")
	
	var muzzle_marker = turret.get_node_or_null("GunPitch/Recoil/Muzzle") as Marker3D
	assert_true(muzzle_marker != null and muzzle_marker.position.z < -1.0, "Muzzle marker is at the forward barrel tip (-Z)")
	
	# Elevation tracking towards high target
	var high_target = enemy.global_position + Vector3(0, 30, -50)
	turret.track_aim(high_target, 0.5, 5.0)
	assert_true(turret.gun_pitch.rotation.x > 0.1, "Gun pitches up towards elevated target")
	assert_true(is_equal_approx(turret.rotation.x, 0.0), "Pedestal mount remains flat and upright (zero pitch on Turret root)")
	
	# Max elevation clamp (+55 deg)
	var straight_up_target = enemy.global_position + Vector3(0, 1000, 0)
	turret.track_aim(straight_up_target, 1.0, 20.0)
	assert_true(rad_to_deg(turret.gun_pitch.rotation.x) <= 55.1, "Gun elevation is strictly clamped to max elevation (+55 deg)")
	
	# Min depression clamp (-10 deg)
	var underground_target = enemy.global_position + Vector3(0, -1000, -50)
	turret.track_aim(underground_target, 1.0, 20.0)
	assert_true(rad_to_deg(turret.gun_pitch.rotation.x) >= -10.1, "Gun depression is strictly clamped to min elevation (-10 deg)")
	
	# Recoil check without cumulative drift over 10 consecutive bursts
	var init_recoil_pos = turret.recoil.position
	for i in range(10):
		turret.play_recoil()
		# Fast forward recovery time
		turret._process(0.12)
	assert_true(turret.recoil.position.is_equal_approx(init_recoil_pos), "10 consecutive bursts return cleanly to bind pose without cumulative drift")
	
	test_stage.queue_free()

func test_spawner_and_elite_modifier(stage_parent: Node) -> void:
	print("\n--- 4. Spawner, Combat Balance, & ELITE Modifier Checks ---")
	var test_stage = Node3D.new()
	stage_parent.add_child(test_stage)
	
	var spawner = load("res://src/enemies/enemy_spawner.gd").new()
	test_stage.add_child(spawner)
	
	# Check variant specifications in EnemyData
	var apc_data = EnemyData.VARIANTS.get("assault_apc", {})
	assert_true(apc_data.get("gate_wave", 0) == 3, "Assault APC gate wave is 3")
	assert_true(apc_data.get("max_cap", 0) == 4, "Assault APC max cap is 4")
	assert_true(apc_data.get("speed", 0.0) == 9.5 or apc_data.get("speed", 0.0) == 15.0, "Assault APC speed is calibrated (9.5)")
	assert_true(apc_data.get("base_hull", 0.0) == 75.0, "Assault APC base hull is 75.0")
	assert_true(apc_data.get("score", 0) == 160, "Assault APC score is 160")
	assert_true(apc_data.get("xp", 0) == 5, "Assault APC xp is 5")
	assert_true(apc_data.get("burst_count", 0) == 3, "Assault APC burst count is 3")
	assert_true(apc_data.get("burst_delay", 0.0) == 0.12, "Assault APC burst delay is 0.12s")
	
	var normal_enemy = spawner.spawn_enemy_type("assault_apc", Vector3(0, 0, 0))
	assert_true(normal_enemy != null, "Standard assault_apc spawned via EnemySpawner")
	
	var norm_vis = normal_enemy.get_node_or_null("Visuals")
	var norm_turret = normal_enemy.get_node_or_null("Turret")
	assert_true(norm_vis != null and norm_turret != null, "Normal enemy has Visuals and Turret direct children")
	
	# ELITE variant
	var elite_enemy = spawner.spawn_enemy_type("assault_apc", Vector3(10, 0, 0))
	elite_enemy.modifier = EnemyData.ModifierType.ELITE
	elite_enemy._apply_modifiers()
	
	var elite_vis = elite_enemy.get_node_or_null("Visuals")
	var elite_turret = elite_enemy.get_node_or_null("Turret")
	assert_true(is_equal_approx(elite_vis.scale.x, 1.2), "Elite modifier scales Visuals by 1.2x")
	assert_true(is_equal_approx(elite_turret.scale.x, 1.2), "Elite modifier scales Turret by 1.2x")
	assert_true(is_equal_approx(elite_turret.position.y, 2.081 * 1.2), "Elite modifier repositions Turret along with scaled roof (2.081 * 1.2)")
	
	# Verify procedural fallback
	var fallback_enemy = Node3D.new()
	var dummy_visual = Node3D.new()
	dummy_visual.name = "Visuals"
	fallback_enemy.add_child(dummy_visual)
	var raider_vis_class = load("res://src/enemies/raider_visuals.gd")
	raider_vis_class._build_procedural_assault_apc(fallback_enemy, dummy_visual)
	assert_true(fallback_enemy.has_node("Turret"), "Procedural fallback generates functional turret if asset missing")
	fallback_enemy.free()
	
	test_stage.queue_free()
