extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var scn = load("res://scenes/player/player.tscn").instantiate()
	root.add_child(scn)
	await process_frame
	var v = scn.get_node("Visuals")
	var body = v.find_child("Helicopter_Body", true, false)
	print("After process_frame - Body material_override: ", body.material_override)
	if body.material_override:
		print("  override albedo_color: ", body.material_override.albedo_color)
		print("  override albedo_texture: ", body.material_override.albedo_texture.resource_path)
	quit(0)
