class_name DestructibleBuilding
extends StaticBody3D

## DestructibleBuilding â€” Multi-stage destructible building structure (Page 23 & 32).
## Architectural styling for Nuclear Strike urban aesthetic.
## Collapsing lowers collision height to 3.5 to open up flight corridors.

const DamageReceiverScript = preload("res://src/combat/damage_receiver.gd")
const DetailMesh = preload("res://src/world/detail_mesh.gd")
const Tile = DetailMesh.Tile
const Materials = preload("res://src/world/stylized_materials.gd")

@export var building_width: float = 14.0
@export var building_height: float = 14.0
@export var building_depth: float = 14.0
@export var max_building_health: float = 250.0

enum DestructionStage {
	INTACT = 0,
	DAMAGED = 1,
	COLLAPSED = 2
}

var current_stage: DestructionStage = DestructionStage.INTACT

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var damage_receiver: Node = $DamageReceiver

var details_root: Node3D = null

## Central archetype geometry and collision shape cache for repeatable town structures
static var intact_mesh_cache: Dictionary = {}
static var box_shape_cache: Dictionary = {}
const GEOMETRY_CACHE_VERSION := 2

static func clear_geometry_cache() -> void:
	intact_mesh_cache.clear()
	box_shape_cache.clear()

func _enter_tree() -> void:
	collision_layer = 2
	collision_mask = 5

func _ready() -> void:
	_setup_structure()

func _setup_structure() -> void:
	if not damage_receiver:
		damage_receiver = get_node_or_null("DamageReceiver")
	if not collision_shape:
		collision_shape = get_node_or_null("CollisionShape3D")
	if not mesh_instance:
		mesh_instance = get_node_or_null("MeshInstance3D")

	if damage_receiver:
		damage_receiver.max_health = max_building_health
		damage_receiver.current_health = max_building_health
		damage_receiver.target_affinity = GameConstants.TargetAffinity.STRUCTURE
		if not damage_receiver.damaged.is_connected(_on_damaged):
			damage_receiver.damaged.connect(_on_damaged)
		if not damage_receiver.destroyed.is_connected(_on_destroyed):
			damage_receiver.destroyed.connect(_on_destroyed)

	mesh_instance.visibility_range_end = 260.0
	mesh_instance.visibility_range_end_margin = 35.0
	mesh_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	_update_visuals_and_collision()

func _on_damaged(_amount: float, remaining_hp: float, _data: RefCounted) -> void:
	if current_stage == DestructionStage.INTACT and remaining_hp < max_building_health * 0.5:
		current_stage = DestructionStage.DAMAGED
		_update_visuals_and_collision()

func _on_destroyed(_data: RefCounted) -> void:
	if current_stage != DestructionStage.COLLAPSED:
		current_stage = DestructionStage.COLLAPSED
		_update_visuals_and_collision()
		_spawn_collapse_rubble()
		if is_inside_tree() and has_node("/root/FXManager"):
			get_node("/root/FXManager").spawn_building_collapse_dust(global_position + Vector3(0, building_height * 0.2, 0), Vector3(building_width, building_height, building_depth))

@export var archetype: String = "auto"

