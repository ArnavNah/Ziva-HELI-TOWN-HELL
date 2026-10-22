extends SceneTree

func _init() -> void:
	print("--- BEGIN VISUAL CAPTURE: FLAMES, SMOKE & BLOOD VIGNETTE ---")
	var scene = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(scene)
	var capturer = CaptureRunner.new()
	root.add_child(capturer)

class CaptureRunner extends Node:
	var frame: int = 0

	func _process(_delta: float) -> void:
		frame += 1

		var player: PlayerHelicopter = get_tree().get_first_node_in_group("player") as PlayerHelicopter
		var hud: CombatHUD = get_tree().root.find_child("CombatHUD", true, false) as CombatHUD

		if frame >= 5 and frame <= 29 and player and hud:
			player.current_hull = 10.0
			player._update_damage_effects(0.016)
			hud.player_helicopter = player
			hud.hit_flash_intensity = 0.35
			hud._update_blood_vignette(0.016)

		elif frame == 30:
			if hud and hud.blood_overlay:
				print("DEBUG: visible=", hud.blood_overlay.visible, " size=", hud.blood_overlay.size, " intensity=", hud.blood_intensity, " flash=", hud.hit_flash_intensity)
			var img = get_viewport().get_texture().get_image()
			if img:
				var target_path = "C:/Users/Prime 3/.gemini/antigravity/brain/246bfbd5-df79-41ad-b1db-2ff3804610f7/helicopter_damage_fire_blood_vignette.png"
				img.save_png(target_path)
				print("[CAPTURE SUCCESS] Saved visual proof to: ", target_path)
			else:
				print("[CAPTURE FAIL] Could not retrieve viewport image.")
			get_tree().quit(0)
