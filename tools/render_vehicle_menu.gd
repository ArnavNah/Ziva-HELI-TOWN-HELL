extends SceneTree

func _initialize() -> void:
	call_deferred("_start")

func _start() -> void:
	root.size = Vector2i(1280, 720)
	var pm = root.get_node_or_null("ProfileManager")
	if pm:
		pm.banked_credits = 150
		pm.salvage = 0
		pm.high_score = 0

	var menu: VehicleSelectionMenu = load("res://scenes/ui/vehicle_selection_menu.tscn").instantiate()
	root.add_child(menu)
	menu.visible = true

	var files := [
		{"idx": 0, "path": "res://artifacts/vehicle_menu_apache.png"},
		{"idx": 1, "path": "res://artifacts/vehicle_menu_nighthawk.png"},
		{"idx": 2, "path": "res://artifacts/vehicle_menu_warlock.png"}
	]

	for f in files:
		menu.select_aircraft(f.idx)
		for _i in range(10):
			await process_frame
		await RenderingServer.frame_post_draw
		var img = root.get_texture().get_image()
		var real_path = ProjectSettings.globalize_path(f.path)
		img.save_png(real_path)
		print("Saved screenshot: ", real_path)

	print("All screenshots successfully captured!")
	quit(0)
