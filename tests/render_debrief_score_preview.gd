extends SceneTree

const ARTIFACT_DIR = "C:/Users/Prime 3/.gemini/antigravity/brain/95ea2036-de70-4bda-98bc-0cd205794470"

func _init() -> void:
	call_deferred("_render_preview")

func _render_preview() -> void:
	var pm = root.get_node_or_null("ProfileManager")
	if pm:
		pm.clear_high_scores()
		var sample_runs = [
			{"score": 24500, "selected_aircraft": "apache", "wave_reached": 6, "kills": 42, "survival_time": 260.0, "successful": true, "total_payout": 1400},
			{"score": 19200, "selected_aircraft": "nighthawk", "wave_reached": 5, "kills": 35, "survival_time": 210.0, "successful": true, "total_payout": 1100},
			{"score": 15800, "selected_aircraft": "warlock", "wave_reached": 4, "kills": 28, "survival_time": 180.0, "successful": false, "total_payout": 650},
			{"score": 12400, "selected_aircraft": "apache", "wave_reached": 3, "kills": 20, "survival_time": 145.0, "successful": false, "total_payout": 400},
			{"score": 8900, "selected_aircraft": "nighthawk", "wave_reached": 2, "kills": 14, "survival_time": 95.0, "successful": false, "total_payout": 250}
		]
		for r in sample_runs:
			pm.record_run(r)

	var debrief_script = preload("res://src/ui/menus/debrief_screen.gd")
	var debrief = debrief_script.new()
	root.add_child(debrief)
	
	var summary = {
		"successful": true,
		"score": 24500,
		"is_new_high_score": true,
		"wave_reached": 6,
		"kills": 42,
		"ground_kills": 26,
		"air_kills": 16,
		"survival_time": 260.0,
		"combat_pay": 350,
		"banked_credits": 750,
		"salvage_credits": 300,
		"at_risk_recovered": 400,
		"total_payout": 1400
	}
	debrief.show_debrief(summary)

	# Wait for popup animation & score rollup to finish
	await create_timer(1.3).timeout
	await RenderingServer.frame_post_draw

	var vp = root.get_viewport()
	var tex = vp.get_texture()
	var img = tex.get_image()
	if img:
		var out_path = ARTIFACT_DIR + "/debrief_score_leaderboard_verification.png"
		img.save_png(out_path)
		print("Saved debrief_score_leaderboard_verification.png successfully!")

	quit(0)
