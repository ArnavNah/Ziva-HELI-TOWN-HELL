extends Node3D
## Seeded, sector-batched meadow vegetation and collision-backed faceted knolls.
const Materials = preload("res://src/world/stylized_materials.gd")
const WATER = preload("res://src/shaders/field_water.gdshader")

func generate(seed_value: int, width: int, depth: int, spacing: float, clearings: Array[Vector3] = [], building_footprints: Dictionary = {}, terrain_lots: Array[Vector3] = [], city_generator: Node = null, attempt: int = -1) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 3917
	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	var broadleaf: Array[Transform3D] = []
	var stones: Array[Transform3D] = []
	var grass: Array[Transform3D] = []
	var flowers: Array[Transform3D] = []
	var street_lamps: Array[Transform3D] = []

	var total_cells: int = width * depth
	var cell_idx: int = 0
	var dressing_yield_timer := Time.get_ticks_usec()
	for x in range(-int(width * 0.5), int(width * 0.5)):
		for z in range(-int(depth * 0.5), int(depth * 0.5)):
			cell_idx += 1
			if city_generator and attempt >= 0:
				if not await city_generator._check_frame_budget(attempt):
					return
			elif has_node("/root/UIFlow") and get_node("/root/UIFlow").busy:
				if Time.get_ticks_usec() - dressing_yield_timer >= 5000:
					await get_tree().process_frame
					if not is_inside_tree() or is_queued_for_deletion():
						return
					dressing_yield_timer = Time.get_ticks_usec()
			if city_generator and cell_idx % 8 == 0:
				city_generator.generation_ratio = 0.80 + 0.18 * (float(cell_idx) / float(total_cells))
			var center := Vector3((x + 0.5) * spacing, 0, (z + 0.5) * spacing)
			if center.length() < 30.0:
				continue
			var meadow := clearings.has(center)
			for corner in [Vector3(-11, 0, -11), Vector3(11, 0, 11), Vector3(-11, 0, 11), Vector3(11, 0, -11)]:
				if rng.randf() > (0.85 if meadow else 0.52):
					continue
				var pos: Vector3 = center + corner + Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8))
				var footprint: Vector2 = building_footprints.get(center, Vector2.ZERO)
				# Leave room for the largest crown instead of growing foliage through facades.
				var local_pos := pos - center
				if footprint != Vector2.ZERO and absf(local_pos.x) < footprint.x * 0.5 + 4.8 and absf(local_pos.z) < footprint.y * 0.5 + 4.8:
					continue
				var size := rng.randf_range(0.85, 1.45)
				var tree_basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size)
				trunks.append(Transform3D(tree_basis, pos + Vector3.UP * 1.6 * size))
				if rng.randf() < 0.55:
					broadleaf.append(Transform3D(tree_basis.scaled(Vector3(1.2, 0.95, 1.2)), pos + Vector3.UP * 5.1 * size))
				else:
					crowns.append(Transform3D(tree_basis, pos + Vector3.UP * 4.8 * size))
				if rng.randf() < 0.55:
					stones.append(Transform3D(tree_basis.scaled(Vector3(1.4, 0.7, 1.0)), pos + Vector3(1.9, 0.35, 0)))
				for i in range(6):
					var tuft_pos := pos + Vector3(rng.randf_range(-1.8, 1.8), 0.2, rng.randf_range(-1.8, 1.8))
					grass.append(Transform3D(tree_basis.scaled(Vector3(0.65, 0.5, 0.65)), tuft_pos))

			# Sidewalk street lamps at block corners
			if not meadow and center.length() > 35.0:
				for sc: Vector3 in [Vector3(-14.5, 0, -14.5), Vector3(14.5, 0, 14.5)]:
					if rng.randf() < 0.60:
						var lamp_pos: Vector3 = center + sc
						var lamp_basis := Basis(Vector3.UP, (0.0 if sc.x > 0.0 else PI))
						street_lamps.append(Transform3D(lamp_basis, lamp_pos))

			# Sports courts and fountain plazas get vegetation at their edges only.
			var natural := terrain_lots.has(center) or (terrain_lots.is_empty() and meadow)
			if natural:
				var roll := rng.randf()
				if roll < 0.46:
					_knoll(center, rng.randf_range(5.5, 8.5), rng.randf_range(2.5, 5.0), rng)
				elif roll < 0.62:
					_pond(center, rng.randf_range(3.5, 6.0))
				for i in range(12):
					var angle := rng.randf() * TAU
					var pos := center + Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(9.5, 12.5)
					pos.y = 0.25
					flowers.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * rng.randf_range(0.4, 0.8)), pos))

	# Outer perimeter ring of trees surrounding the town on the open meadow
	var perimeter_radius := float(width * 0.5) * spacing + 12.0
	for i in range(70):
		var p_angle := float(i) * TAU / 70.0 + rng.randf_range(-0.03, 0.03)
		var p_dist := perimeter_radius + rng.randf_range(-8.0, 24.0)
		var p_pos := Vector3(cos(p_angle) * p_dist, 0, sin(p_angle) * p_dist)
		var p_size := rng.randf_range(0.9, 1.5)
		var p_basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * p_size)
		trunks.append(Transform3D(p_basis, p_pos + Vector3.UP * 1.6 * p_size))
		if rng.randf() < 0.60:
			broadleaf.append(Transform3D(p_basis.scaled(Vector3(1.2, 0.95, 1.2)), p_pos + Vector3.UP * 5.1 * p_size))
		else:
			crowns.append(Transform3D(p_basis, p_pos + Vector3.UP * 4.8 * p_size))

	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.22
	trunk.bottom_radius = 0.42
	trunk.height = 3.2
	trunk.radial_segments = 5
	trunk.material = Materials.town_atlas(false, 9, true)
	await _batch("Trunks", trunk, trunks, city_generator, attempt)
	if city_generator and not city_generator.generation_is_current(attempt):
		return

	var crown := CylinderMesh.new()
	crown.top_radius = 0.0
	crown.bottom_radius = 2.6
	crown.height = 6.0
	crown.radial_segments = 6
	crown.material = Materials.town_atlas(false, 8, true, 0.025)
	await _batch("PineCrowns", _pine_mesh(crown.material), crowns, city_generator, attempt)
	if city_generator and not city_generator.generation_is_current(attempt):
		return

	var leaf := SphereMesh.new()
	leaf.radius = 2.3
	leaf.height = 4.6
	leaf.radial_segments = 7
	leaf.rings = 3
	leaf.material = Materials.town_atlas(false, 8, true, 0.02)
	await _batch("BroadleafCrowns", _clustered_crown(leaf), broadleaf, city_generator, attempt)
	if city_generator and not city_generator.generation_is_current(attempt):
		return

	var rock := SphereMesh.new()
	rock.radius = 0.85
	rock.height = 1.7
	rock.radial_segments = 5
	rock.rings = 2
	rock.material = Materials.town_atlas(false, 10, true)
	await _batch("Stones", _faceted(rock), stones, city_generator, attempt)
	if city_generator and not city_generator.generation_is_current(attempt):
		return

	var tuft := CylinderMesh.new()
	tuft.top_radius = 0.0
	tuft.bottom_radius = 0.5
	tuft.height = 1.4
	tuft.radial_segments = 3
	tuft.material = Materials.town_atlas(false, 12, true, 0.06)
	await _batch("GrassTufts", tuft, grass, city_generator, attempt)
	if city_generator and not city_generator.generation_is_current(attempt):
		return

	var flower := SphereMesh.new()
	flower.radius = 0.32
	flower.height = 0.4
	flower.radial_segments = 5
	flower.rings = 2
	flower.material = Materials.surface(Color("efcd75"))
	await _batch("Wildflowers", flower, flowers, city_generator, attempt)
	if city_generator and not city_generator.generation_is_current(attempt):
		return

	# Low-poly street lamp model
	if not street_lamps.is_empty():
		var lamp_mesh := BoxMesh.new()
		lamp_mesh.size = Vector3(0.2, 4.2, 0.2)
		lamp_mesh.material = Materials.town_atlas(false, 5, true)
		await _batch("StreetLamps", lamp_mesh, street_lamps, city_generator, attempt)

