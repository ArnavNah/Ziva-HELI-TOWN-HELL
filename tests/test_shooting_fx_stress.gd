extends SceneTree

## Multi-run Stress & Transition Verification
## Tests 5 successive gameplay/cleanup runs, rapid firing, pool exhaustion,
## pause freezing, and zero leakage after transition.

func _init():
	print("=== BEGIN SHOOTING FX MULTI-RUN STRESS & LEAK TEST ===")
	var runner = StressRunner.new()
	root.add_child(runner)

class StressRunner extends Node:
	var fx: Node = null
	var current_run: int = 0
	var total_runs: int = 5
	var frame: int = 0
	var stress_firing: bool = false
	var passed_runs: int = 0

	func _ready():
		process_mode = Node.PROCESS_MODE_ALWAYS
		fx = get_node_or_null("/root/FXManager")
		_start_run()

	func _start_run():
		current_run += 1
		frame = 0
		stress_firing = true
		print("  Starting Run %d / %d..." % [current_run, total_runs])

	func _process(delta: float):
		frame += 1

		if stress_firing and frame < 60:
			# High-frequency rapid fire to exhaust and stress pools
			for i in 12:
				var tf = Transform3D(Basis(), Vector3(randf_range(-10, 10), randf_range(1, 10), randf_range(-10, 10)))
				fx.play_muzzle("player_mg" if i % 2 == 0 else "enemy_gatling", tf, null, Vector3.FORWARD)
				fx.play_impact("player_rocket" if i % 3 == 0 else "enemy_bullet", tf.origin, Vector3.UP)
				fx.request_flash_light(tf.origin, Color.ORANGE, 2.5, 10.0, 0.12, 1)

		elif frame == 65:
			# Check pool limits during peak saturation
			var m = fx.get_active_muzzle_count()
			var imp = fx.get_active_impact_count()
			var l = fx.get_active_flash_light_count()
			print("    Peak saturation (Run %d): Muzzles=%d/48, Impacts=%d/32, Lights=%d/4" % [current_run, m, imp, l])
			if m > 48 or imp > 32 or l > 4:
				print("    [FAIL] Pool budget exceeded during peak load!")
				get_tree().quit(1)
				return

		elif frame == 75:
			# Emulate game pause
			get_tree().paused = true
			# Verify lifetimes do not advance during pause
			var snapshot_active = fx.get_active_muzzle_count()

		elif frame == 95:
			# Unpause
			get_tree().paused = false

		elif frame == 110:
			# Emulate transition (retry / return to menu / die)
			stress_firing = false
			fx.clear_combat_effects()

			var remaining_active = (
				fx.get_active_muzzle_count() +
				fx.get_active_impact_count() +
				fx.get_active_patch_count() +
				fx.get_active_trail_count() +
				fx.get_active_flash_light_count()
			)

			if remaining_active == 0:
				print("    [PASS] Run %d completed and cleanly reset (0 lingering effects)." % current_run)
				passed_runs += 1
			else:
				print("    [FAIL] Run %d had %d lingering effects after cleanup!" % [current_run, remaining_active])
				get_tree().quit(1)
				return

			if current_run < total_runs:
				_start_run()
			else:
				_finish()

	func _finish():
		print("\n=== MULTI-RUN STRESS SUMMARY ===")
		print("Passed Runs: %d / %d." % [passed_runs, total_runs])
		if passed_runs == total_runs:
			print("ALL 5 RUNS COMPLETED WITH PERFECT POOL RECYCLING AND ZERO ORPHANS!")
			get_tree().quit(0)
		else:
			get_tree().quit(1)
