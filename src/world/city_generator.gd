class_name CityGenerator
extends Node3D

## CityGenerator — Procedural tactical district generation for Nuclear Strike combat scale.
## Calibrated low-poly architectural styling matching miniature vibrant town reference:
## - Crisp dark asphalt roads with white zebra crosswalks and stop lines at all intersections
## - Continuous light-gray sidewalks and curbs framing city blocks
## - Rich zoned archetypes: Skyscraper with rooftop helipad, corporate glass towers,
##   supermarkets with parking stalls, burger diners, pizzerias, ice cream shops,
##   colorful multi-story apartments, suburban gabled houses with picket fences,
##   industrial factories with red-and-white smokestacks, sports courts, and fountain plazas.

const DestructibleBuildingScene = preload("res://scenes/world/destructible_building.tscn")
const DestructibleBuildingScript = preload("res://src/world/destructible_building.gd")
const VolatileHazardScript = preload("res://src/world/volatile_hazard.gd")
const DamageReceiverScript = preload("res://src/combat/damage_receiver.gd")
const Materials = preload("res://src/world/stylized_materials.gd")
const FieldDressing = preload("res://src/world/field_dressing.gd")
const DetailMesh = preload("res://src/world/detail_mesh.gd")
const Props = preload("res://src/world/town_props.gd")

@export var current_district: String = "Downtown"
@export var grid_width: int = 8
@export var grid_depth: int = 8
@export var block_size: float = 38.0
@export var main_avenue_width: float = 12.0
@export var secondary_street_width: float = 8.0

var spawned_blocks: Array[Node3D] = []
var meadow_lots: Array[Vector3] = []
var terrain_lots: Array[Vector3] = []
var building_footprints: Dictionary = {}
var district_rng := RandomNumberGenerator.new()
signal generation_complete
var is_generating: bool = false
var generation_ratio: float = 0.0
var generation_stage: String = "INITIALIZING"

const WORK_BUDGET_USEC: int = 5000 # 5.0 ms generation budget per frame
var _budget_start_usec: int = 0

func _check_frame_budget() -> void:
	if _budget_start_usec == 0:
		_budget_start_usec = Time.get_ticks_usec()
	if has_node("/root/UIFlow") and get_node("/root/UIFlow").busy:
		if Time.get_ticks_usec() - _budget_start_usec >= WORK_BUDGET_USEC:
			await get_tree().process_frame
			_budget_start_usec = Time.get_ticks_usec()

func _ready() -> void:
	generate_district(current_district, 1337)

func generate_district(district_name: String, seed_val: int) -> void:
	is_generating = true
	generation_ratio = 0.05
	generation_stage = "BUILDING ARTERIAL ROAD NETWORK"
	_clear_existing()
	district_rng.seed = seed_val
	current_district = district_name
	_budget_start_usec = Time.get_ticks_usec()

	var half_x: int = int(grid_width * 0.5)
	var half_z: int = int(grid_depth * 0.5)

	# 1. Generate Arterial Road Network with Crosswalks and Sidewalks
	await _spawn_road_network(half_x, half_z)
	generation_ratio = 0.22
	generation_stage = "CONSTRUCTING URBAN BLOCKS"

	# 2. Central Military FOB Helipad Launch Plaza at (0, 0, 0)
	_spawn_depot_plaza(Vector3.ZERO)

	# 3. Generate City Blocks flanking the arterial avenues
	var total_blocks: int = (half_x * 2) * (half_z * 2)
	var block_idx: int = 0
	for ix in range(-half_x, half_x):
		for iz in range(-half_z, half_z):
			block_idx += 1
			var block_origin = Vector3(
				(float(ix) + 0.5) * block_size,
				0,
				(float(iz) + 0.5) * block_size
			)
			# Central clearing check: blocks adjacent to (0, 0) are kept low/open for clean takeoff
			var is_central_fob: bool = (abs(ix) <= 1 and abs(iz) <= 1 and (ix == 0 or ix == -1) and (iz == 0 or iz == -1))
			_generate_block(block_origin, district_name, is_central_fob, ix, iz)
			generation_ratio = 0.22 + 0.58 * (float(block_idx) / float(total_blocks))
			if block_idx % 4 == 0 or block_idx == total_blocks:
				generation_stage = "CONSTRUCTING URBAN DISTRICT (%d/%d)" % [block_idx, total_blocks]
			await _check_frame_budget()

	generation_ratio = 0.80
	generation_stage = "DEPLOYING VEGETATION & URBAN DRESSING"
	var dressing := FieldDressing.new()
	dressing.name = "FieldDressing"
	add_child(dressing)
	spawned_blocks.append(dressing)
	await dressing.generate(seed_val, grid_width, grid_depth, block_size, meadow_lots, building_footprints, terrain_lots, self)
	is_generating = false
	generation_ratio = 1.0
	generation_stage = "URBAN SECTOR OPERATIONAL"
	generation_complete.emit()

