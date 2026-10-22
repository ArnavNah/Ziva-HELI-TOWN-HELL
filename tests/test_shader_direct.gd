extends SceneTree

func _init() -> void:
	var cr = ColorRect.new()
	cr.size = Vector2(1280, 720)
	var sm = ShaderMaterial.new()
	sm.shader = load("res://src/shaders/blood_vignette.gdshader")
	sm.set_shader_parameter("blood_intensity", 0.8)
	sm.set_shader_parameter("pulse_speed", 5.0)
	sm.set_shader_parameter("hit_flash", 0.0)
	cr.material = sm
	root.add_child(cr)
	
	var runner = TestRunner.new()
	runner.cr = cr
	root.add_child(runner)

class TestRunner extends Node:
	var cr: ColorRect
	var frame = 0
	func _process(_delta):
		frame += 1
		if frame == 10:
			var img = get_viewport().get_texture().get_image()
			img.save_png("C:/Users/Prime 3/.gemini/antigravity/brain/246bfbd5-df79-41ad-b1db-2ff3804610f7/test_shader_direct.png")
			print("Saved test_shader_direct.png")
			get_tree().quit(0)
