extends SceneTree

func _init() -> void:
	print("Testing scout_buggy_visuals.tscn loading...")
	var scn = load("res://scenes/enemies/scout_buggy_visuals.tscn")
	if not scn:
		print("FAILED to load scene!")
		quit(1)
		return
	var inst = scn.instantiate()
	if not inst:
		print("FAILED to instantiate scene!")
		quit(1)
		return
	print("Instantiated successfully. Children:")
	for c in inst.get_children():
		print("- ", c.name, " (", c.get_class(), ") script:", c.get_script())
	quit(0)