func _clear_existing() -> void:
	for b in spawned_blocks:
		if is_instance_valid(b):
			b.queue_free()
	spawned_blocks.clear()
	meadow_lots.clear()
	terrain_lots.clear()
	building_footprints.clear()

func _spawn_road_network(half_x: int, half_z: int) -> void:
	var total_w = float(half_x * 2) * block_size + block_size
	var total_d = float(half_z * 2) * block_size + block_size

	# Dark charcoal slate asphalt with authentic pixel texture
	var road_mat = Materials.road()

	# 1. Asphalt Road Surfaces
	# Avenues running along Z (parallel to forward flight) at X = 0, ±38, ±76...
	for ix in range(-half_x, half_x + 1):
		var ave_x = float(ix) * block_size
		var is_central = (ix == 0)
		var w = main_avenue_width if is_central else secondary_street_width

		var ave_mesh = MeshInstance3D.new()
		var m = BoxMesh.new()
		m.size = Vector3(w, 0.04, total_d)
		m.material = road_mat
		ave_mesh.mesh = m
		ave_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ave_mesh.position = Vector3(ave_x, 0.02, 0)
		add_child(ave_mesh)
		spawned_blocks.append(ave_mesh)

	# Cross Streets running along X at Z = 0, ±38, ±76...
	for iz in range(-half_z, half_z + 1):
		var str_z = float(iz) * block_size
		var is_central = (iz == 0)
		var w = main_avenue_width if is_central else secondary_street_width

		var str_mesh = MeshInstance3D.new()
		var m2 = BoxMesh.new()
		m2.size = Vector3(total_w, 0.04, w)
		m2.material = road_mat
		str_mesh.mesh = m2
		str_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		str_mesh.position = Vector3(0, 0.025, str_z)
		add_child(str_mesh)
		spawned_blocks.append(str_mesh)

	# 2. Road Markings (Zebra Crosswalks, Stop Lines, Dashed Centerlines) Merged into 1 ArrayMesh!
	var markings := DetailMesh.new()
	var white_line_col := Color(0.78, 0.80, 0.78)
	var yellow_line_col := Color(0.85, 0.70, 0.25)

	# Intersection Crosswalks and Centerlines
	var total_intersections: int = (half_x * 2 + 1) * (half_z * 2 + 1)
	var inter_idx: int = 0
	for ix in range(-half_x, half_x + 1):
		var ave_x = float(ix) * block_size
		var is_central_x = (ix == 0)
		var w_x = main_avenue_width if is_central_x else secondary_street_width

		for iz in range(-half_z, half_z + 1):
			inter_idx += 1
			await _check_frame_budget()
			if inter_idx % 8 == 0:
				generation_ratio = 0.05 + 0.17 * (float(inter_idx) / float(total_intersections))
				generation_stage = "BUILDING ARTERIAL ROADWAYS (%d%%)" % int(generation_ratio * 100)
			var str_z = float(iz) * block_size
			var is_central_z = (iz == 0)
			var w_z = main_avenue_width if is_central_z else secondary_street_width

			var is_fob_center = (ix == 0 and iz == 0)

			# Zebra Crosswalks approaching intersection from 4 sides
			if not is_fob_center:
				# North approach (Z negative)
				var n_z = str_z - w_z * 0.5 - 1.6
				for s in range(5):
					var sx = ave_x + (-2.0 + float(s)) * (w_x * 0.18)
					markings.box(Vector3(w_x * 0.12, 0.02, 2.2), Vector3(sx, 0.038, n_z), white_line_col)
				# Stop line
				markings.box(Vector3(w_x * 0.85, 0.02, 0.35), Vector3(ave_x, 0.038, str_z - w_z * 0.5 - 3.1), white_line_col)

				# South approach (Z positive)
				var s_z = str_z + w_z * 0.5 + 1.6
				for s in range(5):
					var sx = ave_x + (-2.0 + float(s)) * (w_x * 0.18)
					markings.box(Vector3(w_x * 0.12, 0.02, 2.2), Vector3(sx, 0.038, s_z), white_line_col)
				# Stop line
				markings.box(Vector3(w_x * 0.85, 0.02, 0.35), Vector3(ave_x, 0.038, str_z + w_z * 0.5 + 3.1), white_line_col)

				# West approach (X negative)
				var w_x_pos = ave_x - w_x * 0.5 - 1.6
				for s in range(5):
					var sz = str_z + (-2.0 + float(s)) * (w_z * 0.18)
					markings.box(Vector3(2.2, 0.02, w_z * 0.12), Vector3(w_x_pos, 0.038, sz), white_line_col)
				# Stop line
				markings.box(Vector3(0.35, 0.02, w_z * 0.85), Vector3(ave_x - w_x * 0.5 - 3.1, 0.038, str_z), white_line_col)

				# East approach (X positive)
				var e_x_pos = ave_x + w_x * 0.5 + 1.6
				for s in range(5):
					var sz = str_z + (-2.0 + float(s)) * (w_z * 0.18)
					markings.box(Vector3(2.2, 0.02, w_z * 0.12), Vector3(e_x_pos, 0.038, sz), white_line_col)
				# Stop line
				markings.box(Vector3(0.35, 0.02, w_z * 0.85), Vector3(ave_x + w_x * 0.5 + 3.1, 0.038, str_z), white_line_col)

			# Center dashed lines along avenue between this intersection and the next
			if iz < half_z:
				var z_start = str_z + w_z * 0.5 + 3.6
				var z_end = (iz + 1) * block_size - w_z * 0.5 - 3.6
				var seg_len = z_end - z_start
				if seg_len > 4.0:
					if is_central_x:
						# Main avenue yellow center lines
						if abs(ave_x) < 0.1 and (abs(z_start) < 14.0 or abs(z_end) < 14.0):
							pass
						else:
							markings.box(Vector3(0.35, 0.02, seg_len), Vector3(ave_x, 0.038, (z_start + z_end) * 0.5), yellow_line_col)
					else:
						# Secondary street white dashed center line
						var dashes = int(seg_len / 4.4)
						for d in range(dashes):
							var dz = z_start + float(d) * 4.4 + 1.2
							markings.box(Vector3(0.24, 0.02, 2.2), Vector3(ave_x, 0.038, dz), white_line_col)

			# Center dashed lines along cross street between this intersection and the next
			if ix < half_x:
				var x_start = ave_x + w_x * 0.5 + 3.6
				var x_end = (ix + 1) * block_size - w_x * 0.5 - 3.6
				var seg_len_x = x_end - x_start
				if seg_len_x > 4.0:
					if is_central_z:
						# Main cross boulevard yellow center lines
						if abs(str_z) < 0.1 and (abs(x_start) < 14.0 or abs(x_end) < 14.0):
							pass
						else:
							markings.box(Vector3(seg_len_x, 0.02, 0.35), Vector3((x_start + x_end) * 0.5, 0.038, str_z), yellow_line_col)
					else:
						# Secondary cross street white dashed center line
						var dashes_x = int(seg_len_x / 4.4)
						for d in range(dashes_x):
							var dx = x_start + float(d) * 4.4 + 1.2
							markings.box(Vector3(2.2, 0.02, 0.24), Vector3(dx, 0.038, str_z), white_line_col)

	var markings_node = MeshInstance3D.new()
	markings_node.name = "RoadMarkings"
	markings_node.mesh = markings.build()
	markings_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(markings_node)
	spawned_blocks.append(markings_node)

	# 3. Continuous Sidewalks & Curbs Framing Every City Block Merged into 1 ArrayMesh!
	var sidewalks := DetailMesh.new()
	var sidewalk_col := Color(0.71, 0.67, 0.55) # Plaster/stone #B6AA8B curb
	var curb_w := 1.8
	var curb_h := 0.09

	for ix in range(-half_x, half_x):
		var is_w_central = (ix == 0)
		var is_e_central = (ix + 1 == 0)
		var hw_w = (main_avenue_width if is_w_central else secondary_street_width) * 0.5
		var hw_e = (main_avenue_width if is_e_central else secondary_street_width) * 0.5

		var x_min = float(ix) * block_size + hw_w
		var x_max = float(ix + 1) * block_size - hw_e
		var lot_w = x_max - x_min
		var center_x = (x_min + x_max) * 0.5

		for iz in range(-half_z, half_z):
			var is_s_central = (iz == 0)
			var is_n_central = (iz + 1 == 0)
			var hw_s = (main_avenue_width if is_s_central else secondary_street_width) * 0.5
			var hw_n = (main_avenue_width if is_n_central else secondary_street_width) * 0.5

			var z_min = float(iz) * block_size + hw_s
			var z_max = float(iz + 1) * block_size - hw_n
			var lot_d = z_max - z_min
			var center_z = (z_min + z_max) * 0.5

			# Perimeter Sidewalks (South, North, West, East)
			sidewalks.box(Vector3(lot_w, curb_h, curb_w), Vector3(center_x, curb_h * 0.5, z_min + curb_w * 0.5), sidewalk_col)
			sidewalks.box(Vector3(lot_w, curb_h, curb_w), Vector3(center_x, curb_h * 0.5, z_max - curb_w * 0.5), sidewalk_col)
			sidewalks.box(Vector3(curb_w, curb_h, lot_d - curb_w * 2.0), Vector3(x_min + curb_w * 0.5, curb_h * 0.5, center_z), sidewalk_col)
			sidewalks.box(Vector3(curb_w, curb_h, lot_d - curb_w * 2.0), Vector3(x_max - curb_w * 0.5, curb_h * 0.5, center_z), sidewalk_col)

	var sidewalks_node = MeshInstance3D.new()
	sidewalks_node.name = "Sidewalks"
	sidewalks_node.mesh = sidewalks.build(Materials.sidewalk())
	sidewalks_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sidewalks_node)
	spawned_blocks.append(sidewalks_node)

