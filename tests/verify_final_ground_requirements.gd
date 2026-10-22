extends SceneTree

## Independent requirements audit. Deliberately reports unmet requirements rather
## than repairing production code or accepting node names as visual evidence.
const Spawner = preload("res://src/enemies/enemy_spawner.gd")
const Receiver = preload("res://src/combat/damage_receiver.gd")
const SharedWheel = preload("res://assets/Enemy/tank_game_ready/universal_wheel_mesh.res")
var checks: Array[Dictionary] = []
var stage: Node3D
var player: CharacterBody3D
var camera: Camera3D
var spawner: Node
var vehicles: Array[Node3D] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String, details: String = "") -> void:
	checks.append({"passed": ok, "requirement": label, "details": details})
	print("PASS " if ok else "FAIL ", label, " ", details)

func freeze(node: Node, disabled: bool) -> void:
	node.set_process(not disabled)
	node.set_physics_process(not disabled)
	for child in node.get_children():
		freeze(child, disabled)

func setup_world() -> void:
	root.get_node("CombatDirector").stop_wave_director()
	root.get_node("GameManager").current_state = 2
	stage = Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 2
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(250, 1, 250)
	collision.shape = box
	collision.position.y = -0.5
	floor_body.add_child(collision)
	stage.add_child(floor_body)
	var floor_visual := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(250, 250)
	floor_visual.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("34454c")
	floor_visual.material_override = material
	stage.add_child(floor_visual)
	player = CharacterBody3D.new()
	player.name = "AuditPlayer"
	player.collision_layer = 1
	player.collision_mask = 0
	player.add_to_group("player")
	player.position = Vector3(0, 10, -25)
	var player_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.8
	player_shape.shape = sphere
	player.add_child(player_shape)
	var receiver := Receiver.new()
	receiver.name = "DamageReceiver"
	receiver.max_health = 1000
	player.add_child(receiver)
	stage.add_child(player)
	spawner = Spawner.new()
	stage.add_child(spawner)
	spawner.set_process(false)
	spawner.set_physics_process(false)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -35, 0)
	sun.light_energy = 1.8
	stage.add_child(sun)
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("18252c")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.7
	world_environment.environment = environment
	stage.add_child(world_environment)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 9
	stage.add_child(camera)
	camera.make_current()

func closest_mesh_vertex(mesh_node: MeshInstance3D, point: Vector3) -> float:
	var closest := INF
	for surface in range(mesh_node.mesh.get_surface_count()):
		var vertices: PackedVector3Array = mesh_node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			closest = minf(closest, mesh_node.to_global(vertex).distance_to(point))
	return closest

func inspect_vehicle(unit: Node3D) -> void:
	var id: String = unit.variant_id
	var visual: Node3D = unit.get_node("Visuals")
	var turret: Node3D = unit.get_node("Turret")
	var hull: MeshInstance3D = visual.get_node("HullModel").get_child(0)
	var nose_direction := (hull.global_basis * Vector3.LEFT).normalized()
	var motion_forward := -unit.global_basis.z.normalized()
	check(nose_direction.dot(motion_forward) > 0.99, id + " source nose points along movement forward", "dot=%.3f" % nose_direction.dot(motion_forward))
	var wheel_nodes: Array[MeshInstance3D] = []
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		if node.name == "WheelModel":
			wheel_nodes.append(node)
	var expected_count := 4 if id == "raptor_raider" else 6
	check(wheel_nodes.size() == expected_count, id + " correct wheel count")
	var shared := true
	for wheel in wheel_nodes:
		shared = shared and wheel.mesh == SharedWheel and wheel.mesh.surface_get_material(0) == SharedWheel.surface_get_material(0)
	check(shared, id + " exact shared wheel mesh AND material")
	var wheel := wheel_nodes[0]
	var radius := wheel.mesh.get_aabb().size.y * wheel.global_basis.y.length() * 0.5
	var configured: float = visual.wheel_radius * unit.scale.x
	check(absf(configured / radius - 1.0) < 0.05, id + " wheel spin radius matches physical wheel size", "controller=%.4f actual=%.4f" % [configured, radius])
	var old_scale := visual.scale
	visual.scale *= 1.2
	var elite_radius := wheel.mesh.get_aabb().size.y * wheel.global_basis.y.length() * 0.5
	check(absf(configured / elite_radius - 1.0) < 0.05, id + " radius accounts for elite visual scale", "controller=%.4f elite_actual=%.4f" % [configured, elite_radius])
	visual.scale = old_scale
	var chassis_controller := false
	for node in unit.find_children("*", "Node3D", true, false):
		var script: Script = node.get_script()
		if script and "chassis" in script.resource_path.to_lower():
			chassis_controller = true
	check(chassis_controller, id + " acceleration/braking chassis controller is wired")
	if id == "raptor_raider":
		var gun: MeshInstance3D = turret.get_node("GunPitch/Recoil/GunModel")
		var muzzle: Marker3D = turret.get_node("GunPitch/Recoil/Muzzle")
		var bore_direction := (gun.global_basis * Vector3.LEFT).normalized()
		var marker_direction := -muzzle.global_basis.z.normalized()
		check(bore_direction.dot(marker_direction) > 0.99, "Raptor actual barrel and muzzle marker point the same way", "dot=%.3f" % bore_direction.dot(marker_direction))
		var gap := closest_mesh_vertex(gun, muzzle.global_position)
		check(gap < 0.2, "Raptor muzzle sits at actual gun geometry", "nearest_vertex=%.3fm" % gap)
	else:
		var tubes: Node3D = turret.get_node("LauncherPitch/Tubes")
		check(tubes.get_child_count() == 8, "Desert has eight tube outlets")
		var start: int = turret._current_tube_index
		for index in range(10):
			turret.get_muzzle_position()
			turret.get_muzzle_transform()
		check(turret._current_tube_index == start, "Desert muzzle queries do not advance sequence")
		var pods: MeshInstance3D = turret.get_node("LauncherPitch/PodModel")
		var max_gap := 0.0
		for tube in tubes.get_children():
			max_gap = maxf(max_gap, closest_mesh_vertex(pods, tube.global_position))
		check(max_gap < 0.2, "Desert tube markers sit on launcher geometry", "worst_nearest_vertex=%.3fm" % max_gap)

