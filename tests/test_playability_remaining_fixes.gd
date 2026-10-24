extends SceneTree

var failed := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failed += 1

func run() -> void:
	if OS.get_environment("ZIVA_TEST_DATA_DIR").is_empty():
		quit(2)
		return
	root.size = Vector2i(1280, 720)
	var player = load("res://scenes/player/player.tscn").instantiate()
	player.position = Vector3(0, 14, 0)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(player)
	var turret = player.get_node("Turret")
	var camera = player.get_node("PlayerCamera")
	camera.global_position = Vector3(0, 60, 35)
	camera.look_at(Vector3(0, 0, -45))
	camera.current = true
	var enemy := Node3D.new()
	enemy.position = Vector3(0, 0.6, -45)
	root.add_child(enemy)
	enemy.add_to_group("enemies")
	await physics_frame
	var enemy_screen: Vector2 = camera.unproject_position(enemy.global_position)
	turret.update_aim(camera, enemy_screen, player, 1.0)
	check(turret.current_target_node == enemy, "hover assist acquires target")
	var outside_found := false
	for x in range(40, 1240, 10):
		for y in range(40, 680, 10):
			var mouse := Vector2(x, y)
			if mouse.distance_to(enemy_screen) <= 100.0:
				continue
			turret.current_target_node = null
			turret.update_aim(camera, mouse, player, 0.01667)
			if turret.current_target_node == enemy:
				print("OFF_CURSOR_ACQUIRE screen_distance_px=", mouse.distance_to(enemy_screen), " world_distance_m=", Vector2(enemy.position.x - turret.requested_world_point.x, enemy.position.z - turret.requested_world_point.z).length(), " mouse=", mouse)
				outside_found = true
				break
		if outside_found:
			break
	check(not outside_found, "no acquisition outside both 65px acquire / 90px retain radii")
	enemy.position = Vector3(0, 0, -200)
	turret.update_aim(camera, enemy_screen, player, 0.01667)
	check(turret.current_target_node == null, "target outside 140m range releases")
	enemy.position = Vector3(0, 0.6, -45)
	turret.update_aim(camera, enemy_screen, player, 0.01667)
	var enemy_b := Node3D.new()
	enemy_b.position = Vector3(20, 0.6, -45)
	root.add_child(enemy_b)
	enemy_b.add_to_group("enemies")
	turret.enemy_query_timer = 0.0
	var screen_b: Vector2 = camera.unproject_position(enemy_b.global_position)
	turret.update_aim(camera, screen_b, player, 0.01667)
	check(turret.current_target_node == enemy_b, "moving from enemy A to B switches the target immediately")
	enemy_b.queue_free()
	turret.update_aim(camera, screen_b, player, 0.01667)
	check(turret.current_target_node == null, "queued-for-deletion target releases before its node is freed")
	var receiver := DamageReceiver.new()
	receiver.name = "DamageReceiver"
	enemy.add_child(receiver)
	receiver.is_dead = true
	turret.update_aim(camera, enemy_screen, player, 0.01667)
	check(turret.current_target_node == null, "dead target cannot be reacquired")
	receiver.is_dead = false
	var cover := StaticBody3D.new()
	cover.collision_layer = 2
	cover.position = camera.global_position.lerp(enemy.global_position, 0.5)
	var cover_shape := CollisionShape3D.new()
	var cover_box := BoxShape3D.new()
	cover_box.size = Vector3(4, 4, 4)
	cover_shape.shape = cover_box
	cover.add_child(cover_shape)
	root.add_child(cover)
	await physics_frame
	await physics_frame
	turret.update_aim(camera, enemy_screen, player, 0.01667)
	check(turret.current_target_node == null, "world cover breaks assisted target visibility")
	cover.queue_free()
	root.remove_child(enemy)
	turret.update_aim(camera, enemy_screen, player, 0.01667)
	check(turret.current_target_node == null, "target leaving the scene releases without a freed-node error")
	enemy.free()
	turret.yaw_pivot.rotation = Vector3.ZERO
	turret.pitch_pivot.rotation = Vector3.ZERO
	turret.actual_aim_direction = Vector3.FORWARD
	turret.target_world_pos = turret.pitch_pivot.global_position + Vector3.FORWARD * 40
	var pivot: Vector3 = turret.pitch_pivot.global_position
	var muzzle: Vector3 = turret.get_current_muzzle_transform().origin
	print("MUZZLE_OFFSET ", muzzle - pivot)
	var wall := StaticBody3D.new()
	wall.collision_layer = 2
	wall.collision_mask = 0
	wall.position = pivot + Vector3.FORWARD * 0.6
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 3, 0.15)
	shape.shape = box
	wall.add_child(shape)
	root.add_child(wall)
	await physics_frame
	await physics_frame
	turret._update_actual_impact_point(player.get_world_3d().direct_space_state, player)
	var ahead: float = (turret.actual_impact_point - muzzle).dot(Vector3.FORWARD)
	print("IMPACT_DISTANCE_AHEAD_OF_MUZZLE ", ahead)
	check(ahead >= 0, "impact marker does not hit a wall behind the actual shot muzzle")
	wall.queue_free()
	var parent := Node3D.new()
	parent.position = Vector3(100, 20, 50)
	root.add_child(parent)
	var loot = load("res://src/loot/loot_manager.gd").new()
	parent.add_child(loot)
	var intended := Vector3(8, 25, -30)
	var drop = loot.spawn_xp_drop(intended, 1)
	drop.set_physics_process(false)
	print("TRANSLATED_SPAWN intended=", intended, " actual=", drop.global_position)
	check(drop.global_position.distance_to(intended + Vector3(0, 0.5, 0)) < 1.0, "production XP spawn treats supplied position as world coordinates under a translated parent")
	var before: float = drop.global_position.y
	drop._physics_process(0.01667)
	print("TRANSLATED_BOB before_y=", before, " after_y=", drop.global_position.y)
	check(absf(drop.global_position.y - before) < 0.2, "idle bob preserves baseline under translated parent")
	drop.queue_free()
	var gm = root.get_node("GameManager")
	var xp = root.get_node("XpManager")
	xp.reset_run()
	gm.current_state = gm.RunState.ACTIVE
	player.is_dying = true
	var death_drop = load("res://scenes/loot/xp_drop.tscn").instantiate()
	death_drop.xp_amount = 1
	death_drop.position = player.global_position + Vector3(1, 0, 0)
	death_drop.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(death_drop)
	death_drop.start_attraction(player)
	death_drop._physics_process(0.01667)
	print("XP_DURING_DEATH ", xp.total_xp_collected)
	check(xp.total_xp_collected == 0, "dying helicopter cannot collect new XP")
	player.is_dying = false
	var stale_drop = loot.spawn_xp_drop(player.global_position, 3)
	stale_drop.set_physics_process(false)
	xp.reset_run()
	stale_drop._on_body_entered(player)
	check(xp.total_xp_collected == 0, "a previous-run drop cannot award XP to the new run")
	stale_drop.queue_free()
	var contact_drop = loot.spawn_xp_drop(player.global_position, 1)
	contact_drop.set_physics_process(false)
	contact_drop._on_body_entered(player)
	contact_drop._on_body_entered(player)
	check(xp.total_xp_collected == 1, "physical body contact awards XP once without prior magnet attraction")
	var supply = loot.spawn_pickup(loot.PickupClass.PickupType.XP_GEM, intended, 1)
	supply.set_process(false)
	var supply_y: float = supply.global_position.y
	supply._process(0.01667)
	check(supply.global_position.distance_to(intended + Vector3(0, 0.5, 0)) < 2.3 and absf(supply.global_position.y - supply_y) < 0.2, "legacy pickups also preserve world placement and idle baseline under translated parents")
	xp.reset_run()
	supply._collect(player)
	check(xp.total_xp_collected == 0, "legacy pickup cannot transfer rewards across runs")
	supply.queue_free()
	var ui = load("res://src/ui/level_up_ui.gd").new()
	root.add_child(ui)
	player.is_dying = true
	xp.add_xp(25)
	ui._process(1.0)
	check(not ui.visible and not paused, "earned level cannot pause an active death animation")
	xp.reset_run()
	player.is_dying = false
	xp.add_xp(25)
	ui._process(0.20)
	gm.change_state(gm.RunState.PAUSED)
	var delay: float = ui.presentation_delay_remaining
	ui._process(2.0)
	check(is_equal_approx(ui.presentation_delay_remaining, delay) and not ui.visible, "pause freezes pending draft presentation")
	gm.change_state(gm.RunState.ACTIVE)
	ui._process(0.20)
	check(ui.visible and paused, "draft resumes after its remaining presentation delay")
	player.is_dying = true
	ui._on_card_clicked(0)
	check(not ui.visible and not paused and xp.queued_level_ups == 1, "death dismisses an open draft without applying or consuming its queued choice")
	xp.reset_run()
	ui.queue_free()
	await verify_building_cache()
	player.queue_free()
	parent.queue_free()
	await process_frame
	print("EDGE_CASE_RESULTS checks=", checks, " failed=", failed)
	await load("res://tests/runtime_cleanup.gd").finish(self, 0 if failed == 0 else 1)

