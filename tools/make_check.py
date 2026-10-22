code = '''extends SceneTree
func _init():
	var vm = load("res://src/ui/menus/vehicle_selection_menu.gd").new()
	root.add_child(vm)
	vm._ready()
	print("Showcase heli_model: ", vm.heli_model)
	if vm.heli_model:
		print("Children of heli_model:")
		for c in vm.heli_model.get_children():
			print("  ", c.name, " (", c.get_class(), ") vis=", c.visible if "visible" in c else "N/A")
			for c2 in c.get_children():
				print("    ", c2.name, " (", c2.get_class(), ") vis=", c2.visible if "visible" in c2 else "N/A")
	quit(0)
'''
with open('tools/check_showcase.gd', 'w') as f:
	f.write(code)
