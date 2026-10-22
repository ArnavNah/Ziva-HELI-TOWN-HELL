extends SceneTree

const ARTIFACT_DIR = "C:/Users/Prime 3/.gemini/antigravity/brain/7fe842b3-2e28-4d17-b446-0deca635b154"

func _init() -> void:
	call_deferred("_run_game")

func _run_game() -> void:
	var game_scene = load("res://scenes/main_game.tscn")
	var game = game_scene.instantiate()
	root.add_child(game)
	current_scene = game

	var player = game.find_child("PlayerHelicopter", true, false)
	if player:
		player.is_invulnerable = true
		# Give a slight forward movement command to test dynamic rotor RPM and attitude lean
		player._process(0.016)

	await create_timer(1.2).timeout
	await RenderingServer.frame_post_draw

	var vp = root.get_viewport()
	var tex = vp.get_texture()
	var img = tex.get_image()
	if img:
		img.save_png(ARTIFACT_DIR + "/gameplay_player_hero.png")
		print("Saved gameplay_player_hero.png successfully!")

	quit(0)
