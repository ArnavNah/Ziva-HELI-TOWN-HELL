extends RefCounted

static func finish(tree: SceneTree, code: int) -> void:
	var flow = tree.root.get_node_or_null("UIFlow")
	if flow:
		flow._clear_transients()
	if is_instance_valid(tree.current_scene):
		tree.current_scene.queue_free()
	var audio = tree.root.get_node_or_null("AudioManager")
	if audio:
		await audio.prepare_shutdown()
	tree.quit(code)
