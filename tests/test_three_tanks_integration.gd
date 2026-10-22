extends SceneTree

const TankModelConfig = preload("res://src/enemies/ground/tank_model_config.gd")
const TankChassisController = preload("res://src/enemies/ground/tank_chassis_controller.gd")
const ArticulatedTankTurret = preload("res://src/enemies/ground/articulated_tank_turret.gd")
const EnemySpawner = preload("res://src/enemies/enemy_spawner.gd")
const EnemyData = preload("res://src/enemies/enemy_data.gd")
const ProceduralRaider = preload("res://src/enemies/procedural_raider.gd")
const SiegeTank = preload("res://src/enemies/ground/siege_tank.gd")
const GatlingHeavy = preload("res://src/enemies/ground/gatling_heavy.gd")

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
	print("\n=== THREE MODULAR ARTICULATED TANKS INTEGRATION TEST SUITE ===")
	test_rig_structures()
	
	var runner = LiveDemoRunner.new(self)
	root.add_child(runner)

func test_rig_structures() -> void:
	print("\n--- 1. Visual Rig Scene Structures & Meshes ---")
	var rigs = [
		{
			"scene": "res://scenes/enemies/azure_siege_tank_visuals.tscn",
			"name": "Azure Siege Tank (Rail Crawler)",
			"has_barrels": false,
		},
		{
			"scene": "res://scenes/enemies/desert_ironclad_visuals.tscn",
			"name": "Desert Ironclad (Siege Tank)",
			"has_barrels": false,
		},
		{
			"scene": "res://scenes/enemies/ironclad_sentinel_visuals.tscn",
			"name": "Ironclad Sentinel (Gatling Heavy)",
			"has_barrels": true,
		}
	]

	for r in rigs:
		var scene = load(r["scene"]) as PackedScene
		assert_true(scene != null, r["name"] + " scene loads successfully")
		if not scene:
			continue
		var rig = scene.instantiate()
		var vis = rig.get_node_or_null("Visuals")
		var turret = rig.get_node_or_null("Turret")
		assert_true(vis != null, r["name"] + " has Visuals node")
		assert_true(turret != null, r["name"] + " has Turret node")
		assert_true(vis.get_script() == TankChassisController, r["name"] + " Visuals has TankChassisController")
		assert_true(turret.get_script() == ArticulatedTankTurret, r["name"] + " Turret has ArticulatedTankTurret")

		# Check Hull and Body mesh
		var hull = vis.get_node_or_null("ChassisMotion/HullModel")
		assert_true(hull != null, r["name"] + " has ChassisMotion/HullModel")
		var body_mesh = hull.get_node_or_null("Tank_Body") as MeshInstance3D if hull else null
		assert_true(body_mesh != null and body_mesh.mesh != null, r["name"] + " has Tank_Body with valid mesh")

		# Check Turret and Gun hierarchy
		var mount = turret.get_node_or_null("MountModel/Tank_Turret") as MeshInstance3D
		assert_true(mount != null and mount.mesh != null, r["name"] + " has Tank_Turret with valid mesh")
		var gun_pitch = turret.get_node_or_null("GunPitch")
		assert_true(gun_pitch != null, r["name"] + " has GunPitch elevation hinge")
		var recoil = gun_pitch.get_node_or_null("Recoil") if gun_pitch else null
		assert_true(recoil != null, r["name"] + " has Recoil translational node")
		var muzzle = recoil.get_node_or_null("Muzzle") as Marker3D if recoil else null
		assert_true(muzzle != null, r["name"] + " has Muzzle Marker3D under Recoil")

		if r["has_barrels"]:
			var housing = recoil.get_node_or_null("GunHousingModel/Tank_GunHousing") as MeshInstance3D
			assert_true(housing != null and housing.mesh != null, r["name"] + " has isolated fixed gun housing")
			var b_spin = recoil.get_node_or_null("BarrelSpin")
			assert_true(b_spin != null, r["name"] + " has BarrelSpin rotary node")
			var barrels = b_spin.get_node_or_null("Tank_GunBarrels") as MeshInstance3D if b_spin else null
			assert_true(barrels != null and barrels.mesh != null, r["name"] + " has Tank_GunBarrels mesh under BarrelSpin")
		else:
			var gun_mesh = recoil.get_node_or_null("GunModel/Tank_Gun") as MeshInstance3D
			assert_true(gun_mesh != null and gun_mesh.mesh != null, r["name"] + " has Tank_Gun with valid mesh")

		rig.free()