func _generate_block(origin: Vector3, district_name: String, is_central_fob: bool, ix: int, iz: int) -> void:
	if is_central_fob:
		_spawn_staging_yard(origin, "fob")
		return

	# Natural meadow clearings interrupting grid
	var dist_from_center := sqrt(float(ix * ix + iz * iz))
	var clearing := sin(origin.x * 0.037) + cos(origin.z * 0.043)

	# Dedicated recreation / park plaza in mid-ring
	if origin.length() > 42.0 and district_name not in ["Military Base", "Industrial", "Ruins"] and clearing > 0.68:
		if clearing > 1.55:
			_spawn_sports_court(origin)
		elif clearing > 1.30:
			_spawn_fountain_plaza(origin)
		else:
			_spawn_staging_yard(origin, "plaza")
		return

	var roll = district_rng.randf()

	match district_name:
		"Downtown":
			if dist_from_center <= 3.2:
				# Downtown Core: Landmark Skyscraper with Rooftop Helipad & Corporate Glass Towers
				if (ix == -1 and iz == 1) or (ix == 1 and iz == -1):
					_spawn_building(origin, 25.0, 15.0, 15.0, 500.0, "skyscraper_heli")
				elif (ix == 1 and iz == 1) or (ix == -2 and iz == 0):
					_spawn_building(origin, 18.0, 14.0, 14.0, 360.0, "corporate_glass")
				elif roll < 0.40:
					_spawn_building(origin, 13.0, 16.0, 13.0, 320.0, "business_center")
				else:
					_spawn_building(origin, 16.0, 13.0, 13.0, 350.0, "corporate_glass")
			elif dist_from_center <= 5.5:
				# Commercial Strip, Dining & Apartments
				if roll < 0.16:
					_spawn_building(origin, 8.0, 16.0, 12.0, 260.0, "supermarket")
				elif roll < 0.32:
					_spawn_building(origin, 7.5, 12.0, 12.0, 210.0, "fastfood_burger")
				elif roll < 0.46:
					_spawn_building(origin, 7.5, 12.0, 12.0, 200.0, "pizzeria")
				elif roll < 0.58:
					_spawn_building(origin, 7.0, 11.0, 11.0, 180.0, "ice_cream")
				elif roll < 0.78:
					_spawn_building(origin, 12.0, 13.0, 13.0, 240.0, "apartment")
				else:
					_spawn_building(origin, 7.0, 10.0, 10.0, 160.0, "townhouse")
			else:
				# Outer District: Apartments, Townhouses, Sports Courts, and Edge Factories
				if ix <= -4 and iz <= -2:
					# Industrial enclave in outer quadrant
					if roll < 0.45:
						_spawn_building(origin, 8.5, 18.0, 15.0, 300.0, "factory")
						_spawn_volatile_tank(origin + Vector3(7.5, 0, 6.0))
					elif roll < 0.70:
						_spawn_construction_site(origin)
					else:
						_spawn_staging_yard(origin, "depot")
						_spawn_volatile_tank(origin + Vector3(6.0, 0, 6.0))
				elif roll < 0.20:
					_spawn_sports_court(origin)
				elif roll < 0.55:
					_spawn_building(origin, 11.0, 12.5, 12.5, 220.0, "apartment")
				elif roll < 0.85:
					_spawn_building(origin, 6.5, 10.0, 10.0, 160.0, "townhouse")
				else:
					_spawn_staging_yard(origin, "yard")

		"Commercial":
			if roll < 0.18:
				_spawn_fountain_plaza(origin)
			elif roll < 0.38:
				_spawn_building(origin, 8.0, 17.0, 13.0, 260.0, "supermarket")
			elif roll < 0.54:
				_spawn_building(origin, 7.5, 12.0, 12.0, 200.0, "fastfood_burger")
			elif roll < 0.68:
				_spawn_building(origin, 7.5, 12.0, 12.0, 200.0, "pizzeria")
			elif roll < 0.82:
				_spawn_building(origin, 7.0, 11.0, 11.0, 180.0, "ice_cream")
			else:
				_spawn_building(origin, 14.0, 13.0, 13.0, 280.0, "corporate_glass")

		"Residential":
			if roll < 0.20:
				_spawn_sports_court(origin)
			elif roll < 0.55:
				_spawn_building(origin, 11.5, 13.0, 13.0, 220.0, "apartment")
			elif roll < 0.85:
				_spawn_building(origin, 6.5, 10.0, 10.0, 160.0, "townhouse")
			else:
				_spawn_staging_yard(origin, "yard")

		"Industrial":
			if roll < 0.25:
				_spawn_staging_yard(origin, "depot")
				_spawn_volatile_tank(origin + Vector3(7.0, 0, 7.0))
			elif roll < 0.60:
				_spawn_building(origin, 8.5, 20.0, 16.0, 320.0, "factory")
				_spawn_volatile_tank(origin + Vector3(8.0, 0, 0))
			elif roll < 0.80:
				_spawn_construction_site(origin)
			else:
				_spawn_building(origin, 7.5, 14.0, 13.0, 240.0, "factory")

		"Military Base":
			if roll < 0.20:
				_spawn_staging_yard(origin, "motor_pool")
			elif roll < 0.55:
				_spawn_building(origin, 9.5, 20.0, 17.0, 360.0, "factory")
				_spawn_volatile_tank(origin + Vector3(9.0, 0, 7.0))
			elif roll < 0.80:
				_spawn_building(origin, 8.0, 12.0, 12.0, 260.0, "corporate_glass")
			else:
				_spawn_staging_yard(origin, "depot")
				_spawn_volatile_tank(origin + Vector3(6.0, 0, -6.0))
				_spawn_volatile_tank(origin + Vector3(-6.0, 0, 6.0))

		"Waterfront":
			if roll < 0.25:
				_spawn_staging_yard(origin, "dock")
			elif roll < 0.65:
				_spawn_building(origin, 9.0, 14.0, 12.0, 230.0, "supermarket")
			else:
				_spawn_building(origin, 6.5, 10.0, 10.0, 160.0, "townhouse")

		"Desert":
			if roll < 0.35:
				_spawn_staging_yard(origin, "outpost")
				if district_rng.randf() < 0.5:
					_spawn_volatile_tank(origin + Vector3(7.0, 0, -7.0))
			elif roll < 0.70:
				_spawn_building(origin, 7.5, 11.0, 11.0, 180.0, "townhouse")
			else:
				_spawn_building(origin, 8.5, 12.0, 12.0, 200.0, "apartment")

		"Forest":
			if roll < 0.40:
				_spawn_staging_yard(origin, "yard")
			elif roll < 0.70:
				_spawn_building(origin, 6.5, 10.0, 10.0, 160.0, "townhouse")
			else:
				_spawn_building(origin, 10.0, 12.0, 12.0, 200.0, "apartment")

		"Ruins":
			var b = _spawn_building(origin, 8.0, 11.0, 11.0, 180.0, "apartment")
			b.current_stage = DestructibleBuildingScript.DestructionStage.DAMAGED

		_:
			_spawn_building(origin, 9.5, 12.0, 12.0, 220.0, "apartment")

