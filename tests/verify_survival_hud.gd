extends SceneTree
var checks := 0
var failures: Array[String] = []

func _init() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func frames(count: int) -> void:
	for i in count:
		await process_frame

func run() -> void:
	var game = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var manager := root.get_node("GameManager")
	var director := root.get_node("CombatDirector")
	director.is_wave_active = false
	var player: Node3D = game.get_node("PlayerHelicopter")
	player.set_physics_process(false)
	player.is_invulnerable = true
	var camera: Camera3D = player.get_node("PlayerCamera")
	camera.set_process(false)
	var spawner: Node = game.get_node("EnemySpawner")
	spawner.set_process(false)
	await frames(3)
	var hud: Node = game.get_node("UI/CombatHUD")
	var header: Control = hud.survival_overlay
	var radar: Control = hud.get_node("TacticalRadar")
	header.refresh(manager, player)
	check(header.coins_label.text == "0" and header.kills_label.text == "0", "New run starts with empty counters")
	check(header.level_label.text == "LVL 1", "Level comes from the player's progression")
	check(header.level_label.get_theme_font("font") == FloatingText.get_pixel_font(), "HUD uses the exact menu font")
	check(header.hull_bar.size.y <= 18 and header.fuel_bar.size.y <= 6 and header.super_bar.size.y <= 5, "Status bars retain their compact reference proportions")
	check(header.xp_bar.size.x == header.size.x and header.xp_bar.size.y == 7, "XP stripe fills the viewport without covering gameplay")
	manager.run_time = 154
	header.refresh(manager, player)
	check(header.elapsed_label.text == "2:34", "Elapsed time formats minutes and seconds")
	var loot: Node = game.get_node("LootManager")
	var coin = loot.spawn_pickup(Pickup.PickupType.COIN, player.global_position, 5)
	coin._on_body_entered(player)
	coin._on_body_entered(player)
	header.refresh(manager, player)
	check(manager.coins_collected == 5 and manager.banked_credits == 5, "Coin collection updates the real economy once")
	check(header.coins_label.text == "5", "Collected coin value reaches the HUD")
	var building: Node3D
	for block in game.get_node("CityGenerator").spawned_blocks:
		if block is DestructibleBuilding:
			building = block
			break
	building.get_node("DamageReceiver").take_damage(DamageData.new(9999, GameConstants.WeaponType.ROCKET))
	check(manager.kills_count == 0, "Building destruction is excluded from enemy kills")
	var enemy = spawner.spawn_enemy_type("scout_buggy", Vector3(0, 1, -46))
	check(radar.is_alive(enemy), "Living enemies appear on the map")
	enemy.damage_receiver.take_damage(DamageData.new(9999, GameConstants.WeaponType.MISSILE))
	header.refresh(manager, player)
	check(header.kills_label.text == "1" and manager.ground_kills == 1, "Enemy death updates the HUD and correct ground-family count")
	check(not radar.is_alive(enemy), "Dead enemies disappear from the map immediately")
	var installation = load("res://scenes/installations/sam_site.tscn").instantiate()
	game.add_child(installation)
	installation.position = Vector3(-76, 0, -76)
	check(installation.is_in_group("installations") and radar.is_alive(installation), "Actual SAM installation registers as a live minimap marker")
	var xp = loot.spawn_pickup(Pickup.PickupType.XP_GEM, player.global_position, 35)
	xp._on_body_entered(player)
	header.refresh(manager, player)
	check(header.level_label.text == "LVL 3", "Actual XP collection updates level while upgrade choices are open")
	check(is_equal_approx(header.xp_bar.value, 50), "XP bar shows progress within the current level")
	var progression: Node = player.get_node("RunProgression")
	while progression.queued_level_ups > 0:
		progression.apply_upgrade_choice("Field Repair")
	game.get_node("UI/UpgradeDialog").hide()
	director.is_wave_active = true
	manager.change_state(manager.RunState.PAUSED)
	var frozen_time: float = manager.run_time
	var frozen_stage: float = director.wave_timer
	await create_timer(0.18).timeout
	check(is_equal_approx(manager.run_time, frozen_time), "Run timer freezes during pause")
	check(is_equal_approx(director.wave_timer, frozen_stage), "Stage timer freezes during pause")
	manager.change_state(manager.RunState.ACTIVE)
	director.is_wave_active = false
	player.global_position = Vector3(0, 22, 0)
	camera.global_position = Vector3(0, 74, 40)
	camera.look_at(player.global_position)
	radar.update_orientation()
	var north: Vector2 = radar.world_offset_to_map(Vector3(0, 0, -40))
	var east: Vector2 = radar.world_offset_to_map(Vector3(40, 0, 0))
	check(north.y < 0 and absf(north.x) < 0.01, "North projects above the player when looking north")
	check(east.x > 0 and absf(east.y) < 0.01, "East projects right when looking north")
	camera.global_position = Vector3(-40, 74, 0)
	camera.look_at(player.global_position)
	radar.update_orientation()
	east = radar.world_offset_to_map(Vector3(40, 0, 0))
	check(east.y < 0 and absf(east.x) < 0.01, "Map rotates with the camera when facing east")
	check(radar.project_world_position(player.global_position).is_equal_approx(radar.map_center()), "Player remains centered during heading changes")
	var far_marker: Vector2 = radar.project_world_position(Vector3(600, 0, 600), true)
	check(far_marker.distance_to(radar.map_center()) <= radar.radar_radius_pixels - 6, "Far objectives clamp inside the circular bezel")
	var clipped: PackedVector2Array = radar.clip_line_to_circle(Vector2(-200, 0), Vector2(200, 0), 75)
	check(clipped.size() == 2 and clipped[0].is_equal_approx(Vector2(-75, 0)) and clipped[1].is_equal_approx(Vector2(75, 0)), "Road lines are clipped exactly to the circular map")
	check(radar.get_global_rect().position.y == 76 and radar.get_global_rect().end.x <= root.get_visible_rect().size.x, "Minimap fits the upper-right HUD")
	# Capture representative real data and a mixed encounter.
	manager.set_process(false)
	manager.run_time = 154
	director.wave_timer = 25
	spawner.spawn_enemy_type("flak_tank", Vector3(0, 1, -45)).set_physics_process(false)
	spawner.spawn_enemy_type("attack_wing", Vector3(20, 27, -30)).set_physics_process(false)
	loot.spawn_pickup(Pickup.PickupType.COIN, Vector3(-28, 8, -20), 5)
	camera.global_position = Vector3(0, 74, 40)
	camera.look_at(Vector3(0, 17, -10))
	hud._update_survival_layer()
	hud._update_task_layer()
	header.refresh(manager, player)
	await frames(8)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/survival_hud.png")
	manager.start_new_run()
	header.refresh(manager, player)
	check(header.coins_label.text == "0" and header.kills_label.text == "0" and header.elapsed_label.text == "0:00", "Restart clears counters and elapsed time")
	print("SURVIVAL HUD CHECKS: ", checks - failures.size(), "/", checks)
	quit(0 if failures.is_empty() else 1)
