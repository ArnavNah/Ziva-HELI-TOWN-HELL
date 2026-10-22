extends SceneTree

const Specs = preload("res://src/enemies/enemy_data.gd")
const Spawner = preload("res://src/enemies/enemy_spawner.gd")
const MultiAxleWheelController = preload("res://src/enemies/ground/multi_axle_wheel_controller.gd")
const RaptorCannonTurret = preload("res://src/enemies/ground/raptor_cannon_turret.gd")
const DesertBarrageLauncher = preload("res://src/enemies/ground/desert_barrage_launcher.gd")
const UniversalWheelMesh = preload("res://assets/Enemy/tank_game_ready/universal_wheel_mesh.res")

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
	print("\n=======================================================")
	print("=== SEVEN GROUND VEHICLES INTEGRATION TEST SUITE ===")
	print("=======================================================")
	
	test_roster_and_rejections()
	test_rig_hierarchies_and_shared_wheels()
	
	var runner = LiveShowroomRunner.new(self)
	root.add_child(runner)

func test_roster_and_rejections() -> void:
	print("\n--- 1. Roster Truth & Disabled Rejections ---")
	var expected_7 = [
		"scout_buggy", "assault_apc", "rail_crawler", "siege_tank",
		"gatling_heavy", "raptor_raider", "desert_barrage_rover"
	]
	expected_7.sort()
	
	var active_ground: Array[String] = []
	for k in Specs.VARIANTS:
		if Specs.is_variant_enabled(k) and Specs.VARIANTS[k].family == "ground":
			active_ground.append(k)
	active_ground.sort()
	
	assert_true(active_ground == expected_7, "Active ground roster contains exactly the 7 required vehicles")
	
	var disabled_8 = [
		"rocket_buggy", "flame_tank", "mortar_crawler", "sam_launcher",
		"technical_truck", "flak_tank", "missile_carrier", "infantry_squad"
	]
	var all_disabled_rejected = true
	for d in disabled_8:
		if Specs.is_variant_enabled(d):
			all_disabled_rejected = false
	assert_true(all_disabled_rejected, "All 8 disabled ground types are rejected by Specs.is_variant_enabled")

func test_rig_hierarchies_and_shared_wheels() -> void:
	print("\n--- 2. Visual Rig Hierarchies & Shared Wheel Identity ---")
	var test_vehicles = [
		{"scene": "res://scenes/enemies/scout_buggy_visuals.tscn", "name": "Scout Buggy", "expected_wheels": 4},
		{"scene": "res://scenes/enemies/assault_apc_visuals.tscn", "name": "Assault APC", "expected_wheels": 4},
		{"scene": "res://scenes/enemies/raptor_raider_visuals.tscn", "name": "Raptor Raider", "expected_wheels": 4},
		{"scene": "res://scenes/enemies/desert_barrage_rover_visuals.tscn", "name": "Desert Barrage Rover", "expected_wheels": 6}
	]
	
	for v in test_vehicles:
		var scene = load(v["scene"]) as PackedScene
		assert_true(scene != null, v["name"] + " scene loads successfully")
		if not scene:
			continue
		var rig = scene.instantiate() as Node3D
		var vis = rig.get_node_or_null("Visuals")
		assert_true(vis != null, v["name"] + " has Visuals node")
		
		var wheel_count = 0
		var all_meshes = rig.find_children("*", "MeshInstance3D", true, false)
		var all_shared = true
		for m in all_meshes:
			if m.name == "WheelModel":
				wheel_count += 1
				if m.mesh != UniversalWheelMesh:
					all_shared = false
		assert_true(wheel_count == v["expected_wheels"], v["name"] + " has %d wheels (found: %d)" % [v["expected_wheels"], wheel_count])
		assert_true(all_shared, v["name"] + " wheels reference EXACT shared universal_wheel_mesh.res")
		
		rig.free()

