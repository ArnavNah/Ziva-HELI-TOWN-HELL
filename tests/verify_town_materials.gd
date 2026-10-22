extends SceneTree
const Detail = preload("res://src/world/detail_mesh.gd")
const Materials = preload("res://src/world/stylized_materials.gd")
var checks := 0
var failed := 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failed += 1
	print("PASS: " if ok else "FAIL: ", message)

func run() -> void:
	var game = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	root.get_node("CombatDirector").stop_wave_director()
	game.get_node("PlayerHelicopter").set_physics_process(false)
	var representatives := {}
	for block in game.get_node("CityGenerator").spawned_blocks:
		if block is DestructibleBuilding and not representatives.has(block.archetype): representatives[block.archetype] = block
	check(representatives.size() >= 10, "All ten generated archetypes are covered")
	var intact_material = Materials.town_atlas()
	for arch in representatives:
		var building: DestructibleBuilding = representatives[arch]
		var arrays = building.mesh_instance.mesh.surface_get_arrays(0)
		var ids := {}
		for id: Vector2 in arrays[Mesh.ARRAY_TEX_UV2]: ids[int(id.x)] = true
		check(ids.has(Detail.Tile.ROOF) and ids.size() >= 3, arch + ": roof and facade material categories share one surface")
		check(arrays[Mesh.ARRAY_VERTEX].size() == arrays[Mesh.ARRAY_TEX_UV].size(), arch + ": every painted vertex has texture coordinates")
		check(building.mesh_instance.get_active_material(0) == intact_material, arch + ": immutable material is reused")
		var old_height: float = building.collision_shape.shape.size.y
		var affinity: float = GameConstants.DAMAGE_AFFINITY_MATRIX[GameConstants.WeaponType.ROCKET][GameConstants.TargetAffinity.STRUCTURE]
		building.damage_receiver.take_damage(DamageData.new(building.max_building_health * 0.65 / affinity, GameConstants.WeaponType.ROCKET))
		check(building.current_stage == 1 and building.collision_shape.shape.size.y == old_height, arch + ": damage threshold and structural collision are preserved")
		check(intact_material.get_shader_parameter("damage_amount") == 0.0, arch + ": damage does not stain unrelated buildings")
		building.damage_receiver.take_damage(DamageData.new(building.max_building_health * 2.0, GameConstants.WeaponType.ROCKET))
		var bounds: AABB = building.mesh_instance.mesh.get_aabb()
		check(building.current_stage == 2 and is_equal_approx(building.collision_shape.shape.size.y, 3.5) and bounds.end.y <= 3.5, arch + ": rubble and collision both fit the flight corridor")
		check(building.mesh_instance.mesh.get_surface_count() == 1, arch + ": collapsed rubble stays batched")
	check(Materials.town_texture.get_image().has_mipmaps(), "Painted atlas has generated mipmaps")
	check(load("res://assets/environment/textures/tile_helipad.png").get_image().has_mipmaps(), "Retained helipad texture has generated mipmaps")
	var density := Detail.new()
	density.box(Vector3.ONE * 8.0, Vector3.ZERO, Color.WHITE)
	check(is_equal_approx(density.uvs[1].x - density.uvs[0].x, 1.0), "An 8m face spans exactly one 128px tile")
	var shapes := Detail.new()
	shapes.gable_roof(Vector3(10, 3, 10), Vector3.ZERO, Color.WHITE)
	shapes.cylinder(2, 4, Vector3(20, 0, 0), Color.WHITE, 6, true, true)
	var correct_winding := true
	for i in range(0, shapes.indices.size(), 3):
		var a: int = shapes.indices[i]
		var b: int = shapes.indices[i + 1]
		var c: int = shapes.indices[i + 2]
		var cross: Vector3 = (shapes.vertices[b] - shapes.vertices[a]).cross(shapes.vertices[c] - shapes.vertices[a])
		correct_winding = correct_winding and cross.dot(shapes.normals[a]) < 0.0
	check(correct_winding, "Pitched roofs and cylinders face outward with Godot clockwise triangles")
	# A deliberately multi-surface object catches whole-mesh outline overrides.
	var multi := ArrayMesh.new()
	for tile in [Detail.Tile.BRICK, Detail.Tile.ROOF]:
		var detail := Detail.new()
		detail.box(Vector3.ONE * 8, Vector3(tile * 10, 0, 0), Color.WHITE)
		var mesh := detail.build(Materials.town_atlas(false, tile))
		multi.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(0))
		multi.surface_set_material(multi.get_surface_count() - 1, mesh.surface_get_material(0))
	var specimen := MeshInstance3D.new()
	specimen.mesh = multi
	game.add_child(specimen)
	root.get_node("ShaderManager").apply_selective_outline(specimen)
	check(specimen.material_override == null and specimen.get_active_material(0).get_shader_parameter("fixed_tile") != specimen.get_active_material(1).get_shader_parameter("fixed_tile"), "Outlines preserve distinct per-surface material assignments")
	check(multi.surface_get_material(0).next_pass == null, "Outlines do not mutate the shared source material")
	print("TOWN MATERIAL CHECKS: ", checks-failed, "/", checks)
	quit(1 if failed else 0)
