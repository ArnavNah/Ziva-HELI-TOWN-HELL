extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	await RenderingServer.frame_post_draw

	print("=== SCENE PRIMITIVE & NODE DIAGNOSTICS ===")
	print("Total nodes: ", Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	print("Total draw calls: ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("Total primitives: ", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))

	var meshes_by_group: Dictionary = {}
	var primitives_by_group: Dictionary = {}

	for node in game.find_children("", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh:
			var parent_name = mi.get_parent().name if mi.get_parent() else "root"
			var faces = mi.mesh.get_faces().size() / 3
			meshes_by_group[parent_name] = meshes_by_group.get(parent_name, 0) + 1
			primitives_by_group[parent_name] = primitives_by_group.get(parent_name, 0) + faces

	for node in game.find_children("", "MultiMeshInstance3D", true, false):
		var mmi := node as MultiMeshInstance3D
		if mmi.multimesh and mmi.multimesh.mesh:
			var faces = (mmi.multimesh.mesh.get_faces().size() / 3) * mmi.multimesh.instance_count
			primitives_by_group[mmi.name] = faces

	print("\n--- Primitives by Component ---")
	var sorted_keys = primitives_by_group.keys()
	sorted_keys.sort_custom(func(a, b): return primitives_by_group[a] > primitives_by_group[b])
	for k in sorted_keys.slice(0, 25):
		print("  %s: %d primitives (meshes: %d)" % [k, primitives_by_group[k], meshes_by_group.get(k, 1)])

	quit(0)
