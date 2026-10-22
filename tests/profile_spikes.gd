extends SceneTree

func _init():
	print("--- PROFILING FRAME SPIKES ---")
	var runner = SpikeProfiler.new()
	root.add_child(runner)

class SpikeProfiler extends Node:
	var frame: int = 0
	var game_scene: Node = null
	var player: Node3D = null
	var spawner: Node = null
	var fx: Node = null

	func _ready():
		process_mode = Node.PROCESS_MODE_ALWAYS
		var t0 = Time.get_ticks_usec()
		var main_res = load("res://scenes/main_game.tscn")
		print("Load main_game.tscn: %.2f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))

		t0 = Time.get_ticks_usec()
		game_scene = main_res.instantiate()
		print("Instantiate main_game.tscn: %.2f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))

		t0 = Time.get_ticks_usec()
		get_tree().root.add_child(game_scene)
		print("add_child main_game: %.2f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))

		player = game_scene.find_child("PlayerHelicopter", true, false)
		spawner = game_scene.find_child("EnemySpawner", true, false)
		fx = get_node_or_null("/root/FXManager")

	func _process(_delta):
		frame += 1
		var t_start = Time.get_ticks_usec()

		# Profile sub-operations on specific frames
		if frame == 5:
			# Test FX warmup: call play_muzzle, play_impact, request_flash_light
			var t_fx = Time.get_ticks_usec()
			if fx:
				fx.play_muzzle("player_mg", Transform3D(), null, Vector3.FORWARD)
				fx.play_impact("player_rocket", Vector3.ZERO, Vector3.UP)
				fx.request_flash_light(Vector3.ZERO, Color.ORANGE, 2.0, 10.0, 0.2, 1)
			print("[Frame 5] FX trigger cost: %.2f ms" % ((Time.get_ticks_usec() - t_fx) / 1000.0))

		if frame == 15:
			# Test spawn enemy
			var t_sp = Time.get_ticks_usec()
			if spawner:
				spawner.spawn_enemy_type("rocket_buggy", Vector3(0, 0, -20))
				spawner.spawn_enemy_type("attack_gunship", Vector3(0, 10, -20))
			print("[Frame 15] Spawn 2 enemies cost: %.2f ms" % ((Time.get_ticks_usec() - t_sp) / 1000.0))

		if frame == 25:
			# Test pathfinding
			var t_path = Time.get_ticks_usec()
			var up = load("res://src/world/urban_pathfinder.gd")
			for i in 50:
				var p = up.find_street_path(Vector3(-100, 0, -100), Vector3(100, 0, 100))
			print("[Frame 25] 50x AStar pathfinding cost: %.2f ms" % ((Time.get_ticks_usec() - t_path) / 1000.0))

		var total_ms = (Time.get_ticks_usec() - t_start) / 1000.0
		if total_ms > 20.0:
			print("[Frame %d] Frame spike: %.2f ms" % [frame, total_ms])

		if frame >= 80:
			print("--- PROFILER COMPLETED ---")
			get_tree().quit(0)
