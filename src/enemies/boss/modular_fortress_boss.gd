extends "res://src/enemies/boss/heavy_gunship_boss.gd"
## Two distinct multi-phase encounters, using the existing director's combat contracts.
var fortress_kind := "ground"
var boss_title := "GROUND FORTRESS / MEGA CRAWLER"
var components: Dictionary = {}
var status_label: Label3D
var summon_timer := 8.0
var summon_cycle := 0
var ground_route := PackedVector3Array()
var route_timer := 0.0
var pulse := 0.0
var blister_turrets: Array[Node3D] = []
var blister_index := 0
var launch_warning := 0.0

func _setup_boss_stats() -> void:
	if not damage_receiver:
		damage_receiver = preload("res://src/enemies/boss/boss_core_receiver.gd").new()
		damage_receiver.name = "DamageReceiver"
		add_child(damage_receiver)
	super._setup_boss_stats()

func core_exposed() -> bool:
	return _engine_count() == 0 if fortress_kind == "air" else not components.has("main_battery") and not components.has("radar")

func _ready() -> void:
	name = "MegaCrawler" if fortress_kind == "ground" else "AirborneTitan"
	boss_title = "GROUND FORTRESS / MEGA CRAWLER" if fortress_kind == "ground" else "AIRBORNE CARRIER / TITAN"
	var visuals := Node3D.new()
	visuals.name = "Visuals"
	add_child(visuals)
	var ground := fortress_kind == "ground"
	_box(visuals, Vector3(7, 3, 13) if ground else Vector3(9, 3, 18), Vector3(0, 2, 0), Color("455461"))
	_box(visuals, Vector3(5, 1.4, 6), Vector3(0, 4, -1), Color("b49c66"))
	var pivot := Node3D.new()
	pivot.name = "TurretPivot"
	pivot.position = Vector3(0, 5, -4)
	add_child(pivot)
	# The inherited @onready lookup ran before this code-built rig existed.
	turret_pivot = pivot
	_box(pivot, Vector3(0.7, 0.7, 6), Vector3(0, 0, -2), Color("252e38"))
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(7, 4, 13) if ground else Vector3(9, 4, 18)
	collision.shape = shape
	collision.position.y = 2
	add_child(collision)
	if ground:
		_component("left_tread", Vector3(-4.3, 1.3, 0), Vector3(2, 2.6, 13), 100, Color("33383b"))
		_component("right_tread", Vector3(4.3, 1.3, 0), Vector3(2, 2.6, 13), 100, Color("33383b"))
		_component("main_battery", Vector3(0, 5, -3), Vector3(3.2, 2, 4), 110, Color("c6ae77"))
		_component("radar", Vector3(0, 6.2, 4), Vector3(3.2, 2.5, 0.7), 70, Color("66c8c4"))
		_component("missile_blisters", Vector3(0, 4.6, 4), Vector3(5.4, 1.5, 3), 90, Color("a57456"))
		for side in [-1, 1]:
			var pod := Node3D.new()
			pod.position = Vector3(side * 1.5, 0.8, 0)
			components["missile_blisters"].add_child(pod)
			_box(pod, Vector3(0.8, 0.8, 3), Vector3(0, 0, -0.8), Color("4d6265"))
			blister_turrets.append(pod)
	else:
		for side in [-1, 1]:
			_box(visuals, Vector3(9, 0.6, 7), Vector3(side * 7, 2.2, 0), Color("5c7183"))
			for z in [-5, 5]:
				_component("engine_%s_%s" % [side, z], Vector3(side * 8, 1.5, z), Vector3(3, 3, 5), 100, Color("63c6d4"))
		_component("launch_bay", Vector3(0, 0, -5), Vector3(6, 2.5, 5), 130, Color("b58d5e"))
	status_label = Label3D.new()
	status_label.position.y = 10
	status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	status_label.font_size = 30
	status_label.outline_size = 8
	status_label.pixel_size = 0.025
	add_child(status_label)
	super._ready()
	damage_receiver.max_health = 650.0 if ground else 700.0
	damage_receiver.current_health = damage_receiver.max_health
	damage_receiver.armor_mitigation = 0.24
	move_speed = 5.0 if ground else 16.0
	_update_status()

