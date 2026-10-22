extends SceneTree

const ARTIFACT_DIR = "C:/Users/Prime 3/.gemini/antigravity/brain/7fe842b3-2e28-4d17-b446-0deca635b154"
const LoadingScreenScript = preload("res://src/ui/menus/loading_screen.gd")

func _init() -> void:
	call_deferred("_render_preview")

func _render_preview() -> void:
	var loading = LoadingScreenScript.new()
	root.add_child(loading)
	loading.start_loading("res://scenes/main_game.tscn", "apache", 3.0)

	# Advance 2.0s into loading
	await create_timer(2.0).timeout
	await RenderingServer.frame_post_draw

	var vp = root.get_viewport()
	var tex = vp.get_texture()
	var img = tex.get_image()
	if img:
		img.save_png(ARTIFACT_DIR + "/current_loading_screen.png")
		print("Saved current_loading_screen.png successfully!")

	quit(0)
