extends SceneTree

const ARTIFACT_DIR = "C:/Users/Prime 3/.gemini/antigravity/brain/95ea2036-de70-4bda-98bc-0cd205794470"

func _init() -> void:
	call_deferred("_render_preview")

func _render_preview() -> void:
	var game_scene = load("res://scenes/main_game.tscn")
	var game = game_scene.instantiate()
	root.add_child(game)
	current_scene = game

	for i in 10:
		await process_frame

	var player = game.get_node_or_null("PlayerHelicopter")
	if player:
		# Deal lethal damage to trigger death spiral
		player.take_damage(9999.0, "Heavy Anti-Air Artillery")

	# Advance 20 physics frames into the death spiral (spinning, trailing fire and smoke)
	for i in 22:
		await physics_frame
	await RenderingServer.frame_post_draw

	var vp = root.get_viewport()
	var tex = vp.get_texture()
	var img = tex.get_image()
	if img:
		var out_path = ARTIFACT_DIR + "/death_spiral_animation_verification.png"
		img.save_png(out_path)
		print("Saved death_spiral_animation_verification.png successfully!")

	# Advance until impact and capture crash site
	var count = 0
	while not player.death_impact_occurred and count < 80:
		count += 1
		await physics_frame

	# Wait 8 frames post impact for explosion fireball peak
	for i in 8:
		await physics_frame
	await RenderingServer.frame_post_draw

	img = vp.get_texture().get_image()
	if img:
		var out_path = ARTIFACT_DIR + "/death_crash_explosion_verification.png"
		img.save_png(out_path)
		print("Saved death_crash_explosion_verification.png successfully!")

	game.queue_free()
	quit(0)