func test_turret_elevation_and_yaw(stage_parent: Node) -> void:
	print("\n--- 2. Turret Yaw, Elevation Clamps, & Out-Of-Reach Reporting ---")
	var test_stage = Node3D.new()
	stage_parent.add_child(test_stage)
	var spawner = EnemySpawner.new()
	test_stage.add_child(spawner)

	var tanks_to_test = [
		{"role": "rail_crawler", "min_pitch": -8.0, "max_pitch": 45.0, "name": "Azure"},
		{"role": "siege_tank", "min_pitch": -7.0, "max_pitch": 50.0, "name": "Desert"},
		{"role": "gatling_heavy", "min_pitch": -10.0, "max_pitch": 55.0, "name": "Sentinel"},
	]

	for t in tanks_to_test:
		var enemy = spawner.spawn_enemy_type(t["role"], Vector3(0, 0, 0))
		assert_true(enemy != null, "Spawned " + t["name"] + " (" + t["role"] + ")")
		if not enemy:
			continue
		var turret = enemy.get_node_or_null("Turret") as ArticulatedTankTurret
		assert_true(turret != null, t["name"] + " has ArticulatedTankTurret")
		if not turret:
			enemy.queue_free()
			continue

		var gun_pitch = turret.get_node_or_null("GunPitch")

		# Target at high elevation within mechanical limits (+30 deg)
		var valid_target = enemy.global_position + Vector3(0, 15.0, -25.0)
		for f in range(20):
			turret.track_aim(valid_target, 0.05, 360.0, 5.0)
		var pitch_deg = rad_to_deg(gun_pitch.rotation.x)
		assert_true(pitch_deg > 15.0 and pitch_deg < t["max_pitch"] + 0.1, t["name"] + " pitches up towards valid elevated target (actual: %.1f deg)" % pitch_deg)

		# Extreme high target (outside mechanical elevation limits: +80 deg)
		var extreme_high = enemy.global_position + Vector3(0, 100.0, -10.0)
		var high_aligned = turret.track_aim(extreme_high, 0.5, 360.0, 15.0)
		var max_clamped = rad_to_deg(gun_pitch.rotation.x)
		assert_true(max_clamped <= t["max_pitch"] + 0.1, t["name"] + " strictly clamps gun to max elevation (clamped: %.1f, limit: %.1f)" % [max_clamped, t["max_pitch"]])
		assert_true(not high_aligned, t["name"] + " correctly reports target is OUT OF MECHANICAL REACH when exceeding elevation limit")

		# Extreme low target (outside depression limit: -45 deg)
		var extreme_low = enemy.global_position + Vector3(0, -60.0, -10.0)
		var low_aligned = turret.track_aim(extreme_low, 0.5, 360.0, 15.0)
		var min_clamped = rad_to_deg(gun_pitch.rotation.x)
		assert_true(min_clamped >= t["min_pitch"] - 0.1, t["name"] + " strictly clamps gun to min depression (clamped: %.1f, limit: %.1f)" % [min_clamped, t["min_pitch"]])
		assert_true(not low_aligned, t["name"] + " correctly reports target is OUT OF MECHANICAL REACH when below depression limit")

		# Yaw 360 tracking (target to the right +X)
		var right_target = enemy.global_position + Vector3(50.0, 0.0, 0.0)
		for f in range(30):
			turret.track_aim(right_target, 0.05, 360.0, 5.0)
		assert_true(turret.rotation.y < 0.0, t["name"] + " yaws turret right towards +X target")

		enemy.queue_free()

	test_stage.queue_free()

func test_recoil_and_zero_drift(stage_parent: Node) -> void:
	print("\n--- 3. Firing Recoil Translation & Zero Cumulative Drift Over 15 Shots ---")
	var test_stage = Node3D.new()
	stage_parent.add_child(test_stage)
	var spawner = EnemySpawner.new()
	test_stage.add_child(spawner)

	var enemy = spawner.spawn_enemy_type("siege_tank", Vector3(0, 0, 0))
	var turret = enemy.get_node_or_null("Turret") as ArticulatedTankTurret
	assert_true(turret != null, "ArticulatedTankTurret present for recoil test")
	var recoil_node = turret.get_node_or_null("GunPitch/Recoil")
	var bind_pos: Vector3 = recoil_node.position

	# Test 15 rapid consecutive firing impulses
	var max_drift: float = 0.0
	for shot in range(15):
		turret.play_recoil()
		# Check kick displacement
		assert_true(recoil_node.position.z > bind_pos.z + 0.05, "Shot %d kicks along local +Z" % (shot + 1))
		# Run full recovery duration
		var rec_time = turret.config.recoil_recovery_time if turret.config else 0.28
		var elapsed = 0.0
		while elapsed < rec_time + 0.05:
			turret._process(0.016)
			elapsed += 0.016
		var drift = (recoil_node.position - bind_pos).length()
		max_drift = maxf(max_drift, drift)

	assert_true(max_drift < 0.0001, "Zero cumulative recoil drift after 15 shots (max drift: %.6f m)" % max_drift)
	enemy.queue_free()
	test_stage.queue_free()

