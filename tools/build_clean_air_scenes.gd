@tool
extends SceneTree
## Production wrappers are hand-authored and authoritative. Never regenerate them
## from model-only definitions: doing so used to erase sockets and animation.
func _init() -> void:
	var names := ["iron_viper", "crimson_desert", "desert_rotorblade_boss", "astra_viper", "crimson_skyblade", "ironclad_skycarrier", "ironclad_skyrunner", "viperhawk_gunship"]
	var failed := false
	for name in names:
		var path := "res://scenes/enemies/air/%s_visuals.tscn" % name
		var scene := load(path) as PackedScene
		if not scene:
			failed = true
			continue
		var rig := scene.instantiate()
		if not rig.has_node("CosmeticOffset/Model") or not rig.has_method("get_weapon_socket"):
			push_error("Incomplete authoritative wrapper: " + path)
			failed = true
		rig.free()
	print("Validated production air wrappers; no files were overwritten.")
	quit(1 if failed else 0)
