class_name UrbanPathfinder
extends RefCounted

## UrbanPathfinder — High-performance road network and intersection pathfinding
## for ground vehicles in Heli-Town Hell.
## Navigates vehicles along clear street corridors and around city blocks,
## preventing hostiles from driving into or getting stuck on buildings.

const BLOCK_SIZE: float = 38.0
const HALF_GRID: int = 9 # Covers -9 to +9 (-342m to +342m, covering entire 16x16 city district & boundary)

static var _astar: AStar3D = null

static func _ensure_initialized() -> void:
	if _astar != null:
		return
	_astar = AStar3D.new()

	# Node ID scheme:
	# Intersections: (ix + 20) * 10000 + (iz + 20) * 100 + 0
	# Avenue waypoints: 1000000 + (ix + 20) * 10000 + (iz + 20) * 100 + step (step 1, 2, 3)
	# Street waypoints: 2000000 + (ix + 20) * 10000 + (iz + 20) * 100 + step (step 1, 2, 3)

	# 1. Add Intersection Points
	for ix in range(-HALF_GRID, HALF_GRID + 1):
		for iz in range(-HALF_GRID, HALF_GRID + 1):
			var id = _intersection_id(ix, iz)
			var pos = Vector3(float(ix) * BLOCK_SIZE, 0.5, float(iz) * BLOCK_SIZE)
			_astar.add_point(id, pos)

	# 2. Add Avenue Waypoints (3 internal quarter nodes per block: 0.25, 0.50, 0.75)
	for ix in range(-HALF_GRID, HALF_GRID + 1):
		for iz in range(-HALF_GRID, HALF_GRID):
			var prev_id = _intersection_id(ix, iz)
			for step in [1, 2, 3]:
				var fraction = float(step) * 0.25
				var q_id = _ave_sub_id(ix, iz, step)
				var pos = Vector3(float(ix) * BLOCK_SIZE, 0.5, (float(iz) + fraction) * BLOCK_SIZE)
				_astar.add_point(q_id, pos)
				_astar.connect_points(prev_id, q_id)
				prev_id = q_id
			_astar.connect_points(prev_id, _intersection_id(ix, iz + 1))

	# 3. Add Street Waypoints (3 internal quarter nodes per block: 0.25, 0.50, 0.75)
	for ix in range(-HALF_GRID, HALF_GRID):
		for iz in range(-HALF_GRID, HALF_GRID + 1):
			var prev_id = _intersection_id(ix, iz)
			for step in [1, 2, 3]:
				var fraction = float(step) * 0.25
				var q_id = _str_sub_id(ix, iz, step)
				var pos = Vector3((float(ix) + fraction) * BLOCK_SIZE, 0.5, float(iz) * BLOCK_SIZE)
				_astar.add_point(q_id, pos)
				_astar.connect_points(prev_id, q_id)
				prev_id = q_id
			_astar.connect_points(prev_id, _intersection_id(ix + 1, iz))

static func _intersection_id(ix: int, iz: int) -> int:
	return (ix + 20) * 10000 + (iz + 20) * 100 + 0

static func _ave_sub_id(ix: int, iz: int, step: int) -> int:
	return 1000000 + (ix + 20) * 10000 + (iz + 20) * 100 + step

static func _str_sub_id(ix: int, iz: int, step: int) -> int:
	return 2000000 + (ix + 20) * 10000 + (iz + 20) * 100 + step

## Returns a sequence of 3D road waypoints guiding from from_pos to to_pos along streets.
static func find_street_path(from_pos: Vector3, to_pos: Vector3) -> PackedVector3Array:
	_ensure_initialized()

	var flat_from = Vector3(from_pos.x, 0.5, from_pos.z)
	var flat_to = Vector3(to_pos.x, 0.5, to_pos.z)

	var start_id = _astar.get_closest_point(flat_from)
	var end_id = _astar.get_closest_point(flat_to)

	if start_id < 0 or end_id < 0:
		var fallback = PackedVector3Array()
		fallback.append(flat_to)
		return fallback

	if start_id == end_id:
		var p = PackedVector3Array()
		p.append(_astar.get_point_position(end_id))
		return p

	var pts = _astar.get_point_path(start_id, end_id)
	if pts.is_empty():
		var p = PackedVector3Array()
		p.append(_astar.get_point_position(start_id))
		return p

	return pts

## Checks line-of-sight against buildings (Mask 2)
static func has_line_of_sight(from_pos: Vector3, to_pos: Vector3, space: PhysicsDirectSpaceState3D) -> bool:
	if space == null:
		return true
	var query = PhysicsRayQueryParameters3D.create(
		from_pos + Vector3(0.0, 1.2, 0.0),
		to_pos + Vector3(0.0, 1.0, 0.0),
		2 # Mask 2: Buildings / Environment
	)
	var hit = space.intersect_ray(query)
	return hit.is_empty()

## Returns the closest road center line point to any position
static func get_nearest_road_point(pos: Vector3) -> Vector3:
	var ave_ix = clampi(int(roundf(pos.x / BLOCK_SIZE)), -HALF_GRID, HALF_GRID)
	var str_iz = clampi(int(roundf(pos.z / BLOCK_SIZE)), -HALF_GRID, HALF_GRID)
	var ave_x = float(ave_ix) * BLOCK_SIZE
	var str_z = float(str_iz) * BLOCK_SIZE
	var dist_ave = absf(pos.x - ave_x)
	var dist_str = absf(pos.z - str_z)

	if dist_ave < dist_str:
		return Vector3(ave_x, 0.5, pos.z)
	else:
		return Vector3(pos.x, 0.5, str_z)

## Returns the perpendicular distance from pos to the nearest street or avenue centerline
static func distance_to_nearest_road(pos: Vector3) -> float:
	var ave_ix = clampi(int(roundf(pos.x / BLOCK_SIZE)), -HALF_GRID, HALF_GRID)
	var str_iz = clampi(int(roundf(pos.z / BLOCK_SIZE)), -HALF_GRID, HALF_GRID)
	var ave_x = float(ave_ix) * BLOCK_SIZE
	var str_z = float(str_iz) * BLOCK_SIZE
	return minf(absf(pos.x - ave_x), absf(pos.z - str_z))

## Returns true if pos is within road corridor clearance (within 4.8m of an avenue or street centerline)
static func is_on_road_corridor(pos: Vector3, road_margin: float = 4.8) -> bool:
	return distance_to_nearest_road(pos) <= road_margin
