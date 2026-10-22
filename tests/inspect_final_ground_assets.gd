extends SceneTree

var view: SubViewport
var stage: Node3D
var camera: Camera3D

func _initialize() -> void:
	call_deferred("run")

func source_scene(path: String) -> Node3D:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(path, state)
	if error != OK:
		push_error("Cannot inspect source: " + path)
		return null
	return document.generate_scene(state)

func run() -> void:
	if OS.get_environment("ZIVA_TEST_DATA_DIR").is_empty():
		quit(2)
		return
	view = SubViewport.new()
	view.size = Vector2i(1280, 800)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	stage = Node3D.new()
	view.add_child(stage)
	var environment := WorldEnvironment.new()
	var setup := Environment.new()
	setup.background_mode = Environment.BG_COLOR
	setup.background_color = Color("1b2832")
	setup.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	setup.ambient_light_color = Color.WHITE
	setup.ambient_light_energy = 0.7
	environment.environment = setup
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -35, 0)
	sun.light_energy = 1.8
	stage.add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10.5
	stage.add_child(camera)
	camera.make_current()
	var wheel = load("res://assets/Enemy/tank_game_ready/universal_wheel_mesh.res") as ArrayMesh
	print("SHARED WHEEL AABB: ", wheel.get_aabb(), " SURFACES: ", wheel.get_surface_count())
	for item in [
		["Desert_Barrage_Rover", "Desert_Barrage_Rover_Complete.glb", "Chassis.glb"],
		["Raptor_Raider", "Raptor_Raider_Complete.glb", "Chassis.glb"]
	]:
		for part in ["complete", "chassis"]:
			var path: String = "res://assets/Enemy/new ground/%s/%s" % [item[0], item[1] if part == "complete" else item[2]]
			var model = source_scene(path)
			if not model:
				quit(1)
				return
			var wrapper := Node3D.new()
			stage.add_child(wrapper)
			wrapper.add_child(model)
			wrapper.rotation_degrees.y = -90.0
			wrapper.scale = Vector3.ONE * 6.3
			for angle in ["three_quarter", "side"]:
				if angle == "three_quarter":
					camera.look_at_from_position(Vector3(8, 6, -10), Vector3(0, 0.3, 0))
				else:
					camera.look_at_from_position(Vector3(12, 2, 0), Vector3(0, 0.2, 0))
				await process_frame
				await RenderingServer.frame_post_draw
				var output: String = "res://artifacts/final-ground-%s-%s-%s.png" % [item[0], part, angle]
				var result := view.get_texture().get_image().save_png(output)
				print("PREVIEW ", output, " result=", result)
			wrapper.free()
	view.free()
	quit(0)
