extends SceneTree
## Actual main scene, city, player controller and chase camera. Isolated saves.
const ROLES := ["attack_gunship", "rocket_gunship", "interceptor", "escort_fighter", "attack_wing", "heavy_bomber", "torpedo_vtol", "stealth_vtol", "minelayer"]
var samples: Array = []
var actors: Array[Node3D] = []
var game: Node3D
var player: Node3D
var spawner: Node
var director: Node
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func capture(name: String) -> void:
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://artifacts/air-model-review/" + name + ".png")
func sample(count: int, n: int) -> void:
	var milliseconds: Array[float] = []
	var draws: Array[float] = []
	var primitives: Array[float] = []
	for i in n:
		var start := Time.get_ticks_usec()
		await process_frame
		milliseconds.append((Time.get_ticks_usec() - start) / 1000.0)
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	milliseconds.sort()
	var record := {"aircraft":count,"frames":n,"median_frame_ms":milliseconds[n/2],"p95_frame_ms":milliseconds[int(n*.95)],"mean_draw_calls":0.0,"mean_primitives":0.0}
	for x in draws: record.mean_draw_calls += x / n
	for x in primitives: record.mean_primitives += x / n
	samples.append(record)
	print("AIR_RENDER_MEASUREMENT ", JSON.stringify(record))
func spawn_group(count: int) -> void:
	for i in count:
		var angle := TAU * float(i) / count
		var pos := player.global_position + Vector3(sin(angle) * 32, 5 + (i % 3) * 3, cos(angle) * 32)
		var enemy = spawner.spawn_enemy_type(ROLES[i % ROLES.size()], pos, true)
		if enemy:
			actors.append(enemy)
			enemy.entry_grace_timer = 0.25
			enemy.rotation.y = atan2(pos.x - player.position.x, pos.z - player.position.z)
func clear_group() -> void:
	for actor in actors:
		if is_instance_valid(actor): actor.queue_free()
	actors.clear()
	for shot in get_nodes_in_group("combat_projectiles"): shot.queue_free()

func run() -> void:
	if DisplayServer.get_name() == "headless" or OS.get_environment("ZIVA_TEST_DATA_DIR").is_empty():
		quit(2)
		return
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	var gm := root.get_node("GameManager")
	gm.selected_biome = "town"
	gm.selected_aircraft = "apache"
	game = preload("res://scenes/main_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 2400:
		await process_frame
		if game.is_prepared: break
	if not game.is_prepared:
		print("FAIL main game preparation timed out")
		quit(1)
		return
	player = game.get_node("PlayerHelicopter")
	player.debug_invulnerable = true
	player.position = Vector3(0, 30, 0)
	director = root.get_node("CombatDirector")
	director.current_wave = 20
	director.is_wave_active = true
	director.target_population = 30
	director.wave_timer = 999
	director.set_process(false)
	spawner = game.get_node("EnemySpawner")
	spawner.set_process(false)
	for actor in get_nodes_in_group("enemies"): actor.queue_free()
	if "--boss-only" in OS.get_cmdline_user_args():
		await frames(3)
		player.set_physics_process(false)
		player.get_node("PlayerCamera").init_camera(player)
		director.current_wave = 10
		director.wave_boss_spawned = false
		director._check_wave_10_boss()
		var staged_bosses := get_nodes_in_group("bosses")
		if staged_bosses.is_empty():
			quit(1)
			return
		var staged_boss = staged_bosses[0]
		staged_boss.global_position = player.global_position + Vector3(8,3,-14)
		staged_boss._begin_telegraph(7,115)
		await frames(8)
		await capture("gameplay-boss-warning")
		staged_boss.damage_receiver.take_damage(DamageData.new(140,GameConstants.WeaponType.MACHINE_GUN,null))
		staged_boss.damage_receiver.take_damage(DamageData.new(60,GameConstants.WeaponType.MACHINE_GUN,null))
		staged_boss._begin_telegraph(9,135)
		await frames(8)
		await capture("gameplay-boss-final-phase")
		gm.current_state = gm.RunState.MENU
		quit(0)
		return
	await frames(90)
	print("Actual camera: ", root.get_camera_3d().get_script().resource_path)
	await sample(0,120)
	for role in ROLES:
		var actual = spawner.spawn_enemy_type(role)
		print("AIR_CITY_PUBLIC_SPAWN role=", role, " success=", actual != null, " position=", actual.global_position if actual else Vector3.INF)
		if actual: actors.append(actual)
	clear_group()
	await frames(3)
	spawn_group(9)
	await frames(120)
	await capture("gameplay-nine-aircraft")
	await sample(9,180)
	# Real controller input: sustained forward movement, yaw and primary fire.
	var before := player.global_position
	Input.action_press("thrust_forward",0.75)
	Input.action_press("yaw_right",0.3)
	Input.action_press("fire_primary")
	await frames(150)
	Input.action_release("fire_primary")
	Input.action_release("yaw_right")
	Input.action_release("thrust_forward")
	print("AIR_GAMEPLAY controller_distance=", before.distance_to(player.global_position))
	await capture("gameplay-turning-and-fire")
	clear_group()
	await frames(30)
	player.position = Vector3(0,30,0)
	player.velocity = Vector3.ZERO
	spawn_group(24)
	await frames(120)
	await sample(24,180)
	await capture("gameplay-24-aircraft")
	clear_group()
	await frames(30)
	# Actual town boss route, telegraph and phase presentation.
	director.current_wave = 10
	director.wave_boss_spawned = false
	director._check_wave_10_boss()
	var bosses := get_nodes_in_group("bosses")
	if not bosses.is_empty():
		var boss = bosses[0]
		player.rotation = Vector3.ZERO
		player.velocity = Vector3.ZERO
		player.get_node("PlayerCamera").init_camera(player)
		boss.global_position = player.global_position + Vector3(0,5,-28)
		boss._begin_telegraph(7,115)
		await frames(8)
		await capture("gameplay-boss-warning")
		boss._on_damaged(1.0,60.0,null)
		await frames(90)
		await capture("gameplay-boss-final-phase")
		boss.queue_free()
	await frames(15)
	# Restart through the real manager and construct a fresh aircraft; no enemy pool exists.
	gm.start_new_run("apache")
	var restarted = spawner.spawn_enemy_type("attack_gunship", player.global_position + Vector3(0,5,-25), true)
	print("AIR_RESTART fresh_aircraft=", restarted != null, " xp=", root.get_node("XpManager").total_xp_collected)
	if restarted: restarted.queue_free()
	var file := FileAccess.open("res://artifacts/air-model-review/render-performance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(samples,"  "))
	gm.current_state = gm.RunState.MENU
	await frames(3)
	quit(0)