func _update_visuals_and_collision() -> void:
	if not collision_shape or not mesh_instance:
		return

	# Spatial integer hash for diverse per-building coloring
	var gx: int = int(round(position.x / 12.0))
	var gz: int = int(round(position.z / 12.0))
	var h: int = abs((gx * 73856093) ^ (gz * 19349663) ^ int(round(building_width * 31.0 + building_height * 17.0)))
	var color_seed: float = float(h % 1000) / 1000.0

	# Clean up previous details if any
	if details_root and is_instance_valid(details_root):
		details_root.queue_free()
		details_root = null

	match current_stage:
		DestructionStage.INTACT:
			mesh_instance.material_override = null

			# Shared immutable BoxShape3D cache by dimensions
			var dimensions := Vector3(building_width, building_height, building_depth)
			var shape_key := var_to_bytes(dimensions).hex_encode()
			var shape: BoxShape3D = box_shape_cache.get(shape_key, null)
			if not shape:
				shape = BoxShape3D.new()
				shape.size = Vector3(building_width, building_height, building_depth)
				box_shape_cache[shape_key] = shape
			collision_shape.shape = shape
			collision_shape.position = Vector3(0, building_height * 0.5, 0)

			var arch := _resolved_archetype(h)
			var wall_tile := _wall_tile(arch, h)
			# Hash influences house siding/roof and apartment wall colors. Cache the
			# actual palette variant, not the location, to keep safe sharing useful.
			var palette := Vector2i.ZERO
			if arch == "townhouse":
				palette = Vector2i(h % 3, int(h / 3.0) % 3)
			elif arch == "apartment":
				palette.x = h % 4
			var cache_key := var_to_str([GEOMETRY_CACHE_VERSION, arch, shape_key, wall_tile, palette])
			var cached_mesh: ArrayMesh = intact_mesh_cache.get(cache_key, null)

			if cached_mesh:
				mesh_instance.mesh = cached_mesh
			else:
				var details := preload("res://src/world/detail_mesh.gd").new()
				_build_archetype_geometry(details, arch, h, color_seed)

				var merged_mesh := details.build(Materials.town_atlas())
				var shadow := preload("res://src/world/detail_mesh.gd").new()
				shadow.box(Vector3(building_width, building_height, building_depth), Vector3(0, building_height * 0.5, 0), Color.WHITE)
				merged_mesh.shadow_mesh = shadow.build()

				intact_mesh_cache[cache_key] = merged_mesh
				mesh_instance.mesh = merged_mesh

			mesh_instance.position = Vector3.ZERO

		DestructionStage.DAMAGED:
			mesh_instance.material_override = null
			var details := DetailMesh.new()
			_build_archetype_geometry(details, _resolved_archetype(h), h, color_seed)
			# Remove a roof/wall corner. Keep UVs and the building's original material IDs.
			var cut_min := Vector3(building_width * 0.08, building_height * 0.43, -building_depth * 0.12)
			details.remove_box(AABB(cut_min, Vector3(building_width, building_height * 2.0, building_depth)))
			details.use_material(Tile.INTERIOR)
			details.box(Vector3(building_width * 0.44, 0.22, building_depth * 0.62), Vector3(building_width * 0.29, cut_min.y, building_depth * 0.19), Color.WHITE)
			details.box(Vector3(0.22, building_height * 0.30, building_depth * 0.62), Vector3(cut_min.x, cut_min.y + building_height * 0.15, building_depth * 0.19), Color.WHITE)
			details.box(Vector3(building_width * 0.44, building_height * 0.23, 0.22), Vector3(building_width * 0.29, cut_min.y + building_height * 0.115, cut_min.z), Color.WHITE)
			details.use_material(Tile.WOOD)
			for i in 3:
				details.box(Vector3(building_width * 0.39, 0.20, 0.22), Vector3(building_width * 0.28, cut_min.y + 0.24, building_depth * (-0.02 + i * 0.23)), Color(0.56, 0.49, 0.36))
			mesh_instance.mesh = details.build(Materials.town_atlas(true))
			mesh_instance.position = Vector3.ZERO

		DestructionStage.COLLAPSED:
			mesh_instance.material_override = null
			var rubble_h: float = 3.5
			var shape = BoxShape3D.new()
			shape.size = Vector3(building_width * 1.15, rubble_h, building_depth * 1.15)
			collision_shape.shape = shape
			collision_shape.position = Vector3(0, rubble_h * 0.5, 0)
			mesh_instance.mesh = _build_collapsed(h)
			mesh_instance.position = Vector3.ZERO

func _resolved_archetype(h: int) -> String:
	if archetype != "auto":
		return archetype
	if building_height >= 14.5:
		return "skyscraper_heli" if h % 3 == 0 else "corporate_glass"
	if building_width >= 16.0 and building_height <= 10.0:
		return "factory"
	return ["apartment", "townhouse", "supermarket", "fastfood_burger", "pizzeria", "ice_cream", "business_center", "apartment"][h % 8]

func _wall_tile(arch: String, h: int) -> int:
	if arch in ["townhouse", "pizzeria", "fastfood_burger"] or (arch == "apartment" and h % 2 == 0):
		return Tile.BRICK
	return Tile.INDUSTRIAL if arch == "factory" else Tile.PLASTER

