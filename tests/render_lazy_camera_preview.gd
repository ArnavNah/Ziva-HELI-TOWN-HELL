extends SceneTree

const ARTIFACT_DIR = "C:/Users/Prime 3/.gemini/antigravity/brain/95ea2036-de70-4bda-98bc-0cd205794470"

func _init() -> void:
	call_deferred("_render_preview")

func _render_preview() -> void:
	var game_scene = load("res://scenes/main_game.tscn")
	var game = game_scene.instantiate()
	root.add_child(game)
	current_scene = game

	if root.has_node("CombatDirector"):
		root.get_node("CombatDirector").stop_wave_director()

	for i in 10:
		await process_frame

	var player = game.get_node_or_null("PlayerHelicopter")
	var cam = null
	if player:
		cam = player.get_node_or_null("PlayerCamera")
		# Set player to high-speed banking turn maneuver
		var forward = -player.global_transform.basis.z.normalized()
		player.velocity = forward * 32.0
		player.bank_angle = deg_to_rad(24.0)
		if "visual_bank" in player:
			player.visual_bank = deg_to_rad(24.0)
		player.rotate_y(deg_to_rad(18.0))

	# Run simulation frames maintaining helicopter banking turn maneuver
	for i in 30:
		if player:
			var forward = -player.global_transform.basis.z.normalized()
			player.velocity = forward * 34.0
			player.bank_angle = deg_to_rad(22.0)
			if "visual_bank" in player:
				player.visual_bank = deg_to_rad(22.0)
			player.rotate_y(deg_to_rad(0.4))
		await physics_frame
		await process_frame

	await RenderingServer.frame_post_draw

	var vp = root.get_viewport()
	var tex = vp.get_texture()
	var img = tex.get_image()
	if img:
		var out_path = ARTIFACT_DIR + "/lazy_camera_and_post_process_verification.png"
		img.save_png(out_path)
		print("Saved lazy_camera_and_post_process_verification.png successfully!")
		if cam:
			print("Camera state: pos=", cam.global_position, " dist=", cam.current_cam_dist, " roll=", rad_to_deg(cam.current_cam_roll), " deg, fov=", cam.fov)

	game.queue_free()
	quit(0)
