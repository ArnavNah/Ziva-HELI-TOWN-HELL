extends SceneTree

func _init() -> void:
	var root_node = Node3D.new()
	root.add_child(root_node)

	var env = WorldEnvironment.new()
	var env_res = Environment.new()
	env_res.background_mode = Environment.BG_COLOR
	env_res.background_color = Color(0.2, 0.25, 0.3)
	env.environment = env_res
	root_node.add_child(env)

	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 45, 0)
	root_node.add_child(sun)

	var glb_path = "C:/Users/Prime 3/Documents/Downloads/urban-stike-rogue/assets/vehicles/player/body.glb"
	var gltf_doc = GLTFDocument.new()
	var gltf_state = GLTFState.new()
	var err = gltf_doc.append_from_file(glb_path, gltf_state)
	if err == OK:
		var model = gltf_doc.generate_scene(gltf_state)
		root_node.add_child(model)
		model.position = Vector3(0, 0, 0)
		print("Loaded player body.glb successfully!")

	var cam = Camera3D.new()
	root_node.add_child(cam)
	cam.position = Vector3(6, 4, 8)
	cam.look_at_from_position(cam.position, Vector3(0, 1.0, 0), Vector3.UP)

	var runner = PreviewRunner.new()
	root.add_child(runner)

class PreviewRunner extends Node:
	var frame = 0
	func _process(_delta):
		frame += 1
		if frame == 10:
			var img = get_viewport().get_texture().get_image()
			if img and not img.is_empty():
				img.save_png("C:/Users/Prime 3/.gemini/antigravity/brain/06e196af-0c7a-4631-b084-e06e5feaf17e/player_body_glb_preview.png")
				print("Saved player_body_glb_preview.png")
			get_tree().quit(0)
