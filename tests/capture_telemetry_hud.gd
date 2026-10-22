extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game

	var player = game.get_node("PlayerHelicopter")
	player.position = Vector3(15.0, 18.0, 25.0)

	var spawner = game.get_node("EnemySpawner")
	spawner.spawn_enemy_type("scout_drone", Vector3(25.0, 18.0, -10.0))
	spawner.spawn_enemy_type("attack_wing", Vector3(-20.0, 22.0, 5.0))
	spawner.spawn_enemy_type("flak_tank", Vector3(5.0, 1.0, -35.0))

	# Advance 90 frames (1.5s) so initial shader load clears and 1-second FPS rolling average stabilizes at 60 FPS
	for i in 90:
		await process_frame

	var img = root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_absolute("res://artifacts")
	var save_path = "res://artifacts/live_60fps_telemetry.png"
	var err = img.save_png(save_path)
	print("Captured telemetry screenshot saved to: ", save_path, " Result: ", err, " Final FPS: ", Engine.get_frames_per_second())
	quit(0)
