extends SceneTree

func _init() -> void:
	print("Instantiating main_game for Enemy AI Navigation verification...")
	var scene = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(scene)

	var runner = NavigationVisualRunner.new()
	root.add_child(runner)

class NavigationVisualRunner extends Node:
	var frame: int = 0

	func _process(_delta: float) -> void:
		frame += 1

		# Spawn representative ground convoys and aerial gunships near buildings and corridors
		if frame == 10:
			var spawner = get_tree().root.get_node_or_null("MainGame/EnemySpawner")
			if spawner:
				print("Spawning enemy squadrons in urban sectors...")
				spawner.spawn_enemy_type("assault_apc", Vector3(-12.0, 1.0, 15.0))
				spawner.spawn_enemy_type("flak_tank", Vector3(14.0, 1.0, -12.0))
				spawner.spawn_enemy_type("siege_tank", Vector3(-18.0, 1.0, -20.0))
				spawner.spawn_enemy_type("attack_gunship", Vector3(10.0, 22.0, -25.0))
				spawner.spawn_enemy_type("scout_drone", Vector3(-15.0, 24.0, 10.0))
				spawner.spawn_enemy_type("technical_truck", Vector3(6.0, 1.0, 22.0))

		# Capture high-res verification screenshot at frame 60 after active navigation and wall avoidance
		if frame == 60:
			for e in get_tree().get_nodes_in_group("enemies"):
				var spd = Vector2(e.velocity.x, e.velocity.z).length() if "velocity" in e else 0.0
				print("Enemy AI Status: ", e.variant_id if "variant_id" in e else e.name, " at pos: ", e.global_position, " | Horiz Speed: ", spd)
			var img = get_viewport().get_texture().get_image()
			if img and not img.is_empty():
				var out_path = "C:/Users/Prime 3/.gemini/antigravity/brain/95ea2036-de70-4bda-98bc-0cd205794470/enemy_ai_navigation_verification.png"
				var err = img.save_png(out_path)
				print("Saved Enemy AI navigation screenshot with code: ", err, " to ", out_path)
			else:
				print("Viewport texture image was empty or unavailable.")
			get_tree().quit(0)
