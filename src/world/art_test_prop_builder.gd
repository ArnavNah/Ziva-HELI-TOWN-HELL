class_name ArtTestPropBuilder
extends RefCounted

## ArtTestPropBuilder — Constructs modular assets for the modern-retro art test street.
## All UVs are calibrated strictly to 64 pixels per metre:
##   - 128x128 textures cover 2m x 2m (UV = dimension / 2.0)
##   - 256x256 textures cover 4m x 4m (UV = dimension / 4.0)

const Library = preload("res://src/world/retro_material_library.gd")

# -----------------------------------------------------------------------------
# 1. MODULAR BUILDING
# -----------------------------------------------------------------------------
static func build_modular_building() -> Node3D:
	var root := Node3D.new()
	root.name = "ArtTestBuilding"
	
	var static_body := StaticBody3D.new()
	static_body.name = "BuildingBody"
	root.add_child(static_body)
	
	# Overall building footprint: 10m wide (X), 12m high (Y), 8m deep (Z)
	var b_width := 10.0
	var b_depth := 8.0
	var brick_height := 4.0
	var plaster_height := 8.0
	var total_height := brick_height + plaster_height # 12.0m
	
	# --- Lower Section: Warm Brick (Y = 0 to 4m) ---
	var lower_mesh := BoxMesh.new()
	lower_mesh.size = Vector3(b_width, brick_height, b_depth)
	# UV mapping: 64 px/m -> 2m per repeat. Width 10m = 5 repeats, Height 4m = 2 repeats
	lower_mesh.material = Library.brick()
	var lower_instance := MeshInstance3D.new()
	lower_instance.name = "LowerBrickSection"
	lower_instance.mesh = lower_mesh
	lower_instance.position = Vector3(0, brick_height * 0.5, 0)
	static_body.add_child(lower_instance)
	
	# --- Upper Section: Pale Plaster (Y = 4 to 12m) ---
	var upper_mesh := BoxMesh.new()
	upper_mesh.size = Vector3(b_width, plaster_height, b_depth)
	upper_mesh.material = Library.plaster()
	var upper_instance := MeshInstance3D.new()
	upper_instance.name = "UpperPlasterSection"
	upper_instance.mesh = upper_mesh
	upper_instance.position = Vector3(0, brick_height + plaster_height * 0.5, 0)
	static_body.add_child(upper_instance)
	
	# --- Roof Parapet Rim (0.6m high along top perimeter) ---
	var parapet_mat = Library.brick()
	for i in 4:
		var p_mesh := BoxMesh.new()
		var p_inst := MeshInstance3D.new()
		p_inst.material_override = parapet_mat
		if i == 0 or i == 1: # North / South
			p_mesh.size = Vector3(b_width, 0.7, 0.4)
			p_inst.position = Vector3(0, total_height + 0.35, -b_depth * 0.5 if i == 0 else b_depth * 0.5)
		else: # East / West
			p_mesh.size = Vector3(0.4, 0.7, b_depth)
			p_inst.position = Vector3(-b_width * 0.5 if i == 2 else b_width * 0.5, total_height + 0.35, 0)
		p_inst.mesh = p_mesh
		static_body.add_child(p_inst)
		
	# Roof gravel deck
	var roof_mesh := PlaneMesh.new()
	roof_mesh.size = Vector2(b_width - 0.6, b_depth - 0.6)
	roof_mesh.material = Library.pavement()
	var roof_inst := MeshInstance3D.new()
	roof_inst.mesh = roof_mesh
	roof_inst.position = Vector3(0, total_height + 0.05, 0)
	static_body.add_child(roof_inst)
	
	# --- Architectural Silhouette Features ---
	# 1. Entrance Doorway Overhang / Portico (Z = -b_depth/2 front facing road)
	var portico_mesh := BoxMesh.new()
	portico_mesh.size = Vector3(2.6, 0.35, 1.2)
	portico_mesh.material = Library.plaster()
	var portico_inst := MeshInstance3D.new()
	portico_inst.mesh = portico_mesh
	portico_inst.position = Vector3(0, 3.4, -b_depth * 0.5 - 0.6)
	static_body.add_child(portico_inst)
	
	# Entrance Door Frame & Recess
	var door_mesh := BoxMesh.new()
	door_mesh.size = Vector3(1.8, 3.0, 0.15)
	door_mesh.material = Library.crate() # Wood plank door
	var door_inst := MeshInstance3D.new()
	door_inst.mesh = door_mesh
	door_inst.position = Vector3(0, 1.5, -b_depth * 0.5 - 0.05)
	static_body.add_child(door_inst)
	
	# 2. Window Modules (Protruding sills + window panes on upper plaster facade)
	var win_mat = Library.building_window()
	var sill_mat = Library.plaster()
	var window_positions := [
		# Floor 2 (Y = 6.0m)
		Vector3(-2.8, 6.0, -b_depth * 0.5 - 0.06),
		Vector3(0.0, 6.0, -b_depth * 0.5 - 0.06),
		Vector3(2.8, 6.0, -b_depth * 0.5 - 0.06),
		# Floor 3 (Y = 9.5m)
		Vector3(-2.8, 9.5, -b_depth * 0.5 - 0.06),
		Vector3(0.0, 9.5, -b_depth * 0.5 - 0.06),
		Vector3(2.8, 9.5, -b_depth * 0.5 - 0.06)
	]
	
	for wpos in window_positions:
		# Window pane quad / thin box
		var w_mesh := BoxMesh.new()
		w_mesh.size = Vector3(1.6, 2.0, 0.12)
		var w_inst := MeshInstance3D.new()
		w_inst.mesh = w_mesh
		w_inst.material_override = win_mat
		w_inst.position = wpos
		static_body.add_child(w_inst)
		
		# Protruding stone window sill for silhouette depth
		var s_mesh := BoxMesh.new()
		s_mesh.size = Vector3(1.8, 0.22, 0.35)
		var s_inst := MeshInstance3D.new()
		s_inst.mesh = s_mesh
		s_inst.material_override = sill_mat
		s_inst.position = Vector3(wpos.x, wpos.y - 1.05, wpos.z - 0.1)
		static_body.add_child(s_inst)
		
	# Cornice Trim between Brick and Plaster (at Y = 4.0m)
	var cornice_mesh := BoxMesh.new()
	cornice_mesh.size = Vector3(b_width + 0.4, 0.28, b_depth + 0.4)
	cornice_mesh.material = Library.pavement()
	var cornice_inst := MeshInstance3D.new()
	cornice_inst.mesh = cornice_mesh
	cornice_inst.position = Vector3(0, brick_height, 0)
	static_body.add_child(cornice_inst)
	
	# Full Building Collision
	var col_shape := CollisionShape3D.new()
	var box_col := BoxShape3D.new()
	box_col.size = Vector3(b_width, total_height, b_depth)
	col_shape.shape = box_col
	col_shape.position = Vector3(0, total_height * 0.5, 0)
	static_body.add_child(col_shape)
	
	return root

