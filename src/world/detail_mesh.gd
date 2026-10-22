extends RefCounted
## Merge decorative shapes into one draw surface with per-vertex colors and UVs.
## Supports textured retro pixel materials with filter_nearest_mipmap.

const FACES := [
	[Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(-1, 1, 1)],
	[Vector3(1, -1, -1), Vector3(-1, -1, -1), Vector3(-1, 1, -1), Vector3(1, 1, -1)],
	[Vector3(1, -1, 1), Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(1, 1, 1)],
	[Vector3(-1, -1, -1), Vector3(-1, -1, 1), Vector3(-1, 1, 1), Vector3(-1, 1, -1)],
	[Vector3(-1, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, -1), Vector3(-1, 1, -1)],
	[Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(-1, -1, 1)],
]
const NORMALS := [Vector3.FORWARD * -1, Vector3.FORWARD, Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN]

var vertices := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()
var indices := PackedInt32Array()
var uvs := PackedVector2Array()
var material_ids := PackedVector2Array()
enum Tile { BRICK, PLASTER, ROOF, GLASS, TRIM, METAL, INTERIOR, WOOD, LEAF, BARK, STONE, ASPHALT, GRASS, PAVING, INDUSTRIAL, DAMAGE }
var material_index: int = Tile.TRIM

const TILE_METERS := preload("res://src/world/stylized_materials.gd").TILE_METERS
const TEX_SCALE := 1.0 / TILE_METERS

func use_material(index: int) -> void:
	material_index = index

func box(size: Vector3, center: Vector3, color: Color, omit_top: bool = false, omit_bottom: bool = false) -> void:
	for face in 6:
		if omit_top and face == 4:
			continue
		if omit_bottom and face == 5:
			continue
		var start := vertices.size()
		for point in FACES[face]:
			vertices.append(center + point * size * 0.5)
			normals.append(NORMALS[face])
			colors.append(color)
			material_ids.append(Vector2(material_index, 0))

		# Generate texture UVs based on face orientation and dimensions
		var u_len: float = 1.0
		var v_len: float = 1.0
		match face:
			0, 1: # Front / Back (XY)
				u_len = size.x * TEX_SCALE
				v_len = size.y * TEX_SCALE
			2, 3: # Right / Left (ZY)
				u_len = size.z * TEX_SCALE
				v_len = size.y * TEX_SCALE
			4, 5: # Top / Bottom (XZ)
				u_len = size.x * TEX_SCALE
				v_len = size.z * TEX_SCALE

		uvs.append(Vector2(0, v_len))
		uvs.append(Vector2(u_len, v_len))
		uvs.append(Vector2(u_len, 0))
		uvs.append(Vector2(0, 0))

		for index in [0, 2, 1, 0, 3, 2]:
			indices.append(start + index)

func quad(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, color: Color, normal: Vector3 = Vector3.ZERO) -> void:
	if normal == Vector3.ZERO:
		normal = (p1 - p0).cross(p3 - p0).normalized()
	var start := vertices.size()
	vertices.append(p0)
	vertices.append(p1)
	vertices.append(p2)
	vertices.append(p3)

	var u_len := (p1 - p0).length() * TEX_SCALE
	var v_len := (p3 - p0).length() * TEX_SCALE
	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(u_len, 0))
	uvs.append(Vector2(u_len, v_len))
	uvs.append(Vector2(0, v_len))

	for i in 4:
		normals.append(normal)
		colors.append(color)
		material_ids.append(Vector2(material_index, 0))
	indices.append(start + 0)
	indices.append(start + 2)
	indices.append(start + 1)
	indices.append(start + 0)
	indices.append(start + 3)
	indices.append(start + 2)

func triangle(p0: Vector3, p1: Vector3, p2: Vector3, color: Color, normal: Vector3 = Vector3.ZERO) -> void:
	if normal == Vector3.ZERO:
		normal = (p1 - p0).cross(p2 - p0).normalized()
	var start := vertices.size()
	vertices.append(p0)
	vertices.append(p1)
	vertices.append(p2)

	var u_len := (p1 - p0).length() * TEX_SCALE
	var v_len := (p2 - p0).length() * TEX_SCALE
	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(u_len, 0))
	uvs.append(Vector2(0, v_len))

	for i in 3:
		normals.append(normal)
		colors.append(color)
		material_ids.append(Vector2(material_index, 0))
	indices.append(start + 0)
	indices.append(start + 2)
	indices.append(start + 1)

