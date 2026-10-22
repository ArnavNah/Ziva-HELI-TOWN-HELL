extends SceneTree

## render_encounter_director_combat.gd
## Captures high-intensity combat screenshot showing active ground vehicles,
## air units, muzzle flashes, and projectile interactions.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- LAUNCHING ENCOUNTER DIRECTOR COMBAT EVIDENCE RENDERER ---")
	var game = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game

	var cd = root.get_node_or_null("CombatDirector")
	if cd:
		cd.use_credit_director = true
		cd.set_encounter_seed(2026)
		cd.start_wave_director()
		cd._setup_wave(6)

	var spawner = game.get_node_or_null("EnemySpawner")
	if spawner:
		var buggy = spawner.spawn_enemy_type("scout_buggy", Vector3(-10.0, 0.0, -22.0))
		var apc = spawner.spawn_enemy_type("assault_apc", Vector3(14.0, 0.0, -30.0))
		var crawler = spawner.spawn_enemy_type("rail_crawler", Vector3(-2.0, 0.0, -50.0))
		var sentinel = spawner.spawn_enemy_type("gatling_heavy", Vector3(22.0, 0.0, -55.0))
		var gunship = spawner.spawn_enemy_type("attack_gunship", Vector3(-18.0, 24.0, -35.0))

		# Trigger visual aim and muzzle flash / telegraph on ground units
		if crawler and crawler.has_method("start_telegraph"):
			crawler.start_telegraph(1.5, 0.7, Color("5ec8ff"))
		if apc and apc.has_method("start_telegraph"):
			apc.start_telegraph(1.2, 0.7, Color("ff8b3d"))
		if sentinel:
			var t = sentinel.get_node_or_null("Turret")
			if t and t.has_method("spin_barrels"):
				t.spin_barrels(1.0, 42.0)

	# Stabilize frames
	for i in range(40):
		await process_frame

	var vp = root.get_viewport()
	if vp:
		var tex = vp.get_texture()
		if tex:
			var img = tex.get_image()
			if img and not img.is_empty():
				var out_path = "C:/Users/Prime 3/.gemini/antigravity/brain/423781a6-7f88-4467-b2c8-9d81542777cd/autonomous_encounter_director_combat.png"
				var err = img.save_png(out_path)
				print("Saved combat evidence to: ", out_path, " Result: ", err)
	quit(0)