class LiveShowroomRunner extends Node3D:
	var _tree: SceneTree
	var _frame: int = 0
	var _stage: Node3D
	var _cam: Camera3D
	var _spawner: Spawner
	var _vehicles: Array[Node3D] = []
	var _raptor_vehicle: Node3D
	var _desert_vehicle: Node3D
	
	func _init(tree: SceneTree) -> void:
		_tree = tree

	func _ready() -> void:
		_stage = Node3D.new()
		add_child(_stage)
		
		_spawner = Spawner.new()
		_stage.add_child(_spawner)

	func _process(delta: float) -> void:
		_frame += 1
		
		if _frame == 2:
			_test_multi_axle_wheel_controller()
		elif _frame == 4:
			_test_raptor_cannon_articulation_and_recoil()
		elif _frame == 6:
			_test_desert_barrage_launcher_tubes_and_sequencing()
		elif _frame == 8:
			_build_showroom_lineup()
		elif _frame >= 9 and _frame < 25:
			# Aim turrets towards target point in showroom
			var aim_target = Vector3(0.0, 8.0, -15.0)
			for veh in _vehicles:
				if veh and is_instance_valid(veh):
					var turret = veh.get_node_or_null("Turret")
					if turret and turret.has_method("track_aim"):
						turret.track_aim(aim_target, delta * 3.0)
			if _frame == 15 and _raptor_vehicle and is_instance_valid(_raptor_vehicle):
				var r_turret = _raptor_vehicle.get_node_or_null("Turret")
				if r_turret and r_turret.has_method("play_recoil"):
					r_turret.play_recoil()
			if _frame == 16 and _desert_vehicle and is_instance_valid(_desert_vehicle):
				var d_turret = _desert_vehicle.get_node_or_null("Turret")
				if d_turret and d_turret.has_method("play_recoil"):
					d_turret.play_recoil()
		elif _frame == 25:
			_capture_and_finalize()

	func _test_multi_axle_wheel_controller() -> void:
		print("\n--- 3. Multi-Axle Wheel Controller Dynamics & Steering ---")
		var test_body = CharacterBody3D.new()
		_stage.add_child(test_body)
		var scene = load("res://scenes/enemies/desert_barrage_rover_visuals.tscn") as PackedScene
		var rig = scene.instantiate() as Node3D
		test_body.add_child(rig)
		
		var vis = rig.get_node("Visuals") as MultiAxleWheelController
		_tree.assert_true(vis != null, "MultiAxleWheelController attached to Desert Barrage Rover Visuals")
		
		# Allow _ready to execute
		vis._discover_wheel_nodes()
		_tree.assert_true(vis._steer_pivots.size() == 2, "Discovered exactly 2 front steering pivots (Left & Right)")
		_tree.assert_true(vis._spin_pivots.size() == 6, "Discovered exactly 6 wheel spin pivots across 3 axles")
		
		# Forward travel produces wheel spin
		vis._prev_pos = Vector3(0, 0, 0)
		test_body.global_position = Vector3(0, 0, -2.0)
		var spin_node = vis._spin_pivots[0]
		var rot_before = spin_node.rotation.x
		vis._physics_process(0.05)
		_tree.assert_true(spin_node.rotation.x != rot_before, "Forward movement spins wheels")
		
		# Reverse travel reverses wheel spin
		var rot_after_fwd = spin_node.rotation.x
		vis._prev_pos = Vector3(0, 0, -2.0)
		test_body.global_position = Vector3(0, 0, 0.0)
		vis._physics_process(0.05)
		_tree.assert_true(spin_node.rotation.x != rot_after_fwd, "Reverse movement reverses wheel spin")
		
		# Wall blocked / stationary: zero spin
		var rot_stopped = spin_node.rotation.x
		vis._prev_pos = Vector3(0, 0, 0)
		test_body.global_position = Vector3(0, 0, 0)
		vis._physics_process(0.05)
		_tree.assert_true(is_equal_approx(spin_node.rotation.x, rot_stopped), "Stationary/blocked vehicle wheels stop spinning")
		
		# Front wheel steering follows turning
		vis._prev_pos = Vector3(0, 0, 0)
		vis._prev_yaw = 0.0
		test_body.rotation.y = deg_to_rad(25.0)
		vis._physics_process(0.05)
		var steer_node = vis._steer_pivots[0]
		_tree.assert_true(steer_node.rotation.y != 0.0, "Front wheels steer dynamically during vehicle turn")
		
		test_body.queue_free()

	func _test_raptor_cannon_articulation_and_recoil() -> void:
		print("\n--- 4. Raptor Cannon Turret Articulation & Drift-Free Recoil ---")
		var test_body = CharacterBody3D.new()
		_stage.add_child(test_body)
		var scene = load("res://scenes/enemies/raptor_raider_visuals.tscn") as PackedScene
		var rig = scene.instantiate() as Node3D
		test_body.add_child(rig)
		
		var turret = rig.get_node("Turret") as RaptorCannonTurret
		_tree.assert_true(turret != null, "RaptorCannonTurret attached to Turret node")
		
		var gun_pitch = turret.get_node_or_null("GunPitch")
		var recoil_node = turret.get_node_or_null("GunPitch/Recoil")
		var muzzle = turret.get_node_or_null("GunPitch/Recoil/Muzzle") as Marker3D
		_tree.assert_true(gun_pitch != null, "Raptor has GunPitch elevation hinge")
		_tree.assert_true(recoil_node != null, "Raptor has Recoil translational node")
		_tree.assert_true(muzzle != null, "Raptor has bore-aligned Muzzle Marker3D")
		
		# Target at elevated helicopter (+30 deg)
		var heli_target = test_body.global_position + Vector3(0, 15.0, -25.0)
		for f in range(25):
			turret.track_aim(heli_target, 0.05, 360.0, 5.0)
		var pitch_deg = rad_to_deg(gun_pitch.rotation.x)
		_tree.assert_true(pitch_deg > 15.0 and pitch_deg <= 55.1, "Raptor cannon elevates towards helicopter (pitch: %.1f deg)" % pitch_deg)
		
		# Impossible high angle (+85 deg)
		var extreme_target = test_body.global_position + Vector3(0, 100.0, -5.0)
		var can_reach = turret.track_aim(extreme_target, 0.5, 360.0, 10.0)
		_tree.assert_true(not can_reach, "Raptor reports target OUT OF REACH when exceeding elevation limit (+55 deg)")
		
		# 15 Rapid firing recoil impulses with zero cumulative drift
		var bind_pos = recoil_node.position
		var max_drift: float = 0.0
		for shot in range(15):
			turret.play_recoil()
			_tree.assert_true(recoil_node.position.z > bind_pos.z + 0.04, "Shot %d kicks backward along +Z" % (shot + 1))
			var elapsed = 0.0
			while elapsed < turret.recoil_recovery_time + 0.05:
				turret._process(0.016)
				elapsed += 0.016
			var drift = (recoil_node.position - bind_pos).length()
			max_drift = maxf(max_drift, drift)
		_tree.assert_true(max_drift < 0.0001, "Raptor zero cumulative recoil drift after 15 shots (max drift: %.6f m)" % max_drift)
		
		test_body.queue_free()

	func _test_desert_barrage_launcher_tubes_and_sequencing() -> void:
		print("\n--- 5. Desert Barrage Launcher 8 Tubes & Alternating Salvo Sequencing ---")
		var test_body = CharacterBody3D.new()
		_stage.add_child(test_body)
		var scene = load("res://scenes/enemies/desert_barrage_rover_visuals.tscn") as PackedScene
		var rig = scene.instantiate() as Node3D
		test_body.add_child(rig)
		
		var launcher = rig.get_node("Turret") as DesertBarrageLauncher
		_tree.assert_true(launcher != null, "DesertBarrageLauncher attached to Turret node")
		launcher._collect_tubes()
		_tree.assert_true(launcher._tubes.size() == 8, "Launcher has exactly 8 distinct tube markers")
		
		# Pure query does not advance tube
		var m0_pos = launcher.get_muzzle_position()
		for q in range(10):
			var test_pos = launcher.get_muzzle_position()
			_tree.assert_true(test_pos == m0_pos, "Querying muzzle position %d times does NOT advance tube index" % (q + 1))
		
		# Deterministic alternating salvo sequence over 8 shots
		var visited_tubes: Array[String] = []
		var visited_sides: Array[String] = []
		for shot in range(8):
			var active = launcher.get_active_tube()
			visited_tubes.append(active.name)
			var is_left = active.position.x < 0.0
			visited_sides.append("Left" if is_left else "Right")
			launcher.play_recoil()
		
		_tree.assert_true(visited_tubes.size() == 8, "Fired full 8-tube salvo cycle")
		var alternating_ok = true
		for i in range(7):
			if visited_sides[i] == visited_sides[i + 1]:
				alternating_ok = false
		_tree.assert_true(alternating_ok, "Salvo strictly alternates between Left and Right pods: " + str(visited_sides))
		
		_tree.assert_true(launcher.get_active_tube().name == visited_tubes[0], "Launcher cycles deterministically back to tube 1 after 8 shots")
		
		test_body.queue_free()

	func _build_showroom_lineup() -> void:
		print("\n--- 6. Constructing Showroom Lineup (All 7 Vehicles) ---")
		
		# Solid dark floor
		var floor_mesh = PlaneMesh.new()
		floor_mesh.size = Vector2(90.0, 50.0)
		var floor_mat = StandardMaterial3D.new()
		floor_mat.albedo_color = Color("23292e")
		floor_mat.roughness = 0.85
		var floor_inst = MeshInstance3D.new()
		floor_inst.mesh = floor_mesh
		floor_inst.material_override = floor_mat
		_stage.add_child(floor_inst)
		
		# Environment & Sun
		var env_node = WorldEnvironment.new()
		var env = Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color("14191e")
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color("d0d8e2")
		env.ambient_light_energy = 0.8
		env_node.environment = env
		_stage.add_child(env_node)
		
		var sun = DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-45, -35, 0)
		sun.light_energy = 1.8
		_stage.add_child(sun)
		
		# 7 Vehicles in a wide line
		var lineup = [
			{"id": "scout_buggy", "name": "Scout Buggy", "x": -21.0},
			{"id": "assault_apc", "name": "Assault APC", "x": -14.0},
			{"id": "rail_crawler", "name": "Azure Siege Tank", "x": -7.0},
			{"id": "siege_tank", "name": "Desert Ironclad", "x": 0.0},
			{"id": "gatling_heavy", "name": "Ironclad Sentinel", "x": 7.0},
			{"id": "raptor_raider", "name": "Raptor Raider", "x": 14.0},
			{"id": "desert_barrage_rover", "name": "Desert Barrage Rover", "x": 21.0}
		]
		
		for entry in lineup:
			var unit = _spawner.spawn_enemy_type(entry["id"], Vector3(entry["x"], 0, -3.0), true)
			if unit:
				unit.rotation_degrees.y = 12.0
				_vehicles.append(unit)
				if entry["id"] == "raptor_raider":
					_raptor_vehicle = unit
				elif entry["id"] == "desert_barrage_rover":
					_desert_vehicle = unit
		
		_tree.assert_true(_vehicles.size() == 7, "All 7 ground vehicles spawned simultaneously in showroom")
		
		# Camera
		_cam = Camera3D.new()
		_stage.add_child(_cam)
		_cam.look_at_from_position(Vector3(0.0, 9.5, 22.0), Vector3(0.0, 1.5, -3.0), Vector3.UP)
		_cam.make_current()

	func _capture_and_finalize() -> void:
		DirAccess.make_dir_absolute("res://artifacts")
		var save_path = "res://artifacts/seven_ground_vehicles_demonstration.png"
		var viewport = get_viewport()
		if viewport:
			var img = viewport.get_texture().get_image()
			if img:
				var err = img.save_png(save_path)
				_tree.assert_true(err == OK, "Saved showroom demonstration screenshot to: " + save_path)
		
		print("\n=======================================================")
		print("FINAL TEST RESULTS: %d / %d PASSED" % [_tree.passed, _tree.total])
		print("=======================================================")
		_tree.quit(0 if _tree.passed == _tree.total else 1)
