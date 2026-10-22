extends SceneTree

func _init():
	print("Booting main_game to capture Megabonk-style colorful environment screenshot...")
	var scene = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(scene)

	var runner = VisualEnvironmentRunner.new()
	root.add_child(runner)

class VisualEnvironmentRunner extends Node:
	var frame: int = 0

	func _process(_delta):
		frame += 1

		# Frame 10: Spawn test enemies in the colorful city streets
		if frame == 10:
			var spawner = get_tree().root.get_node_or_null("MainGame/EnemySpawner")
			if spawner:
				print("Spawning enemies in street corridors...")
				spawner.spawn_enemy_type("flak_tank", Vector3(-4.0, 1.0, -14.0))
				spawner.spawn_enemy_type("attack_gunship", Vector3(5.0, 4.0, -16.0))
				spawner.spawn_enemy_type("scout_buggy", Vector3(3.0, 1.0, 12.0))

		# Frame 30: Save screenshot of bright colorful environment
		if frame == 30:
			var img = get_viewport().get_texture().get_image()
			if img and not img.is_empty():
				var out_path = "C:/Users/Prime 3/.gemini/antigravity/brain/95ea2036-de70-4bda-98bc-0cd205794470/megabonk_environment_verification.png"
				var err = img.save_png(out_path)
				print("Saved Megabonk environment verification screenshot with code: ", err, " to ", out_path)
			else:
				print("Viewport texture was empty.")
			get_tree().quit(0)
