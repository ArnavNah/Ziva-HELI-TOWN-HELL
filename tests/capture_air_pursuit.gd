extends SceneTree
const ROLES := ["attack_gunship","rocket_gunship","interceptor","escort_fighter","attack_wing","heavy_bomber","torpedo_vtol","stealth_vtol","minelayer"]
const OUT := "res://artifacts/air-pursuit-fix-2026-11-04/"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless" or OS.get_environment("ZIVA_TEST_DATA_DIR").is_empty():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	var gm := root.get_node("GameManager")
	gm.selected_biome = "town"
	var game = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 2400:
		await process_frame
		if game.is_prepared: break
	if not game.is_prepared:
		quit(1)
		return
	var player = game.get_node("PlayerHelicopter")
	player.debug_invulnerable = true
	player.set_physics_process(false)
	var spawner: Node = game.get_node("EnemySpawner")
	spawner.set_process(false)
	var director: Node = root.get_node("CombatDirector")
	director.set_process(false)
	director.current_wave = 20
	for enemy in get_nodes_in_group("enemies"): enemy.queue_free()
	await process_frame
	Engine.time_scale = 2
	Engine.physics_ticks_per_second = 120
	var rows: Array = []
	for role in ROLES:
		player.position = Vector3(0,35,0)
		player.velocity = Vector3.ZERO
		player.get_node("PlayerCamera").init_camera(player)
		var unit = spawner.spawn_enemy_type(role,Vector3(26,41,-75),true)
		if not unit:
			printerr("FAIL spawn ",role)
			quit(1)
			return
		unit.rotation.y = 0 # Nose initially points away: exercise actual turning.
		for step in 3:
			for frame in 120: await physics_frame
			if step==1: player.position.x += 14
			var to_player: Vector3 = player.position-unit.position
			rows.append({"role":role,"step":step,"distance":to_player.length(),"facing_dot":(-unit.global_basis.z).dot(to_player.normalized()),"state":unit.behavior_state,"outlets":unit.get_node("Visuals").outlet_index})
			print("CITY_AIR ",rows.back())
			RenderingServer.force_draw(false)
			var error := root.get_texture().get_image().save_png(OUT+role+"-"+str(step)+".png")
			if error != OK:
				quit(1)
				return
		unit._release_all_slots()
		unit.queue_free()
		for projectile in get_nodes_in_group("combat_projectiles"): projectile.queue_free()
		await process_frame
	var file := FileAccess.open(OUT+"city-pursuit.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"\t"))
	print("AIR_CITY_CAPTURE_COMPLETE ",rows.size())
	gm.current_state = gm.RunState.MENU
	quit()