func test_sentinel_rotary_barrels(stage_parent: Node) -> void:
	print("\n--- 4. Sentinel Rotary Barrel Isolation & Spin Acceleration ---")
	var test_stage = Node3D.new()
	stage_parent.add_child(test_stage)
	var spawner = EnemySpawner.new()
	test_stage.add_child(spawner)

	var sentinel = spawner.spawn_enemy_type("gatling_heavy", Vector3(0, 0, 0)) as GatlingHeavy
	assert_true(sentinel != null, "Spawned GatlingHeavy instance")
	var turret = sentinel.get_node_or_null("Turret") as ArticulatedTankTurret
	assert_true(turret != null, "ArticulatedTankTurret present on GatlingHeavy")
	var b_spin = turret.get_node_or_null("GunPitch/Recoil/BarrelSpin")
	var housing = turret.get_node_or_null("GunPitch/Recoil/GunHousingModel")
	assert_true(b_spin != null, "BarrelSpin node present under Recoil")
	assert_true(housing != null, "Fixed GunHousingModel present under Recoil")

	# 1. Rest state
	var initial_rot = b_spin.rotation.z
	var initial_housing_rot = housing.rotation
	turret._process(0.1)
	assert_true(is_equal_approx(b_spin.rotation.z, initial_rot), "Barrels do not spin while at rest")

	# 2. Windup spin
	turret.set_barrel_spin_speed(28.0)
	for f in range(35):
		turret._process(0.016)
	assert_true(turret._current_barrel_spin > 15.0, "Barrel spin accelerates towards windup speed (current: %.1f)" % turret._current_barrel_spin)
	assert_true(not is_equal_approx(b_spin.rotation.z, initial_rot), "BarrelSpin node has rotated around bore axis")
	assert_true(housing.rotation.is_equal_approx(initial_housing_rot), "Fixed gun housing mantlet remains stationary while barrels spin")

	# 3. Fire spin
	turret.set_barrel_spin_speed(42.0)
	for f in range(35):
		turret._process(0.016)
	assert_true(turret._current_barrel_spin > 28.0, "Barrel spin accelerates to full fire speed (current: %.1f)" % turret._current_barrel_spin)

	# 4. Spin down to rest
	turret.set_barrel_spin_speed(0.0)
	for f in range(120):
		turret._process(0.016)
	assert_true(turret._current_barrel_spin < 0.1, "Barrel spin smoothly decelerates back to rest")

	sentinel.queue_free()
	test_stage.queue_free()

func test_chassis_dynamics_and_turret_sync(stage_parent: Node) -> void:
	print("\n--- 5. Chassis Dynamics (Pitch, Roll, Settling) & Turret Mount Sync ---")
	var test_stage = Node3D.new()
	stage_parent.add_child(test_stage)
	var spawner = EnemySpawner.new()
	test_stage.add_child(spawner)

	var enemy = spawner.spawn_enemy_type("siege_tank", Vector3(0, 0, 0))
	var vis = enemy.get_node_or_null("Visuals")
	var chassis_ctrl = vis as TankChassisController
	var turret = enemy.get_node_or_null("Turret") as ArticulatedTankTurret
	assert_true(chassis_ctrl != null, "TankChassisController present on Visuals")
	assert_true(turret != null, "ArticulatedTankTurret present on Turret")

	var initial_turret_y = turret.position.y
	var chassis_motion = chassis_ctrl.chassis_motion

	# Simulate Forward Acceleration
	chassis_ctrl._prev_pos = Vector3(0, 0, 0)
	chassis_ctrl._prev_speed = 0.0
	enemy.global_position = Vector3(0, 0, -2.0)
	chassis_ctrl._physics_process(0.05)

	assert_true(chassis_motion.rotation.x != 0.0, "Chassis pitches during acceleration/braking")
	assert_true(is_equal_approx(turret.rotation.x, chassis_motion.rotation.x), "Turret pitches in lockstep with chassis roof (no gap)")

	# Simulate Turning Roll
	chassis_ctrl._prev_yaw = 0.0
	enemy.rotation.y = deg_to_rad(-45.0) # Right turn
	chassis_ctrl._physics_process(0.05)
	assert_true(chassis_motion.rotation.z != 0.0, "Chassis rolls during turn inertia")
	assert_true(is_equal_approx(turret.rotation.z, chassis_motion.rotation.z), "Turret rolls in lockstep with chassis roof (no gap)")

	# Settle to Rest when stationary
	enemy.global_position = Vector3(0, 0, 0)
	chassis_ctrl._prev_pos = Vector3(0, 0, 0)
	chassis_ctrl._prev_speed = 0.0
	enemy.rotation = Vector3.ZERO
	chassis_ctrl._prev_yaw = 0.0
	for f in range(60):
		chassis_ctrl._physics_process(0.016)

	assert_true(absf(chassis_motion.rotation.x) < 0.001, "Chassis pitch settles back to zero at rest")
	assert_true(absf(chassis_motion.rotation.z) < 0.001, "Chassis roll settles back to zero at rest")
	assert_true(is_equal_approx(turret.position.y, initial_turret_y), "Turret returns cleanly to bind pose height")

	enemy.queue_free()
	test_stage.queue_free()