func _pine_mesh(material: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	for i in 3:
		var tier := CylinderMesh.new()
		tier.bottom_radius = 2.6 - i * 0.6
		tier.top_radius = 0.0
		tier.height = 3.0
		tier.radial_segments = 6
		tier.rings = 0
		st.append_from(tier, 0, Transform3D(Basis.IDENTITY, Vector3(0, -1.5 + i * 1.5, 0)))
	var mesh := st.commit()
	mesh.surface_set_material(0, material)
	return mesh

func _clustered_crown(leaf: SphereMesh) -> ArrayMesh:
	var source := _faceted(leaf)
	var st := SurfaceTool.new()
	for offset in [Vector3(-0.85, -0.25, 0.1), Vector3(0.75, -0.2, 0.1), Vector3(0, 0.75, -0.4)]:
		st.append_from(source, 0, Transform3D(Basis.IDENTITY.scaled(Vector3(0.73, 0.78, 0.73)), offset))
	var mesh := st.commit()
	mesh.surface_set_material(0, leaf.material)
	return mesh

func _faceted(source: Mesh) -> ArrayMesh:
	var triangles := source.get_faces()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(source.surface_get_material(0))
	for i in range(0, triangles.size(), 3):
		var a := triangles[i]
		var b := triangles[i + 1]
		var c := triangles[i + 2]
		var normal := (b - a).cross(c - a).normalized()
		if normal.dot((a + b + c) / 3.0) < 0:
			normal = -normal
		st.set_normal(normal)
		st.set_color(Color.WHITE)
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(c)
	return st.commit()

func _knoll(center: Vector3, radius: float, height: float, rng: RandomNumberGenerator) -> void:
	var outer: Array[Vector3] = []
	var inner: Array[Vector3] = []
	var top := Vector3(0, height, 0)
	for i in range(8):
		var angle := float(i) * TAU / 8.0
		var direction := Vector3(cos(angle), 0, sin(angle))
		outer.append(direction * radius * rng.randf_range(0.88, 1.0))
		inner.append(direction * radius * 0.48 + Vector3.UP * height)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(8):
		var j := (i + 1) % 8
		_triangle(st, top, inner[j], inner[i])
		_triangle(st, inner[i], inner[j], outer[j])
		_triangle(st, inner[i], outer[j], outer[i])
	var mesh := st.commit()
	mesh.surface_set_material(0, Materials.terrain())
	var body := StaticBody3D.new()
	body.name = "MeadowKnoll"
	body.position = center
	body.collision_layer = 2
	body.collision_mask = 0
	var knoll_mesh := MeshInstance3D.new()
	knoll_mesh.mesh = mesh
	knoll_mesh.visibility_range_end = 260.0
	knoll_mesh.visibility_range_end_margin = 35.0
	knoll_mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	body.add_child(knoll_mesh)
	var collision := CollisionShape3D.new()
	collision.shape = mesh.create_trimesh_shape()
	body.add_child(collision)
	add_child(body)

func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	st.set_normal(normal)
	for point in [a, c, b]:
		st.add_vertex(point)

func _pond(center: Vector3, radius: float) -> void:
	var rim := MeshInstance3D.new()
	rim.name = "PondBank"
	var bank := CylinderMesh.new()
	bank.top_radius = radius + 0.7
	bank.bottom_radius = radius + 0.9
	bank.height = 0.10
	bank.radial_segments = 9
	bank.material = Materials.surface(Color("baad7b"))
	rim.mesh = bank
	rim.position = center + Vector3.UP * 0.1
	add_child(rim)
	var water := MeshInstance3D.new()
	water.name = "MeadowPond"
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.04
	mesh.radial_segments = 9
	var material := ShaderMaterial.new()
	material.shader = WATER
	mesh.material = material
	water.mesh = mesh
	water.position = center + Vector3.UP * 0.18
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)

