extends SceneTree

const ARTIFACT_DIR = "C:/Users/Prime 3/.gemini/antigravity/brain/246bfbd5-df79-41ad-b1db-2ff3804610f7"

func _init() -> void:
	print("--- LAUNCHING TIMED VEHICLE & AIRFRAME DESTRUCTION SHOWCASE ---")
	var scene = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(scene)

	var runner = DestructionShowcaseRunner.new()
	runner.game_scene = scene
	root.add_child(runner)

class DestructionShowcaseRunner extends Node:
	var frame: int = 0
	var game_scene: Node = null
	var player: Node3D = null
	var fx: Node = null
	var frame_times: Array[float] = []
	var last_tick: int = 0

	var max_fragments: int = 0
	var max_puffs: int = 0
	var max_lights: int = 0

	func _ready():
		player = game_scene.find_child("PlayerHelicopter", true, false)
		if player:
			player.position = Vector3(0, 10.0, 0.0)
		fx = get_node_or_null("/root/FXManager")
		last_tick = Time.get_ticks_usec()

	func _process(_delta: float):
		var now_tick = Time.get_ticks_usec()
		var dt_ms = float(now_tick - last_tick) / 1000.0
		last_tick = now_tick
		if frame > 10:
			frame_times.append(dt_ms)

		frame += 1

		# Frame 20: Avenue Vehicle Destruction (Right on the road in clear view)
		if frame == 20 and fx:
			var target_pos = Vector3(0.0, 0.5, -6.5)
			fx.play_destruction(null, target_pos, Vector3.UP, true, "heavy_ground")
			print("Triggered avenue vehicle destruction at frame 20")

		# Track telemetry
		if fx and "fragment_trail_emitter" in fx and fx.fragment_trail_emitter:
			var em = fx.fragment_trail_emitter
			var active_h = 0
			for h in em.fragment_heads:
				if h.active: active_h += 1
			var active_p = 0
			for p in em.smoke_puffs:
				if p.active: active_p += 1
			max_fragments = maxi(max_fragments, active_h)
			max_puffs = maxi(max_puffs, active_p)
		if fx and fx.has_method("get_active_flash_light_count"):
			max_lights = maxi(max_lights, fx.get_active_flash_light_count())

		# Frame 25: Capture the peak bright flash & initial fireball burst of the vehicle explosion
		if frame == 25:
			var vp = get_viewport()
			if vp:
				var tex = vp.get_texture()
				if tex:
					var img = tex.get_image()
					if img and not img.is_empty():
						var path1 = ARTIFACT_DIR + "/vehicle_destruction_burst.png"
						img.save_png(path1)
						print("Saved vehicle destruction peak screenshot: ", path1)

		# Frame 36: Capture the expanding ballistic burning fragments & curved segmented dark smoke trails
		if frame == 36:
			var vp = get_viewport()
			if vp:
				var tex = vp.get_texture()
				if tex:
					var img = tex.get_image()
					if img and not img.is_empty():
						var path2 = ARTIFACT_DIR + "/vehicle_destruction_trails.png"
						img.save_png(path2)
						print("Saved vehicle destruction trails screenshot: ", path2)

		# Frame 45: Inflict lethal damage on player helicopter to trigger crash spiral
		if frame == 45 and player:
			print("Inflicting lethal damage on player helicopter at frame 45")
			player.take_damage(9999.0, "Heavy Anti-Air Flak Shell")

		# Frame 65: Capture player death spiral trailing smoke with blood vignette
		if frame == 65:
			var vp = get_viewport()
			if vp:
				var tex = vp.get_texture()
				if tex:
					var img = tex.get_image()
					if img and not img.is_empty():
						var path3 = ARTIFACT_DIR + "/helicopter_death_spiral.png"
						img.save_png(path3)
						print("Saved helicopter death spiral screenshot: ", path3)

		# Frame 115: Capture ground impact detonation with wreckage
		if frame == 115:
			var vp = get_viewport()
			if vp:
				var tex = vp.get_texture()
				if tex:
					var img = tex.get_image()
					if img and not img.is_empty():
						var path4 = ARTIFACT_DIR + "/helicopter_crash_destruction.png"
						img.save_png(path4)
						print("Saved helicopter crash detonation screenshot: ", path4)

		if frame == 130:
			_report_and_quit()

	func _report_and_quit():
		if frame_times.size() > 0:
			frame_times.sort()
			var median_idx = int(frame_times.size() * 0.50)
			var p95_idx = int(frame_times.size() * 0.95)
			var median_ms = frame_times[median_idx]
			var p95_ms = frame_times[p95_idx]

			print("\n=== DESTRUCTION SYSTEM BENCHMARK RESULTS ===")
			print("Sample frames: %d" % frame_times.size())
			print("Frame time median: %.2f ms" % median_ms)
			print("Frame time p95:    %.2f ms" % p95_ms)
			print("Peak active fragment heads: %d / 48" % max_fragments)
			print("Peak active smoke puffs:    %d / 256" % max_puffs)
			print("Peak active flash lights:   %d / 4" % max_lights)
			print("Renderer: gl_compatibility")
			print("Resolution: 1280x720")
			print("============================================")

		get_tree().quit(0)
