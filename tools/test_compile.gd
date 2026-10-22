extends SceneTree

func _init() -> void:
	var s = load("res://src/player/player_helicopter.gd")
	print("Loaded player_helicopter.gd:", s)
	var inst = load("res://scenes/player/player.tscn").instantiate()
	print("Instantiated player.tscn:", inst, "class:", inst.get_class(), "script:", inst.get_script())
	print("max_hull:", inst.get("max_hull"))
	quit(0)
