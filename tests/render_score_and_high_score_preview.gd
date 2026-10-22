extends SceneTree

const ARTIFACT_DIR = "C:/Users/Prime 3/.gemini/antigravity/brain/95ea2036-de70-4bda-98bc-0cd205794470"

func _init() -> void:
	call_deferred("_render_preview")

func _render_preview() -> void:
	var hud_script = preload("res://src/ui/survival_hud.gd")
	var hud = hud_script.new()
	root.add_child(hud)
	
	var gm = root.get_node_or_null("GameManager")
	var pm = root.get_node_or_null("ProfileManager")
	
	if pm:
		pm.high_score = 15000
	if gm:
		gm.score = 18500
		gm.combo_multiplier = 3.2
		gm.combo_count = 22
		gm.current_wave = 5
		gm.kills_count = 37
		gm.banked_credits = 1450
		gm.at_risk_credits = 400
		gm.carried_salvage = 3
	
	hud.refresh(gm, null)
	hud._on_high_score_beaten(18500, 15000)
	
	# Wait for render frame
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	
	var vp = root.get_viewport()
	var tex = vp.get_texture()
	var img = tex.get_image()
	if img:
		var out_path = ARTIFACT_DIR + "/score_and_high_score_verification.png"
		img.save_png(out_path)
		print("Saved score_and_high_score_verification.png successfully!")
	
	quit(0)