## Low-poly pitched gabled roof with 2 sloped sides and 2 triangular end gables
func gable_roof(size: Vector3, center: Vector3, color: Color, gable_color: Color = Color.TRANSPARENT, along_x: bool = false) -> void:
	if gable_color == Color.TRANSPARENT:
		gable_color = color
	var hx: float = size.x * 0.5
	var hy: float = size.y
	var hz: float = size.z * 0.5
	var base_y: float = center.y - hy * 0.5
	var ridge_y: float = center.y + hy * 0.5
	var wall_index := material_index
	use_material(Tile.ROOF)

	if along_x:
		var p_ridge_w := Vector3(center.x - hx, ridge_y, center.z)
		var p_ridge_e := Vector3(center.x + hx, ridge_y, center.z)
		var p_sw := Vector3(center.x - hx, base_y, center.z + hz)
		var p_se := Vector3(center.x + hx, base_y, center.z + hz)
		var p_nw := Vector3(center.x - hx, base_y, center.z - hz)
		var p_ne := Vector3(center.x + hx, base_y, center.z - hz)
		quad(p_sw, p_se, p_ridge_e, p_ridge_w, color)
		quad(p_ridge_w, p_ridge_e, p_ne, p_nw, color)
		use_material(wall_index)
		triangle(p_sw, p_ridge_w, p_nw, gable_color)
		triangle(p_ridge_e, p_se, p_ne, gable_color)
	else:
		var p_ridge_s := Vector3(center.x, ridge_y, center.z + hz)
		var p_ridge_n := Vector3(center.x, ridge_y, center.z - hz)
		var p_sw := Vector3(center.x - hx, base_y, center.z + hz)
		var p_se := Vector3(center.x + hx, base_y, center.z + hz)
		var p_nw := Vector3(center.x - hx, base_y, center.z - hz)
		var p_ne := Vector3(center.x + hx, base_y, center.z - hz)
		quad(p_sw, p_ridge_s, p_ridge_n, p_nw, color)
		quad(p_se, p_ne, p_ridge_n, p_ridge_s, color)
		use_material(wall_index)
		triangle(p_se, p_ridge_s, p_sw, gable_color)
		triangle(p_ridge_n, p_ne, p_nw, gable_color)

