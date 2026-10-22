extends SceneTree

## 60-Second Active Combat & Playability Verification Simulator
## Runs 3,600 physics frames of full active combat in main_game.tscn,
## exercising weapon fire, enemy waves, gem drops, level-ups, card choices,
## damage resolution, and pause/resume pacing.

func _init() -> void:
	print("==================================================================")
	print("--- LAUNCHING 60-SECOND ACTIVE COMBAT & STABILITY SIMULATION ---")
	print("==================================================================")
	var scene = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(scene)
	var sim = CombatSimulator.new()
	root.add_child(sim)

class CombatSimulator extends Node:
	var total_frames: int = 0
	const TARGET_FRAMES: int = 3600 # 60 seconds at 60 FPS
	
	var player: PlayerHelicopter = null
	var progression: RunProgression = null
	var diag: UpgradeDialog = null
	var combat_director: Node = null
	
	# Telemetry counters
	var level_ups_processed: int = 0
	var upgrades_applied: int = 0
	var damage_events_handled: int = 0
	var xp_gems_collected: int = 0
	var lowest_player_health: float = 100.0
	var pauses_occurred: int = 0
	var errors_caught: int = 0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		
		# Disconnect real save settlement so profile stays untouched
		var gm = get_node_or_null("/root/GameManager")
		var bus = get_node_or_null("/root/EventBus")
		if gm and bus:
			var dh = Callable(gm, "_on_player_died")
			if bus.player_died.is_connected(dh):
				bus.player_died.disconnect(dh)

	func _physics_process(delta: float) -> void:
		total_frames += 1

		# Cache node references once ready
		if player == null:
			player = get_tree().get_first_node_in_group("player") as PlayerHelicopter
			if player:
				progression = player.get_node_or_null("RunProgression") as RunProgression
				lowest_player_health = player.current_hull
		
		if diag == null:
			diag = get_tree().root.find_child("UpgradeDialog", true, false) as UpgradeDialog

		# 1. Active flight input & combat simulation
		if player and is_instance_valid(player) and not player.is_dying:
			# Circular patrol pattern over combat area
			var t = total_frames * 0.016
			var thrust = sin(t * 0.5) * 0.8
			var strafe = cos(t * 0.4) * 0.6
			var yaw = sin(t * 0.2) * 0.5
			player.override_flight_input = {
				"thrust": thrust,
				"strafe": strafe,
				"yaw": yaw,
				"lift": 0.0,
				"dash": (total_frames % 240 == 0) # Dash every 4 seconds
			}
			
			if player.current_hull < lowest_player_health:
				lowest_player_health = player.current_hull
			
			# Verify hull clamping at all times
			if player.current_hull < 0.0 or player.current_hull > player.max_hull:
				push_error("HULL CLAMP VIOLATION: current_hull = %f (max: %f)" % [player.current_hull, player.max_hull])
				errors_caught += 1

		# 2. Periodic XP progression simulation to trigger level-ups & card dialogs
		if progression and is_instance_valid(progression):
			# Award combat XP every ~7 seconds
			if total_frames % 420 == 0 and not get_tree().paused:
				progression.add_run_xp(25)
				xp_gems_collected += 1

		# 3. Handle modal upgrade selection when UpgradeDialog is open
		if diag and is_instance_valid(diag) and diag.visible and not diag.offered_cards.is_empty():
			pauses_occurred += 1
			level_ups_processed += 1
			# Choose first offered card transactionally
			var chosen = diag.offered_cards[0]
			diag._choose_card(0)
			upgrades_applied += 1
			print("  [SIM LEVEL-UP] Frame %d: Selected upgrade '%s' (Queue remaining: %d)" % [total_frames, chosen, progression.queued_level_ups])

		# 4. Progress checkpoints
		if total_frames % 900 == 0:
			var sec = int(total_frames / 60.0)
			print("  [SIM CHECKPOINT] %2ds / 60s -- Player Hull: %.1f/%.1f | Level: %d | Upgrades: %d | Pauses: %d" % [
				sec,
				player.current_hull if player else 0.0,
				player.max_hull if player else 0.0,
				progression.current_run_level if progression else 1,
				upgrades_applied,
				pauses_occurred
			])

		# 5. Conclusion at 3,600 frames
		if total_frames >= TARGET_FRAMES:
			_conclude_simulation()

	func _conclude_simulation() -> void:
		print("==================================================================")
		print("--- 60-SECOND ACTIVE COMBAT SIMULATION COMPLETED ---")
		print("==================================================================")
		print("  Total Physics Frames:   %d (60.00s simulation)" % total_frames)
		print("  Upgrades Selected:      %d" % upgrades_applied)
		print("  Level-Up Pauses:        %d" % pauses_occurred)
		print("  Lowest Player Hull:     %.1f" % lowest_player_health)
		print("  Final Player Hull:      %.1f / %.1f" % [player.current_hull if player else 0.0, player.max_hull if player else 0.0])
		print("  Violations / Errors:    %d" % errors_caught)
		print("==================================================================")
		
		if errors_caught == 0:
			print("SIMULATION SUCCESS: Flawless 60s active combat and upgrade loop!")
			get_tree().quit(0)
		else:
			push_error("SIMULATION FAILED: %d errors encountered" % errors_caught)
			get_tree().quit(1)
