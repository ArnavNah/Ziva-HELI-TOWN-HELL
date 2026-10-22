extends SceneTree

const LevelUpUi = preload("res://src/ui/level_up_ui.gd")

func _init() -> void:
	print("--- Rendering Data-Driven LevelUpUi Modal Showcase ---")
	var scene = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(scene)
	var capturer = ShowcaseCapturer.new()
	root.add_child(capturer)

class ShowcaseCapturer extends Node:
	var frame: int = 0
	var ui: Node = null

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(_delta: float) -> void:
		frame += 1

		if ui == null:
			ui = get_tree().root.find_child("LevelUpUi", true, false)

		# Frame 5: Open draft modal
		if frame == 5 and ui:
			ui.open_draft(2)

		# Frame 15: Capture 1280x720
		elif frame == 15:
			var img = get_viewport().get_texture().get_image()
			if img and not img.is_empty():
				img.save_png("res://artifacts/levelup_ui_1280x720.png")
				print("Saved res://artifacts/levelup_ui_1280x720.png")

			# Resize to 960x540
			DisplayServer.window_set_size(Vector2i(960, 540))

		# Frame 30: Capture 960x540
		elif frame == 30:
			var img2 = get_viewport().get_texture().get_image()
			if img2 and not img2.is_empty():
				img2.save_png("res://artifacts/levelup_ui_960x540.png")
				print("Saved res://artifacts/levelup_ui_960x540.png")
			get_tree().quit(0)