func _build_collapsed(h: int) -> ArrayMesh:
	var details := DetailMesh.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = h
	var wall := _wall_tile(_resolved_archetype(h), h)
	details.use_material(Tile.INTERIOR)
	details.box(Vector3(building_width * 1.07, 0.45, building_depth * 1.07), Vector3(0, 0.225, 0), Color(0.62, 0.57, 0.49))
	# A low incomplete shell, with open gaps rather than a solid slab.
	details.use_material(wall)
	details.box(Vector3(building_width * 0.64, 2.6, 0.6), Vector3(-building_width * 0.14, 1.3, -building_depth * 0.43), Color.WHITE)
	details.box(Vector3(0.6, 3.3, building_depth * 0.38), Vector3(-building_width * 0.44, 1.65, -building_depth * 0.22), Color.WHITE)
	details.box(Vector3(building_width * 0.24, 1.4, 0.7), Vector3(building_width * 0.29, 0.7, building_depth * 0.42), Color.WHITE)
	for i in 12:
		details.use_material([wall, Tile.INTERIOR, Tile.ROOF, Tile.WOOD][i % 4])
		var size := Vector3(rng.randf_range(1.1, 3.0), rng.randf_range(0.55, 1.25), rng.randf_range(1.0, 2.5))
		var center := Vector3(rng.randf_range(-0.36, 0.36) * building_width, size.y * 0.5 + rng.randf_range(0.25, 1.5), rng.randf_range(-0.36, 0.36) * building_depth)
		details.box(size, center, Color(0.75, 0.72, 0.64))
	details.use_material(Tile.ROOF)
	details.gable_roof(Vector3(building_width * 0.48, 0.65, building_depth * 0.46), Vector3(building_width * 0.18, 1.4, 0), Color.WHITE, Color(0.7, 0.66, 0.55))
	return details.build(Materials.town_atlas(true))

