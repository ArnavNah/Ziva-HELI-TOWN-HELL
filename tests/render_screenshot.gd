extends SceneTree

func _init():
	print("Instantiating main_game for visual verification...")
	var scene = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(scene)
	
	var runner = ScreenshotCapture.new()
	root.add_child(runner)

class ScreenshotCapture extends Node:
	var frame = 0
	
	func _process(_delta):
		frame += 1
		if frame == 15:
			var img = get_viewport().get_texture().get_image()
			if img and not img.is_empty():
				var out_path = "C:/Users/Prime 3/.gemini/antigravity/brain/95ea2036-de70-4bda-98bc-0cd205794470/altitude_verification.png"
				var err = img.save_png(out_path)
				print("Saved screenshot with code: ", err, " to ", out_path)
			else:
				print("Viewport texture image was empty or unavailable in this mode.")
			get_tree().quit(0)
