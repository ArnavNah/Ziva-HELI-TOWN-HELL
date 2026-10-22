extends SceneTree

const ARTIFACT_DIR = "C:/Users/Prime 3/.gemini/antigravity/brain/95ea2036-de70-4bda-98bc-0cd205794470"

func _init() -> void:
	call_deferred("_render_preview")

func _render_preview() -> void:
	var pm = root.get_node_or_null("ProfileManager")
	if pm:
		pm.high_score = 24500

	var menu_scene = load("res://scenes/ui/main_menu.tscn")
	var menu = menu_scene.instantiate()
	root.add_child(menu)
	current_scene = menu

	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw

	var vp = root.get_viewport()
	var tex = vp.get_texture()
	var img = tex.get_image()
	if img:
		var out_path = ARTIFACT_DIR + "/main_menu_highscore_verification.png"
		img.save_png(out_path)
		print("Saved main_menu_highscore_verification.png successfully!")

	quit(0)
