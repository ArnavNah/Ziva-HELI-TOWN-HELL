extends SceneTree

const ARTIFACT_DIR = "C:/Users/Prime 3/.gemini/antigravity/brain/06e196af-0c7a-4631-b084-e06e5feaf17e"

func _init() -> void:
	print("--- LAUNCHING SHOOTING FX SHOWCASE & BENCHMARK ---")
	var scene = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(scene)

	var runner = ShowcaseRunner.new()
	runner.game_scene = scene
	root.add_child(runner)

class ShowcaseRunner extends Node:
	var frame: int = 0
	var game_scene: Node = null
	var player: Node3D = null
	var weapons: Node = null
	var turret: Node3D = null
	var spawner: Node = null
	var fx: Node = null
	var spawned_enemies: Array = []

	var frame_times: Array[float] = []
	var max_muzzles: int = 0
	var max_impacts: int = 0
	var max_patches: int = 0
	var max_trails: int = 0
	var max_lights: int = 0

	var last_tick: int = 0

	func _ready():
		player = game_scene.find_child("PlayerHelicopter", true, false)
		if player:
			player.is_invulnerable = true
			player.position = Vector3(0, 14.0, 0)
			weapons = player.get_node_or_null("Weapons")
			turret = player.get_node_or_null("Turret")

		spawner = game_scene.get_node_or_null("EnemySpawner")
		fx = get_node_or_null("/root/FXManager")
		last_tick = Time.get_ticks_usec()

	func _process(delta: float):
		var now_tick = Time.get_ticks_usec()
		var dt_ms = float(now_tick - last_tick) / 1000.0
		last_tick = now_tick
		if frame > 10: # Discard first 10 warmup frames
			frame_times.append(dt_ms)

		frame += 1

		# Spawn tactical formation directly in front (-Z) of the helicopter on the avenue
		if frame == 15 and spawner and player:
			var p_pos = player.global_position
			var e1 = spawner.spawn_enemy_type("rocket_buggy", p_pos + Vector3(-6.0, -13.5, -20.0))
			var e2 = spawner.spawn_enemy_type("attack_gunship", p_pos + Vector3(8.0, 0.0, -24.0))
			var e3 = spawner.spawn_enemy_type("flak_tank", p_pos + Vector3(5.0, -13.5, -16.0))
			var e4 = spawner.spawn_enemy_type("siege_tank", p_pos + Vector3(-10.0, -13.5, -28.0))
			spawned_enemies = [e1, e2, e3, e4]

		# Direct turret aim toward the enemy formation on the road
		if player and turret:
			turret.target_world_pos = player.global_position + Vector3(2.0, -13.5, -18.0)

		# Drive player weapon fire and cycle weapons every 20 frames
		if weapons and is_instance_valid(weapons) and frame >= 20:
			var w_idx = ((frame - 20) / 25) % 4
			weapons.switch_weapon(w_idx)
			weapons.try_fire()

		# Have spawned enemies fire when ready
		if frame >= 30:
			for e in spawned_enemies:
				if is_instance_valid(e):
					if e.has_method("_fire_single_shot"):
						e._fire_single_shot(player.global_position)
					elif e.has_method("_fire_gun"):
						e._fire_gun(player.global_position)
					elif e.has_method("_fire_rocket"):
						e._fire_rocket(0)
					elif e.has_method("_fire_single_flak"):
						e._fire_single_flak(player.global_position)
					elif e.has_method("_fire_heavy_shell"):
						e._fire_heavy_shell(player.global_position)

		# Track peak active effects
		if fx:
			max_muzzles = maxi(max_muzzles, fx.get_active_muzzle_count())
			max_impacts = maxi(max_impacts, fx.get_active_impact_count())
			max_patches = maxi(max_patches, fx.get_active_patch_count())
			max_trails = maxi(max_trails, fx.get_active_trail_count())
			max_lights = maxi(max_lights, fx.get_active_flash_light_count())

		# Capture combat action screenshot at frame 60
		if frame == 60:
			var vp = get_viewport()
			if vp:
				var tex = vp.get_texture()
				if tex:
					var img = tex.get_image()
					if img and not img.is_empty():
						var path1 = ARTIFACT_DIR + "/shooting_fx_combat_active.png"
						img.save_png(path1)
						print("Captured active combat screenshot: ", path1)

		# Capture showcase closeup screenshot at frame 90
		if frame == 90:
			var vp = get_viewport()
			if vp:
				var tex = vp.get_texture()
				if tex:
					var img = tex.get_image()
					if img and not img.is_empty():
						var path2 = ARTIFACT_DIR + "/shooting_fx_showcase.png"
						img.save_png(path2)
						print("Captured showcase screenshot: ", path2)

		# End benchmark at frame 130
		if frame == 130:
			_report_and_quit()

	func _report_and_quit():
		if frame_times.size() > 0:
			frame_times.sort()
			var median_idx = int(frame_times.size() * 0.50)
			var p95_idx = int(frame_times.size() * 0.95)
			var median_ms = frame_times[median_idx]
			var p95_ms = frame_times[p95_idx]
			var min_ms = frame_times[0]
			var max_ms = frame_times[frame_times.size() - 1]

			print("\n=== SHOOTING FX BENCHMARK RESULTS ===")
			print("Sample frames: %d" % frame_times.size())
			print("Frame time min:    %.2f ms" % min_ms)
			print("Frame time median: %.2f ms" % median_ms)
			print("Frame time p95:    %.2f ms" % p95_ms)
			print("Frame time max:    %.2f ms" % max_ms)
			print("Peak active muzzles:         %d / 48" % max_muzzles)
			print("Peak active impacts:         %d / 32" % max_impacts)
			print("Peak active surface patches: %d / 16" % max_patches)
			print("Peak active trails:          %d / 32" % max_trails)
			print("Peak active flash lights:    %d / 4" % max_lights)
			print("Renderer: gl_compatibility")
			print("Resolution: 1280x720")
			print("=====================================")

		get_tree().quit(0)
