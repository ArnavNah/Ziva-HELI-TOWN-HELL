extends SceneTree
const MODELS := ["iron_viper", "crimson_desert", "desert_rotorblade_boss", "crimson_skyblade", "astra_viper", "ironclad_skyrunner", "ironclad_skycarrier", "viperhawk_gunship"]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1620, 1010)
	root.content_scale_size = root.size
	var grid := GridContainer.new()
	grid.columns = 4
	root.add_child(grid)
	for name in MODELS:
		var column := VBoxContainer.new()
		column.custom_minimum_size = Vector2(355, 475)
		grid.add_child(column)
		var label := Label.new()
		label.text = name
		column.add_child(label)
		var holder := SubViewportContainer.new()
		column.add_child(holder)
		var sub := SubViewport.new()
		sub.size = Vector2i(355, 440)
		sub.own_world_3d = true
		holder.add_child(sub)
		var world := Node3D.new()
		sub.add_child(world)
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_COLOR
		env.environment.background_color = Color("263039")
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color.WHITE
		env.environment.ambient_light_energy = 0.7
		world.add_child(env)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-55, -25, 0)
		world.add_child(light)
		var rig = load("res://scenes/enemies/air/%s_visuals.tscn" % name).instantiate()
		world.add_child(rig)
		var rc = rig.get_node_or_null("RotorController")
		if rc:
			rc.set_process(false)
			for part in rc._parts:
				var tag := Label3D.new()
				tag.text = str(part.node.name)
				tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				tag.font_size = 24
				tag.modulate = Color.GREEN_YELLOW
				tag.pixel_size = .013
				world.add_child(tag)
				tag.global_position = part.node.global_position + Vector3.UP * .35
		for marker in rig.get_node("CosmeticOffset/Sockets").get_children():
			if not marker is Marker3D: continue
			var dot := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.085
			sphere.height = 0.17
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = Color.CYAN if str(marker.name).begins_with("Exhaust") else Color.ORANGE_RED
			sphere.material = mat
			dot.mesh = sphere
			world.add_child(dot)
			dot.global_position = marker.global_position
		var forward := Label3D.new()
		forward.text = "CONTROLLER FORWARD (-Z)"
		forward.position = Vector3(0, 0, -5.8)
		forward.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		forward.font_size = 22
		forward.pixel_size = .014
		world.add_child(forward)
		var cam := Camera3D.new()
		world.add_child(cam)
		cam.position = Vector3(0, 14, -3)
		cam.look_at(Vector3(0, .7, 0), Vector3.BACK)
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 13.5
		cam.current = true
	for frame in 10: await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://artifacts/air-model-review/socket-audit.png")
	quit()
