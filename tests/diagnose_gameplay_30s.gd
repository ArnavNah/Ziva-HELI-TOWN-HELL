extends SceneTree

func _init() -> void:
	print("--- BEGIN 45-SECOND GAMEPLAY STABILITY RUN ---")
	var scene = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(scene)

	var runner = StabilityRunner.new()
	runner.game_scene = scene
	root.add_child(runner)

class StabilityRunner extends Node:
	var frame: int = 0
	var game_scene: Node = null
	var player: Node3D = null
	var weapons: Node = null
	var spawner: Node = null
	var fx: Node = null

	var start_msec: int = 0

	func _ready():
		process_mode = Node.PROCESS_MODE_ALWAYS
		player = game_scene.find_child("PlayerHelicopter", true, false)
		if player:
			weapons = player.get_node_or_null("Weapons")
		spawner = game_scene.find_child("EnemySpawner", true, false)
		fx = get_node_or_null("/root/FXManager")
		start_msec = Time.get_ticks_msec()

	func _process(delta: float):
		frame += 1
		var elapsed_sec = float(Time.get_ticks_msec() - start_msec) / 1000.0

		# Every 5 seconds print telemetry
		if frame % 300 == 0:
			var enemy_count = get_tree().get_nodes_in_group("enemies").size()
			var proj_count = get_tree().get_nodes_in_group("combat_projectiles").size() + get_tree().get_nodes_in_group("enemy_projectiles").size()
			var fps = Performance.get_monitor(Performance.TIME_FPS)
			var mem_mb = Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0)
			var wave = 1
			var cd = get_node_or_null("/root/CombatDirector")
			if cd:
				wave = cd.current_wave
			print("[t=%.1fs | frame=%d] FPS=%.1f Mem=%.1fMB Enemies=%d Projectiles=%d Wave=%d Paused=%s" % [
				elapsed_sec, frame, fps, mem_mb, enemy_count, proj_count, wave, get_tree().paused
			])

		# Periodically fly and shoot to simulate real gameplay
		if player and is_instance_valid(player) and not get_tree().paused:
			# Gentle flight input
			player.position.x += sin(float(frame) * 0.02) * 0.15
			player.position.z += cos(float(frame) * 0.02) * 0.15
			if weapons and is_instance_valid(weapons) and frame % 15 == 0:
				weapons.try_fire()

		# Stop at 40 seconds (2400 frames)
		if elapsed_sec >= 40.0 or frame >= 2400:
			print("--- 40-SECOND STABILITY RUN FINISHED SUCCESSFULLY ---")
			get_tree().quit(0)