func clear_shots() -> void:
	for shot in get_nodes_in_group("enemy_projectiles"):
		shot.free()

func test_live_shot(unit: Node3D) -> void:
	clear_shots()
	var turret: Node3D = unit.get_node("Turret")
	for iteration in range(120):
		turret.track_aim(player.global_position, 0.016, 360.0, 2.0)
	var origin: Vector3 = unit.get_muzzle_origin()
	var old_index: int = turret._current_tube_index if unit.variant_id == "desert_barrage_rover" else 0
	unit._fire_single_shot(player.global_position)
	var shots := get_nodes_in_group("enemy_projectiles")
	check(shots.size() == 1, String(unit.variant_id) + " actual firing emits one projectile")
	if shots.is_empty():
		return
	var shot = shots[0]
	check(shot.global_position.distance_to(origin) < 0.001, String(unit.variant_id) + " shot uses selected pre-emission muzzle")
	if unit.variant_id == "desert_barrage_rover":
		check(shot.profile_id == "enemy_rocket" and shot.blast_radius > 0.0 and shot.damage_data.weapon_type == GameConstants.WeaponType.MISSILE, "Desert shot is a real explosive missile")
		check(turret._current_tube_index == (old_index + 1) % 8, "Desert actual emitted shot advances exactly one tube")
	var receiver: Node = player.get_node("DamageReceiver")
	var health_before: float = receiver.current_health
	for frame in range(90):
		await physics_frame
	check(receiver.current_health < health_before, String(unit.variant_id) + " swept projectile actually damages player", "damage=%.2f" % (health_before - receiver.current_health))

func test_late_unreachable(unit: Node3D) -> void:
	clear_shots()
	var old_player := player.position
	player.position = unit.position + Vector3(0, 100, -5)
	var turret: Node3D = unit.get_node("Turret")
	var reachable: bool = turret.track_aim(player.global_position, 0.05, 150.0, 24.0)
	check(not reachable, String(unit.variant_id) + " detects target above mechanical limit")
	unit.behavior_state = BaseEnemy.BehaviorState.WINDUP
	unit.start_telegraph(0.1, 0.7, Color.RED)
	unit.telegraph_timer = 0.001
	unit.aim_committed = true
	unit.committed_aim_point = player.global_position
	unit._custom_process(0.05)
	var emitted := get_nodes_in_group("enemy_projectiles").size()
	check(emitted == 0, String(unit.variant_id) + " cancels final windup shot when target is mechanically unreachable", "emitted=%d" % emitted)
	unit.clear_telegraph()
	unit._release_all_slots()
	unit.behavior_state = BaseEnemy.BehaviorState.POSITION
	player.position = old_player
	clear_shots()