func verify_building_cache() -> void:
	var buildings: Array[Node] = []
	var colors_ok := true
	for index in 6:
		var b = load("res://scenes/world/destructible_building.tscn").instantiate()
		b.archetype = "townhouse"
		b.position = Vector3(index * 24.0, 0, 12)
		root.add_child(b)
		buildings.append(b)
		var gx := roundi(b.position.x / 12.0)
		var gz := roundi(b.position.z / 12.0)
		var h := absi((gx * 73856093) ^ (gz * 19349663) ^ roundi(b.building_width * 31.0 + b.building_height * 17.0))
		var raw = load("res://src/world/detail_mesh.gd").new()
		b._build_archetype_geometry(raw, "townhouse", h, float(h % 1000) / 1000.0)
		var cached_colors = b.mesh_instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		var reference: ArrayMesh = raw.build()
		colors_ok = colors_ok and cached_colors == reference.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	check(colors_ok, "cached houses preserve each location's intended siding and roof colors")
	var a = buildings[0]
	var b = load("res://scenes/world/destructible_building.tscn").instantiate()
	b.archetype = a.archetype
	b.position = a.position
	root.add_child(b)
	buildings.append(b)
	check(a.mesh_instance.mesh == b.mesh_instance.mesh and a.collision_shape.shape == b.collision_shape.shape, "identical intact buildings still share immutable mesh and collision resources")
	var size_before: Vector3 = b.collision_shape.shape.size
	a.current_stage = a.DestructionStage.COLLAPSED
	a._update_visuals_and_collision()
	check(b.collision_shape.shape.size == size_before and a.collision_shape.shape != b.collision_shape.shape, "collapsing one building never mutates another building's cached shape")
	var c = load("res://scenes/world/destructible_building.tscn").instantiate()
	c.building_width = b.building_width + 0.01
	root.add_child(c)
	buildings.append(c)
	check(c.collision_shape.shape != b.collision_shape.shape and is_equal_approx(c.collision_shape.shape.size.x, c.building_width), "close but different dimensions do not alias a rounded collision cache key")
	for building in buildings:
		building.queue_free()
	await process_frame
