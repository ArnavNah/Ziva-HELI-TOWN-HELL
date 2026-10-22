extends SceneTree

func _init() -> void:
	var scr = load("res://src/ui/menus/loading_screen.gd").new()
	root.add_child(scr)
	await process_frame
	await process_frame
	for c in scr.find_children("*"):
		if c is Control and c.name.contains("log") or c.name.contains("tip") or c.name.contains("Right") or c.name.contains("Terminal") or c.name.contains("Panel"):
			print(c.name, " (", c.get_class(), ") pos:", c.global_position, " size:", c.size)
	quit(0)
