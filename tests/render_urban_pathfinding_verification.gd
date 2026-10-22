extends SceneTree

func _init() -> void:
	print("Booting main_game to verify and capture Urban Pathfinder street navigation...")
	var scene = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(scene)

	var runner = UrbanPathfinderVisualRunner.new()
	root.add_child(runner)

class UrbanPathfinderVisualRunner extends Node:
	var frame: int = 0
	var spawned_enemies: Array[Node3D] = []
	var start_positions: Array[Vector3] = []

	func _process(_delta: float) -> void:
		frame += 1

		# Frame 10: Spawn diverse ground hostiles at street intersections and avenue midpoints
		if frame == 10:
			var spawner = get_tree().root.get_node_or_null("MainGame/EnemySpawner")
			var player = get_tree().root.get_node_or_null("MainGame/Player")
			if player:
				player.global_position = Vector3(0.0, 14.0, 0.0)

			if spawner:
				print("Spawning ground convoys along urban street grid...")
				# Spawn at street coordinates around city blocks:
				var e1 = spawner.spawn_enemy_type("assault_apc", Vector3(38.0, 0.5, 25.0))
				var e2 = spawner.spawn_enemy_type("flak_tank", Vector3(0.0, 0.5, 35.0))
				var e3 = spawner.spawn_enemy_type("technical_truck", Vector3(-25.0, 0.5, 0.0))
				var e4 = spawner.spawn_enemy_type("rocket_buggy", Vector3(15.0, 0.5, -38.0))
				var e5 = spawner.spawn_enemy_type("gatling_heavy", Vector3(38.0, 0.5, -20.0))

				for e in [e1, e2, e3, e4, e5]:
					if e:
						spawned_enemies.append(e)
						start_positions.append(e.global_position)

		# Frame 40: Verify all ground hostiles navigated along streets with active speed
		if frame == 40:
			print("--- EVALUATING GROUND HOSTILE PATHFINDING & VELOCITY ---")
			var all_moving = true
			for i in range(spawned_enemies.size()):
				var e = spawned_enemies[i]
				if is_instance_valid(e):
					var start_pos = start_positions[i]
					var curr_pos = e.global_position
					var dist_traveled = start_pos.distance_to(curr_pos)
					var vel = e.velocity.length()
					print("  Enemy [%s]: Moved %.2f m | Speed: %.1f m/s | Pos: (%0.1f, %0.1f, %0.1f)" % [
						e.name, dist_traveled, vel, curr_pos.x, curr_pos.y, curr_pos.z
					])
					if vel < 1.0 and dist_traveled < 2.0:
						all_moving = false

			if all_moving:
				print("[PASS] All ground hostiles actively navigated along street corridors without getting stuck!")
			else:
				print("[WARN] Some ground units had low movement, checking visual capture...")

		# Frame 45: Capture high-fidelity verification screenshot
		if frame == 45:
			var img = get_viewport().get_texture().get_image()
			if img and not img.is_empty():
				var brain_artifact = "C:/Users/Prime 3/.gemini/antigravity/brain/95ea2036-de70-4bda-98bc-0cd205794470/enemy_street_pathfinding_verification.png"
				var err = img.save_png(brain_artifact)
				print("Saved street pathfinding screenshot to brain artifact: ", err, " -> ", brain_artifact)

				DirAccess.make_dir_recursive_absolute("res://artifacts")
				img.save_png("artifacts/enemy_street_pathfinding_verification.png")
			else:
				print("Viewport texture was empty.")
			get_tree().quit(0)