## Low-poly cylinder for columns, smokestacks, silos, tanks, fountains
func cylinder(radius: float, height: float, center: Vector3, color: Color, segments: int = 8, top_cap: bool = true, bottom_cap: bool = false) -> void:
	var half_h: float = height * 0.5
	var y_top: float = center.y + half_h
	var y_bot: float = center.y - half_h
	var circ: float = radius * TAU * TEX_SCALE

	for i in range(segments):
		var a0: float = float(i) * TAU / float(segments)
		var a1: float = float(i + 1) * TAU / float(segments)
		var c0: float = cos(a0)
		var s0: float = sin(a0)
		var c1: float = cos(a1)
		var s1: float = sin(a1)

		var b0 := Vector3(center.x + c0 * radius, y_bot, center.z + s0 * radius)
		var b1 := Vector3(center.x + c1 * radius, y_bot, center.z + s1 * radius)
		var t0 := Vector3(center.x + c0 * radius, y_top, center.z + s0 * radius)
		var t1 := Vector3(center.x + c1 * radius, y_top, center.z + s1 * radius)

		var n_mid := Vector3((c0 + c1) * 0.5, 0.0, (s0 + s1) * 0.5).normalized()
		var start := vertices.size()
		vertices.append(b0)
		vertices.append(b1)
		vertices.append(t1)
		vertices.append(t0)

		var u0 := float(i) / float(segments) * circ
		var u1 := float(i + 1) / float(segments) * circ
		var v_h := height * TEX_SCALE
		uvs.append(Vector2(u0, 0))
		uvs.append(Vector2(u1, 0))
		uvs.append(Vector2(u1, v_h))
		uvs.append(Vector2(u0, v_h))

		for _k in 4:
			normals.append(n_mid)
			colors.append(color)
			material_ids.append(Vector2(material_index, 0))
		indices.append(start + 0)
		indices.append(start + 1)
		indices.append(start + 2)
		indices.append(start + 0)
		indices.append(start + 2)
		indices.append(start + 3)

		if top_cap:
			var top_center := Vector3(center.x, y_top, center.z)
			var s_top := vertices.size()
			vertices.append(top_center)
			vertices.append(t1)
			vertices.append(t0)
			uvs.append(Vector2.ZERO)
			uvs.append(Vector2(c1, s1) * radius * TEX_SCALE)
			uvs.append(Vector2(c0, s0) * radius * TEX_SCALE)
			for _k in 3:
				normals.append(Vector3.UP)
				colors.append(color)
				material_ids.append(Vector2(material_index, 0))
			indices.append(s_top + 0)
			indices.append(s_top + 2)
			indices.append(s_top + 1)

		if bottom_cap:
			var bot_center := Vector3(center.x, y_bot, center.z)
			var s_bot := vertices.size()
			vertices.append(bot_center)
			vertices.append(b0)
			vertices.append(b1)
			uvs.append(Vector2.ZERO)
			uvs.append(Vector2(c0, s0) * radius * TEX_SCALE)
			uvs.append(Vector2(c1, s1) * radius * TEX_SCALE)
			for _k in 3:
				normals.append(Vector3.DOWN)
				colors.append(color)
				material_ids.append(Vector2(material_index, 0))
			indices.append(s_bot + 0)
			indices.append(s_bot + 2)
			indices.append(s_bot + 1)

## Helipad surface with outer border ring and central 'H' symbol
func helipad(center: Vector3, radius: float, pad_color: Color, ring_color: Color, h_color: Color) -> void:
	var segments: int = 12
	var y: float = center.y
	var inner_r: float = radius * 0.82
	var outer_r: float = radius

	for i in range(segments):
		var a0: float = float(i) * TAU / float(segments)
		var a1: float = float(i + 1) * TAU / float(segments)
		var p0 := Vector3(center.x + cos(a0) * inner_r, y, center.z + sin(a0) * inner_r)
		var p1 := Vector3(center.x + cos(a1) * inner_r, y, center.z + sin(a1) * inner_r)
		triangle(center, p1, p0, pad_color, Vector3.UP)
		var r0 := Vector3(center.x + cos(a0) * outer_r, y + 0.01, center.z + sin(a0) * outer_r)
		var r1 := Vector3(center.x + cos(a1) * outer_r, y + 0.01, center.z + sin(a1) * outer_r)
		var ri0 := Vector3(center.x + cos(a0) * inner_r, y + 0.01, center.z + sin(a0) * inner_r)
		var ri1 := Vector3(center.x + cos(a1) * inner_r, y + 0.01, center.z + sin(a1) * inner_r)
		quad(ri0, ri1, r1, r0, ring_color, Vector3.UP)

	var h_scale: float = radius * 0.55
	var bar_w: float = h_scale * 0.22
	var stem_h: float = h_scale * 1.5
	var cross_w: float = h_scale * 1.1

	box(Vector3(bar_w, 0.03, stem_h), center + Vector3(-cross_w * 0.45, 0.02, 0), h_color)
	box(Vector3(bar_w, 0.03, stem_h), center + Vector3(cross_w * 0.45, 0.02, 0), h_color)
	box(Vector3(cross_w, 0.03, bar_w), center + Vector3(0, 0.02, 0), h_color)

func burger_sign(center: Vector3, size: float) -> void:
	var y := center.y
	box(Vector3(size * 1.1, size * 0.25, size * 1.1), Vector3(center.x, y + size * 0.12, center.z), Color(0.72, 0.52, 0.30))
	box(Vector3(size * 1.15, size * 0.22, size * 1.15), Vector3(center.x, y + size * 0.32, center.z), Color(0.32, 0.18, 0.12))
	box(Vector3(size * 1.2, size * 0.08, size * 1.2), Vector3(center.x, y + size * 0.45, center.z), Color(0.85, 0.68, 0.22))
	box(Vector3(size * 1.22, size * 0.10, size * 1.22), Vector3(center.x, y + size * 0.52, center.z), Color(0.32, 0.46, 0.24))
	box(Vector3(size * 1.05, size * 0.40, size * 1.05), Vector3(center.x, y + size * 0.72, center.z), Color(0.75, 0.54, 0.32))
	box(Vector3(size * 0.8, size * 0.15, size * 0.8), Vector3(center.x, y + size * 0.95, center.z), Color(0.78, 0.58, 0.34))

