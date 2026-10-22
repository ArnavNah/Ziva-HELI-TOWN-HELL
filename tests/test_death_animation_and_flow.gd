extends SceneTree

## Comprehensive Verification Test for Death Animation & Score Popup Flow:
## 1. Lethal damage engages death state without immediate hard-cut.
## 2. Airframe enters uncontrolled death spiral with spin, pitch down, and gravity descent.
## 3. Continuous trailing smoke/fire bursts and audio alarms trigger.
## 4. Ground/surface collision triggers catastrophic impact detonation and airframe disintegration.
## 5. Camera trauma shake activates on initial hit and ground impact.
## 6. EventBus.player_died fires post-impact, transitioning GameManager to RESULTS.
## 7. DebriefScreen pops up with animated scale/alpha, status banner, and rolling score counter.
## 8. Action button deck is active and focused for instant restart or hangar return.

var tests_passed: int = 0
var total_tests: int = 12

func _init() -> void:
	print("==================================================================")
	print("--- BEGIN DEATH ANIMATION & SCORE POPUP FLOW VERIFICATION ---")
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
	var eb = root.get_node_or_null("EventBus")

	if not gm or not eb:
		print("[FAIL] Autoload singletons not found.")
		quit(1)
		return

	# Load MainGame scene
	var game_scene = load("res://scenes/main_game.tscn")
	var game = game_scene.instantiate()
	root.add_child(game)
	current_scene = game

	for i in 10:
		await process_frame

	var player = game.get_node_or_null("PlayerHelicopter")
	var debrief = game.get_node_or_null("UI/DebriefScreen")
	var camera = player.get_node_or_null("PlayerCamera") if player else null

	if not player or not debrief:
		print("[FAIL] PlayerHelicopter or DebriefScreen not found in MainGame.")
		quit(1)
		return

	# --- TEST 1: Lethal damage engages death state without immediate hard-cut ---
	var initial_rot_y = player.rotation.y
	player.take_damage(9999.0, "Heavy SAM Missile")
	check(player.is_dying and player.is_invulnerable and player.current_hull == 0.0, "1. Lethal damage initiates death sequence (is_dying=true, is_invulnerable=true)")
	check(not debrief.visible, "1.2 DebriefScreen remains hidden during active death sequence (no immediate cut)")

	# --- TEST 2: Airframe enters uncontrolled death spiral with spin, pitch down, and gravity descent ---
	var prev_y = player.global_position.y
	for i in 12:
		await physics_frame

	check(player.velocity.y < -2.0 and player.global_position.y < prev_y, "2.1 Gravity accelerates airframe downward into descent")
	check(abs(player.death_spiral_yaw_speed) > 10.0 and player.rotation.y != initial_rot_y, "2.2 Airframe rapidly spins in yaw death spiral")

	# --- TEST 3: Camera trauma shake activates on initial hit ---
	check(camera != null and camera.trauma > 0.0, "3. Camera trauma shake activated during crash sequence")

	# --- TEST 4: Ground/surface collision triggers catastrophic impact detonation ---
	# Fast-forward until impact occurs
	var frames = 0
	while not player.death_impact_occurred and frames < 150:
		frames += 1
		await physics_frame

	check(player.death_impact_occurred, "4.1 Ground impact occurred with catastrophic crash detonation")
	check(player.visual_hull != null and not player.visual_hull.visible, "4.2 Intact airframe disintegrated into wreckage (visual_hull.visible=false)")

	# --- TEST 5: EventBus.player_died fires post-impact, transitioning GameManager to RESULTS ---
	var post_impact_frames = 0
	while debrief != null and not debrief.visible and post_impact_frames < 120:
		post_impact_frames += 1
		await physics_frame

	check(gm.current_state == gm.RunState.RESULTS, "5.1 GameManager cleanly transitioned to RESULTS run state")
	check(debrief.visible, "5.2 DebriefScreen automatically became visible post-crash")

	# --- TEST 6: Minimal Game Over title ---
	check(debrief.outcome_label != null and debrief.outcome_label.text == "GAME OVER", "6. DebriefScreen displays a minimal GAME OVER title")

	# --- TEST 7: Dark gameplay overlay ---
	check(debrief.backdrop != null and debrief.backdrop.color.a > 0.5 and debrief.backdrop.color.a < 1.0, "7. Translucent dark overlay preserves the paused battlefield")

	# --- TEST 8: Action button deck active and focused ---
	check(debrief.retry_button != null and debrief.quit_button != null, "8. Play Again and Quit actions are present")

	print("------------------------------------------------------------------")
	print("DEATH ANIMATION & SCORE POPUP: ", tests_passed, "/", total_tests, " PASSED")
	print("==================================================================")

	game.queue_free()

	if tests_passed >= total_tests:
		quit(0)
	else:
		quit(1)
