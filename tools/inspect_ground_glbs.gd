@tool
extends SceneTree

func _init() -> void:
	print("--- INSPECTING NEW GROUND GLBS IN GODOT ---")
	
	var raptor_chassis = load("res://assets/Enemy/new ground/Raptor_Raider/Chassis.glb") as PackedScene
	var raptor_gun = load("res://assets/Enemy/new ground/Raptor_Raider/Gun_Turret.glb") as PackedScene
	var raptor_comp = load("res://assets/Enemy/new ground/Raptor_Raider/Raptor_Raider_Complete.glb") as PackedScene
	
	var desert_chassis = load("res://assets/Enemy/new ground/Desert_Barrage_Rover/Chassis.glb") as PackedScene
	var desert_gun = load("res://assets/Enemy/new ground/Desert_Barrage_Rover/Missile_Barrage_Launcher.glb") as PackedScene
	var desert_comp = load("res://assets/Enemy/new ground/Desert_Barrage_Rover/Desert_Barrage_Rover_Complete.glb") as PackedScene
	
	print("Raptor Chassis scene:", raptor_chassis != null)
	print("Raptor Gun scene:", raptor_gun != null)
	print("Raptor Complete scene:", raptor_comp != null)
	
	if raptor_comp:
		var root = raptor_comp.instantiate()
		print("Raptor Complete hierarchy:")
		_print_tree(root, "  ")
		root.free()
		
	if desert_comp:
		var root = desert_comp.instantiate()
		print("Desert Complete hierarchy:")
		_print_tree(root, "  ")
		root.free()
		
	quit()

func _print_tree(n: Node, indent: String) -> void:
	var extra = ""
	if n is Node3D:
		extra = " pos=" + str(n.position) + " rot=" + str(n.rotation_degrees) + " scale=" + str(n.scale)
	if n is MeshInstance3D and n.mesh:
		extra += " aabb=" + str(n.mesh.get_aabb())
	print(indent, n.name, " (", n.get_class(), ")", extra)
	for c in n.get_children():
		_print_tree(c, indent + "  ")
