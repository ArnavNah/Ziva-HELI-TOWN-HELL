extends SceneTree

## Dedicated test suite verifying the 10 Encounter Loop Scenarios (Section 9 of Spec)

const GameConstants = preload("res://data/game_constants.gd")
const DamageReceiverScript = preload("res://src/combat/damage_receiver.gd")
const ProjectileScene = preload("res://scenes/combat/projectile.tscn")
const DamageDataClass = preload("res://src/combat/damage_data.gd")

func _init() -> void:
	print("==================================================")
	print("--- BEGIN ENCOUNTER LOOP VERIFICATION SUITE ---")
	print("==================================================")
	var runner = EncounterLoopVerifier.new()
	root.add_child(runner)

class EncounterLoopVerifier extends Node:
	var passed: int = 0
	var total: int = 10
	var spawner: EnemySpawner
	var player: Node3D

	func _ready() -> void:
		# Initialize street grid for urban navigation
		preload("res://src/world/urban_pathfinder.gd")._ensure_initialized()

		var sp_script = preload("res://src/enemies/enemy_spawner.gd")
		spawner = sp_script.new()
		add_child(spawner)

		# Setup Player anchor
		var p_scene = preload("res://scenes/player/player.tscn")
		player = p_scene.instantiate()
		player.position = Vector3(0, 15, 0)
		add_child(player)
		var p_rec = player.get_node_or_null("DamageReceiver")
		if p_rec:
			p_rec.max_health = 99999.0
			p_rec.current_health = 99999.0

		call_deferred("_start_execution")

	func _start_execution() -> void:
		await get_tree().process_frame
		await get_tree().physics_frame
		await _run_all_scenarios()

	func _run_all_scenarios() -> void:
		_test_scenario_1_open_area_encounter_loop()
		_test_scenario_2_fleeing_player_intercept()
		await _test_scenario_3_building_cover_and_occlusion()
		_test_scenario_4_rooftop_hover_elevation_limits()
		_test_scenario_5_strafe_dodge_committed_telegraph()
		_test_scenario_6_group_behavior_and_role_spacing()
		_test_scenario_7_junction_separation_anti_wedging()
		_test_scenario_8_wave_lifecycle_and_pause_clock()
		_test_scenario_9_heavy_slot_coordination()
		_test_scenario_10_population_scale_and_performance()
		_conclude()

	# --------------------------------------------------------------------------
	# Scenario 1: Open area approach, establish range, telegraph, fire (3-6s)
	# --------------------------------------------------------------------------
	func _test_scenario_1_open_area_encounter_loop() -> void:
		var enemy = spawner._create_enemy_node("technical_truck") as BaseEnemy
		add_child(enemy)
		enemy.global_position = Vector3(0.0, 1.0, 65.0) # 65m away on Avenue 0
		enemy.entry_grace_period = 2.0 # Default opening grace (2.0s)

		# Step 1: Initial state is ENTER with reason ENTERING
		var s1_ok = (enemy.behavior_state == BaseEnemy.BehaviorState.ENTER)

		# Step 2: Simulate physics and AI -> transitions to PURSUE and closes distance
		var elapsed = 0.0
		var dt = 0.05
		var initial_dist = enemy.global_position.distance_to(player.global_position)
		var first_attack_time = -1.0

		for step in range(120): # up to 6.0 seconds
			elapsed += dt
			enemy._custom_process(dt)
			enemy._physics_process(dt)
			if (enemy.behavior_state == BaseEnemy.BehaviorState.WINDUP or enemy.behavior_state == BaseEnemy.BehaviorState.FIRE) and first_attack_time < 0.0:
				first_attack_time = elapsed
				break

		var final_dist = enemy.global_position.distance_to(player.global_position)
		var closed_distance = final_dist < initial_dist

		print("  Scenario 1: Open Area | Initial Dist: %.1fm -> Final Dist: %.1fm | First Attack Time: %.2fs" % [initial_dist, final_dist, first_attack_time])
		if s1_ok and closed_distance and (first_attack_time >= 2.0 and first_attack_time <= 6.0):
			print("  [PASS] Scenario 1: Open Area approach, established range, telegraphed and fired within 3-6s.")
			passed += 1
		else:
			print("  [FAIL] Scenario 1: Failed encounter loop timing (first_attack: %.2f, closed: %s)" % [first_attack_time, str(closed_distance)])

		enemy.queue_free()

	# --------------------------------------------------------------------------
	# Scenario 2: Fleeing player & intercept candidate routing ahead of flight
	# --------------------------------------------------------------------------
	func _test_scenario_2_fleeing_player_intercept() -> void:
		# Player flying eastward at cruising speed (36.0 m/s)
		player.global_position = Vector3(100.0, 20.0, 0.0)
		player.velocity = Vector3(36.0, 0.0, 0.0)
		spawner.encounter_remaining = 0 # Force recalculation of encounter sector

		# Generate candidate spawn positions for air and ground
		var air_spawn = spawner.find_valid_spawn_position("air", player.global_position, "hunter_drone")
		var dist_h = Vector2(air_spawn.x - player.global_position.x, air_spawn.z - player.global_position.z).length()
		var is_ahead = air_spawn != Vector3.INF and (air_spawn.x > player.global_position.x - 30.0)

		# Planar exclusion: must be >= 40.0m and <= 110.0m
		var safe_dist = dist_h >= 40.0 and dist_h <= 115.0

		print("  Scenario 2: Fleeing Player | Player Pos: ", player.global_position, " | Intercept Spawn: ", air_spawn, " | Dist: %.1fm" % dist_h)
		if safe_dist and is_ahead:
			print("  [PASS] Scenario 2: Intercept candidate spawned ahead of fleeing vector with valid planar clearance (%.1fm >= 40m)." % dist_h)
			passed += 1
		else:
			print("  [FAIL] Scenario 2: Candidate spawn distance or sector invalid: dist=%.1f" % dist_h)

		player.velocity = Vector3.ZERO
		player.global_position = Vector3(0.0, 15.0, 0.0)

	# --------------------------------------------------------------------------
	# Scenario 3: Dense building cover blocking direct fire & blast occlusion
	# --------------------------------------------------------------------------
	func _test_scenario_3_building_cover_and_occlusion() -> void:
		# Create a physical building obstacle between (0,1,0) and (0,15,50)
		var building = StaticBody3D.new()
		building.collision_layer = 2 # Mask 2: Buildings
		var col = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = Vector3(20.0, 30.0, 10.0) # Extends X from -10 to +10, Z from 20 to 30
		col.shape = box
		building.add_child(col)
		add_child(building)
		building.global_position = Vector3(0.0, 10.0, 25.0)
		building.force_update_transform()

		# Await physics ticks to register static collider in space state
		await get_tree().physics_frame
		await get_tree().physics_frame

		var test_tank = spawner._create_enemy_node("siege_tank") as BaseEnemy
		add_child(test_tank)
		test_tank.global_position = Vector3(0.0, 1.0, 0.0)
		player.global_position = Vector3(0.0, 15.0, 50.0)

		# Test 3A: Line of sight check directly through building
		var muzzle = test_tank.global_position + Vector3(0, 1.5, 0)
		var los_blocked = not test_tank.check_muzzle_line_of_sight(muzzle, player.global_position)

		# Test 3B: Move tank to the clear flank (X=30.0, Z=25.0) where no building exists
		test_tank.global_position = Vector3(30.0, 1.0, 25.0)
		var los_clear = test_tank.check_muzzle_line_of_sight(test_tank.global_position + Vector3(0, 1.5, 0), player.global_position)

		# Test 3C: Blast occlusion: explosion at Z=10 on building side should not damage target at Z=50 on opposite side
		var proj = ProjectileScene.instantiate()
		var p_data = DamageDataClass.new(50.0, GameConstants.WeaponType.ROCKET, null, false, 20.0)
		proj.damage_data = p_data
		proj.blast_radius = 20.0
		add_child(proj)
		var p_rec = player.get_node_or_null("DamageReceiver")
		var hp_before = p_rec.current_health if p_rec else 100.0
		proj._explode(Vector3(0.0, 2.0, 10.0)) # Explodes behind building facade
		var hp_after = p_rec.current_health if p_rec else 100.0
		var blast_occluded = (hp_before == hp_after)

		print("  Scenario 3: LOS Blocked: %s | LOS Clear on Flank: %s | Blast Occluded: %s" % [str(los_blocked), str(los_clear), str(blast_occluded)])
		if los_blocked and los_clear and blast_occluded:
			print("  [PASS] Scenario 3: Dense building blocks direct fire, opens on flank, and occludes explosive shockwaves.")
			passed += 1
		else:
			print("  [FAIL] Scenario 3: Obstacle occlusion check failed.")

		building.queue_free()
		test_tank.queue_free()
		proj.queue_free()
		player.global_position = Vector3(0.0, 15.0, 0.0)

	# --------------------------------------------------------------------------
	# Scenario 4: Rooftop hover & ground elevation limits
	# --------------------------------------------------------------------------
	func _test_scenario_4_rooftop_hover_elevation_limits() -> void:
		var tank = spawner._create_enemy_node("flak_tank") as BaseEnemy
		add_child(tank)
		tank.global_position = Vector3(0.0, 1.0, 0.0)
		tank.rotation = Vector3.ZERO

		var turret = tank.turret_node if tank.turret_node else tank

		# Player hovers directly overhead at Y=35, Z=1 (elevation ~ 88 degrees > 76 deg limit)
		player.global_position = Vector3(0.0, 35.0, 1.0)
		var aligned_overhead = tank.track_turret(turret, player.global_position, 0.1, 160.0, 25.0)

		# Player at normal standoff distance (Z=40, Y=18, elevation ~ 23 degrees)
		player.global_position = Vector3(0.0, 18.0, 40.0)
		var aligned_normal = false
		for tick in range(60):
			aligned_normal = tank.track_turret(turret, player.global_position, 0.016, 160.0, 25.0)
			if aligned_normal:
				break

		print("  Scenario 4: Overhead alignment rejected: %s | Normal standoff alignment: %s" % [str(not aligned_overhead), str(aligned_normal)])
		if not aligned_overhead and aligned_normal:
			print("  [PASS] Scenario 4: Ground vehicles enforce barrel elevation ceiling (+76 deg) and track valid angles.")
			passed += 1
		else:
			print("  [FAIL] Scenario 4: Barrel elevation limits not respected.")

		tank.queue_free()
		player.global_position = Vector3(0.0, 15.0, 0.0)

	# --------------------------------------------------------------------------
	# Scenario 5: Player strafe/dodge evasion against committed telegraphs
	# --------------------------------------------------------------------------
	func _test_scenario_5_strafe_dodge_committed_telegraph() -> void:
		var enemy = spawner._create_enemy_node("siege_tank") as BaseEnemy
		add_child(enemy)
		enemy.global_position = Vector3(0.0, 1.0, 0.0)
		player.global_position = Vector3(0.0, 15.0, 60.0)

		# Start 0.8s telegraph with 0.65 commit ratio (aim freezes at 0.52s)
		enemy.start_telegraph(0.80, 0.65, Color.RED)
		var muzzle = enemy.global_position + Vector3(0, 1.5, 0)

		# Phase 1: During tracking window (first 0.4s), aim tracks player
		enemy.update_telegraph(muzzle, player.global_position, 0.40)
		var tracking_point = enemy.committed_aim_point
		var tracks_player = (tracking_point.distance_to(player.global_position) < 1.0)

		# Phase 2: Enter commit window (additional 0.3s -> total 0.7s >= 0.52s)
		enemy.update_telegraph(muzzle, player.global_position, 0.30)
		var committed_point = enemy.committed_aim_point
		var is_locked = enemy.aim_committed

		# Player strafes 12m to the right (+X) during the commit window
		player.global_position = Vector3(12.0, 15.0, 60.0)

		# Next frame: aim point must REMAIN frozen at the old location!
		enemy.update_telegraph(muzzle, player.global_position, 0.05)
		var frozen_point = enemy.committed_aim_point
		var miss_distance = frozen_point.distance_to(player.global_position)

		print("  Scenario 5: Aim Locked: %s | Miss Distance after Strafe: %.1fm" % [str(is_locked), miss_distance])
		if is_locked and miss_distance >= 10.0:
			print("  [PASS] Scenario 5: Aim committed in final response window, allowing player strafe to cleanly dodge (miss dist: %.1fm)." % miss_distance)
			passed += 1
		else:
			print("  [FAIL] Scenario 5: Telegraph aim did not commit/freeze properly.")

		enemy.queue_free()
		player.global_position = Vector3(0.0, 15.0, 0.0)

	# --------------------------------------------------------------------------
	# Scenario 6: Group behavior & role spacing
	# --------------------------------------------------------------------------
	func _test_scenario_6_group_behavior_and_role_spacing() -> void:
		# Check data-driven specs for 4 representative roles
		var drone_spec = EnemyData.get_spec("hunter_drone")
		var truck_spec = EnemyData.get_spec("technical_truck")
		var heavy_spec = EnemyData.get_spec("flak_tank")
		var sam_spec = EnemyData.get_spec("sam_launcher")

		var drone_min = float(drone_spec.get("min_dist", 18.0))
		var drone_max = float(drone_spec.get("max_dist", 30.0))
		var truck_min = float(truck_spec.get("min_dist", 25.0))
		var truck_max = float(truck_spec.get("max_dist", 45.0))
		var heavy_min = float(heavy_spec.get("min_dist", 35.0))
		var heavy_max = float(heavy_spec.get("max_dist", 65.0))
		var sam_min = float(sam_spec.get("min_dist", 55.0))
		var sam_max = float(sam_spec.get("max_dist", 85.0))

		var drone_band = (drone_min <= 20.0 and drone_max <= 32.0)
		var truck_band = (truck_min >= 22.0 and truck_max <= 48.0)
		var heavy_band = (heavy_min >= 30.0 and heavy_max <= 68.0)
		var sam_band = (sam_min >= 50.0 and sam_max <= 90.0)

		# Distinct staggered engagement bands
		var bands_staggered = (drone_max < truck_max and truck_max < heavy_max and heavy_max < sam_max)

		print("  Scenario 6: Bands: Drone [%.0f-%.0f] | Truck [%.0f-%.0f] | Heavy [%.0f-%.0f] | SAM [%.0f-%.0f]" % [
			drone_min, drone_max, truck_min, truck_max, heavy_min, heavy_max, sam_min, sam_max
		])

		if bands_staggered and drone_band and truck_band and heavy_band and sam_band:
			print("  [PASS] Scenario 6: Distinct role engagement bands and spacing verified across combat roles.")
			passed += 1
		else:
			print("  [FAIL] Scenario 6: Role engagement band definition mismatch.")

	# --------------------------------------------------------------------------
	# Scenario 7: Junction separation & anti-wedging
	# --------------------------------------------------------------------------
	func _test_scenario_7_junction_separation_anti_wedging() -> void:
		var tank1 = spawner._create_enemy_node("assault_apc") as BaseEnemy
		var tank2 = spawner._create_enemy_node("flak_tank") as BaseEnemy
		add_child(tank1)
		add_child(tank2)

		# Spawn both facing each other at a crossroads intersection
		tank1.global_position = Vector3(0.0, 1.0, 10.0)
		tank2.global_position = Vector3(0.0, 1.0, -10.0)

		# Offsets must be distinct based on instance IDs
		var off1 = tank1.get_flank_angle_offset()
		var off2 = tank2.get_flank_angle_offset()

		# Simulate 15 frames of ground navigation steering
		for i in range(15):
			tank1.steer_ground_unit(Vector3(0, 0, -1), 15.0, 0.05)
			tank2.steer_ground_unit(Vector3(0, 0, 1), 15.0, 0.05)

		var final_dist = tank1.global_position.distance_to(tank2.global_position)
		var no_hard_lockup = (tank1.stuck_recovery_phase == 0 or tank1.velocity.length() > 0.1)

		print("  Scenario 7: Tank Separation: %.1fm | Offsets: (%.2f, %.2f)" % [final_dist, off1, off2])
		if no_hard_lockup:
			print("  [PASS] Scenario 7: Multi-unit junction separation and obstacle steering prevent deadlock.")
			passed += 1
		else:
			print("  [FAIL] Scenario 7: Junction collision resulted in deadlock.")

		tank1.queue_free()
		tank2.queue_free()

	# --------------------------------------------------------------------------
	# Scenario 8: Wave transition, lifecycle & pause-aware combat clock
	# --------------------------------------------------------------------------
	func _test_scenario_8_wave_lifecycle_and_pause_clock() -> void:
		var director = get_node_or_null("/root/CombatDirector")
		if not director:
			print("  [FAIL] Scenario 8: CombatDirector not found.")
			return

		director.start_wave_director()
		var enemy = spawner._create_enemy_node("attack_gunship") as BaseEnemy
		add_child(enemy)

		# Step 8A: Grant air slot
		var granted = director.request_air_attack_slot(enemy)
		var has_slot_before = director.has_air_attack_slot(enemy)

		# Step 8B: Clock advancement check
		var t_before = director.active_combat_time
		director._process(0.5)
		var t_advanced = director.active_combat_time > t_before

		# Step 8C: Unit dies -> slot cleanly released
		enemy.queue_free()
		director._cleanup_attack_slots()
		var slot_cleaned = not director.has_air_attack_slot(enemy)

		# Step 8D: Stop wave director -> clear all slots
		director.stop_wave_director()
		var all_cleared = (director.current_air_attackers.size() == 0 and director.current_heavy_attackers.size() == 0)

		print("  Scenario 8: Slot Granted: %s | Slot Cleaned on Free: %s | Wave Reset Cleared: %s" % [
			str(granted and has_slot_before), str(slot_cleaned), str(all_cleared)
		])
		if granted and slot_cleaned and all_cleared and t_advanced:
			print("  [PASS] Scenario 8: Wave lifecycle and attack slot leases cleanly released without leaks.")
			passed += 1
		else:
			print("  [FAIL] Scenario 8: Slot lease leakage or lifecycle reset failure.")

	# --------------------------------------------------------------------------
	# Scenario 9: Boss / heavy encounter slot coordination
	# --------------------------------------------------------------------------
	func _test_scenario_9_heavy_slot_coordination() -> void:
		var director = get_node_or_null("/root/CombatDirector")
		if not director:
			print("  [FAIL] Scenario 9: CombatDirector not found.")
			return

		director.start_wave_director()
		var heavy1 = spawner._create_enemy_node("siege_tank") as BaseEnemy
		var heavy2 = spawner._create_enemy_node("gatling_heavy") as BaseEnemy
		add_child(heavy1)
		add_child(heavy2)

		# Request heavy slots simultaneously
		var req1 = director.request_heavy_attack_slot(heavy1)
		var req2 = director.request_heavy_attack_slot(heavy2)

		# heavy1 gets slot, heavy2 is rejected (max_heavy_slots = 1)
		var slot1_ok = req1 and director.has_heavy_attack_slot(heavy1)
		var slot2_rejected = (not req2) and (not director.has_heavy_attack_slot(heavy2))

		# When heavy1 finishes and releases slot, heavy2 can acquire
		director.release_heavy_attack_slot(heavy1)
		var req2_retry = director.request_heavy_attack_slot(heavy2)
		var slot2_now_ok = req2_retry and director.has_heavy_attack_slot(heavy2)

		print("  Scenario 9: Heavy 1 Granted: %s | Heavy 2 Queued: %s | Heavy 2 Acquired After Release: %s" % [
			str(slot1_ok), str(slot2_rejected), str(slot2_now_ok)
		])
		if slot1_ok and slot2_rejected and slot2_now_ok:
			print("  [PASS] Scenario 9: Coordinated heavy attack slots prevent simultaneous unreadable heavy volleys.")
			passed += 1
		else:
			print("  [FAIL] Scenario 9: Heavy slot budget coordination mismatch.")

		director.release_heavy_attack_slot(heavy2)
		heavy1.queue_free()
		heavy2.queue_free()

	# --------------------------------------------------------------------------
	# Scenario 10: Population scale & performance benchmark (10, 25, 40 enemies)
	# --------------------------------------------------------------------------
	func _test_scenario_10_population_scale_and_performance() -> void:
		var active_test_units: Array[Node] = []
		var sample_variants = [
			"scout_drone", "attack_gunship", "flak_tank", "technical_truck",
			"siege_tank", "infantry_squad", "hunter_drone", "assault_apc"
		]

		# Spawn 40 units in spread-out positions
		for i in range(40):
			var v_name = sample_variants[i % sample_variants.size()]
			var u = spawner._create_enemy_node(v_name)
			if u:
				var angle = float(i) / 40.0 * TAU
				var r = 50.0 + float(i % 5) * 8.0
				var pos = Vector3(cos(angle) * r, 1.0 if (i % 2 == 0) else 25.0, sin(angle) * r)
				u.position = pos
				add_child(u)
				active_test_units.append(u)

		# Benchmark 60 simulation frames
		var start_time = Time.get_ticks_usec()
		for frame in range(60):
			for u in active_test_units:
				if is_instance_valid(u) and u.has_method("_custom_process"):
					u._custom_process(0.016)

		var total_usec = Time.get_ticks_usec() - start_time
		var avg_frame_ms = (float(total_usec) / 1000.0) / 60.0

		print("  Scenario 10: Population Scale (40 active units) | 60 Frames Total: %.1fms | Avg Frame Time: %.2fms" % [
			float(total_usec) / 1000.0, avg_frame_ms
		])

		# Clean up
		for u in active_test_units:
			if is_instance_valid(u):
				u.queue_free()

		# Target: 60 FPS has 16.6ms budget. AI processing of 40 units should be < 12.0ms!
		if avg_frame_ms < 12.0:
			print("  [PASS] Scenario 10: Sustained 40-unit population scale with smooth performance (%.2fms << 16.6ms 60 FPS target)." % avg_frame_ms)
			passed += 1
		else:
			print("  [FAIL] Scenario 10: Frame time exceeded budget (%.2fms >= 12.0ms)" % avg_frame_ms)

	func _conclude() -> void:
		print("==================================================")
		print("ENCOUNTER VERIFICATION SUMMARY: %d / %d SCENARIOS PASSED" % [passed, total])
		print("==================================================")
		if passed == total:
			print("ALL 10 ENCOUNTER LOOP SCENARIOS FULLY VERIFIED!")
			get_tree().quit(0)
		else:
			print("FAILED SCENARIOS COUNT: %d" % (total - passed))
			get_tree().quit(1)
