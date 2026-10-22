class_name PlayableArea
extends Node3D

## PlayableArea — Soft warning airspace boundary, hard physical collision barrier,
## visible holographic perimeter hazard wall with warning towers, and proximity damage (Spec 12.5).

@export var safe_radius: float = GameConstants.BOUNDARY_SAFE_RADIUS
@export var hard_radius: float = GameConstants.BOUNDARY_HARD_RADIUS
@export var wall_height: float = 80.0
@export var player_node: CharacterBody3D

var was_warning: bool = false
var hard_boundary_body: StaticBody3D
var border_visuals: Node3D
var barrier_material: ShaderMaterial
var border_damage_timer: float = 0.0

const BORDER_SHADER = preload("res://src/shaders/border_energy_barrier.gdshader")

func _ready() -> void:
	_setup_hard_boundary()
	_setup_border_visuals()
	_setup_distant_backdrop()

func _setup_hard_boundary() -> void:
	hard_boundary_body = StaticBody3D.new()
	hard_boundary_body.name = "HardBoundary"
	# Collision Layer 2 (World), so player (mask 6) and projectiles collide
	hard_boundary_body.collision_layer = 2
	hard_boundary_body.collision_mask = 1 | 4 | 5
	add_child(hard_boundary_body)

	var span: float = hard_radius * 2.1
	var wall_thickness: float = 4.0
	var half_h: float = wall_height * 0.5

	# 1. North Wall (Z = -hard_radius)
	_add_wall_shape(Vector3(0, half_h, -hard_radius), Vector3(span, wall_height, wall_thickness), "NorthWall")
	# 2. South Wall (Z = +hard_radius)
	_add_wall_shape(Vector3(0, half_h, hard_radius), Vector3(span, wall_height, wall_thickness), "SouthWall")
	# 3. East Wall (X = +hard_radius)
	_add_wall_shape(Vector3(hard_radius, half_h, 0), Vector3(wall_thickness, wall_height, span), "EastWall")
	# 4. West Wall (X = -hard_radius)
	_add_wall_shape(Vector3(-hard_radius, half_h, 0), Vector3(wall_thickness, wall_height, span), "WestWall")
	# 5. Top Airspace Flight Ceiling (Y = GameConstants.FLIGHT_CEILING)
	_add_wall_shape(Vector3(0, GameConstants.FLIGHT_CEILING + 2.0, 0), Vector3(span, 4.0, span), "CeilingBarrier")

func _add_wall_shape(pos: Vector3, size: Vector3, shape_name: String) -> void:
	var col = CollisionShape3D.new()
	col.name = shape_name
	var box = BoxShape3D.new()
	box.size = size
	col.shape = box
	col.transform.origin = pos
	hard_boundary_body.add_child(col)

func _setup_border_visuals() -> void:
	border_visuals = Node3D.new()
	border_visuals.name = "BorderVisuals"
	add_child(border_visuals)

	barrier_material = ShaderMaterial.new()
	barrier_material.shader = BORDER_SHADER

	var span: float = hard_radius * 2.1
	var visual_h: float = 55.0
	var half_h: float = visual_h * 0.5

	# 4 visible energy wall planes along the perimeter
	_add_wall_visual(Vector3(0, half_h, -hard_radius), Vector2(span, visual_h), 0.0)
	_add_wall_visual(Vector3(0, half_h, hard_radius), Vector2(span, visual_h), PI)
	_add_wall_visual(Vector3(hard_radius, half_h, 0), Vector2(span, visual_h), -PI * 0.5)
	_add_wall_visual(Vector3(-hard_radius, half_h, 0), Vector2(span, visual_h), PI * 0.5)

	# Boundary warning towers with pulsing red beacons
	_setup_warning_towers()

func _add_wall_visual(pos: Vector3, size: Vector2, rot_y: float) -> void:
	var quad := QuadMesh.new()
	quad.size = size
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = quad
	mesh_inst.material_override = barrier_material
	mesh_inst.position = pos
	mesh_inst.rotation.y = rot_y
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	border_visuals.add_child(mesh_inst)

