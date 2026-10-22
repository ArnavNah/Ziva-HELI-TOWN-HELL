extends SceneTree

func _init():
	print("Booting main_game for Slice A & B visual verification...")
	var scene = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(scene)

	var runner = VisualSliceRunner.new()
	root.add_child(runner)

class VisualSliceRunner extends Node:
	var frame: int = 0

	func _process(_delta):
		frame += 1

		# Frame 12: Spawn target enemies directly in line of sight on the open central avenue
		if frame == 12:
			var spawner = get_tree().root.get_node_or_null("MainGame/EnemySpawner")
			if spawner:
				print("Spawning test targets on open central avenue...")
				spawner.spawn_enemy_type("flak_tank", Vector3(-3.5, 1.0, -12.0))
				spawner.spawn_enemy_type("attack_gunship", Vector3(3.0, 3.5, -12.0))

		# Frame 25+: Paint salvo locks, lock turret, and trigger soft boundary warning
		if frame >= 25:
			var heli = get_tree().root.get_node_or_null("MainGame/PlayerHelicopter")
			var enemies = get_tree().get_nodes_in_group("enemies")
			if heli and enemies.size() >= 2:
				var ground_tank = null
				var air_gunship = null
				for e in enemies:
					if e.get("variant_id") == "flak_tank":
						ground_tank = e
					elif e.get("variant_id") == "attack_gunship":
						air_gunship = e

				if air_gunship and heli.turret:
					heli.turret.current_target_node = air_gunship
					heli.turret.current_target_score = 999.0

				if ground_tank and frame == 25:
					var salvo = heli.get_node_or_null("Salvo")
					if salvo:
						salvo.current_locks.append(ground_tank)
						salvo.current_locks.append(ground_tank)
						print("Painted 2 salvo locks on: ", ground_tank.name)

			# Trigger soft boundary warning state to display the alert banner
			var event_bus = get_tree().root.get_node_or_null("EventBus")
			if event_bus and frame == 25:
				event_bus.border_warning_changed.emit(true, Vector3(0, 0, -1), 18.0)
				print("Emitted soft border warning (18m to edge)...")

		# Frame 45: Capture rendered screenshot
		if frame == 45:
			var img = get_viewport().get_texture().get_image()
			if img and not img.is_empty():
				var out_path = "C:/Users/Prime 3/.gemini/antigravity/brain/95ea2036-de70-4bda-98bc-0cd205794470/slice_a_b_verification.png"
				var err = img.save_png(out_path)
				print("Saved Slice A & B verification screenshot with code: ", err, " to ", out_path)
			else:
				print("Viewport texture was empty.")
			get_tree().quit(0)
