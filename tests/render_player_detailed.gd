extends SceneTree

func _init() -> void:
	var game = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(game)
	var runner = DetailedCaptureRunner.new()
	root.add_child(runner)

class DetailedCaptureRunner extends Node:
	var frame: int = 0

	func _process(_delta: float) -> void:
		frame += 1
		var player = get_tree().root.get_node_or_null("MainGame/PlayerHelicopter")
		var cam = get_tree().root.get_node_or_null("MainGame/PlayerHelicopter/PlayerCamera")
		
		# Move camera close to player for detailed inspection
		if cam and player:
			cam.global_position = player.global_position + Vector3(5.0, 3.5, 7.0)
			cam.look_at(player.global_position + Vector3(0, 0.5, 0), Vector3.UP)

		if frame == 25:
			var img = get_viewport().get_texture().get_image()
			if img and not img.is_empty():
				var out_path = "C:/Users/Prime 3/.gemini/antigravity/brain/06e196af-0c7a-4631-b084-e06e5feaf17e/player_detailed_closeup.png"
				img.save_png(out_path)
				print("Saved player detailed close up to: ", out_path)
			get_tree().quit(0)