func test_spawner_and_elite_scaling(stage_parent: Node) -> void:
	print("\n--- 6. Spawner Integration & ELITE 1.2x Scaling Verification ---")
	var test_stage = Node3D.new()
	stage_parent.add_child(test_stage)
	var spawner = EnemySpawner.new()
	test_stage.add_child(spawner)

	var roles = ["rail_crawler", "siege_tank", "gatling_heavy"]
	for role in roles:
		# Standard enemy
		var standard = spawner.spawn_enemy_type(role, Vector3(0, 0, 0))
		assert_true(standard != null, "Standard " + role + " spawned via EnemySpawner")
		var std_vis = standard.get_node_or_null("Visuals")
		var std_turret = standard.get_node_or_null("Turret")
		assert_true(std_vis != null and std_turret != null, role + " has both Visuals and Turret direct children")

		# Check that no old procedural box meshes remain under Visuals
		var box_meshes = 0
		for c in std_vis.get_children():
			if c is MeshInstance3D and c.mesh is BoxMesh:
				box_meshes += 1
		assert_true(box_meshes == 0, role + " has NO leftover procedural box meshes under Visuals")

		# ELITE enemy
		var elite = spawner.spawn_enemy_type(role, Vector3(5, 0, 0))
		elite.modifier = EnemyData.ModifierType.ELITE
		elite._apply_modifiers()
		var elite_vis = elite.get_node_or_null("Visuals")
		var elite_turret = elite.get_node_or_null("Turret")
		assert_true(elite_vis.scale.is_equal_approx(Vector3(1.2, 1.2, 1.2)), role + " ELITE scales Visuals by 1.2x")
		assert_true(elite_turret.scale.is_equal_approx(Vector3(1.2, 1.2, 1.2)), role + " ELITE scales Turret by 1.2x")
		assert_true(is_equal_approx(elite_turret.position.y, std_turret.position.y * 1.2), role + " ELITE scales Turret roof mount height by 1.2x")

		standard.queue_free()
		elite.queue_free()

	test_stage.queue_free()

