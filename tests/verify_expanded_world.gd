extends SceneTree
var failures: Array[String] = []
var checks := 0

func _init() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)

func run() -> void:
	var game = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var director := root.get_node("CombatDirector")
	director.is_wave_active = false
	var player: CharacterBody3D = game.get_node("PlayerHelicopter")
	player.is_invulnerable = true
	player.set_physics_process(false)
	var city: Node3D = game.get_node("CityGenerator")
	check(city.grid_width == 16 and city.grid_depth == 16, "Expanded city has 256 lots")
	check(game.get_node("Ground/CollisionShape3D").shape.size.x >= 620, "Collision ground covers the expanded city")
	check(city.get_node("FieldDressing/PineCrowns").get_child_count() > 1, "Vegetation has independently culled sectors")
	var buildings: Array[DestructibleBuilding] = []
	for block in city.spawned_blocks:
		if block is DestructibleBuilding:
			buildings.append(block)
	check(buildings.size() > 100, "Expanded area contains generated buildings")
	var building := buildings[0]
	check(building.mesh_instance.mesh.get_surface_count() == 1, "Painted material atlas keeps the building on one render surface")
	check(not building.damage_receiver.is_processing(), "Idle building has no status callback cost")
	var weapon := GameConstants.WeaponType.ROCKET
	var affinity: float = GameConstants.DAMAGE_AFFINITY_MATRIX[weapon][GameConstants.TargetAffinity.STRUCTURE]
	building.damage_receiver.take_damage(DamageData.new(building.max_building_health * 0.65 / affinity, weapon))
	check(building.current_stage == DestructibleBuilding.DestructionStage.DAMAGED, "Merged building becomes damaged through actual combat damage")
	check(building.mesh_instance.material_override == null and building.mesh_instance.get_active_material(0) is ShaderMaterial and building.mesh_instance.get_active_material(0).get_shader_parameter("damage_amount") > 0.0, "Damage keeps the painted atlas and adds isolated scorch artwork")
	building.damage_receiver.take_damage(DamageData.new(building.max_building_health * 2, weapon))
	check(building.current_stage == DestructibleBuilding.DestructionStage.COLLAPSED, "Merged building still collapses")
	check(is_equal_approx(building.collision_shape.shape.size.y, 3.5), "Collapse opens the flight corridor")
	var receiver := DamageReceiver.new()
	root.add_child(receiver)
	check(not receiver.is_processing(), "Inactive receiver starts asleep")
	receiver.apply_emp(0.05)
	check(receiver.is_processing() and receiver.is_emp_disabled, "Status effects wake processing")
	await create_timer(0.15).timeout
	check(not receiver.is_processing() and not receiver.is_emp_disabled, "Expired status returns receiver to sleep")
	player.global_position = Vector3(266, 22, 266)
	player.velocity = Vector3.ZERO
	player._process_flight_physics(0.016)
	check(player.global_position.x > 260 and player.global_position.z > 260, "Player can reach square map corners")
	player.global_position = Vector3(325, 22, 325)
	player._process_flight_physics(0.016)
	check(player.global_position.x <= 304 and player.global_position.z <= 304, "Hard clamp keeps the aircraft inside perimeter walls")
	player.global_position = Vector3(228, 22, 0)
	var spawner: Node = game.get_node("EnemySpawner")
	for role in ["scout_buggy", "attack_wing"]:
		var unit = spawner.spawn_enemy_type(role)
		check(unit != null, "Reinforcements spawn beyond the old map: " + role)
		if unit:
			check(absf(unit.global_position.x) <= 298 and absf(unit.global_position.z) <= 298, "Reinforcements stay within expanded bounds")
	var far_enemy = spawner.spawn_enemy_type("scout_buggy", Vector3(-228, 1, 0))
	await physics_frame
	await physics_frame
	check(not is_instance_valid(far_enemy), "Distant enemy retires to free the encounter budget")
	director._setup_wave(50)
	director.is_wave_active = false
	check(director.target_population == 40, "Endless waves have a bounded simultaneous population")
	var fx := root.get_node("FXManager")
	for i in 24:
		fx.spawn_explosion(Vector3(0, 5, 0))
	check(get_nodes_in_group("combat_explosions").size() <= 16, "Explosion bursts have a bounded visual budget")
	await create_timer(1.6).timeout
	check(get_nodes_in_group("combat_explosions").is_empty(), "Explosion resources are cleaned up")
	if DisplayServer.get_name() != "headless":
		show_all_geometry(game)
		player.get_node("PlayerCamera").set_process(false)
		var camera := Camera3D.new()
		game.add_child(camera)
		camera.position = Vector3(370, 500, 420)
		camera.look_at(Vector3.ZERO)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 730
		camera.far = 1400
		camera.current = true
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/expanded_map.png")
	print("EXPANDED WORLD CHECKS: ", checks - failures.size(), "/", checks)
	quit(0 if failures.is_empty() else 1)

func show_all_geometry(node: Node) -> void:
	if node is GeometryInstance3D:
		node.visibility_range_end = 0
	for child in node.get_children():
		show_all_geometry(child)
