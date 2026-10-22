extends SceneTree

func _init():
	print("Launching main_game for enemy AI combat visual verification...")
	var scene = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(scene)

	var runner = ScreenshotCapture.new()
	runner.game_scene = scene
	root.add_child(runner)

class ScreenshotCapture extends Node:
	var frame = 0
	var game_scene: Node
	var spawned_test_encounter = false

	func _process(_delta):
		frame += 1

		# At frame 25, spawn tactical hostile formation in front of player
		if frame == 25 and not spawned_test_encounter:
			spawned_test_encounter = true
			var player = get_tree().get_first_node_in_group("player")
			var spawner = game_scene.get_node_or_null("EnemySpawner")
			if player and spawner:
				var p_pos = player.global_position
				# Spawn mixed strike group right within tactical engagement range
				spawner.spawn_enemy_type("assault_apc", p_pos + Vector3(-12.0, -12.0, 24.0))
				spawner.spawn_enemy_type("attack_gunship", p_pos + Vector3(14.0, 4.0, 28.0))
				spawner.spawn_enemy_type("rocket_buggy", p_pos + Vector3(8.0, -12.0, 32.0))
				spawner.spawn_enemy_type("torpedo_vtol", p_pos + Vector3(-16.0, 6.0, 36.0))

		# Capture at frame 90 when units are actively maneuvering, aiming turrets, and firing
		if frame == 95:
			var img = get_viewport().get_texture().get_image()
			if img and not img.is_empty():
				var out_path = "C:/Users/Prime 3/.gemini/antigravity/brain/95ea2036-de70-4bda-98bc-0cd205794470/enemy_combat_active_verification.png"
				var err = img.save_png(out_path)
				print("Saved combat screenshot with code: ", err, " to ", out_path)
			get_tree().quit(0)