func _spawn_building(origin: Vector3, h: float, w: float, d: float, hp: float, arch_type: String = "auto") -> DestructibleBuilding:
	h = clampf(h, 4.5, 28.0)
	w = clampf(w, 8.0, block_size - secondary_street_width - 4.0)
	d = clampf(d, 8.0, block_size - secondary_street_width - 4.0)

	# Clean architectural stone sidewalk apron framing the building
	var lot = MeshInstance3D.new()
	var lm = BoxMesh.new()
	lm.size = Vector3(w + 1.6, 0.08, d + 1.6)
	lm.material = Materials.sidewalk()
	lot.mesh = lm
	lot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lot.visibility_range_end = 260.0
	lot.visibility_range_end_margin = 35.0
	lot.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	lot.position = origin + Vector3(0, 0.04, 0)
	add_child(lot)
	spawned_blocks.append(lot)

	var bld = DestructibleBuildingScene.instantiate()
	bld.position = origin
	bld.building_height = h
	bld.building_width = w
	bld.building_depth = d
	bld.archetype = arch_type
	building_footprints[origin] = Vector2(w, d)
	bld.max_building_health = hp
	add_child(bld)
	spawned_blocks.append(bld)
	if arch_type in ["factory", "supermarket", "pizzeria", "fastfood_burger"]:
		var parked := Props.instance("vehicle", origin + Vector3(w * 0.5 + 2.3, 0.08, -d * 0.22))
		add_child(parked)
		spawned_blocks.append(parked)
		var supplies := Props.instance("crate", origin + Vector3(w * 0.5 + 2.3, 0.08, d * 0.28))
		add_child(supplies)
		spawned_blocks.append(supplies)
	return bld