func _build_archetype_geometry(details: RefCounted, arch: String, h: int, _color_seed: float) -> void:
	var w := building_width
	var h_val := building_height
	var d := building_depth
	var wall_tile := _wall_tile(arch, h)

	match arch:
		"skyscraper_heli":
			# Modern Off-White Skyscraper with Rooftop Helipad
			var wall_col := Color(0.82, 0.80, 0.76)
			var plinth_col := Color(0.26, 0.28, 0.30)
			var trim_col := Color(0.68, 0.66, 0.62)
			var win_col := Color(0.18, 0.22, 0.26)
			var core_col := Color(0.24, 0.28, 0.32)

			# Main tower body
			details.use_material(wall_tile)
			details.box(Vector3(w, h_val, d), Vector3(0, h_val * 0.5, 0), wall_col, true)
			# Base plinth
			details.use_material(Tile.TRIM)
			details.box(Vector3(w + 0.6, 1.6, d + 0.6), Vector3(0, 0.8, 0), plinth_col)
			# Vertical recessed glass core
			details.use_material(Tile.GLASS)
			details.box(Vector3(w * 0.35, h_val - 2.0, d + 0.08), Vector3(0, h_val * 0.5 + 0.5, 0), core_col)
			# Roof parapet trim & slate deck
			details.use_material(Tile.TRIM)
			details.box(Vector3(w + 0.3, 0.6, d + 0.3), Vector3(0, h_val - 0.1, 0), trim_col)
			details.use_material(Tile.ROOF)
			details.box(Vector3(w - 0.2, 0.1, d - 0.2), Vector3(0, h_val - 0.05, 0), Color(0.33, 0.36, 0.35))

			# Window bands on floors
			var floors := int(floor((h_val - 3.5) / 3.0))
			for fi in floors:
				var lvl := 2.6 + fi * 3.0
				details.use_material(Tile.GLASS)
				details.box(Vector3(w + 0.05, 1.2, d * 0.28), Vector3(0, lvl + 0.6, -d * 0.35), win_col)
				details.use_material(Tile.GLASS)
				details.box(Vector3(w + 0.05, 1.2, d * 0.28), Vector3(0, lvl + 0.6, d * 0.35), win_col)
				details.use_material(Tile.GLASS)
				details.box(Vector3(w * 0.28, 1.2, d + 0.05), Vector3(-w * 0.35, lvl + 0.6, 0), win_col)
				details.use_material(Tile.GLASS)
				details.box(Vector3(w * 0.28, 1.2, d + 0.05), Vector3(w * 0.35, lvl + 0.6, 0), win_col)

			# Rooftop Helipad
			var heli_r := minf(w, d) * 0.38
			var heli_center := Vector3(0, h_val + 0.04, 0)
			details.use_material(Tile.TRIM)
			details.helipad(heli_center, heli_r, Color(0.28, 0.30, 0.32), Color(0.85, 0.68, 0.25), Color(0.85, 0.88, 0.86))

			# Rooftop HVAC penthouse & antenna
			details.use_material(Tile.TRIM)
			details.box(Vector3(w * 0.28, 2.2, d * 0.28), Vector3(-w * 0.30, h_val + 1.1, -d * 0.30), Color(0.65, 0.68, 0.70))
			details.use_material(Tile.TRIM)
			details.box(Vector3(0.22, 5.5, 0.22), Vector3(w * 0.35, h_val + 2.75, w * 0.35), Color(0.85, 0.24, 0.20))

		"corporate_glass":
			# Tactical slate steel / petrol glass tower
			var wall_col := Color(0.26, 0.32, 0.38)
			var trim_col := Color(0.72, 0.70, 0.65)
			var plinth_col := Color(0.22, 0.24, 0.28)
			var win_col := Color(0.16, 0.20, 0.24)

			details.use_material(wall_tile)
			details.box(Vector3(w, h_val, d), Vector3(0, h_val * 0.5, 0), wall_col, true)
			details.use_material(Tile.TRIM)
			details.box(Vector3(w + 0.5, 1.4, d + 0.5), Vector3(0, 0.7, 0), plinth_col)
			details.use_material(Tile.TRIM)
			details.box(Vector3(w + 0.3, 0.5, d + 0.3), Vector3(0, h_val - 0.1, 0), trim_col)
			details.use_material(Tile.ROOF)
			details.box(Vector3(w - 0.2, 0.1, d - 0.2), Vector3(0, h_val - 0.05, 0), Color(0.33, 0.36, 0.35))

			# Horizontal spandrel bands
			var floors := int(floor((h_val - 2.8) / 3.0))
			for fi in floors:
				var lvl := 2.2 + fi * 3.0
				details.use_material(Tile.TRIM)
				details.box(Vector3(w + 0.08, 0.45, d + 0.08), Vector3(0, lvl + 1.4, 0), trim_col)
				details.use_material(Tile.GLASS)
				details.box(Vector3(w + 0.04, 1.1, d + 0.04), Vector3(0, lvl + 0.6, 0), win_col)

			# Stepped top mechanical floor
			details.use_material(Tile.TRIM)
			details.box(Vector3(w * 0.6, 2.0, d * 0.6), Vector3(0, h_val + 1.0, 0), Color(0.68, 0.70, 0.74))
			details.use_material(Tile.TRIM)
			details.cylinder(1.2, 1.5, Vector3(w * 0.2, h_val + 0.75, d * 0.2), Color(0.55, 0.58, 0.62), 8)

		"supermarket":
			# Commercial supermarket with earthy stone walls and muted fascia
			var wall_col := Color(0.76, 0.73, 0.66)
			var plinth_col := Color(0.30, 0.32, 0.34)
			var sign_col := Color(0.24, 0.45, 0.38)
			var glass_col := Color(0.18, 0.22, 0.26)

			details.use_material(wall_tile)
			details.box(Vector3(w, h_val, d), Vector3(0, h_val * 0.5, 0), wall_col, true)
			details.use_material(Tile.TRIM)
			details.box(Vector3(w + 0.4, 0.6, d + 0.4), Vector3(0, 0.3, 0), plinth_col)
			details.use_material(Tile.TRIM)
			details.box(Vector3(w + 0.25, 1.4, 0.4), Vector3(0, h_val - 0.7, d * 0.5 + 0.2), sign_col)
			details.use_material(Tile.GLASS)
			details.box(Vector3(w * 0.85, h_val * 0.45, 0.15), Vector3(0, h_val * 0.32, d * 0.5 + 0.06), glass_col)
			details.use_material(Tile.TRIM)
			details.box(Vector3(w * 0.45, 0.25, 2.0), Vector3(0, h_val * 0.45, d * 0.5 + 1.0), Color(0.85, 0.68, 0.25))
			details.use_material(Tile.TRIM)
			details.box(Vector3(3.2, 1.4, 2.4), Vector3(-w * 0.25, h_val + 0.7, 0), Color(0.65, 0.68, 0.70))
			details.use_material(Tile.TRIM)
			details.box(Vector3(2.4, 1.2, 2.0), Vector3(w * 0.25, h_val + 0.6, 0), Color(0.65, 0.68, 0.70))

		"fastfood_burger":
			# Brick diner with roof icon
			var wall_col := Color(0.58, 0.36, 0.27)
			var trim_col := Color(0.65, 0.26, 0.20)
			var glass_col := Color(0.18, 0.22, 0.26)

			details.use_material(wall_tile)
			details.box(Vector3(w, h_val, d), Vector3(0, h_val * 0.5, 0), wall_col, true)
			details.use_material(Tile.TRIM)
			details.box(Vector3(w + 0.3, 0.6, d + 0.3), Vector3(0, h_val - 0.3, 0), trim_col)
			details.use_material(Tile.GLASS)
			details.box(Vector3(w * 0.75, 1.6, 0.15), Vector3(0, 1.6, d * 0.5 + 0.06), glass_col)
			details.use_material(Tile.TRIM)
			details.box(Vector3(w * 0.6, 0.25, 1.6), Vector3(0, 2.7, d * 0.5 + 0.8), Color(0.65, 0.26, 0.20))
			details.use_material(Tile.TRIM)
			details.burger_sign(Vector3(0, h_val, 0), minf(w, d) * 0.32)

		"pizzeria":
			# Terracotta brick pizzeria
			var wall_col := Color(0.62, 0.38, 0.28)
			var trim_col := Color(0.78, 0.75, 0.68)
			var glass_col := Color(0.18, 0.22, 0.26)

			details.use_material(wall_tile)
			details.box(Vector3(w, h_val, d), Vector3(0, h_val * 0.5, 0), wall_col, true)
			details.use_material(Tile.TRIM)
			details.box(Vector3(w + 0.3, 0.5, d + 0.3), Vector3(0, h_val - 0.25, 0), trim_col)
			details.use_material(Tile.GLASS)
			details.box(Vector3(w * 0.7, 1.5, 0.15), Vector3(0, 1.5, d * 0.5 + 0.06), glass_col)
			details.use_material(Tile.TRIM)
			details.box(Vector3(w * 0.55, 0.22, 1.8), Vector3(0, 2.6, d * 0.5 + 0.9), Color(0.68, 0.24, 0.18))
			details.use_material(Tile.TRIM)
			details.pizza_sign(Vector3(0, h_val + 0.1, 0), minf(w, d) * 0.35)

		"ice_cream":
			# Warm sandstone cafe with amber awning
			var wall_col := Color(0.78, 0.74, 0.66)
			var awning_col := Color(0.85, 0.68, 0.25)
			var trim_col := Color(0.88, 0.86, 0.82)
			var glass_col := Color(0.18, 0.22, 0.26)

			details.use_material(wall_tile)
			details.box(Vector3(w, h_val, d), Vector3(0, h_val * 0.5, 0), wall_col, true)
			details.use_material(Tile.TRIM)
			details.box(Vector3(w + 0.3, 0.4, d + 0.3), Vector3(0, h_val - 0.2, 0), trim_col)
			details.use_material(Tile.GLASS)
			details.box(Vector3(w * 0.65, 1.6, 0.15), Vector3(0, 1.6, d * 0.5 + 0.06), glass_col)
			details.use_material(Tile.TRIM)
			details.box(Vector3(w * 0.5, 0.25, 1.6), Vector3(0, 2.7, d * 0.5 + 0.8), awning_col)
			details.use_material(Tile.TRIM)
			details.box(Vector3(1.8, 1.8, 0.2), Vector3(0, h_val + 1.2, 0), awning_col)
			details.use_material(Tile.TRIM)
			details.box(Vector3(1.4, 1.4, 0.25), Vector3(0, h_val + 1.2, 0), Color(0.88, 0.85, 0.78))

		"business_center":
			# Symmetrical municipal / business center
			var wing_col := Color(0.75, 0.72, 0.65)
			var glass_col := Color(0.18, 0.24, 0.30)
			var trim_col := Color(0.28, 0.32, 0.36)

			details.use_material(Tile.GLASS)
			details.box(Vector3(w * 0.45, h_val + 1.2, d + 0.3), Vector3(0, (h_val + 1.2) * 0.5, 0), glass_col)
			details.use_material(wall_tile)
			details.box(Vector3(w * 0.30, h_val, d * 0.85), Vector3(-w * 0.35, h_val * 0.5, 0), wing_col)
			details.use_material(wall_tile)
			details.box(Vector3(w * 0.30, h_val, d * 0.85), Vector3(w * 0.35, h_val * 0.5, 0), wing_col)
			details.use_material(Tile.TRIM)
			details.box(Vector3(w * 0.35, 0.3, 2.2), Vector3(0, 3.2, d * 0.5 + 1.1), trim_col)
			details.use_material(Tile.TRIM)
			details.cylinder(0.25, 3.0, Vector3(-w * 0.12, 1.5, d * 0.5 + 1.8), Color(0.85, 0.85, 0.86), 6)
			details.use_material(Tile.TRIM)
			details.cylinder(0.25, 3.0, Vector3(w * 0.12, 1.5, d * 0.5 + 1.8), Color(0.85, 0.85, 0.86), 6)

		"townhouse":
			# Gabled house with brick/stone walls and slate roof
			var sidings := [Color(0.75, 0.71, 0.64), Color(0.58, 0.36, 0.27), Color(0.68, 0.65, 0.58)]
			var wall_col: Color = sidings[h % sidings.size()]
			var roof_cols := [Color(0.33, 0.36, 0.35), Color(0.48, 0.28, 0.20), Color(0.28, 0.33, 0.26)]
			var roof_col: Color = roof_cols[int(h / 3.0) % roof_cols.size()]

			var wall_h := h_val * 0.65
			var roof_h := h_val * 0.42
			details.use_material(wall_tile)
			details.box(Vector3(w, wall_h, d), Vector3(0, wall_h * 0.5, 0), wall_col, true)
			details.use_material(wall_tile)
			details.gable_roof(Vector3(w + 0.8, roof_h, d + 0.8), Vector3(0, wall_h + roof_h * 0.5, 0), roof_col, wall_col, false)
			details.use_material(Tile.TRIM)
			details.box(Vector3(0.9, roof_h * 1.1, 0.9), Vector3(w * 0.28, wall_h + roof_h * 0.55, -d * 0.15), Color(0.58, 0.36, 0.27))
			details.use_material(Tile.TRIM)
			details.box(Vector3(w * 0.4, 0.2, 1.6), Vector3(0, 0.1, d * 0.5 + 0.8), Color(0.75, 0.75, 0.76))
			details.use_material(Tile.ROOF)
			details.box(Vector3(w * 0.42, 0.15, 1.4), Vector3(0, 2.4, d * 0.5 + 0.7), roof_col)
			details.use_material(Tile.TRIM)
			details.box(Vector3(1.2, 1.2, 0.1), Vector3(-w * 0.28, wall_h * 0.55, d * 0.5 + 0.05), Color(0.18, 0.22, 0.26))
			details.use_material(Tile.TRIM)
			details.box(Vector3(1.2, 1.2, 0.1), Vector3(w * 0.28, wall_h * 0.55, d * 0.5 + 0.05), Color(0.18, 0.22, 0.26))

		"factory":
			# Industrial factory warehouse with smokestack
			var wall_col := Color(0.32, 0.36, 0.30)
			var trim_col := Color(0.85, 0.68, 0.25)
			var stack_red := Color(0.72, 0.22, 0.18)
			var stack_white := Color(0.82, 0.82, 0.80)

			details.use_material(wall_tile)
			details.box(Vector3(w, h_val, d), Vector3(0, h_val * 0.5, 0), wall_col, true)
			details.use_material(Tile.TRIM)
			details.box(Vector3(w + 0.4, 0.8, d + 0.4), Vector3(0, 0.4, 0), Color(0.24, 0.26, 0.28))
			details.use_material(Tile.TRIM)
			details.box(Vector3(w + 0.3, 0.4, d + 0.3), Vector3(0, h_val - 0.2, 0), trim_col)
			details.use_material(Tile.ROOF)
			details.box(Vector3(w - 0.2, 0.08, d - 0.2), Vector3(0, h_val + 0.02, 0), Color(0.28, 0.30, 0.30))
			details.use_material(Tile.TRIM)
			details.box(Vector3(w * 0.45, h_val * 0.65, 0.2), Vector3(0, h_val * 0.325, d * 0.5 + 0.08), Color(0.65, 0.68, 0.70))
			var stack_h := h_val + 8.0
			var stack_r := 1.2
			var stack_pos := Vector3(w * 0.45 + stack_r + 0.2, 0, d * 0.45)
			var bands := 6
			var band_h := stack_h / float(bands)
			for bi in bands:
				var col := stack_red if (bi % 2 == 1) else stack_white
				details.use_material(Tile.TRIM)
				details.cylinder(stack_r, band_h, Vector3(stack_pos.x, (bi + 0.5) * band_h, stack_pos.z), col, 8, bi == bands - 1)

		_: # "apartment" or general
			# Low-poly multi-story apartment block with Megabonk palette
			var pal_colors := [
				Color(0.58, 0.36, 0.27), # Warm Brick #945D45
				Color(0.71, 0.67, 0.55), # Plaster / Stone #B6AA8B
				Color(0.48, 0.44, 0.36), # Weathered Sandstone
				Color(0.36, 0.42, 0.34), # Olive Drab Masonry
			]
			var wall_col: Color = pal_colors[h % pal_colors.size()]
			var trim_col := Color(0.75, 0.73, 0.68)
			var plinth_col := Color(0.26, 0.28, 0.30)
			var win_col := Color(0.18, 0.22, 0.26)

			details.use_material(wall_tile)
			details.box(Vector3(w, h_val, d), Vector3(0, h_val * 0.5, 0), wall_col, true)
			details.use_material(Tile.TRIM)
			details.box(Vector3(w + 0.4, 1.0, d + 0.4), Vector3(0, 0.5, 0), plinth_col)
			details.use_material(Tile.TRIM)
			details.box(Vector3(w + 0.3, 0.5, d + 0.3), Vector3(0, h_val - 0.2, 0), trim_col)
			details.use_material(Tile.ROOF)
			details.box(Vector3(w - 0.2, 0.1, d - 0.2), Vector3(0, h_val + 0.02, 0), Color(0.33, 0.36, 0.35))

			var floors := int(floor((h_val - 2.6) / 2.8))
			for fi in floors:
				var lvl := 2.2 + fi * 2.8
				details.use_material(Tile.GLASS)
				details.box(Vector3(w + 0.06, 1.0, d * 0.35), Vector3(0, lvl + 0.5, -d * 0.28), win_col)
				details.use_material(Tile.GLASS)
				details.box(Vector3(w + 0.06, 1.0, d * 0.35), Vector3(0, lvl + 0.5, d * 0.28), win_col)
				details.use_material(Tile.GLASS)
				details.box(Vector3(w * 0.35, 1.0, d + 0.06), Vector3(-w * 0.28, lvl + 0.5, 0), win_col)
				details.use_material(Tile.GLASS)
				details.box(Vector3(w * 0.35, 1.0, d + 0.06), Vector3(w * 0.28, lvl + 0.5, 0), win_col)
				if fi >= 1:
					details.use_material(Tile.TRIM)
					details.box(Vector3(w * 0.32, 0.7, 0.9), Vector3(0, lvl + 0.35, d * 0.5 + 0.45), trim_col)
					details.use_material(Tile.TRIM)
					details.box(Vector3(w * 0.32, 0.7, 0.9), Vector3(0, lvl + 0.35, -d * 0.5 - 0.45), trim_col)

			details.use_material(wall_tile)
			details.box(Vector3(w * 0.35, 1.8, d * 0.35), Vector3(0, h_val + 0.9, 0), wall_col)
			details.use_material(Tile.TRIM)
			details.box(Vector3(2.0, 1.0, 1.5), Vector3(w * 0.25, h_val + 0.5, d * 0.25), Color(0.65, 0.68, 0.70))

	if arch != "townhouse":
		details.use_material(Tile.ROOF)
		details.box(Vector3(w + 0.35, 0.28, d + 0.35), Vector3(0, h_val - 0.13, 0), Color.WHITE)
		if arch == "factory":
			details.use_material(wall_tile)
			details.gable_roof(Vector3(w + 0.7, 1.8, d + 0.7), Vector3(0, h_val + 1.15, 0), Color.WHITE, Color.WHITE, true)
	else:
		var eave_y := h_val * 0.65
		details.use_material(Tile.TRIM)
		for side in [-1.0, 1.0]:
			details.box(Vector3(0.4, 0.35, d + 0.85), Vector3(side * (w * 0.5 + 0.2), eave_y, 0), Color(0.68, 0.65, 0.56))
		details.box(Vector3(1.8, 2.6, 0.18), Vector3(0, 1.3, d * 0.5 + 0.1), Color(0.65, 0.61, 0.49))
		details.use_material(Tile.WOOD)
		details.box(Vector3(1.4, 2.3, 0.2), Vector3(0, 1.15, d * 0.5 + 0.2), Color.WHITE)

func _spawn_collapse_rubble() -> void:
	# Settled fragments share one rubble mesh; no unbounded rigid bodies.
	pass
