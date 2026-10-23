class_name LootManager
extends Node

## LootManager â€” Listens to global combat events and spawns collectible pickups
## with magnet attraction, roll chances, and visual meshes (Page 17 & 18).

const PickupClass = preload("res://src/loot/pickup.gd")
const XpDropClass = preload("res://src/loot/xp_drop.gd")

func _ready() -> void:
	if has_node("/root/EventBus"):
		var eb = get_node("/root/EventBus")
		eb.entity_destroyed.connect(_on_entity_destroyed)

func _on_entity_destroyed(enemy_node: Node, _killer_weapon: String, _score_val: int, _xp_val: int) -> void:
	if not is_instance_valid(enemy_node) or not is_inside_tree():
		return

	var spawn_pos = enemy_node.global_position
	if not enemy_node.is_in_group("enemies"):
		return

	spawn_pickup(PickupClass.PickupType.COIN, spawn_pos, 5.0)

	# Calibrated XP Gem drop based on enemy tier (authentic spec values)
	var gem_xp: float = 2.0
	if "variant_id" in enemy_node:
		var var_id = enemy_node.variant_id
		var spec = EnemyData.VARIANTS.get(var_id, {})
		var raw_xp = float(spec.get("xp", 2))
		gem_xp = clampf(raw_xp, 2.0, 10.0)
	elif enemy_node.get("is_boss") == true:
		gem_xp = 12.0
	elif _xp_val > 0:
		gem_xp = float(_xp_val)

	# Spawn XpDrop entity with planar magnet attraction
	var xp_drop = spawn_xp_drop(spawn_pos, int(gem_xp))

	# Combat Envelope Immediate Magnetization:
	# If player engaged and destroyed enemy within combat envelope (<= 140m horizontal, <= 50m altitude),
	# immediately attract the dropped XP gem without stranding it in the distance
	var player = get_tree().get_first_node_in_group("player") as Node3D
	if player and is_instance_valid(player) and xp_drop:
		var to_p = player.global_position - spawn_pos
		var horiz_d = Vector2(to_p.x, to_p.z).length()
		var vert_d = absf(to_p.y)
		if horiz_d <= 140.0 and vert_d <= 50.0:
			xp_drop.start_attraction(player)

	# Roll for tactical supplies
	var roll = randf()
	if roll < 0.10:
		spawn_pickup(PickupClass.PickupType.SALVAGE, spawn_pos, 1.0)
	elif roll < 0.17:
		spawn_pickup(PickupClass.PickupType.FUEL, spawn_pos, 35.0)
	elif roll < 0.24:
		spawn_pickup(PickupClass.PickupType.AMMO_PACK, spawn_pos, 0.0)
	elif roll < 0.30:
		spawn_pickup(PickupClass.PickupType.FIELD_REPAIR, spawn_pos, 35.0)
	elif roll < 0.35:
		spawn_pickup(PickupClass.PickupType.COUNTERMEASURE, spawn_pos, 1.0)
	elif roll < 0.38:
		# Rare combat booster
		var rare_roll = randi() % 4
		match rare_roll:
			0: spawn_pickup(PickupClass.PickupType.SHIELD, spawn_pos, 8.0)
			1: spawn_pickup(PickupClass.PickupType.OVERDRIVE, spawn_pos, 8.0)
			2: spawn_pickup(PickupClass.PickupType.SPEED_BOOST, spawn_pos, 6.0)
			3: spawn_pickup(PickupClass.PickupType.BOMB, spawn_pos, 1.0)

func spawn_xp_drop(pos: Vector3, xp_amount: int = 10) -> Node3D:
	var xp_scene = load("res://scenes/loot/xp_drop.tscn")
	var drop: Node3D = null
	if xp_scene:
		drop = xp_scene.instantiate()
	else:
		drop = XpDropClass.new()
	drop.xp_amount = xp_amount
	var target_pos = pos + Vector3(randf_range(-0.5, 0.5), 0.5, randf_range(-0.5, 0.5))
	if get_parent():
		drop.position = get_parent().to_local(target_pos) if get_parent() is Node3D else target_pos
		get_parent().add_child(drop)
	elif get_tree() and get_tree().root:
		drop.position = target_pos
		get_tree().root.add_child(drop)
	return drop

