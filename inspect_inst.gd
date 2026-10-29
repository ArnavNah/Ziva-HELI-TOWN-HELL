@tool
extends SceneTree

func _init() -> void:
	var scene = load("res://scenes/enemies/air/iron_viper_visuals.tscn") as PackedScene
	var inst = scene.instantiate()
	print("Root: ", inst.name)
	for c in inst.get_children():
		print("  child: ", c.name, " (class: ", c.get_class(), ")")
		for cc in c.get_children():
			print("    subchild: ", cc.name, " (class: ", cc.get_class(), ", mesh: ", (cc as MeshInstance3D).mesh if cc is MeshInstance3D else "none", ")")
			for ccc in cc.get_children():
				print("      sub-subchild: ", ccc.name, " (class: ", ccc.get_class(), ", mesh: ", (ccc as MeshInstance3D).mesh if ccc is MeshInstance3D else "none", ")")
	inst.free()
	quit(0)