class LiveDemoRunner extends Node:
	var _tree: SceneTree
	var _frame: int = 0
	var _scene_root: Node3D
	var _cam: Camera3D
	var _azure_tank: Node3D
	var _desert_tank: Node3D
	var _sentinel_tank: Node3D
	var _player: Node3D

	func _init(t: SceneTree) -> void:
		_tree = t

	func _ready() -> void:
		call_deferred("_start_suite")

	func _start_suite() -> void:
		_tree.test_turret_elevation_and_yaw(self)
		_tree.test_recoil_and_zero_drift(self)
		_tree.test_sentinel_rotary_barrels(self)
		_tree.test_chassis_dynamics_and_turret_sync(self)
		_tree.test_spawner_and_elite_scaling(self)

		print("\n--- 7. Live In-Game Combat Demonstration & Visual Verification ---")
		_scene_root = Node3D.new()
		add_child(_scene_root)

		var light = DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-45, 40, 0)
		light.light_energy = 1.3
		_scene_root.add_child(light)

		var env = WorldEnvironment.new()
		var env_res = Environment.new()
		env_res.background_mode = Environment.BG_COLOR
		env_res.background_color = Color(0.18, 0.22, 0.26)
		env_res.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env_res.ambient_light_color = Color(0.35, 0.38, 0.42)
		env.environment = env_res
		_scene_root.add_child(env)

		var ground = MeshInstance3D.new()
		var pm = PlaneMesh.new()
		pm.size = Vector2(100, 100)
		ground.mesh = pm
		var g_mat = StandardMaterial3D.new()
		g_mat.albedo_color = Color(0.24, 0.26, 0.22)
		g_mat.roughness = 0.9
		ground.material_override = g_mat
		_scene_root.add_child(ground)
		# The live demo needs a physical floor so gravity cannot pull the tanks
		# beneath the visible plane before the screenshot is captured.
		var floor_body = StaticBody3D.new()
		floor_body.collision_layer = 2
		var floor_collision = CollisionShape3D.new()
		var floor_shape = BoxShape3D.new()
		floor_shape.size = Vector3(100, 0.5, 100)
		floor_collision.shape = floor_shape
		floor_collision.position.y = -0.25
		floor_body.add_child(floor_collision)
		_scene_root.add_child(floor_body)

		# Player target in the sky
		_player = Node3D.new()
		_player.name = "PlayerHelicopter"
		_player.add_to_group("player")
		_player.position = Vector3(0.0, 14.0, -18.0)
		_scene_root.add_child(_player)

		# Camera positioned to view all three tanks side by side
		_cam = Camera3D.new()
		_scene_root.add_child(_cam)
		_cam.look_at_from_position(Vector3(0.0, 9.0, 16.0), Vector3(0.0, 2.0, -4.0), Vector3.UP)
		_cam.make_current()

		var spawner = EnemySpawner.new()
		_scene_root.add_child(spawner)

		# Spawn all three tanks lined up
		# 1. Azure (Rail Crawler) on the left
		_azure_tank = spawner.spawn_enemy_type("rail_crawler", Vector3(-8.5, 0.0, -4.0))
		# 2. Desert (Siege Tank) in the center
		_desert_tank = spawner.spawn_enemy_type("siege_tank", Vector3(0.0, 0.0, -4.0))
		# 3. Sentinel (Gatling Heavy) on the right
		_sentinel_tank = spawner.spawn_enemy_type("gatling_heavy", Vector3(8.5, 0.0, -4.0))

	func _process(delta: float) -> void:
		if not _scene_root:
			return
		_frame += 1

		# Aim turrets towards the airborne player
		var tanks = [_azure_tank, _desert_tank, _sentinel_tank]
		for t in tanks:
			if t and is_instance_valid(t):
				var turret = t.get_node_or_null("Turret") as ArticulatedTankTurret
				if turret and _player:
					turret.track_aim(_player.global_position, delta * 3.0)

		# Trigger recoil and barrel spin for combat pose
		if _frame == 10:
			if _desert_tank:
				var t_desert = _desert_tank.get_node_or_null("Turret") as ArticulatedTankTurret
				if t_desert:
					t_desert.play_recoil()
			if _sentinel_tank:
				var t_sentinel = _sentinel_tank.get_node_or_null("Turret") as ArticulatedTankTurret
				if t_sentinel:
					t_sentinel.set_barrel_spin_speed(42.0)
			if _azure_tank:
				var t_azure = _azure_tank.get_node_or_null("Turret") as ArticulatedTankTurret
				if t_azure:
					t_azure.play_recoil()

		if _frame == 25:
			_tree.assert_true(is_instance_valid(_azure_tank) and _azure_tank.global_position.y >= -0.5, "Azure remains above the demonstration floor")
			_tree.assert_true(is_instance_valid(_desert_tank) and _desert_tank.global_position.y >= -0.5, "Desert remains above the demonstration floor")
			_tree.assert_true(is_instance_valid(_sentinel_tank) and _sentinel_tank.global_position.y >= -0.5, "Sentinel remains above the demonstration floor")
			if DisplayServer.get_name() == "headless":
				print("Skipping screenshot capture on headless renderer")
				_tree.quit(0 if _tree.passed == _tree.total else 1)
				return
			DirAccess.make_dir_absolute("res://artifacts")
			var img = get_viewport().get_texture().get_image()
			var save_path = "res://artifacts/three_tanks_demonstration.png"
			var err = img.save_png(save_path)
			_tree.assert_true(err == OK, "Saved three tanks combat demonstration screenshot to: " + save_path)

			print("\n=== FINAL TEST SUMMARY: %d/%d PASSED ===" % [_tree.passed, _tree.total])
			if _tree.passed == _tree.total:
				print("ALL THREE TANKS INTEGRATION CHECKS PASSED PERFECTLY!\n")
				_tree.quit(0)
			else:
				print("SOME CHECKS FAILED!\n")
				_tree.quit(1)