func test_autonomous_combat(unit: Node3D) -> void:
	clear_shots()
	unit.global_position = Vector3.ZERO
	unit.rotation = Vector3.ZERO
	unit.velocity = Vector3.ZERO
	unit.entry_grace_timer = 0.0
	unit.has_closed_to_attack_range = true
	unit.fire_timer = 0.0
	unit.burst_count = 0
	unit.behavior_state = BaseEnemy.BehaviorState.POSITION
	unit.clear_telegraph()
	player.position = Vector3(0, 10, -30)
	var seen: Dictionary = {}
	freeze(unit, false)
	for frame in range(420):
		await physics_frame
		for shot in get_nodes_in_group("enemy_projectiles"):
			if shot.damage_data and shot.damage_data.attacker == unit:
				seen[shot.get_instance_id()] = true
	freeze(unit, true)
	check(not seen.is_empty(), String(unit.variant_id) + " AI autonomously navigates windup and fires", "observed_shots=%d state=%s" % [seen.size(), unit.not_firing_reason])
	check(unit.global_position.y > -0.1, String(unit.variant_id) + " remains grounded on actual collision floor")
	unit._release_all_slots()
	unit.clear_telegraph()
	clear_shots()
	unit.position = Vector3(80, 0, 0)

func test_death_rewards(unit: Node3D) -> void:
	var gm: Node = root.get_node("GameManager")
	gm.combo_multiplier = 1.0
	gm.combo_count = 0
	var score_before: int = gm.score
	var ground_kills: int = gm.ground_kills
	var xp_manager: Node = root.get_node("XpManager")
	var xp_before: int = xp_manager.total_xp_collected
	var expected_score: int = unit.score_value
	var expected_xp: int = unit.xp_value
	var id: String = unit.variant_id
	var receiver: Node = unit.get_node("DamageReceiver")
	var settlement: Dictionary = {}
	var capture_score: Callable = func(entity: Node, _weapon: String, points: int, _xp: int) -> void:
		if entity == unit:
			settlement["base_score"] = points
	var event_bus: Node = root.get_node("EventBus")
	event_bus.entity_destroyed.connect(capture_score)
	var hit := DamageData.new(100000, GameConstants.WeaponType.MACHINE_GUN, player)
	receiver.take_damage(hit)
	receiver.take_damage(hit)
	event_bus.entity_destroyed.disconnect(capture_score)
	check(gm.ground_kills == ground_kills + 1, id + " lethal damage counts one ground kill only")
	check(settlement.get("base_score", -1) == expected_score, id + " death grants configured score", "base_actual=%d configured=%d run_score_delta_with_combo=%d" % [settlement.get("base_score", -1), expected_score, gm.score - score_before])
	check(xp_manager.total_xp_collected == xp_before, id + " death grants no immediate XP")
	var drops := get_nodes_in_group("xp_drops")
	check(drops.size() == 1 and drops[0].xp_amount == expected_xp, id + " drops correct physical XP gem")
	if drops.size() == 1:
		drops[0]._on_body_entered(player)
		check(xp_manager.total_xp_collected == xp_before + expected_xp, id + " physical collection awards correct XP once")
		if not drops[0].is_queued_for_deletion():
			drops[0].queue_free()
	var coins: Array[Node] = []
	for pickup in get_nodes_in_group("pickups"):
		if pickup.pickup_type == Pickup.PickupType.COIN:
			coins.append(pickup)
	check(coins.size() == 1, id + " death drops one coin pickup")
	if coins.size() == 1:
		var coins_before: int = gm.coins_collected
		coins[0]._collect(player)
		check(gm.coins_collected == coins_before + 5, id + " coin collection updates run total")
	for pickup in get_nodes_in_group("pickups"):
		pickup.queue_free()
	await process_frame

func run() -> void:
	if OS.get_environment("ZIVA_TEST_DATA_DIR").is_empty():
		quit(2)
		return
	setup_world()
	for id in ["raptor_raider", "desert_barrage_rover"]:
		var unit: Node3D = spawner.spawn_enemy_type(id, Vector3(-5 if vehicles.is_empty() else 5, 0, 0), true)
		vehicles.append(unit)
		freeze(unit, true)
		check(not unit.is_air_unit, id + " uses real ground enemy classification")
	await physics_frame
	for unit in vehicles:
		inspect_vehicle(unit)
		for other in vehicles:
			other.visible = other == unit
		camera.look_at_from_position(unit.position + Vector3(8, 6, -10), unit.position + Vector3(0, 1.2, 0))
		await process_frame
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png("res://artifacts/audit-%s-rig.png" % unit.variant_id)
		await test_live_shot(unit)
		test_late_unreachable(unit)
	for unit in vehicles:
		await test_autonomous_combat(unit)
	var loot := LootManager.new()
	stage.add_child(loot)
	for unit in vehicles:
		await test_death_rewards(unit)
	var failures := 0
	for result in checks:
		if not result.passed:
			failures += 1
	var file := FileAccess.open("res://artifacts/final-ground-requirements-audit.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks.size(), "failures": failures, "results": checks}, "\t"))
	file.close()
	print("AUDIT_RESULT checks=", checks.size(), " failures=", failures)
	stage.free()
	current_scene = null
	await process_frame
	quit(0 if failures == 0 else 1)
