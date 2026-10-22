extends SubViewportContainer
## A display-only model in an isolated world: no gameplay scripts or autoload calls.
const Materials = preload("res://src/world/stylized_materials.gd")
const Parts = preload("res://src/enemies/raider_visuals.gd")
var aircraft: Node3D
var rotor: Node3D
var elapsed := 0.0
var view: SubViewport

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	view = SubViewport.new()
	view.size = Vector2i(640, 480)
	view.own_world_3d = true
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var stage := Node3D.new()
	view.add_child(stage)
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("101e28")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("adcbd2")
	env.ambient_light_energy = 0.65
	env_node.environment = env
	stage.add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_color = Color("ffe0a6")
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	stage.add_child(sun)
	var cam := Camera3D.new()
	stage.add_child(cam)
	cam.position = Vector3(17, 13, 20)
	cam.look_at(Vector3(0, 2, 0))
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 22
	cam.current = true
	Parts.box(stage, Vector3(18, 0.65, 18), Vector3(0, -0.5, 0), Materials.surface(Color("344a4b")))
	Parts.box(stage, Vector3(16.5, 0.12, 16.5), Vector3(0, -0.1, 0), Materials.surface(Color("243a3c")))
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 5.8
	torus.outer_radius = 6.0
	torus.rings = 48
	torus.ring_segments = 6
	torus.material = Materials.surface(Color("e8ba63"))
	ring.mesh = torus
	ring.scale.y = 0.2
	stage.add_child(ring)
	for x in [-7.5, 7.5]:
		for z in [-7.5, 7.5]:
			Parts.box(stage, Vector3(0.4, 0.25, 0.4), Vector3(x, 0.1, z), Materials.surface(Color("f2c36a")))
	var source := preload("res://scenes/player/player.tscn").instantiate()
	aircraft = source.get_node("Visuals").duplicate()
	# Visuals have no attached gameplay scripts; only geometry and aircraft lights.
	source.free()
	stage.add_child(aircraft)
	aircraft.position.y = 2.2
	rotor = aircraft.find_child("Main_Rotor", true, false)
	if not rotor:
		rotor = aircraft.get_node_or_null("MainRotor")
	set_aircraft(0)

func set_aircraft(index: int) -> void:
	if not aircraft:
		return
	var colors := [Color("7c8d59"), Color("596e8c"), Color("a57952")]
	var hull := aircraft.find_child("Helicopter_Body", true, false) as MeshInstance3D
	if not hull:
		hull = aircraft.get_node_or_null("Fuselage") as MeshInstance3D
	if hull and not hull.mesh:
		hull.material_override = Materials.surface(colors[index])
	aircraft.scale = Vector3.ONE * ([1.0, 0.90, 1.12][index])

func _process(delta: float) -> void:
	elapsed += delta
	if aircraft:
		aircraft.rotation.y = -0.5 + sin(elapsed * 0.2) * 0.2
		aircraft.position.y = 2.2 + sin(elapsed * 1.1) * 0.12
	if rotor:
		rotor.rotation.y += delta * 9.0