# -----------------------------------------------------------------------------
# 2. STYLIZED LOW-POLY TREE (Trunk + Alpha-Cutout Foliage Cards)
# -----------------------------------------------------------------------------
static func build_tree() -> Node3D:
	var tree := Node3D.new()
	tree.name = "ArtTestTree"
	
	var static_body := StaticBody3D.new()
	static_body.name = "TreeTrunkBody"
	tree.add_child(static_body)
	
	# Trunk: 8-sided tapered cylinder (height 4.5m, radius 0.35m)
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.22
	trunk_mesh.bottom_radius = 0.38
	trunk_mesh.height = 4.5
	trunk_mesh.radial_segments = 8
	trunk_mesh.rings = 1
	trunk_mesh.material = Library.tree_bark()
	
	var trunk_inst := MeshInstance3D.new()
	trunk_inst.name = "TrunkMesh"
	trunk_inst.mesh = trunk_mesh
	trunk_inst.position = Vector3(0, 2.25, 0)
	static_body.add_child(trunk_inst)
	
	var trunk_col := CollisionShape3D.new()
	var cyl_shape := CylinderShape3D.new()
	cyl_shape.radius = 0.35
	cyl_shape.height = 4.5
	trunk_col.shape = cyl_shape
	trunk_col.position = Vector3(0, 2.25, 0)
	static_body.add_child(trunk_col)
	
	# Canopy: 4 Cross-intersecting vertical foliage cards + 2 horizontal discs
	var foliage_mat = Library.tree_foliage()
	var card_rotations := [0.0, 45.0, 90.0, 135.0]
	
	for i in card_rotations.size():
		var rot_deg: float = card_rotations[i]
		var quad_mesh := QuadMesh.new()
		quad_mesh.size = Vector2(4.2, 4.2)
		var quad_inst := MeshInstance3D.new()
		quad_inst.name = "CanopyCard_" + str(i)
		quad_inst.mesh = quad_mesh
		quad_inst.material_override = foliage_mat
		quad_inst.position = Vector3(0, 5.0, 0)
		quad_inst.rotation_degrees = Vector3(0, rot_deg, 0)
		tree.add_child(quad_inst)
		
	# Horizontal canopy discs for rich top-down readability
	for h_idx in 2:
		var h_quad := QuadMesh.new()
		h_quad.size = Vector2(3.8 - float(h_idx) * 0.6, 3.8 - float(h_idx) * 0.6)
		var h_inst := MeshInstance3D.new()
		h_inst.name = "HorizontalCanopy_" + str(h_idx)
		h_inst.mesh = h_quad
		h_inst.material_override = foliage_mat
		h_inst.position = Vector3(0, 4.6 + float(h_idx) * 1.4, 0)
		h_inst.rotation_degrees = Vector3(90, 0, float(h_idx) * 35.0)
		tree.add_child(h_inst)
		
	return tree

