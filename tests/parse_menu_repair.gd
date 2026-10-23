extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var failures := 0
	for folder in ["res://autoload", "res://src/ui/menus", "res://src/player", "res://src/combat"]:
		for file in DirAccess.get_files_at(folder):
			if file.ends_with(".gd"):
				var script = load(folder.path_join(file))
				if not script or not script.can_instantiate():
					failures += 1
	print("PARSE_FAILURES=", failures)
	await load("res://tests/runtime_cleanup.gd").finish(self, 1 if failures else 0)
