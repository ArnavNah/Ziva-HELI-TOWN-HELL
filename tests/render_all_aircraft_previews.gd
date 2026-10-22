extends SceneTree

func _initialize() -> void:
	call_deferred("_render_all")

func _render_all() -> void:
	root.size = Vector2i(1280, 720)
	var scene: VehicleSelectionMenu = load("res://scenes/ui/vehicle_selection_menu.tscn").instantiate()
	root.add_child(scene)
	scene.visible = true

	var names := ["apache", "nighthawk", "warlock"]
	var brain_dir := "C:/Users/Prime 3/.gemini/antigravity/brain/246bfbd5-df79-41ad-b1db-2ff3804610f7/"

	for i in range(3):
		scene.select_aircraft(i)
		for f in range(12):
			await process_frame
		await RenderingServer.frame_post_draw

		var img = root.get_texture().get_image()
		var p_art = "res://artifacts/vehicle_selection_%s.png" % names[i]
		var p_brain = brain_dir + "vehicle_selection_%s.png" % names[i]
		img.save_png(p_art)
		img.save_png(p_brain)
		print("Rendered selection for: ", names[i])

	quit(0)
