@tool
extends SceneTree

func _init() -> void:
	print("--- INSPECTING AIR SCENES ---")
	var scenes = [
		"res://scenes/enemies/air/iron_viper_visuals.tscn",
		"res://scenes/enemies/air/crimson_desert_visuals.tscn",
		"res://scenes/enemies/air/desert_rotorblade_boss_visuals.tscn",
		"res://scenes/enemies/air/astra_viper_visuals.tscn",
		"res://scenes/enemies/air/crimson_skyblade_visuals.tscn",
		"res://scenes/enemies/air/ironclad_skycarrier_visuals.tscn",
		"res://scenes/enemies/air/ironclad_skyrunner_visuals.tscn",
		"res://scenes/enemies/air/viperhawk_gunship_visuals.tscn"
	]

	for path in scenes:
		print("========================================")
		print("Scene: ", path.get_file())
		var scene: PackedScene = load(path)
		if not scene:
			print("FAILED TO LOAD: ", path)
			continue
		var inst: Node3D = scene.instantiate()
		var aabb = _calc_aabb(inst)
		print("AABB Size: ", aabb.size, " (X: ", aabb.size.x, ", Y: ", aabb.size.y, ", Z: ", aabb.size.z, ")")
		print("AABB Min: ", aabb.position, " Max: ", aabb.end)
		inst.free()

	print("--- DONE ---")
	quit(0)

func _calc_aabb(node: Node) -> AABB:
	var aabb := AABB()
	var first := true
	for child in node.get_children():
		if child is VisualInstance3D:
			var cb = child.get_aabb()
			if first:
				aabb = cb
				first = false
			else:
				aabb = aabb.merge(cb)
		var sub_aabb = _calc_aabb(child)
		if sub_aabb.size != Vector3.ZERO:
			if first:
				aabb = sub_aabb
				first = false
			else:
				aabb = aabb.merge(sub_aabb)
	return aabb
