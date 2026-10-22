@tool
extends SceneTree

func _init() -> void:
	print("--- CHECKING TANK GLB IMPORTS ---")
	var paths = [
		"res://assets/Enemy/enemy_tanks/azure_siege_tank/tank_assembled.glb",
		"res://assets/Enemy/enemy_tanks/desert_ironclad/tank_assembled.glb",
		"res://assets/Enemy/enemy_tanks/ironclad_sentinel/tank_assembled.glb"
	]
	for p in paths:
		var scene = load(p) as PackedScene
		if scene:
			print("SUCCESS loaded: ", p)
			var inst = scene.instantiate()
			print("  Instantiated root: ", inst.name)
			for child in inst.get_children():
				print("    Child: ", child.name, " (", child.get_class(), ")")
			inst.free()
		else:
			print("FAILED to load: ", p)
	quit(0)
