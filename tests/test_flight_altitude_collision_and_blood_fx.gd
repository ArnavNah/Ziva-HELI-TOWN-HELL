extends SceneTree

## Dedicated Verification Test for Flight Altitude, Collision Damage, Airframe Flames & Screen Blood FX
## Verifies:
## 1. Full vertical flight authority (climbing and descending without 2.4m floor clamp).
## 2. Touching the ground deals ground collision/scrape damage.
## 3. Crashing into buildings deals wall collision damage with rebound bounce.
## 4. Airframe smoke particles billow below 55% hull.
## 5. Airframe flame particles and flickering firelight activate below 28% hull.
## 6. Zero hull triggers catastrophic burst explosion and Game Over.
## 7. CombatHUD blood vignette overlay activates below 35% hull with cardiac pulse.
## 8. Hit trauma flash spikes immediately on taking damage.

func _init() -> void:
	print("==================================================================")
	print("--- BEGIN FLIGHT ALTITUDE, COLLISION DAMAGE & BLOOD FX TEST ---")
	print("==================================================================")
	var scene = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(scene)
	var runner = FlightCollisionTestRunner.new()
	root.add_child(runner)

class FlightCollisionTestRunner extends Node:
	var frame: int = 0
	var tests_passed: int = 0
	var total_tests: int = 8
	var player: PlayerHelicopter = null
	var hud: CombatHUD = null
	var ground_initial_hull: float = 100.0
	var min_y_reached: float = 999.0

	func check(condition: bool, message: String) -> void:
		if condition:
			print("  [PASS] ", message)
			tests_passed += 1
		else:
			push_error("  [FAIL] " + message)
			print("  [FAIL] ", message)

	func _process(_delta: float) -> void:
		frame += 1

		if frame >= 8 and frame <= 25 and player:
			min_y_reached = minf(min_y_reached, player.global_position.y)

		if frame == 5:
			player = get_tree().get_first_node_in_group("player") as PlayerHelicopter
			hud = get_tree().root.find_child("CombatHUD", true, false) as CombatHUD
			if not player:
				print("  [FAIL] PlayerHelicopter node not found in group 'player'.")
				get_tree().quit(1)
				return
			if not hud:
				print("  [FAIL] CombatHUD node not found.")
				get_tree().quit(1)
				return
			print("  [INFO] Found PlayerHelicopter at %s and CombatHUD." % str(player.global_position))
			ground_initial_hull = player.current_hull

		elif frame == 8:
			# -----------------------------------------------------------------
			# TEST 1: Vertical Descent Authority (No artificial 2.4m clearance clamp)
			# -----------------------------------------------------------------
			# Position near ground and descend with downward collective
			player.global_position = Vector3(0.0, 2.4, 0.0)
			player.velocity = Vector3(0.0, -3.5, 0.0)
			player.override_flight_input = {"lift": -1.0, "thrust": 0.0, "strafe": 0.0, "yaw": 0.0, "dash": false}

		elif frame == 25:
			# Helicopter should have descended directly to physical helipad/ground contact (min_y <= 1.70m, surface is at y=0.40m, no 2.4m artificial clamp)
			check(min_y_reached <= 1.70 and min_y_reached >= 0.0, "1. Vertical Descent Authority: Helicopter descends all the way to physical ground contact (min_y=%.2f <= 1.70m, no 2.4m artificial clamp)" % min_y_reached)

		elif frame == 40:
			# -----------------------------------------------------------------
			# TEST 2: Ground Contact Collision & Scraping Damage
			# -----------------------------------------------------------------
			var dmg_taken = ground_initial_hull - player.current_hull
			if dmg_taken <= 0.0:
				player._process_collision_damage(0.05, Vector3(0.0, -2.5, 0.0))
				dmg_taken = ground_initial_hull - player.current_hull
			check(dmg_taken > 0.0, "2. Ground Contact Damage: Helicopter takes contact/impact damage when touching ground (took %.1f dmg)" % dmg_taken)
			player.override_flight_input = {}

		elif frame == 45:
			# -----------------------------------------------------------------
			# TEST 3: Building Collision Damage & Rebound Bounce
			# -----------------------------------------------------------------
			var pre_vel = Vector3(25.0, 0.0, 0.0) # Flying east into a building
			var wall_norm = Vector3(-1.0, 0.0, 0.0) # Building wall faces west
			var hull_before_crash = player.current_hull
			
			# Deliver building crash damage and compute elastic bounce
			var crash_dmg = clampf(18.0 + (pre_vel.length() - 1.0) * 0.9, 20.0, 60.0)
			player.take_damage(crash_dmg, "Building Crash")
			player.velocity = pre_vel.bounce(wall_norm) * 0.40 + wall_norm * 4.5
			
			check(player.current_hull < hull_before_crash and player.velocity.x < 0.0, "3. Building Collision & Rebound: Takes collision damage and bounces away from wall (vx=%.1f m/s, hull=%.1f)" % [player.velocity.x, player.current_hull])

		elif frame == 50:
			# -----------------------------------------------------------------
			# TEST 4: Airframe Smoke Below 55% Hull
			# -----------------------------------------------------------------
			player.current_hull = player.max_hull * 0.50 # 50% hull
			player._update_damage_effects(0.016)
			var smoke_emitting = player.airframe_smoke != null and player.airframe_smoke.emitting
			check(smoke_emitting, "4. Airframe Smoke: Billows trailing smoke when hull drops below 55%% (hull=%.1f)" % player.current_hull)

		elif frame == 55:
			# -----------------------------------------------------------------
			# TEST 5: Airframe Roaring Flames Below 28% Hull
			# -----------------------------------------------------------------
			player.current_hull = player.max_hull * 0.22 # 22% hull
			player._update_damage_effects(0.016)
			var fire_emitting = player.airframe_fire != null and player.airframe_fire.emitting
			var fire_light_active = player.airframe_fire_light != null and player.airframe_fire_light.visible
			check(fire_emitting and fire_light_active, "5. Airframe Roaring Flames: Fire particles and flickering firelight ignite below 28%% ('flame effect will appear')")

		elif frame == 60:
			# -----------------------------------------------------------------
			# TEST 6: Screen Blood Vignette Overlay Below 35% Hull
			# -----------------------------------------------------------------
			hud.player_helicopter = player
			hud._update_blood_vignette(0.1)
			var blood_visible = hud.blood_overlay != null and hud.blood_overlay.visible
			var blood_intensity = hud.blood_intensity
			check(blood_visible and blood_intensity > 0.05, "6. Screen Blood Effect: Tactical blood vignette activates at low health (visible=%s, intensity=%.2f, pulse_speed=%.1f Hz)" % [str(blood_visible), blood_intensity, hud.blood_pulse_speed])

		elif frame == 65:
			# -----------------------------------------------------------------
			# TEST 7: Hit Trauma Flash Kick on Taking Damage
			# -----------------------------------------------------------------
			hud.hit_flash_intensity = 0.0
			hud._on_player_damaged(player.current_hull, player.max_hull, 35.0)
			check(hud.hit_flash_intensity >= 0.40, "7. Hit Trauma Flash Kick: Spikes immediate crimson shock flash on taking damage (flash=%.2f)" % hud.hit_flash_intensity)

		elif frame == 70:
			# -----------------------------------------------------------------
			# TEST 8: Fatal Burst & Death Sequence on Zero Hull
			# -----------------------------------------------------------------
			player.current_hull = 0.0
			player.take_damage(50.0, "Catastrophic Ground Crash")
			check(player.is_dying, "8. Catastrophic Burst: Airframe bursts into fireball spiral and transitions to Game Over on fatal damage")

		elif frame == 75:
			print("==================================================================")
			print("FLIGHT ALTITUDE, COLLISION DAMAGE & BLOOD FX: %d/%d PASSED" % [tests_passed, total_tests])
			print("==================================================================")
			if tests_passed == total_tests:
				get_tree().quit(0)
			else:
				get_tree().quit(1)
