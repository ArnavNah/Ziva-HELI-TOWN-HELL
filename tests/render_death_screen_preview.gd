extends SceneTree

const ARTIFACT_DIR = "C:/Users/Prime 3/.gemini/antigravity/brain/95ea2036-de70-4bda-98bc-0cd205794470"

func _init() -> void:
	call_deferred("_render_preview")

func _render_preview() -> void:
	var pm = root.get_node_or_null("ProfileManager")
	if pm:
		pm.clear_high_scores()
		pm.high_score = 30000
		var sample_runs = [
			{"score": 30000, "selected_aircraft": "nighthawk", "wave_reached": 7, "kills": 50, "survival_time": 320.0, "successful": true, "total_payout": 2200},
			{"score": 19200, "selected_aircraft": "apache", "wave_reached": 5, "kills": 35, "survival_time": 210.0, "successful": true, "total_payout": 1100},
			{"score": 14500, "selected_aircraft": "warlock", "wave_reached": 4, "kills": 24, "survival_time": 170.0, "successful": false, "total_payout": 500}
		]
		for r in sample_runs:
			pm.record_run(r)

	var debrief_script = preload("res://src/ui/menus/debrief_screen.gd")
	var debrief = debrief_script.new()
	root.add_child(debrief)

	var summary = {
		"successful": false,
		"cause_of_death": "Heavy SAM Flak Battery",
		"score": 16800,
		"is_new_high_score": false,
		"wave_reached": 4,
		"kills": 29,
		"ground_kills": 18,
		"air_kills": 11,
		"survival_time": 195.0,
		"distance_flown_m": 3100.0,
		"combat_pay": 220,
		"banked_credits": 500,
		"salvage_credits": 0,
		"at_risk_recovered": 0,
		"at_risk_lost": 350,
		"salvage_lost": 2,
		"total_payout": 720
	}
	debrief.show_debrief(summary)

	await create_timer(1.3).timeout
	await RenderingServer.frame_post_draw

	var vp = root.get_viewport()
	var tex = vp.get_texture()
	var img = tex.get_image()
	if img:
		var out_path = ARTIFACT_DIR + "/death_screen_verification.png"
		img.save_png(out_path)
		print("Saved death_screen_verification.png successfully!")

	quit(0)