func _box(parent: Node3D, dimensions: Vector3, offset: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	mesh.mesh = box
	mesh.position = offset
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	mesh.material_override = material
	parent.add_child(mesh)

func _component(id: String, offset: Vector3, dimensions: Vector3, hp: float, color: Color) -> void:
	var actor := StaticBody3D.new()
	actor.name = id
	actor.collision_layer = 4
	actor.collision_mask = 0
	actor.position = offset
	add_child(actor)
	add_collision_exception_with(actor)
	actor.add_to_group("hostile_mission_targets")
	_box(actor, dimensions, Vector3.ZERO, color)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collider.shape = shape
	actor.add_child(collider)
	var receiver = preload("res://src/enemies/boss/boss_component_receiver.gd").new()
	receiver.name = "DamageReceiver"
	receiver.max_health = hp
	actor.add_child(receiver)
	receiver.destroyed.connect(_component_destroyed.bind(id))
	components[id] = actor

func _component_destroyed(_data: RefCounted, id: String) -> void:
	if not components.has(id): return
	var actor: Node3D = components[id]
	if has_node("/root/FXManager"):
		get_node("/root/FXManager").play_destruction(actor, actor.global_position, Vector3.UP, false, "heavy")
	actor.remove_from_group("hostile_mission_targets")
	actor.hide()
	actor.set_deferred("collision_layer", 0)
	components.erase(id)
	# Exposed subsystems remove core integrity but never create extra reward events.
	if damage_receiver and not damage_receiver.is_dead:
		damage_receiver.component_transfer = true
		damage_receiver.take_damage(DamageDataClass.new(55.0, GameConstants.WeaponType.ROCKET, target_player, true, 0.0))
		damage_receiver.component_transfer = false
	_update_status()

func _update_status() -> void:
	if status_label and damage_receiver:
		status_label.text = "CORE EXPOSED" if core_exposed() else "%d SUBSYSTEMS" % components.size()

func _on_damaged(amount: float, remaining_hp: float, data: RefCounted) -> void:
	super._on_damaged(amount, remaining_hp, data)
	if components.is_empty():
		current_stage = BossStage.FINAL
	elif components.size() <= 2 and current_stage == BossStage.OPENING:
		current_stage = BossStage.ESCALATION

func _process(delta: float) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if get_tree().paused or (gm and gm.current_state != gm.RunState.ACTIVE): return
	if not damage_receiver or damage_receiver.is_dead: return
	if not is_instance_valid(target_player):
		_find_player()
		return
	pulse += delta
	if fortress_kind == "air":
		var saved_speed := move_speed
		move_speed = 7.0 + float(_engine_count()) * 2.0
		super._process(delta)
		move_speed = saved_speed
		summon_timer -= delta
		if launch_warning > 0.0:
			launch_warning -= delta
			if launch_warning <= 0.0 and components.has("launch_bay"): _summon_escort()
		elif summon_timer <= 0.0 and components.has("launch_bay"):
			summon_timer = 14.0 if current_stage == BossStage.OPENING else 10.0
			launch_warning = 1.5
			get_node("/root/EventBus").threat_warning.emit(global_position, "CARRIER LAUNCH BAY", 1.5)
	else:
		_ground_tick(delta)
	_update_status()

func _engine_count() -> int:
	var count := 0
	for id in components:
		if str(id).begins_with("engine_"): count += 1
	return count

func _ground_tick(delta: float) -> void:
	route_timer -= delta
	if route_timer <= 0.0:
		route_timer = 2.0
		ground_route = UrbanPathfinder.find_street_path(global_position, target_player.global_position)
	var tread_count := int(components.has("left_tread")) + int(components.has("right_tread"))
	var direction := Vector3.ZERO
	if not ground_route.is_empty():
		direction = ground_route[0] - global_position
		direction.y = 0
		if direction.length() < 5: ground_route.remove_at(0)
	velocity = direction.normalized() * float(tread_count) * 2.0
	velocity.y = -4.0
	move_and_slide()
	if direction.length_squared() > 1:
		rotation.y = rotate_toward(rotation.y, atan2(-direction.x, -direction.z), delta * 0.5)
	var lead := _predict_lead_point(turret_pivot.global_position, target_player, 85.0)
	if components.has("main_battery"): turret_pivot.look_at(lead, Vector3.UP)
	if components.has("missile_blisters"):
		for pod in blister_turrets: pod.look_at(target_player.global_position, Vector3.UP)
	if is_telegraphing:
		telegraph_timer -= delta
		if telegraph_timer <= 0.0:
			is_telegraphing = false
			_launch_telegraphed_volley(lead)
		return
	volley_timer -= delta
	if volley_timer <= 0.0:
		var director = get_node_or_null("/root/CombatDirector")
		if director and not director.request_heavy_attack_slot(self):
			volley_timer = 0.3
			return
		volley_timer = 4.0 if current_stage == BossStage.OPENING else 3.2
		_begin_telegraph(3 if components.has("main_battery") else 1, 85.0)
		# Persistent world warning also covers a large chassis partially behind scenery.
		get_node("/root/EventBus").threat_warning.emit(global_position, "FORTRESS BATTERY", telegraph_timer)

func _fire_spread_volley(count: int, speed: float, aim: Vector3) -> void:
	if fortress_kind == "ground" and not components.has("main_battery") and not components.has("missile_blisters"):
		return
	# Removing radar disables predictive aim. Missing engines reduce carrier output.
	var shot_count := count
	if fortress_kind == "air": shot_count = maxi(2, count - (4 - _engine_count()))
	var point := target_player.global_position if fortress_kind == "ground" and not components.has("radar") else aim
	if fortress_kind == "air" or components.has("main_battery"):
		super._fire_spread_volley(shot_count, speed, point)
	if fortress_kind == "ground" and components.has("missile_blisters"):
		var pod := blister_turrets[blister_index % blister_turrets.size()]
		blister_index += 1
		var projectile = ProjectileScene.instantiate()
		get_parent().add_child(projectile)
		projectile.global_position = pod.to_global(Vector3(0, 0, -2.5))
		projectile.velocity = (point - projectile.global_position).normalized() * 55.0
		projectile.speed = 55.0
		projectile.is_homing = true
		projectile.homing_turn_rate = 1.2
		projectile.collision_mask = 3
		projectile.setup(DamageDataClass.new(6.0, GameConstants.WeaponType.MISSILE, self, false, 2.0), target_player, "enemy_sam")

func _summon_escort() -> void:
	if fortress_kind != "air" or not components.has("launch_bay"): return
	var director = get_node_or_null("/root/CombatDirector")
	if not director or not director.catalog: return
	var spawner = director._find_enemy_spawner()
	if not spawner: return
	# Purchase through the same budgets, caps, gates, placement and refund transaction as normal waves.
	var desired := "interceptor" if summon_cycle % 2 else "kamikaze_drone"
	summon_cycle += 1
	for card in director.catalog.get_all_cards():
		if card.variant_id == desired and card.group_size <= 2:
			for stream in ["fast", "slow"]:
				if card.is_eligible(director.current_wave, director.active_theme, stream):
					if not spawner.spawn_director_card(card, stream, self).is_empty(): return

func escort_launch_position(index: int) -> Vector3:
	if fortress_kind != "air" or not components.has("launch_bay"): return Vector3.INF
	return to_global(Vector3((-2.0 if index % 2 else 2.0), -2.0, -16.0 - float(index) * 9.0))