func _spawn_sports_court(origin: Vector3) -> Node3D:
	var court_root = Node3D.new()
	court_root.name = "SportsCourt"
	court_root.position = origin
	add_child(court_root)
	spawned_blocks.append(court_root)
	meadow_lots.append(origin)

	var details := DetailMesh.new()
	var apron_w: float = 24.0
	var apron_d: float = 16.0
	details.box(Vector3(apron_w, 0.08, apron_d), Vector3(0, 0.04, 0), Color(0.75, 0.77, 0.80))

	# Vibrant terracotta red court surface
	var court_w: float = 20.0
	var court_d: float = 12.0
	details.box(Vector3(court_w, 0.02, court_d), Vector3(0, 0.082, 0), Color(0.78, 0.35, 0.25))

	# White court boundary lines
	var line_col := Color(0.96, 0.96, 0.98)
	var lw := 0.2
	details.box(Vector3(court_w, 0.02, lw), Vector3(0, 0.093, -court_d * 0.5 + lw * 0.5), line_col)
	details.box(Vector3(court_w, 0.02, lw), Vector3(0, 0.093, court_d * 0.5 - lw * 0.5), line_col)
	details.box(Vector3(lw, 0.02, court_d), Vector3(-court_w * 0.5 + lw * 0.5, 0.093, 0), line_col)
	details.box(Vector3(lw, 0.02, court_d), Vector3(court_w * 0.5 - lw * 0.5, 0.093, 0), line_col)
	details.box(Vector3(lw, 0.02, court_d), Vector3(0, 0.093, 0), line_col)
	details.box(Vector3(court_w * 0.5, 0.02, lw), Vector3(0, 0.093, 0), line_col)

	# Tennis net
	details.box(Vector3(0.12, 1.1, court_d), Vector3(0, 0.55, 0), Color(0.92, 0.94, 0.96))

	# Perimeter fence posts and floodlights
	var post_col := Color(0.72, 0.74, 0.78)
	var fence_h := 3.2
	for fx in [-apron_w * 0.5 + 0.3, apron_w * 0.5 - 0.3]:
		for fz in [-apron_d * 0.5 + 0.3, apron_d * 0.5 - 0.3]:
			details.cylinder(0.12, fence_h, Vector3(fx, fence_h * 0.5, fz), post_col, 6)
			details.box(Vector3(0.5, 0.35, 0.5), Vector3(fx, fence_h + 0.2, fz), Color(0.96, 0.96, 0.80))

	details.box(Vector3(apron_w - 0.6, 0.1, 0.1), Vector3(0, fence_h, -apron_d * 0.5 + 0.3), post_col)
	details.box(Vector3(apron_w - 0.6, 0.1, 0.1), Vector3(0, fence_h, apron_d * 0.5 - 0.3), post_col)
	details.box(Vector3(0.1, 0.1, apron_d - 0.6), Vector3(-apron_w * 0.5 + 0.3, fence_h, 0), post_col)
	details.box(Vector3(0.1, 0.1, apron_d - 0.6), Vector3(apron_w * 0.5 - 0.3, fence_h, 0), post_col)

	var mi = MeshInstance3D.new()
	mi.mesh = details.build()
	mi.visibility_range_end = 260.0
	mi.visibility_range_end_margin = 35.0
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	court_root.add_child(mi)
	return court_root

