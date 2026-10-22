extends SceneTree

## render_encounter_director_evidence.gd
## Captures rendered gameplay evidence of the Autonomous Encounter Director in action,
## showing active combat units, off-screen threat warning, and F3 telemetry view.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- LAUNCHING ENCOUNTER DIRECTOR EVIDENCE RENDERER ---")
	var game = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game

	var cd = root.get_node_or_null("CombatDirector")
	if cd:
		cd.use_credit_director = true
		cd.set_encounter_seed(1984)
		cd.start_wave_director()
		cd._setup_wave(6) # Wave 6 Armored Column
		cd.fast_wallet = 35.0
		cd.slow_wallet = 65.0

	var spawner = game.get_node_or_null("EnemySpawner")
	if spawner:
		# Deploy representative combat cohort
		spawner.spawn_enemy_type("scout_buggy", Vector3(-12.0, 0.0, -32.0))
		spawner.spawn_enemy_type("assault_apc", Vector3(18.0, 0.0, -45.0))
		spawner.spawn_enemy_type("rail_crawler", Vector3(0.0, 0.0, -68.0))
		spawner.spawn_enemy_type("attack_gunship", Vector3(-25.0, 26.0, -40.0))

	# Toggle F3 debug telemetry view
	var overlay = game.find_child("DebugTelemetryOverlay", true, false)
	if overlay and overlay.has_method("toggle_overlay"):
		overlay.toggle_overlay()

	# Emit a threat warning to demonstrate offscreen telegraph chevron
	var bus = root.get_node_or_null("EventBus")
	if bus and bus.has_signal("threat_warning"):
		bus.threat_warning.emit(Vector3(120.0, 0.0, 40.0), "rail_crawler", 2.0)

	# Step frames for physics and rendering stabilization
	for i in range(45):
		await process_frame

	var vp = root.get_viewport()
	if vp:
		var tex = vp.get_texture()
		if tex:
			var img = tex.get_image()
			if img and not img.is_empty():
				var out_path = "C:/Users/Prime 3/.gemini/antigravity/brain/423781a6-7f88-4467-b2c8-9d81542777cd/autonomous_encounter_director_telemetry.png"
				var err = img.save_png(out_path)
				print("Saved encounter director telemetry evidence to: ", out_path, " Result: ", err)
			else:
				print("Viewport image was empty or unavailable in this renderer context.")
	quit(0)
