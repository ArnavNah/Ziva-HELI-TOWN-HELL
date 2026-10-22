extends SceneTree

func _initialize() -> void:
	var src = load("res://scenes/player/player.tscn").instantiate()
	print("--- PLAYER TSCN NODES ---")
	_print_tree(src, 0)
	quit(0)

func _print_tree(node: Node, depth: int) -> void:
	var indent = ""
	for i in depth:
		indent += "  "
	var extra = ""
	if node is MeshInstance3D:
		extra = " (Mesh: " + str(node.mesh.get_class() if node.mesh else "null") + ")"
	print(indent + node.name + " [" + node.get_class() + "]" + extra)
	for child in node.get_children():
		_print_tree(child, depth + 1)
