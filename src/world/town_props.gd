class_name TownProps
extends RefCounted
const Detail = preload("res://src/world/detail_mesh.gd")
const Tile = Detail.Tile
static var cache: Dictionary = {}

static func mesh(kind: String) -> ArrayMesh:
	if cache.has(kind):
		return cache[kind]
	var d := Detail.new()
	match kind:
		"crate":
			d.use_material(Tile.WOOD)
			d.box(Vector3(2.3, 1.6, 2.0), Vector3(0, 0.8, 0), Color.WHITE)
			d.use_material(Tile.METAL)
			for x in [-0.8, 0.8]:
				d.box(Vector3(0.16, 1.7, 2.12), Vector3(x, 0.85, 0), Color.WHITE)
		"barrel":
			d.use_material(Tile.TRIM)
			d.cylinder(0.72, 1.8, Vector3(0, 0.9, 0), Color(0.55, 0.25, 0.18), 8)
			d.cylinder(0.73, 0.43, Vector3(0, 1.1, 0), Color(0.79, 0.67, 0.36), 8)
			d.use_material(Tile.METAL)
			for y in [0.12, 1.72]:
				d.cylinder(0.75, 0.13, Vector3(0, y, 0), Color.WHITE, 8)
			d.cylinder(0.15, 0.06, Vector3(0.25, 1.85, 0.2), Color.WHITE, 6)
		"vehicle":
			d.use_material(Tile.METAL)
			d.box(Vector3(2.2, 0.75, 4.2), Vector3(0, 0.85, 0), Color.WHITE)
			d.box(Vector3(2.0, 0.95, 1.9), Vector3(0, 1.5, -0.1), Color.WHITE)
			d.use_material(Tile.GLASS)
			d.box(Vector3(1.8, 0.6, 1.97), Vector3(0, 1.52, -0.1), Color.WHITE)
			d.use_material(Tile.METAL)
			d.box(Vector3(2.15, 0.16, 2.0), Vector3(0, 2.02, -0.1), Color.WHITE)
			d.use_material(Tile.TRIM)
			for x in [-1.07, 1.07]:
				for z in [-1.35, 1.25]:
					d.box(Vector3(0.32, 0.8, 0.8), Vector3(x, 0.5, z), Color(0.13, 0.15, 0.14))
			d.box(Vector3(2.25, 0.2, 0.2), Vector3(0, 0.72, -2.15), Color(0.43, 0.44, 0.38))
	var result := d.build()
	cache[kind] = result
	return result

static func instance(kind: String, point: Vector3) -> MeshInstance3D:
	var prop := MeshInstance3D.new()
	prop.name = "Town_" + kind
	prop.mesh = mesh(kind)
	prop.position = point
	prop.visibility_range_end = 260.0
	prop.visibility_range_end_margin = 35.0
	return prop
