@tool
extends SceneTree

func _init() -> void:
	print("--- TESTING ALL 8 AIR MODELS AS PACKED SCENES ---")
	var models = [
		{"name": "iron_viper_gunship", "path": "res://assets/Enemy/air/iron_viper_gunship/iron_viper_assembled.glb"},
		{"name": "crimson_desert_gunship", "path": "res://assets/Enemy/air/crimson_desert_gunship/crimson_desert_assembled.glb"},
		{"name": "desert_rotorblade_miniature", "path": "res://assets/Enemy/air/desert_rotorblade_miniature/desert_rotorblade_assembled.glb"},
		{"name": "astra_viper", "path": "res://assets/Enemy/air/astra_viper/astra_viper.glb"},
		{"name": "crimson_skyblade", "path": "res://assets/Enemy/air/crimson_skyblade/crimson_skyblade.glb"},
		{"name": "ironclad_skycarrier", "path": "res://assets/Enemy/air/ironclad_skycarrier/ironclad_skycarrier.glb"},
		{"name": "ironclad_skyrunner", "path": "res://assets/Enemy/air/ironclad_skyrunner/ironclad_skyrunner.glb"},
		{"name": "viperhawk_gunship", "path": "res://assets/Enemy/air/viperhawk_gunship/viperhawk_gunship.glb"}
	]

	for m in models:
		var scene: PackedScene = load(m.path)
		if not scene:
			print("FAILED: ", m.name, " at ", m.path)
			quit(1)
			return
		var inst: Node = scene.instantiate()
		print("PASSED: ", m.name, " -> root: ", inst.name, " with ", inst.get_child_count(), " children")
		inst.free()

	print("--- ALL 8 MODELS PASSED ---")
	quit(0)
