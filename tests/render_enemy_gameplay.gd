extends SceneTree

func _init():
	print("Instantiating main_game for Nuclear Strike gameplay verification...")
	var scene = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(scene)

	var spawner = scene.get_node_or_null("EnemySpawner")
	if spawner:
		print("Spawning Nuclear Strike encounter: tanks, gunships, and drones...")
		spawner.spawn_enemy_type("siege_tank", Vector3(-14.0, 1.0, 2.0))
		spawner.spawn_enemy_type("flak_tank", Vector3(-11.0, 1.0, -14.0))
		spawner.spawn_enemy_type("missile_carrier", Vector3(12.0, 1.0, -18.0))
		spawner.spawn_enemy_type("infantry_squad", Vector3(-7.0, 1.0, -10.0))
		spawner.spawn_enemy_type("attack_gunship", Vector3(8.0, 18.0, -24.0))
		spawner.spawn_enemy_type("scout_drone", Vector3(-9.0, 16.0, -14.0))

	for i in range(45):
		await RenderingServer.frame_post_draw

	for e in root.get_tree().get_nodes_in_group("enemies"):
		print("Enemy: ", e.variant_id if "variant_id" in e else e.name, " at pos: ", e.global_position)

	var img = root.get_texture().get_image()
	if img and not img.is_empty():
		var out_path = "C:/Users/Prime 3/.gemini/antigravity/brain/423781a6-7f88-4467-b2c8-9d81542777cd/enemy_gameplay_nuclear_strike.png"
		var err = img.save_png(out_path)
		print("Saved Nuclear Strike gameplay screenshot with code: ", err, " to ", out_path)
	else:
		print("Viewport texture image was empty or unavailable.")
	quit(0)
