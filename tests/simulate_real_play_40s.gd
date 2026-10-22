extends SceneTree

func _init() -> void:
	print("--- SIMULATING REAL USER GAMEPLAY FOR 40 SECONDS ---")
	var menu_scene = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu_scene)

	var bot = RealPlayBot.new()
	root.add_child(bot)

class RealPlayBot extends Node:
	var frame: int = 0
	var player: CharacterBody3D = null
	var deployed: bool = false
	var start_play_msec: int = 0
	var frame_times: Array[float] = []
	var last_tick: int = 0

	func _ready():
		process_mode = Node.PROCESS_MODE_ALWAYS
		last_tick = Time.get_ticks_usec()

	func _process(delta: float):
		var now = Time.get_ticks_usec()
		var dt_ms = float(now - last_tick) / 1000.0
		last_tick = now

		frame += 1

		if frame >= 400 and frame <= 425:
			print("[DEBUG FRAME %d] dt=%.2f ms, enemies=%d, paused=%s" % [frame, dt_ms, get_tree().get_nodes_in_group("enemies").size(), get_tree().paused])

		# At frame 10: Click Deploy on main menu
		if frame == 10 and not deployed:
			deployed = true
			print("[Frame 10] Triggering begin_run via UIFlow...")
			var uif = get_node_or_null("/root/UIFlow")
			if uif and uif.has_method("begin_run"):
				uif.begin_run("apache")
			else:
				var gm = get_node_or_null("/root/GameManager")
				if gm:
					gm.start_new_run("apache")

		if deployed and player == null:
			player = get_tree().get_first_node_in_group("player")
			if player:
				print("[Frame %d] Player spawned into world at: %s" % [frame, str(player.global_position)])
				start_play_msec = Time.get_ticks_msec()
				var dr = player.get_node_or_null("DamageReceiver")
				if dr:
					dr.max_health = 99999.0
					dr.health = 99999.0

		if player and is_instance_valid(player):
			var play_time_sec = float(Time.get_ticks_msec() - start_play_msec) / 1000.0
			var is_paused = get_tree().paused
			
			var dr = player.get_node_or_null("DamageReceiver")
			if dr:
				dr.health = 99999.0

			if is_paused:
				var gm_state = str(get_node("/root/GameManager").current_state) if has_node("/root/GameManager") else "none"
				var up = get_tree().root.find_child("UpgradeDialog", true, false)
				var up_vis = up.visible if up else false
				var up_cards = up.offered_cards if up and "offered_cards" in up else []
				print("[PAUSED DETECTED at %.1fs | frame %d] gm_state=%s, up_dlg_found=%s, up_vis=%s, cards=%s" % [
					play_time_sec, frame, gm_state, up != null, up_vis, str(up_cards)
				])
				if up and up.has_method("_choose_card") and not up_cards.is_empty():
					print("Auto-choosing card 0 from pause detector...")
					up._choose_card(0)
				elif up and up.visible and up.has_method("_on_card_1_selected"):
					up._on_card_1_selected()

			if not is_paused:
				frame_times.append(dt_ms)
				if dt_ms > 50.0:
					var gm_state = "unknown"
					if has_node("/root/GameManager"):
						gm_state = str(get_node("/root/GameManager").current_state)
					var enemy_list = []
					for e in get_tree().get_nodes_in_group("enemies"):
						if is_instance_valid(e):
							enemy_list.append(e.variant_id if "variant_id" in e else e.name)
					print("[LAG SPIKE] Play time: %.1fs (frame %d) took %.2f ms! Engine delta=%.2f ms, state=%s, enemies=%s" % [
						play_time_sec, frame, dt_ms, delta * 1000.0, gm_state, str(enemy_list)
					])

			# If upgrade dialog appears, pick an upgrade automatically to continue
			var upgrade_dlg = get_tree().get_first_node_in_group("upgrade_dialog")
			if not upgrade_dlg:
				upgrade_dlg = get_tree().root.find_child("UpgradeDialog", true, false)
			if upgrade_dlg and upgrade_dlg.visible:
				print("[UpgradeDialog visible at %.1fs] Auto-selecting card 0..." % play_time_sec)
				if upgrade_dlg.has_method("_choose_card"):
					upgrade_dlg._choose_card(0)
				elif upgrade_dlg.has_method("_on_card_1_selected"):
					upgrade_dlg._on_card_1_selected()

			# Emulate player flight circling the town and shooting
			var patrol_radius = 55.0
			var patrol_speed = 0.35
			var angle = play_time_sec * patrol_speed
			player.global_position = Vector3(cos(angle) * patrol_radius, 14.0, sin(angle) * patrol_radius)
			player.velocity = Vector3(-sin(angle) * patrol_radius * patrol_speed, 0.0, cos(angle) * patrol_radius * patrol_speed)

			var weapons = player.get_node_or_null("Weapons")
			if weapons and is_instance_valid(weapons) and not is_paused:
				if frame % 10 == 0:
					weapons.try_fire()

			# Log state every 5s
			if frame % 300 == 0:
				var enemies = get_tree().get_nodes_in_group("enemies")
				var enemy_count = 0
				for e in enemies:
					if is_instance_valid(e) and not (e.has_node("DamageReceiver") and e.get_node("DamageReceiver").is_dead):
						enemy_count += 1
				var proj_count = get_tree().get_nodes_in_group("combat_projectiles").size() + get_tree().get_nodes_in_group("enemy_projectiles").size()
				var wave = 1
				var cd = get_node_or_null("/root/CombatDirector")
				if cd:
					wave = cd.current_wave
				print("[Active Play: %.1fs | frame %d] FPS=%.1f Enemies=%d Proj=%d Wave=%d Paused=%s" % [
					play_time_sec, frame, Performance.get_monitor(Performance.TIME_FPS), enemy_count, proj_count, wave, is_paused
				])

			if play_time_sec >= 38.0:
				print("--- 38 SECONDS OF ACTIVE GAMEPLAY COMPLETED WITHOUT CRASH ---")
				frame_times.sort()
				var med = frame_times[int(frame_times.size() * 0.5)]
				var p95 = frame_times[int(frame_times.size() * 0.95)]
				print("Median dt: %.2f ms, p95 dt: %.2f ms" % [med, p95])
				get_tree().quit(0)
