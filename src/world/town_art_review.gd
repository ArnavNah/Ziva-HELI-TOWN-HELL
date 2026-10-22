extends Node3D
## Playable material/silhouette slice. Uses the production flight camera and assets.
const Detail = preload("res://src/world/detail_mesh.gd")
const Materials = preload("res://src/world/stylized_materials.gd")
const Props = preload("res://src/world/town_props.gd")
const Building = preload("res://scenes/world/destructible_building.tscn")
var house: DestructibleBuilding
var player: PlayerHelicopter

func _ready() -> void:
	var ground := StaticBody3D.new()
	ground.collision_layer = 2
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(300, 2, 300)
	shape.position.y = -1
	ground.add_child(shape)
	add_child(ground)
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(300, 2, 300)
	floor_mesh.material = Materials.terrain()
	var floor_view := MeshInstance3D.new()
	floor_view.mesh = floor_mesh
	floor_view.position.y = -1
	add_child(floor_view)
	var roads := Detail.new()
	roads.use_material(Detail.Tile.ASPHALT)
	roads.box(Vector3(12, 0.04, 130), Vector3(0, 0.02, -25), Color.WHITE)
	roads.box(Vector3(115, 0.04, 8), Vector3(0, 0.03, 10), Color.WHITE)
	roads.use_material(Detail.Tile.PAVING)
	for x in [-7.0, 7.0]:
		roads.box(Vector3(1.8, 0.12, 110), Vector3(x, 0.06, -25), Color.WHITE)
	roads.use_material(Detail.Tile.TRIM)
	for z in range(-80, 21, 6):
		roads.box(Vector3(0.22, 0.02, 2.5), Vector3(0, 0.05, z), Color(0.67, 0.62, 0.43))
	for x in [-4.0, -2.0, 0.0, 2.0, 4.0]:
		roads.box(Vector3(1, 0.02, 2), Vector3(x, 0.06, 3), Color(0.67, 0.67, 0.59))
	var road_view := MeshInstance3D.new()
	road_view.mesh = roads.build()
	road_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(road_view)
	house = _building("townhouse", Vector3(-18, 0, -12), Vector3(10, 8, 10))
	_building("supermarket", Vector3(18, 0, -12), Vector3(12, 7, 10))
	_building("factory", Vector3(20, 0, -48), Vector3(16, 8, 12))
	add_child(Props.instance("crate", Vector3(-10, 0.1, -3)))
	add_child(Props.instance("barrel", Vector3(10, 0.1, -2)))
	add_child(Props.instance("vehicle", Vector3(15, 0.1, 18)))
	var dressing := preload("res://src/world/field_dressing.gd").new()
	add_child(dressing)
	var leaf := SphereMesh.new()
	leaf.radius = 2.3
	leaf.height = 4.6
	leaf.radial_segments = 7
	leaf.rings = 3
	leaf.material = Materials.town_atlas(false, 8, true)
	var crown := MeshInstance3D.new()
	crown.mesh = dressing._clustered_crown(leaf)
	crown.position = Vector3(-24, 5.5, 11)
	add_child(crown)
	var tree := Detail.new()
	tree.use_material(Detail.Tile.BARK)
	tree.cylinder(0.4, 4.5, Vector3(-24, 2.25, 11), Color.WHITE, 6)
	tree.cylinder(0.38, 4.4, Vector3(-34, 2.2, -31), Color.WHITE, 6)
	var pine := MeshInstance3D.new()
	pine.mesh = dressing._pine_mesh(Materials.town_atlas(false, 8, true))
	pine.position = Vector3(-34, 4.8, -31)
	add_child(pine)
	var trees := MeshInstance3D.new()
	trees.mesh = tree.build()
	add_child(trees)
	player = $PlayerHelicopter
	player.is_invulnerable = true
	player.position = Vector3(0, 14, 29)
	player.get_node("PlayerCamera").init_camera(player)
	if has_node("/root/GameManager"):
		var manager := get_node("/root/GameManager")
		manager.change_state(manager.RunState.ACTIVE)
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	var backdrop := ColorRect.new()
	backdrop.position = Vector2(12, 675)
	backdrop.size = Vector2(1256, 32)
	backdrop.color = Color(0.06, 0.09, 0.07, 1.0)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(backdrop)
	var label := Label.new()
	label.text = "TOWN ART REVIEW   |   Normal flight controls   |   1: Damage house   2: Collapse   R: Reset   |   3: Day   4: Storm   5: Night"
	label.position = Vector2(20, 680)
	label.add_theme_font_size_override("font_size", 15)
	layer.add_child(label)

func _building(kind: String, point: Vector3, size: Vector3) -> DestructibleBuilding:
	var b = Building.instantiate()
	b.archetype = kind
	b.position = point
	b.building_width = size.x
	b.building_height = size.y
	b.building_depth = size.z
	add_child(b)
	return b

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1: house.damage_receiver.take_damage(DamageData.new(200, GameConstants.WeaponType.ROCKET))
		KEY_2: house.damage_receiver.take_damage(DamageData.new(1000, GameConstants.WeaponType.ROCKET))
		KEY_R:
			house.current_stage = DestructibleBuilding.DestructionStage.INTACT
			house._setup_structure()
		KEY_3: $WeatherSystem._on_wave_started(1, "Normal", 30)
		KEY_4: $WeatherSystem._on_wave_started(9, "Storm Surge", 30)
		KEY_5: $WeatherSystem._on_wave_started(8, "Night Surge", 30)