func _spawn_fountain_plaza(origin: Vector3) -> Node3D:
	var plaza = Node3D.new()
	plaza.name = "FountainPlaza"
	plaza.position = origin
	add_child(plaza)
	spawned_blocks.append(plaza)
	meadow_lots.append(origin)

	var details := DetailMesh.new()
	details.cylinder(12.0, 0.08, Vector3(0, 0.04, 0), Color(0.82, 0.84, 0.88), 16)
	for angle in [PI * 0.25, PI * 0.75, PI * 1.25, PI * 1.75]:
		var dir := Vector3(cos(angle), 0, sin(angle))
		details.box(Vector3(3.0, 0.09, 12.0), Vector3(dir.x * 6.0, 0.045, dir.z * 6.0), Color(0.86, 0.88, 0.90))

	# 2-Tier Fountain
	var stone_col := Color(0.78, 0.80, 0.84)
	var water_col := Color(0.28, 0.62, 0.86)
	details.cylinder(4.0, 0.75, Vector3(0, 0.375, 0), stone_col, 12)
	details.cylinder(3.6, 0.1, Vector3(0, 0.65, 0), water_col, 12)
	details.cylinder(1.2, 1.4, Vector3(0, 0.7, 0), stone_col, 8)
	details.cylinder(2.0, 0.45, Vector3(0, 1.5, 0), stone_col, 10)
	details.cylinder(1.8, 0.08, Vector3(0, 1.7, 0), water_col, 10)
	details.cylinder(0.35, 0.6, Vector3(0, 1.9, 0), Color(0.92, 0.94, 0.96), 6)

	var bench_col := Color(0.68, 0.45, 0.28)
	for i in 4:
		var a := float(i) * TAU / 4.0 + 0.35
		var bx := cos(a) * 7.5
		var bz := sin(a) * 7.5
		details.box(Vector3(2.2, 0.4, 0.8), Vector3(bx, 0.25, bz), bench_col)
		details.box(Vector3(2.2, 0.6, 0.15), Vector3(bx, 0.55, bz + 0.35), bench_col)

	var mi = MeshInstance3D.new()
	mi.mesh = details.build()
	mi.visibility_range_end = 260.0
	mi.visibility_range_end_margin = 35.0
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	plaza.add_child(mi)
	return plaza

