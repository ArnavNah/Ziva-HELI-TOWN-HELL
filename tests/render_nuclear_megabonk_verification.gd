extends SceneTree

func _init():
	print("Booting main_game to capture Nuclear Strike scale, Megabonk shaders, and procedural enemy roster...")
	var scene = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(scene)

	var runner = VisualVerificationRunner.new()
	root.add_child(runner)

class VisualVerificationRunner extends Node:
	var frame: int = 0

	func _process(_delta):
		frame += 1

		# Frame 15: Spawn all 5 new procedural enemy types in the camera view
		if frame == 15:
			var spawner = get_tree().root.get_node_or_null("MainGame/EnemySpawner")
			if spawner:
				print("Spawning new procedural enemies in view...")
				# Ground: technical_truck, assault_apc, sam_launcher
				spawner.spawn_enemy_type("technical_truck", Vector3(-5.0, 1.0, -8.0))
				spawner.spawn_enemy_type("assault_apc", Vector3(6.0, 1.0, -11.0))
				spawner.spawn_enemy_type("sam_launcher", Vector3(-10.0, 1.0, -16.0))
				
				# Air: stealth_vtol, heavy_bomber flying cleanly in camera frustum
				spawner.spawn_enemy_type("stealth_vtol", Vector3(6.0, 10.0, -12.0))
				spawner.spawn_enemy_type("heavy_bomber", Vector3(-5.0, 12.0, -15.0))

		# Frame 25: Capture screenshot of Nuclear Strike scale + Megabonk environment
		if frame == 25:
			var img = get_viewport().get_texture().get_image()
			if img and not img.is_empty():
				var out_artifact = "C:/Users/Prime 3/.gemini/antigravity/brain/95ea2036-de70-4bda-98bc-0cd205794470/nuclear_megabonk_verification.png"
				var err = img.save_png(out_artifact)
				print("Saved verification screenshot to brain artifact: ", err, " -> ", out_artifact)
				
				var local_artifact = "artifacts/nuclear_megabonk_verification.png"
				img.save_png(local_artifact)
			else:
				print("Viewport texture was empty.")
			get_tree().quit(0)
