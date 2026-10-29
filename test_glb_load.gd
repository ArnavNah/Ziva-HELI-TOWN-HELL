@tool
extends SceneTree

func _init() -> void:
	print("--- TESTING GLB PACKED SCENES ---")
	var glb_path = "res://assets/Enemy/air/iron_viper_gunship/iron_viper_assembled.glb"
	var pscene: PackedScene = load(glb_path)
	if not pscene:
		print("FAILED TO LOAD GLB: ", glb_path)
		quit(1)
		return
	var inst: Node = pscene.instantiate()
	print("Instantiated root: ", inst.name, " (class: ", inst.get_class(), ")")
	for child in inst.get_children():
		print("  child: ", child.name, " (class: ", child.get_class(), ")")
		for sub in child.get_children():
			print("    sub: ", sub.name, " (class: ", sub.get_class(), ")")
	inst.free()
	print("--- TEST PASSED ---")
	quit(0)