func _spawn_construction_site(origin: Vector3) -> Node3D:
	var site = Node3D.new()
	site.name = "ConstructionSite"
	site.position = origin
	add_child(site)
	spawned_blocks.append(site)
	building_footprints[origin] = Vector2(20, 20)

	var details := DetailMesh.new()
	details.box(Vector3(22.0, 0.10, 22.0), Vector3(0, 0.05, 0), Color(0.68, 0.64, 0.55))
	details.box(Vector3(16.0, 0.8, 16.0), Vector3(0, 0.4, 0), Color(0.72, 0.75, 0.78))
	for rx in [-6.0, 0.0, 6.0]:
		for rz in [-6.0, 0.0, 6.0]:
			details.box(Vector3(0.5, 3.5, 0.5), Vector3(rx, 2.0, rz), Color(0.38, 0.40, 0.44))

	# Yellow Tower Crane
	var crane_col := Color(0.96, 0.78, 0.12)
	var cab_col := Color(0.24, 0.45, 0.65)
	var mast_h := 22.0
	var crane_pos := Vector3(5.0, 0, 5.0)
	details.box(Vector3(1.2, mast_h, 1.2), crane_pos + Vector3(0, mast_h * 0.5, 0), crane_col)
	details.box(Vector3(1.6, 1.8, 1.6), crane_pos + Vector3(0, mast_h - 1.0, 0), cab_col)
	details.box(Vector3(1.0, 4.0, 1.0), crane_pos + Vector3(0, mast_h + 2.0, 0), crane_col)
	details.box(Vector3(14.0, 0.9, 0.9), crane_pos + Vector3(-7.0, mast_h + 0.45, 0), crane_col)
	details.box(Vector3(5.5, 0.9, 0.9), crane_pos + Vector3(2.75, mast_h + 0.45, 0), crane_col)
	details.box(Vector3(2.2, 1.4, 1.4), crane_pos + Vector3(4.5, mast_h + 0.6, 0), Color(0.70, 0.72, 0.75))
	details.box(Vector3(0.6, 0.4, 0.6), crane_pos + Vector3(-8.0, mast_h - 0.2, 0), Color(0.25, 0.25, 0.28))
	details.box(Vector3(0.08, 6.0, 0.08), crane_pos + Vector3(-8.0, mast_h - 3.2, 0), Color(0.18, 0.18, 0.20))
	details.box(Vector3(0.4, 0.4, 0.4), crane_pos + Vector3(-8.0, mast_h - 6.3, 0), crane_col)

	var mi = MeshInstance3D.new()
	mi.mesh = details.build()
	mi.visibility_range_end = 260.0
	mi.visibility_range_end_margin = 35.0
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	site.add_child(mi)
	return site

func _spawn_staging_yard(origin: Vector3, yard_type: String) -> Node3D:
	var yard = Node3D.new()
	yard.name = "StagingYard_" + yard_type
	add_child(yard)
	spawned_blocks.append(yard)
	yard.position = origin

	if yard_type == "fob":
		return yard

	if yard_type in ["plaza", "yard"]:
		meadow_lots.append(origin)
		terrain_lots.append(origin)
		var green := MeshInstance3D.new()
		var lawn := BoxMesh.new()
		lawn.size = Vector3(18, 0.08, 18)
		lawn.material = Materials.terrain()
		green.mesh = lawn
		green.position.y = 0.04
		green.visibility_range_end = 260.0
		green.visibility_range_end_margin = 35.0
		green.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		yard.add_child(green)
		for side in [-1.0, 1.0]:
			var berm := MeshInstance3D.new()
			var rock := SphereMesh.new()
			rock.radius = 2.0
			rock.height = 3.0
			rock.radial_segments = 5
			rock.rings = 2
			rock.material = Materials.town_atlas(false, 10, true)
			berm.mesh = rock
			berm.position = Vector3(side * 5.0, 0.3, side * 4.0)
			berm.scale = Vector3(1.6, 0.55, 1.0)
			berm.visibility_range_end = 260.0
			berm.visibility_range_end_margin = 35.0
			berm.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			yard.add_child(berm)
		return yard

	# Clean stylized paved courtyard base
	var pad_mesh = MeshInstance3D.new()
	var m = BoxMesh.new()
	m.size = Vector3(18.0, 0.08, 18.0)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.70, 0.72, 0.76, 1.0)
	mat.roughness = 0.80
	m.material = Materials.sidewalk()
	pad_mesh.mesh = m
	pad_mesh.position = Vector3(0, 0.04, 0)
	pad_mesh.visibility_range_end = 260.0
	pad_mesh.visibility_range_end_margin = 35.0
	pad_mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	yard.add_child(pad_mesh)

	var barrier_mat = StandardMaterial3D.new()
	barrier_mat.albedo_color = Color(0.70, 0.66, 0.58)
	barrier_mat.roughness = 0.85

	var b1 = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(12.0, 0.9, 0.8)
	bm.material = Materials.town_atlas(false, 1, true)
	b1.mesh = bm
	b1.position = Vector3(0, 0.45, -7.5)
	b1.visibility_range_end = 260.0
	b1.visibility_range_end_margin = 35.0
	b1.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	yard.add_child(b1)

	var b2 = MeshInstance3D.new()
	b2.mesh = bm
	b2.position = Vector3(0, 0.45, 7.5)
	b2.visibility_range_end = 260.0
	b2.visibility_range_end_margin = 35.0
	b2.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	yard.add_child(b2)

	var crate := Props.instance("crate", Vector3(-5.0, 0.08, 0))
	yard.add_child(crate)
	yard.add_child(Props.instance("vehicle", Vector3(4.5, 0.08, 0)))

	return yard

