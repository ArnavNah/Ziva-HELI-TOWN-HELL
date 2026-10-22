extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	print("=== RUNNING FULL CODEBASE INTEGRITY AUDIT ===")
	var issues: Array[String] = []

	# 1. Audit all GDScript files for loading / compiling errors
	var files = []
	_scan_dir("res://src", files, ".gd")
	_scan_dir("res://autoload", files, ".gd")
	_scan_dir("res://scenes", files, ".gd")

	print("Auditing %d GDScripts..." % files.size())
	for path in files:
		var res = load(path)
		if not res:
			issues.append("ERROR: Failed to load GDScript: " + path)

	# 2. Audit all .tscn scenes for load integrity
	var scenes = []
	_scan_dir("res://scenes", scenes, ".tscn")
	print("Auditing %d scenes..." % scenes.size())
	for path in scenes:
		var scene_res = load(path)
		if not scene_res:
			issues.append("ERROR: Failed to load PackedScene: " + path)
		else:
			var inst = scene_res.instantiate()
			if not inst:
				issues.append("ERROR: Failed to instantiate PackedScene: " + path)
			else:
				inst.free()

	# 3. Test MainMenu instantiation and child hierarchy
	var menu_scene = load("res://scenes/ui/main_menu.tscn")
	if menu_scene:
		var menu = menu_scene.instantiate()
		var v_menu = menu.get_node_or_null("VehicleSelectionMenu")
		if not v_menu:
			issues.append("ERROR: VehicleSelectionMenu missing in MainMenu")
		menu.free()

	# 4. Test MainGame instantiation and core nodes
	var game_scene = load("res://scenes/main_game.tscn")
	if game_scene:
		var game = game_scene.instantiate()
		var player = game.get_node_or_null("PlayerHelicopter")
		if not player:
			issues.append("ERROR: PlayerHelicopter node missing in MainGame")
		else:
			if not ("max_hull" in player):
				issues.append("ERROR: PlayerHelicopter missing max_hull property")
			if not ("current_hull" in player):
				issues.append("ERROR: PlayerHelicopter missing current_hull property")
		game.free()

	print("\n=== AUDIT SUMMARY ===")
	if issues.size() == 0:
		print("SUCCESS: 0 compile or instantiation errors found in codebase.")
	else:
		print("FAILED with %d issues:" % issues.size())
		for issue in issues:
			print("  - ", issue)

	quit(0 if issues.size() == 0 else 1)

func _scan_dir(path: String, results: Array, extension: String) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with("."):
			_scan_dir(path + "/" + file_name, results, extension)
		elif file_name.ends_with(extension):
			results.append(path + "/" + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