func spawn_pickup(p_type: int, pos: Vector3, val: float = 0.0) -> Node3D:
	# Merge high-density XP gems if scene already contains multiple active pickups
	if p_type == PickupClass.PickupType.XP_GEM and is_inside_tree():
		var existing = get_tree().get_nodes_in_group("pickups")
		if existing.size() > 32:
			for item in existing:
				if is_instance_valid(item) and item.get("pickup_type") == PickupClass.PickupType.XP_GEM and not item.get("is_collected"):
					if item.global_position.distance_to(pos) <= 6.0:
						item.pickup_value += val
						return item

	var p = Area3D.new()
	p.set_script(PickupClass)
	p.pickup_type = p_type
	p.pickup_value = val

	# Collision Shape
	var col = CollisionShape3D.new()
	var s = SphereShape3D.new()
	s.radius = 2.2
	col.shape = s
	p.add_child(col)

	# 3D Mesh & Visual Glow
	var m_inst = MeshInstance3D.new()
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true

	match p_type:
		PickupClass.PickupType.COIN:
			var coin := CylinderMesh.new()
			coin.height = 0.2
			coin.top_radius = 0.6
			coin.bottom_radius = 0.6
			coin.radial_segments = 12
			mat.albedo_color = Color("ffd447")
			mat.emission = Color("b98a21")
			m_inst.mesh = coin
			m_inst.rotation.z = PI * 0.5
		PickupClass.PickupType.XP_GEM:
			var m = PrismMesh.new()
			m.size = Vector3(0.9, 1.1, 0.9)
			mat.albedo_color = Color(0.2, 0.8, 1.0)
			mat.emission = Color(0.1, 0.5, 0.9)
			m_inst.mesh = m
		PickupClass.PickupType.FIELD_REPAIR:
			var m = BoxMesh.new()
			m.size = Vector3(1.2, 0.8, 1.2)
			mat.albedo_color = Color(0.1, 0.9, 0.2)
			mat.emission = Color(0.1, 0.8, 0.1)
			m_inst.mesh = m
		PickupClass.PickupType.FUEL:
			var m = CylinderMesh.new()
			m.height = 1.2
			m.top_radius = 0.5
			m.bottom_radius = 0.5
			mat.albedo_color = Color(1.0, 0.8, 0.1)
			mat.emission = Color(0.9, 0.7, 0.0)
			m_inst.mesh = m
		PickupClass.PickupType.AMMO_PACK:
			var m = BoxMesh.new()
			m.size = Vector3(1.0, 0.6, 1.4)
			mat.albedo_color = Color(0.9, 0.5, 0.1)
			mat.emission = Color(0.8, 0.4, 0.0)
			m_inst.mesh = m
		PickupClass.PickupType.SALVAGE:
			var m = BoxMesh.new()
			m.size = Vector3(0.8, 0.8, 0.8)
			mat.albedo_color = Color(0.8, 0.8, 0.3)
			mat.emission = Color(0.7, 0.7, 0.2)
			m_inst.mesh = m
		PickupClass.PickupType.BOMB:
			var m = SphereMesh.new()
			m.radius = 0.8
			m.height = 1.6
			mat.albedo_color = Color(0.9, 0.1, 0.1)
			mat.emission = Color(0.9, 0.1, 0.1)
			m_inst.mesh = m
		PickupClass.PickupType.SHIELD:
			var m = SphereMesh.new()
			m.radius = 0.75
			m.height = 1.5
			mat.albedo_color = Color(0.2, 0.7, 1.0)
			mat.emission = Color(0.1, 0.8, 1.0)
			m_inst.mesh = m
		PickupClass.PickupType.OVERDRIVE:
			var m = PrismMesh.new()
			m.size = Vector3(1.1, 1.3, 1.1)
			mat.albedo_color = Color(1.0, 0.1, 0.6)
			mat.emission = Color(1.0, 0.2, 0.8)
			m_inst.mesh = m
		PickupClass.PickupType.SPEED_BOOST:
			var m = CylinderMesh.new()
			m.height = 1.0
			m.top_radius = 0.6
			m.bottom_radius = 0.2
			mat.albedo_color = Color(1.0, 0.85, 0.15)
			mat.emission = Color(1.0, 0.9, 0.2)
			m_inst.mesh = m
		_:
			var m = SphereMesh.new()
			m.radius = 0.6
			m.height = 1.2
			mat.albedo_color = Color(0.7, 0.3, 1.0)
			mat.emission = Color(0.6, 0.2, 0.9)
			m_inst.mesh = m

	m_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m_inst.material_override = mat
	p.add_child(m_inst)
	if is_inside_tree() and has_node("/root/ShaderManager"):
		get_node("/root/ShaderManager").apply_selective_outline(p, 0.012, Color(0.12, 0.14, 0.16, 0.70))

	# Assign spawn altitude BEFORE adding to tree so _ready() captures correct idle baseline
	var target_pos = pos + Vector3(randf_range(-1.5, 1.5), 0.5, randf_range(-1.5, 1.5))
	if get_parent() is Node3D:
		target_pos = get_parent().to_local(target_pos)
	p.position = target_pos
	if p.has_method("set_spawn_position"):
		p.set_spawn_position(target_pos)

	if get_parent():
		get_parent().add_child(p)
	elif get_tree() and get_tree().root:
		get_tree().root.add_child(p)
	return p