func _spawn_volatile_tank(pos: Vector3) -> void:
	var tank = StaticBody3D.new()
	tank.set_script(VolatileHazardScript)
	tank.name = "FuelTank"
	tank.position = pos + Vector3.UP * 2.0

	var col = CollisionShape3D.new()
	var s = CylinderShape3D.new()
	s.height = 4.0
	s.radius = 2.0
	col.shape = s
	tank.add_child(col)

	var m_inst = MeshInstance3D.new()
	m_inst.name = "MeshInstance3D"
	m_inst.mesh = Props.mesh("barrel")
	m_inst.scale = Vector3(2.66, 2.16, 2.66)
	m_inst.position.y = -2.0
	m_inst.visibility_range_end = 260.0
	m_inst.visibility_range_end_margin = 35.0
	m_inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	tank.add_child(m_inst)

	var rec = DamageReceiverScript.new()
	rec.name = "DamageReceiver"
	tank.add_child(rec)
	add_child(tank)
	spawned_blocks.append(tank)

func _spawn_depot_plaza(origin: Vector3) -> void:
	# Central military launch helipad matching Nuclear Strike reference design
	var pad = StaticBody3D.new()
	pad.name = "CentralHelipad"
	add_child(pad)
	spawned_blocks.append(pad)
	pad.position = origin
	pad.collision_layer = 2
	pad.collision_mask = 5

	var col = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(24.0, 0.4, 24.0)
	col.shape = box_shape
	col.position = Vector3(0, 0.2, 0)
	pad.add_child(col)

	# 1. Paved concrete apron framing the helipad
	var apron_mesh = MeshInstance3D.new()
	var am = BoxMesh.new()
	am.size = Vector3(26.0, 0.2, 26.0)
	am.material = Materials.sidewalk()
	apron_mesh.mesh = am
	apron_mesh.position = Vector3(0, 0.1, 0)
	pad.add_child(apron_mesh)

	# 2. Authentic military helipad base and textured landing surface
	var pad_mesh = MeshInstance3D.new()
	var b_mesh = BoxMesh.new()
	b_mesh.size = Vector3(22.0, 0.40, 22.0)
	b_mesh.material = Materials.surface(Color(0.24, 0.26, 0.28))
	pad_mesh.mesh = b_mesh
	pad_mesh.position = Vector3(0, 0.20, 0)
	pad.add_child(pad_mesh)

	var top_mesh = MeshInstance3D.new()
	var pm = PlaneMesh.new()
	pm.size = Vector2(22.0, 22.0)
	pm.material = Materials.helipad()
	top_mesh.mesh = pm
	top_mesh.position = Vector3(0, 0.405, 0)
	pad.add_child(top_mesh)

	# 3. Perimeter floodlight posts in 4 corners
	var details := DetailMesh.new()
	var post_col := Color(0.35, 0.38, 0.40)
	var light_col := Color(0.85, 0.70, 0.25)
	for hx in [-11.8, 11.8]:
		for hz in [-11.8, 11.8]:
			details.box(Vector3(0.4, 1.6, 0.4), Vector3(hx, 0.8, hz), post_col)
			details.box(Vector3(0.6, 0.3, 0.6), Vector3(hx, 1.6, hz), light_col)
	var lights_node = MeshInstance3D.new()
	lights_node.mesh = details.build()
	pad.add_child(lights_node)
