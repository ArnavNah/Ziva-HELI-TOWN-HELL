extends SceneTree

func _init() -> void:
	print("--- Running Helicopter Audit & Capture ---")
	var scene = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(scene)
	var runner = HeliAuditRunner.new()
	root.add_child(runner)

class HeliAuditRunner extends Node:
	var frame: int = 0
	var gunship: Node = null

	func _process(_delta: float) -> void:
		frame += 1
		if frame == 5:
			# Spawn an attack_gunship right in front of player
			var player = get_tree().root.get_node_or_null("MainGame/PlayerHelicopter")
			var spawner = get_tree().root.get_node_or_null("MainGame/EnemySpawner")
			if player and spawner:
				var spawn_pos = player.global_position + Vector3(0, 0, -12)
				gunship = spawner.spawn_enemy_type("attack_gunship", spawn_pos)
				print("Spawned attack_gunship at ", spawn_pos)

		if frame == 25:
			var img = get_viewport().get_texture().get_image()
			if img and not img.is_empty():
				var out_dir = "C:/Users/Prime 3/.gemini/antigravity/brain/06e196af-0c7a-4631-b084-e06e5feaf17e"
				var out_path = out_dir + "/helicopter_audit_gameplay.png"
				var err = img.save_png(out_path)
				print("Saved helicopter audit screenshot to: ", out_path, " code: ", err)
			else:
				print("Failed to get viewport image")
			get_tree().quit(0)
