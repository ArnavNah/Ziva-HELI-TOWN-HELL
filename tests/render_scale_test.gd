extends SceneTree

func _init():
	print("Instantiating scale_test.tscn for scale verification...")
	var scene = load("res://scale_test.tscn").instantiate()
	root.add_child(scene)
	
	var runner = ScreenshotCapture.new()
	root.add_child(runner)

class ScreenshotCapture extends Node:
	var frame = 0
	
	func _process(_delta):
		frame += 1
		if frame == 20:
			var img = get_viewport().get_texture().get_image()
			if img and not img.is_empty():
				var out_path = "C:/Users/Prime 3/.gemini/antigravity/brain/95ea2036-de70-4bda-98bc-0cd205794470/scale_test_nuclear_strike.png"
				var err = img.save_png(out_path)
				print("Saved scale test screenshot with code: ", err, " to ", out_path)
			else:
				print("Viewport texture image was empty or unavailable.")
			get_tree().quit(0)
