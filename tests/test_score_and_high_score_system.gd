extends SceneTree

## Comprehensive Verification Test for Score & High Score System:
## 1. Score calculation, combo multiplier scaling, and low hull bonus.
## 2. EventBus score_updated and high_score_beaten signals.
## 3. Wave clear, mission, cargo, and boss score bonuses.
## 4. ProfileManager high_score persistence and Top 10 Leaderboard ranking.
## 5. Live in-run high score surpassing detection and celebratory audio/banner.
## 6. SurvivalHUD live score and high score widgets.
## 7. PauseMenu and DebriefScreen presentation of score, high score, and leaderboard.
## 8. MainMenu top-bar high score display.

var tests_passed: int = 0
var total_tests: int = 24

func _init() -> void:
	print("==================================================================")
	print("--- BEGIN SCORE & HIGH SCORE SYSTEM VERIFICATION ---")
	print("==================================================================")
	call_deferred("_run_tests")

func check(condition: bool, message: String) -> void:
	if condition:
		print("  [PASS] ", message)
		tests_passed += 1
	else:
		push_error("  [FAIL] " + message)
		print("  [FAIL] ", message)

func _run_tests() -> void:
	var gm = root.get_node_or_null("GameManager")
	var pm = root.get_node_or_null("ProfileManager")
	var eb = root.get_node_or_null("EventBus")
	
	if not gm or not pm or not eb:
		print("[FAIL] Required autoload singletons not found on root.")
		quit(1)
		return

	# --- TEST 1: Score calculation, combo scaling, and low-hull bonus ---
	gm.start_new_run("apache")
	check(gm.score == 0 and gm.combo_multiplier == 1.0, "1.1 New run resets score to 0 and combo to 1.0x")
	
	gm.add_score(100) # Base 100 with 1.0x = 100
	check(gm.score == 100, "1.2 Base score added at 1.0x multiplier")
	
	# Simulate 10 hits to raise combo multiplier to 2.0x (1 + min(10 * 0.1, 5) = 2.0x)
	for i in 10:
		gm.register_hit()
	check(gm.combo_multiplier == 2.0, "1.3 Combo multiplier correctly scaled to 2.0x")
	
	gm.add_score(100, 0.5) # 100 * 2.0 * (1.0 + 0.5) = 300
	check(gm.score == 400, "1.4 Low hull bonus (50%) and combo multiplier (2.0x) calculated accurately (100 + 300 = 400)")

	# --- TEST 2: EventBus score_updated and high_score_beaten signals ---
	var score_signal_data = {"received": false, "score": 0, "points": 0}
	var update_callable = func(cur_s, pts):
		score_signal_data["received"] = true
		score_signal_data["score"] = cur_s
		score_signal_data["points"] = pts
	eb.score_updated.connect(update_callable)
	
	gm.add_score(50)
	check(score_signal_data["received"] and score_signal_data["score"] == gm.score and score_signal_data["points"] == 100, "2. EventBus.score_updated emitted with current score and points added")
	eb.score_updated.disconnect(update_callable)

	# --- TEST 3: Wave, Mission, Cargo, and Boss Score Bonuses ---
	var score_before_bonuses = gm.score
	eb.wave_cleared.emit(2) # Wave 2 * 500 = 1000 base * 2.0 combo = 2000
	check(gm.score > score_before_bonuses, "3.1 Wave clear awarded score bonus")
	
	var score_before_mission = gm.score
	eb.tactical_mission_completed.emit({"credits": 300}, true) # 300 * 3.0 = 900 base * 2.0 = 1800
	check(gm.score > score_before_mission, "3.2 Tactical mission completion awarded score bonus")
	
	var score_before_cargo = gm.score
	eb.cargo_delivered.emit({"base_price": 200}, true, true) # 200 * 2.0 * 2.0 = 800 base * 2.0 = 1600
	check(gm.score > score_before_cargo, "3.3 Cargo contract delivery awarded score bonus")
	
	var score_before_boss = gm.score
	eb.boss_defeated.emit() # 5000 base * 2.0 = 10000
	check(gm.score - score_before_boss == 10000, "3.4 Heavy Boss takedown awarded 10,000 score bonus")

	# --- TEST 4: ProfileManager Leaderboard and High Score Persistence ---
	pm.clear_high_scores()
	check(pm.high_score == 0 and pm.high_scores.is_empty(), "4.1 ProfileManager high score cleared for clean test baseline")
	
	# Simulate 12 distinct runs to verify sorting and top-10 capacity limit
	var test_scores = [1200, 4500, 2300, 8900, 3100, 15000, 7200, 600, 11000, 9500, 4000, 18000]
	for sc in test_scores:
		var sim_summary = {
			"score": sc,
			"selected_aircraft": "nighthawk",
			"wave_reached": 5,
			"kills": 25,
			"survival_time": 180.0,
			"successful": true,
			"total_payout": 500
		}
		pm.record_run(sim_summary)
		
	check(pm.high_score == 18000, "4.2 ProfileManager top high score correctly identifies all-time record (18,000 PTS)")
	check(pm.high_scores.size() == 10, "4.3 Top High Scores leaderboard capped strictly at top 10 entries")
	check(pm.high_scores[0]["score"] == 18000 and pm.high_scores[0]["rank"] == 1, "4.4 Leaderboard #1 rank matches maximum score")
	check(pm.high_scores[1]["score"] == 15000 and pm.high_scores[9]["score"] == 2300, "4.5 Leaderboard entries sorted in descending numerical order")
	
	# Test persistence across re-load
	pm.save_profile()
	pm.high_score = 0
	pm.high_scores.clear()
	pm.load_profile()
	check(pm.high_score == 18000 and pm.high_scores.size() == 10, "4.6 High scores and leaderboard cleanly restored from JSON storage")

	# --- TEST 5: Live In-Run High Score Beat Detection ---
	pm.high_score = 5000
	gm.start_new_run("warlock")
	check(gm.run_starting_high_score == 5000 and not gm.has_beaten_high_score, "5.1 Run captures starting benchmark high score (5,000 PTS)")
	
	var high_score_data = {"fired": false, "new_record": 0}
	var beat_callable = func(new_s, old_s):
		high_score_data["fired"] = true
		high_score_data["new_record"] = new_s
	eb.high_score_beaten.connect(beat_callable)
	
	gm.add_score(4000)
	check(not high_score_data["fired"] and not gm.has_beaten_high_score, "5.2 Sub-threshold score (4,000 < 5,000) does not trigger high score event")
	
	gm.add_score(2000) # Score now 6,000 > 5,000
	check(high_score_data["fired"] and gm.has_beaten_high_score and high_score_data["new_record"] == 6000, "5.3 Exceeding benchmark (6,000 > 5,000) immediately triggers EventBus.high_score_beaten")
	eb.high_score_beaten.disconnect(beat_callable)

	# --- TEST 6: SurvivalHUD Live Score and High Score Widgets ---
	var hud_script = preload("res://src/ui/survival_hud.gd")
	var hud = hud_script.new()
	root.add_child(hud)
	await process_frame
	
	check(hud.score_label != null and hud.high_score_label != null and hud.high_score_toast != null, "6.1 SurvivalHUD initializes score_label, high_score_label, and high_score_toast")
	
	hud.refresh(gm, null)
	check(hud.score_label.text == str(gm.score), "6.2 SurvivalHUD score_label accurately displays live game score")
	check(hud.high_score_label.text == str(maxi(pm.high_score, gm.score)), "6.3 SurvivalHUD high_score_label displays active target benchmark")
	hud.queue_free()

	# --- TEST 7: Pause Menu and Debrief Screen Integration ---
	var pause_script = preload("res://src/ui/menus/pause_menu.gd")
	var pause_menu = pause_script.new()
	root.add_child(pause_menu)
	pause_menu._refresh_telemetry()
	check(pause_menu.telemetry_label != null and pause_menu.telemetry_label.text.contains("Sortie Score:") and pause_menu.telemetry_label.text.contains("High:"), "7.1 PauseMenu telemetry displays Sortie Score and High Score")
	pause_menu.queue_free()
	
	var debrief_script = preload("res://src/ui/menus/debrief_screen.gd")
	var debrief = debrief_script.new()
	root.add_child(debrief)
	var mock_summary = {
		"successful": true,
		"score": 25000,
		"is_new_high_score": true,
		"wave_reached": 6,
		"kills": 35,
		"ground_kills": 20,
		"air_kills": 15,
		"survival_time": 240.0,
		"total_payout": 1200
	}
	debrief.show_debrief(mock_summary)
	check(debrief.breakdown_label != null and debrief.breakdown_label.text.contains("Combat Rating Score: 25000 PTS") and debrief.breakdown_label.text.contains("NEW ALL-TIME CAREER HIGH SCORE") and debrief.breakdown_label.text.contains("TOP PILOT LEADERBOARD"), "7.2 DebriefScreen showcases combat rating score, all-time record citation, and top leaderboard")
	debrief.queue_free()

	# --- TEST 8: Main Menu TopBar High Score Display ---
	var menu_scene = load("res://scenes/ui/main_menu.tscn")
	var menu = menu_scene.instantiate()
	root.add_child(menu)
	current_scene = menu
	for i in 5:
		await process_frame
		
	var menu_high_score_lbl = menu.get_node_or_null("TopBar/HighScoreLabel")
	if not menu_high_score_lbl:
		menu_high_score_lbl = menu.high_score_label
	check(menu_high_score_lbl != null and menu_high_score_lbl.text.contains("HIGH SCORE:"), "8. MainMenu TopBar displays formatted career HIGH SCORE label")
	menu.queue_free()

	print("------------------------------------------------------------------")
	print("SCORE & HIGH SCORE SYSTEM VERIFICATION: ", tests_passed, "/", total_tests, " PASSED")
	print("==================================================================")
	
	if tests_passed >= total_tests:
		quit(0)
	else:
		quit(1)