# -----------------------------------------------------------------------------
# 3. PROPS: SUPPLY CRATE & FUEL BARREL
# -----------------------------------------------------------------------------
static func build_crate(pos: Vector3 = Vector3.ZERO) -> Node3D:
	var root := Node3D.new()
	root.name = "SupplyCrate"
	root.position = pos
	
	var body := StaticBody3D.new()
	root.add_child(body)
	
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.5, 1.5, 1.5)
	mesh.material = Library.crate()
	
	var inst := MeshInstance3D.new()
	inst.name = "CrateMesh"
	inst.mesh = mesh
	inst.position = Vector3(0, 0.75, 0)
	body.add_child(inst)
	
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.5, 1.5, 1.5)
	col.shape = shape
	col.position = Vector3(0, 0.75, 0)
	body.add_child(col)
	
	return root

static func build_barrel(pos: Vector3 = Vector3.ZERO) -> Node3D:
	var root := Node3D.new()
	root.name = "FuelBarrel"
	root.position = pos
	
	var body := StaticBody3D.new()
	root.add_child(body)
	
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.42
	mesh.bottom_radius = 0.42
	mesh.height = 1.2
	mesh.radial_segments = 12
	mesh.rings = 1
	mesh.material = Library.barrel()
	
	var inst := MeshInstance3D.new()
	inst.name = "BarrelMesh"
	inst.mesh = mesh
	inst.position = Vector3(0, 0.6, 0)
	body.add_child(inst)
	
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.42
	shape.height = 1.2
	col.shape = shape
	col.position = Vector3(0, 0.6, 0)
	body.add_child(col)
	
	return root

# -----------------------------------------------------------------------------
# 4. DESTRUCTIBLE PROP WITH MATCHING DEBRIS (Security Guard Post)
# -----------------------------------------------------------------------------
static func build_destructible_booth(pos: Vector3 = Vector3.ZERO) -> Node3D:
	var booth_script = load("res://src/world/art_test_destructible_booth.gd")
	var root: Node3D = booth_script.new()
	root.name = "DestructibleGuardBooth"
	root.position = pos
	return root

# -----------------------------------------------------------------------------
# 5. READABILITY PROXIES: ENEMY PROXY & PICKUP PROXY
# -----------------------------------------------------------------------------
static func build_enemy_proxy(pos: Vector3 = Vector3.ZERO) -> Node3D:
	var root := Node3D.new()
	root.name = "EnemyProxy"
	root.position = pos
	
	# Raider Tank / Scout Buggy Body
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(2.4, 0.9, 3.4)
	var body_mat := StandardMaterial3D.new()
	body_mat.resource_name = "mat_enemy_proxy"
	body_mat.albedo_color = Color(0.72, 0.18, 0.14) # Crimson hostile red (high contrast against muted gray/olive ground)
	body_mat.roughness = 0.88
	body_mat.metallic = 0.15
	
	var body_inst := MeshInstance3D.new()
	body_inst.name = "Hull"
	body_inst.mesh = body_mesh
	body_inst.material_override = body_mat
	body_inst.position = Vector3(0, 0.45, 0)
	root.add_child(body_inst)
	
	# Turret
	var turret_mesh := BoxMesh.new()
	turret_mesh.size = Vector3(1.4, 0.6, 1.6)
	var turret_mat := StandardMaterial3D.new()
	turret_mat.albedo_color = Color(0.22, 0.24, 0.26) # Dark armor steel
	turret_mat.roughness = 0.9
	
	var turret_inst := MeshInstance3D.new()
	turret_inst.name = "Turret"
	turret_inst.mesh = turret_mesh
	turret_inst.material_override = turret_mat
	turret_inst.position = Vector3(0, 1.2, -0.2)
	root.add_child(turret_inst)
	
	# Cannon Barrel
	var gun_mesh := CylinderMesh.new()
	gun_mesh.top_radius = 0.1
	gun_mesh.bottom_radius = 0.1
	gun_mesh.height = 1.6
	gun_mesh.radial_segments = 8
	var gun_inst := MeshInstance3D.new()
	gun_inst.mesh = gun_mesh
	gun_inst.material_override = turret_mat
	gun_inst.rotation_degrees = Vector3(90, 0, 0)
	gun_inst.position = Vector3(0, 1.2, -1.5)
	root.add_child(gun_inst)
	
	# Readability Hostile Sensor Eye / Visor (Bright Amber/Orange LED)
	var eye_mesh := BoxMesh.new()
	eye_mesh.size = Vector3(0.8, 0.18, 0.12)
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(1.0, 0.55, 0.1) # Bright glowing orange
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1.0, 0.55, 0.1)
	eye_mat.emission_energy_multiplier = 1.8
	var eye_inst := MeshInstance3D.new()
	eye_inst.mesh = eye_mesh
	eye_inst.material_override = eye_mat
	eye_inst.position = Vector3(0, 1.25, -1.05)
	root.add_child(eye_inst)
	
	return root

