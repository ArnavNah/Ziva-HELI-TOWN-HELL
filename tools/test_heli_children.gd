extends SceneTree

func _initialize() -> void:
	call_deferred("_test")

func _test() -> void:
	var menu: VehicleSelectionMenu = load("res://scenes/ui/vehicle_selection_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	await process_frame

	menu.select_aircraft(0)
	print("--- AFTER SELECT APACHE ---")
	_dump(menu.heli_model, 0)

	menu.select_aircraft(2)
	print("--- AFTER SELECT WARLOCK ---")
	_dump(menu.heli_model, 0)
	quit(0)

func _dump(node: Node, indent: int) -> void:
	if not node:
		print("  ".repeat(indent) + "NULL")
		return
	print("  ".repeat(indent) + node.name + " (" + node.get_class() + ")")
	for child in node.get_children():
		_dump(child, indent + 1)
