extends SceneTree

func _init() -> void:
	var game = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(game)
	var runner = GunshipDetailRunner.new()
	root.add_child(runner)

class GunshipDetailRunner extends Node:
	var frame: int = 0
	var gunship: Node = null

	func _process(_delta: float) -> void:
		frame += 1
		if frame == 3:
			var spawner = get_tree().root.get_node_or_null("MainGame/EnemySpawner")
			if spawner:
				gunship = spawner.spawn_enemy_type("attack_gunship", Vector3(0, 16, 0))

		var cam = get_tree().root.get_node_or_null("MainGame/PlayerHelicopter/PlayerCamera")
		if cam and gunship and is_instance_valid(gunship):
			cam.global_position = gunship.global_position + Vector3(6.0, 3.5, 8.0)
			cam.look_at_from_position(cam.global_position, gunship.global_position, Vector3.UP)

		if frame == 25:
			var img = get_viewport().get_texture().get_image()
			if img and not img.is_empty():
				var out_path = "C:/Users/Prime 3/.gemini/antigravity/brain/06e196af-0c7a-4631-b084-e06e5feaf17e/gunship_detailed_closeup.png"
				img.save_png(out_path)
				print("Saved gunship detailed close up to: ", out_path)
			get_tree().quit(0)
