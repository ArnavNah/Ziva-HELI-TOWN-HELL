extends SceneTree

func _initialize() -> void:
	call_deferred("_render")

func _render() -> void:
	var flow = root.get_node("UIFlow")
	var scene = load("res://scenes/ui/vehicle_selection_menu.tscn").instantiate()
	root.add_child(scene)
	if scene.has_method("initialize_menu"):
		scene.initialize_menu()
	
	for i in range(15):
		await process_frame
	
	await RenderingServer.frame_post_draw
	var img = root.get_texture().get_image()
	img.save_png("res://artifacts/vehicle_selection_before.png")
	img.save_png("C:/Users/Prime 3/.gemini/antigravity/brain/246bfbd5-df79-41ad-b1db-2ff3804610f7/vehicle_selection_before.png")
	print("Captured baseline to artifacts/vehicle_selection_before.png")
	quit(0)
