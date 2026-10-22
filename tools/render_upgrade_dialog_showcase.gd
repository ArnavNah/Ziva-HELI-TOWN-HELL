extends SceneTree

func _init() -> void:
	print("--- Rendering In-Game Upgrade Card Selection Modal ---")
	var scene = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(scene)
	var capturer = ShowcaseCapturer.new()
	root.add_child(capturer)

class ShowcaseCapturer extends Node:
	var frame: int = 0
	var diag: UpgradeDialog = null

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(_delta: float) -> void:
		frame += 1

		if diag == null:
			diag = get_tree().root.find_child("UpgradeDialog", true, false) as UpgradeDialog

		# At frame 5, display the modal with 3 diverse cards (Standard, Evolution, Legendary)
		if frame == 5 and diag:
			var player = get_tree().get_first_node_in_group("player")
			if player:
				var prog = player.get_node_or_null("RunProgression")
				if prog:
					prog.current_run_level = 3
					prog.queued_level_ups = 1
					prog.upgrade_stacks["overclock_rounds"] = 1
					prog.upgrade_stacks["hair_trigger"] = 2
					prog.upgrade_stacks["reinforced_hull"] = 1
			diag.show_choices(["Overclock Rounds", "EVO: Vulcan Storm", "LEGENDARY: Ghost Rotor"])
			if diag.cards.size() >= 2:
				diag.cards[1].grab_focus()

		# Frame 18: Capture 1280x720 (Standard resolution)
		elif frame == 18:
			var img = get_viewport().get_texture().get_image()
			if img and not img.is_empty():
				img.save_png("res://artifacts/upgrade_dialog_1280x720.png")
				print("Saved res://artifacts/upgrade_dialog_1280x720.png (", img.get_width(), "x", img.get_height(), ")")

			# Switch window to 960x540 (Responsive compact resolution)
			DisplayServer.window_set_size(Vector2i(960, 540))

		# Frame 32: Capture 960x540
		elif frame == 32:
			var img2 = get_viewport().get_texture().get_image()
			if img2 and not img2.is_empty():
				img2.save_png("res://artifacts/upgrade_dialog_960x540.png")
				print("Saved res://artifacts/upgrade_dialog_960x540.png (", img2.get_width(), "x", img2.get_height(), ")")
			get_tree().quit(0)
