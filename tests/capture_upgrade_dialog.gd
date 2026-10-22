extends SceneTree

func _init() -> void:
	print("--- CAPTURING UPGRADE CARD SELECTION MODAL ---")
	var scene = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(scene)
	var capturer = CaptureRunner.new()
	root.add_child(capturer)

class CaptureRunner extends Node:
	var frame: int = 0

	func _process(_delta: float) -> void:
		frame += 1

		var diag: UpgradeDialog = get_tree().root.find_child("UpgradeDialog", true, false) as UpgradeDialog

		if frame == 5 and diag:
			diag.show_choices(["Overclock Rounds", "EVOLUTION: Vulcan Storm", "LEGENDARY: Ghost Rotor"])

		elif frame == 25:
			var img = get_viewport().get_texture().get_image()
			if img:
				var path = "C:/Users/Prime 3/.gemini/antigravity/brain/246bfbd5-df79-41ad-b1db-2ff3804610f7/upgrade_card_selection_modal.png"
				img.save_png(path)
				print("[CAPTURE SUCCESS] Saved modal screenshot to: ", path)
			get_tree().quit(0)