func _batch(label: String, mesh: Mesh, transforms: Array[Transform3D], city_generator: Node = null, attempt: int = -1) -> void:
	var group := Node3D.new()
	group.name = label
	add_child(group)
	var sectors: Dictionary = {}
	for instance_transform in transforms:
		var cell := Vector2i(floori(instance_transform.origin.x / 76.0), floori(instance_transform.origin.z / 76.0))
		if not sectors.has(cell):
			sectors[cell] = []
		sectors[cell].append(instance_transform)
	for cell in sectors:
		if city_generator and attempt >= 0:
			if not await city_generator._check_frame_budget(attempt):
				return
		var center := Vector3((cell.x + 0.5) * 76, 0, (cell.y + 0.5) * 76)
		var instance := MultiMeshInstance3D.new()
		instance.name = "Sector_%d_%d" % [cell.x, cell.y]
		instance.position = center
		instance.visibility_range_end = 260.0
		instance.visibility_range_end_margin = 35.0
		instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		if label in ["Stones", "GrassTufts", "Wildflowers"]:
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = mesh
		var local_transforms: Array = sectors[cell]
		batch.instance_count = local_transforms.size()
		for i in local_transforms.size():
			var local_transform: Transform3D = local_transforms[i]
			local_transform.origin -= center
			batch.set_instance_transform(i, local_transform)
		instance.multimesh = batch
		group.add_child(instance)
