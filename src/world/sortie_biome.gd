extends RefCounted
## Collision-backed low-poly districts sharing the proven street navigation grid.
static func selected() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var gm := tree.root.get_node_or_null("GameManager") if tree else null
	return gm.selected_biome if gm else "town"

static func block(city: Node3D, origin: Vector3, ix: int, iz: int) -> void:
	if selected() == "desert":
		if (absi(ix) + absi(iz)) % 3 == 0:
			city._spawn_building(origin, 7.0, 16.0, 15.0, 260.0, "factory")
			city._spawn_volatile_tank(origin + Vector3(9, 0, 7))
		else:
			var mesa := StaticBody3D.new()
			mesa.name = "SandstoneMesa"
			mesa.collision_layer = 2
			mesa.collision_mask = 0
			mesa.position = origin
			city.add_child(mesa)
			city.spawned_blocks.append(mesa)
			city.building_footprints[origin] = Vector2(24, 24)
			var height := 12.0 + float(posmod(ix * 7 + iz * 11, 4)) * 4.0
			for tier in range(3):
				var radius := 12.0 - float(tier) * 1.6
				var mesh := CylinderMesh.new()
				mesh.radial_segments = 7
				mesh.top_radius = radius - 1.0
				mesh.bottom_radius = radius
				mesh.height = height / 3
				var instance := MeshInstance3D.new()
				instance.mesh = mesh
				instance.position.y = height / 3 * (float(tier) + 0.5)
				instance.material_override = material(Color("b88856") if tier % 2 else Color("cda572"))
				mesa.add_child(instance)
				var collision := CollisionShape3D.new()
				collision.shape = mesh.create_convex_shape()
				collision.position = instance.position
				mesa.add_child(collision)
	else:
		if ix < 2:
			city._spawn_building(origin, 8.5, 20.0, 16.0, 320.0, "factory")
			if posmod(ix + iz, 3) == 0: city._spawn_volatile_tank(origin + Vector3(9, 0, 8))
			return
		var dock := Node3D.new()
		dock.name = "HarborDock"
		dock.position = origin
		city.add_child(dock)
		city.spawned_blocks.append(dock)
		box(dock, Vector3(26, 0.15, 27), Vector3(0, 0.03, 0), Color("183943"))
		box(dock, Vector3(6, 0.7, 26), Vector3(-9, 0.45, 0), Color("6c7478"), true)
		# Dockside cargo vessel with raised bridge and stacked freight containers.
		box(dock, Vector3(10, 2.4, 23), Vector3(3, 1.4, 0), Color("314b62"), true)
		box(dock, Vector3(7, 3, 5), Vector3(3, 4.0, 7), Color("c0c4b8"), true)
		for z in [-6, 0]:
			box(dock, Vector3(7, 2.4, 5), Vector3(3, 3.7, z), Color("ab6c4c") if z else Color("468e8c"), true)
		# Crane mast, boom, cabin, and hanging hook, all inside the block footprint.
		box(dock, Vector3(1.3, 20, 1.3), Vector3(-9, 10, -7), Color("d3ad54"), true)
		box(dock, Vector3(18, 1.1, 1.1), Vector3(-1, 20, -7), Color("d3ad54"), true)
		box(dock, Vector3(2.6, 2, 2.6), Vector3(-9, 17, -7), Color("657d87"), true)
		box(dock, Vector3(0.1, 9, 0.1), Vector3(6, 15.5, -7), Color("333a3e"))
		box(dock, Vector3(1.1, 0.5, 1.1), Vector3(6, 11, -7), Color("d3ad54"))
		if posmod(iz, 3) == 0:
			var light := SpotLight3D.new()
			light.position = Vector3(-9, 19, -7)
			light.rotation_degrees.x = -65
			light.light_color = Color("b0d8ea")
			light.light_energy = 3.0
			light.spot_range = 65
			light.spot_angle = 25
			light.shadow_enabled = false
			dock.add_child(light)
			light.add_to_group("harbor_searchlights")

static func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.95
	return result

static func box(parent: Node3D, dimensions: Vector3, offset: Vector3, color: Color, solid: bool = false) -> void:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = offset
	instance.material_override = material(color)
	parent.add_child(instance)
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 2
		body.collision_mask = 0
		body.position = offset
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = dimensions
		collider.shape = shape
		body.add_child(collider)
		parent.add_child(body)