func _setup_warning_towers() -> void:
	var tower_transforms: Array[Transform3D] = []
	var beacon_transforms: Array[Transform3D] = []
	var step_size: float = 24.0
	var tower_height: float = 28.0

	for coord in range(-int(hard_radius), int(hard_radius) + 1, int(step_size)):
		var c_val := float(coord)
		# North & South borders
		for z_pos in [-hard_radius, hard_radius]:
			var t_pos := Vector3(c_val, tower_height * 0.5, z_pos)
			tower_transforms.append(Transform3D(Basis.IDENTITY, t_pos))
			var b_pos := Vector3(c_val, tower_height + 0.8, z_pos)
			beacon_transforms.append(Transform3D(Basis.IDENTITY, b_pos))
		# East & West borders
		for x_pos in [-hard_radius, hard_radius]:
			var t_pos := Vector3(x_pos, tower_height * 0.5, c_val)
			tower_transforms.append(Transform3D(Basis.IDENTITY, t_pos))
			var b_pos := Vector3(x_pos, tower_height + 0.8, c_val)
			beacon_transforms.append(Transform3D(Basis.IDENTITY, b_pos))

	# Batched tower masts
	var pylon_mesh := CylinderMesh.new()
	pylon_mesh.top_radius = 0.35
	pylon_mesh.bottom_radius = 0.85
	pylon_mesh.height = tower_height
	pylon_mesh.radial_segments = 5
	var pylon_mat := StandardMaterial3D.new()
	pylon_mat.albedo_color = Color(0.24, 0.27, 0.32)
	pylon_mat.roughness = 0.85
	pylon_mat.metallic = 0.35
	pylon_mesh.material = pylon_mat

	var towers_multi := MultiMeshInstance3D.new()
	towers_multi.name = "WarningTowers"
	towers_multi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var t_mm := MultiMesh.new()
	t_mm.transform_format = MultiMesh.TRANSFORM_3D
	t_mm.mesh = pylon_mesh
	t_mm.instance_count = tower_transforms.size()
	for i in range(tower_transforms.size()):
		t_mm.set_instance_transform(i, tower_transforms[i])
	towers_multi.multimesh = t_mm
	border_visuals.add_child(towers_multi)

	# Batched red warning beacon lights
	var beacon_mesh := SphereMesh.new()
	beacon_mesh.radius = 1.1
	beacon_mesh.height = 2.2
	beacon_mesh.radial_segments = 6
	beacon_mesh.rings = 3
	var beacon_mat := StandardMaterial3D.new()
	beacon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beacon_mat.albedo_color = Color(1.0, 0.15, 0.05)
	beacon_mesh.material = beacon_mat

	var beacons_multi := MultiMeshInstance3D.new()
	beacons_multi.name = "WarningBeacons"
	beacons_multi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var b_mm := MultiMesh.new()
	b_mm.transform_format = MultiMesh.TRANSFORM_3D
	b_mm.mesh = beacon_mesh
	b_mm.instance_count = beacon_transforms.size()
	for i in range(beacon_transforms.size()):
		b_mm.set_instance_transform(i, beacon_transforms[i])
	beacons_multi.multimesh = b_mm
	border_visuals.add_child(beacons_multi)

func _setup_distant_backdrop() -> void:
	var backdrop_root = Node3D.new()
	backdrop_root.name = "DistantBackdrop"
	add_child(backdrop_root)

	# Peripheral wind turbines on the meadow horizon (matching reference image)
	var wind_turbine_script = preload("res://src/world/wind_turbine.gd")
	var num_turbines = 10
	for i in range(num_turbines):
		var angle = (float(i) / float(num_turbines)) * TAU + 0.25
		var tx = cos(angle) * (hard_radius + 40.0)
		var tz = sin(angle) * (hard_radius + 40.0)
		var turbine = wind_turbine_script.new()
		turbine.position = Vector3(tx, 0, tz)
		turbine.rotation.y = angle + PI * 0.5
		backdrop_root.add_child(turbine)

func _process(delta: float) -> void:
	if not player_node or not is_instance_valid(player_node):
		var found = get_tree().get_first_node_in_group("player")
		if found is CharacterBody3D:
			player_node = found
		elif has_node("../PlayerHelicopter"):
			player_node = get_node("../PlayerHelicopter")
		if not player_node:
			return

	var p_pos: Vector3 = player_node.global_position
	var pos_2d: Vector2 = Vector2(p_pos.x, p_pos.z)
	var dist: float = maxf(absf(pos_2d.x), absf(pos_2d.y))

	var is_horizontal_warning: bool = (dist > safe_radius)
	var is_altitude_warning: bool = (p_pos.y > 42.0)

	if is_horizontal_warning or is_altitude_warning:
		was_warning = true
		var return_dir: Vector3 = Vector3.ZERO
		var dist_to_edge: float = 0.0

		var h_penetration: float = clampf((dist - safe_radius) / maxf(1.0, hard_radius - safe_radius), 0.0, 1.0) if is_horizontal_warning else 0.0
		var v_penetration: float = clampf((p_pos.y - 42.0) / maxf(1.0, GameConstants.FLIGHT_CEILING - 42.0), 0.0, 1.0) if is_altitude_warning else 0.0

		if v_penetration >= h_penetration and is_altitude_warning:
			return_dir = Vector3.DOWN
			dist_to_edge = maxf(0.0, GameConstants.FLIGHT_CEILING - p_pos.y)
		else:
			var return_dir_2d = -pos_2d.normalized()
			return_dir = Vector3(return_dir_2d.x, 0, return_dir_2d.y)
			dist_to_edge = maxf(0.0, hard_radius - dist)

		if has_node("/root/EventBus"):
			get_node("/root/EventBus").border_warning_changed.emit(true, return_dir, dist_to_edge)

		# Intensify boundary holographic grid
		if barrier_material:
			barrier_material.set_shader_parameter("pulse_intensity", 2.2)

		# Soft aerodynamic turbulence & stall pressure pushing down when exceeding safe altitude
		if is_altitude_warning and player_node is CharacterBody3D:
			player_node.velocity.y -= delta * (18.0 + 36.0 * v_penetration)

		# Airframe proximity hazard damage: scales up from 16.0 to 48.0 DPS
		border_damage_timer += delta
		if border_damage_timer >= 0.25:
			border_damage_timer = 0.0
			var max_penetration: float = maxf(h_penetration, v_penetration)
			var dps: float = 16.0 + 32.0 * max_penetration
			var tick_damage: float = dps * 0.25
			if player_node.has_method("take_damage"):
				var hazard_reason = "Flight Ceiling Exceeded" if (v_penetration >= h_penetration and is_altitude_warning) else "Restricted Airspace"
				player_node.take_damage(tick_damage, hazard_reason)
	else:
		border_damage_timer = 0.0
		if barrier_material:
			barrier_material.set_shader_parameter("pulse_intensity", 0.75)
		if was_warning:
			was_warning = false
			if has_node("/root/EventBus"):
				get_node("/root/EventBus").border_warning_changed.emit(false, Vector3.ZERO, 0.0)