static func build_pickup_proxy(pos: Vector3 = Vector3.ZERO) -> Node3D:
	var pickup_script = load("res://src/world/art_test_pickup.gd")
	var root: Node3D = pickup_script.new()
	root.name = "InteractivePickup"
	root.position = pos
	return root

# -----------------------------------------------------------------------------
# 6. STREET ENVIRONMENT (Road, Sidewalk Curb, Grass/Soil Plot)
# -----------------------------------------------------------------------------
static func build_street_environment() -> Node3D:
	var env_root := Node3D.new()
	env_root.name = "StreetEnvironment"
	
	var static_body := StaticBody3D.new()
	env_root.add_child(static_body)
	
	# --- Asphalt Road: 8m wide (X = -4 to +4), 32m long (Z = -16 to +16) ---
	# Uses mat_asphalt_road (256x256 = 4m x 4m) -> UV = (8/4, 32/4) = (2.0, 8.0)
	var road_mesh := PlaneMesh.new()
	road_mesh.size = Vector2(8.0, 32.0)
	road_mesh.material = Library.road()
	var road_inst := MeshInstance3D.new()
	road_inst.name = "RoadAsphalt"
	road_inst.mesh = road_mesh
	road_inst.position = Vector3(0, 0.01, 0)
	static_body.add_child(road_inst)
	
	# --- West Sidewalk & Curb (X = -4 to -7.5m, 3.5m wide, 32m long) ---
	# Pavement sidewalk raised 0.2m above road
	var curb_w := BoxMesh.new()
	curb_w.size = Vector3(3.5, 0.2, 32.0)
	curb_w.material = Library.pavement()
	var curb_w_inst := MeshInstance3D.new()
	curb_w_inst.name = "WestSidewalk"
	curb_w_inst.mesh = curb_w
	curb_w_inst.position = Vector3(-5.75, 0.1, 0)
	static_body.add_child(curb_w_inst)
	
	# --- East Sidewalk & Curb (X = +4 to +7.5m, 3.5m wide, 32m long) ---
	var curb_e := BoxMesh.new()
	curb_e.size = Vector3(3.5, 0.2, 32.0)
	curb_e.material = Library.pavement()
	var curb_e_inst := MeshInstance3D.new()
	curb_e_inst.name = "EastSidewalk"
	curb_e_inst.mesh = curb_e
	curb_e_inst.position = Vector3(5.75, 0.1, 0)
	static_body.add_child(curb_e_inst)
	
	# --- Grass/Soil Lot (West side beyond sidewalk: X = -7.5 to -21.5m, 14m x 32m) ---
	var grass_mesh := PlaneMesh.new()
	grass_mesh.size = Vector2(14.0, 32.0)
	grass_mesh.material = Library.grass_soil_blend()
	var grass_inst := MeshInstance3D.new()
	grass_inst.name = "GrassSoilLot"
	grass_inst.mesh = grass_mesh
	grass_inst.position = Vector3(-14.5, 0.08, 0)
	static_body.add_child(grass_inst)
	
	# Ground Collision Body
	var ground_col := CollisionShape3D.new()
	var ground_box := BoxShape3D.new()
	ground_box.size = Vector3(44.0, 1.0, 36.0)
	ground_col.shape = ground_box
	ground_col.position = Vector3(-4.0, -0.5, 0)
	static_body.add_child(ground_col)
	
	return env_root