func pizza_sign(center: Vector3, size: float) -> void:
	var tip := center + Vector3(0, size * 0.1, -size * 0.7)
	var bl := center + Vector3(-size * 0.6, size * 0.1, size * 0.6)
	var br := center + Vector3(size * 0.6, size * 0.1, size * 0.6)
	box(Vector3(size * 1.3, size * 0.28, size * 0.25), center + Vector3(0, size * 0.14, size * 0.6), Color(0.72, 0.50, 0.28))
	triangle(tip, br, bl, Color(0.88, 0.72, 0.22), Vector3.UP)
	box(Vector3(size * 0.2, 0.06, size * 0.2), center + Vector3(0.0, size * 0.12, 0.1), Color(0.65, 0.22, 0.16))
	box(Vector3(size * 0.18, 0.06, size * 0.18), center + Vector3(-size * 0.2, size * 0.12, size * 0.35), Color(0.65, 0.22, 0.16))
	box(Vector3(size * 0.18, 0.06, size * 0.18), center + Vector3(size * 0.2, size * 0.12, size * 0.35), Color(0.65, 0.22, 0.16))

## Subtract an axis-aligned breach from decorative triangles, retaining their UVs.
## The physics shape is controlled by DestructibleBuilding, independently of this art.
func remove_box(cut: AABB) -> void:
	var result = get_script().new()
	var planes := [Plane(Vector3.RIGHT, cut.end.x), Plane(Vector3.LEFT, -cut.position.x), Plane(Vector3.UP, cut.end.y), Plane(Vector3.DOWN, -cut.position.y), Plane(Vector3.BACK, cut.end.z), Plane(Vector3.FORWARD, -cut.position.z)]
	for i in range(0, indices.size(), 3):
		var remaining: Array = []
		for j in 3:
			var k := indices[i + j]
			remaining.append([vertices[k], normals[k], colors[k], uvs[k], material_ids[k]])
		for plane in planes:
			if remaining.is_empty():
				break
			var outside := _clip_polygon(remaining, plane, true)
			if outside.size() >= 3:
				result._append_polygon(outside)
			remaining = _clip_polygon(remaining, plane, false)
	vertices = result.vertices
	normals = result.normals
	colors = result.colors
	uvs = result.uvs
	material_ids = result.material_ids
	indices = result.indices

func _clip_polygon(poly: Array, plane: Plane, outside: bool) -> Array:
	var clipped: Array = []
	for i in poly.size():
		var a: Array = poly[i]
		var b: Array = poly[(i + 1) % poly.size()]
		var da := plane.distance_to(a[0])
		var db := plane.distance_to(b[0])
		var keep_a := da > 0.0001 if outside else da <= 0.0001
		var keep_b := db > 0.0001 if outside else db <= 0.0001
		if keep_a:
			clipped.append(a)
		if keep_a != keep_b:
			var t := da / (da - db)
			clipped.append([a[0].lerp(b[0], t), a[1].lerp(b[1], t).normalized(), a[2].lerp(b[2], t), a[3].lerp(b[3], t), a[4]])
	return clipped

func _append_polygon(poly: Array) -> void:
	var start := vertices.size()
	for point: Array in poly:
		vertices.append(point[0])
		normals.append(point[1])
		colors.append(point[2])
		uvs.append(point[3])
		material_ids.append(point[4])
	for i in range(1, poly.size() - 1):
		indices.append_array([start, start + i, start + i + 1])

func build(mat: Material = null) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = material_ids
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if mat == null:
		mat = preload("res://src/world/stylized_materials.gd").town_atlas()
	mesh.surface_set_material(0, mat)
	return mesh
