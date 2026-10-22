class_name Minelayer
extends BaseEnemy

## Minelayer — Strategic aerial hazard distributor (Gate Wave 11).
## Deploys hovering proximity mines that arm and explode when player draws near.

const DamageDataClass = preload("res://src/combat/damage_data.gd")

var target_player: Node3D = null
var drop_timer: float = 3.0
var drop_interval: float = 4.5

func _ready() -> void:
	variant_id = "minelayer"
	is_air_unit = true
	super._ready()
	drop_interval *= combat_cooldown_multiplier
	_find_player()
	behavior_state = BehaviorState.ENTER
	state_timer = 0.0

func _find_player() -> void:
	target_player = get_tree().get_first_node_in_group("player") as Node3D

func _custom_process(delta: float) -> void:
	if not target_player or not is_instance_valid(target_player):
		_find_player()
		not_firing_reason = "NO_TARGET"
		behavior_state = BehaviorState.PURSUE
		return

	# Handle entry protection state
	if behavior_state == BehaviorState.ENTER:
		not_firing_reason = "ENTERING"
		if state_timer >= entry_grace_period:
			behavior_state = BehaviorState.PURSUE
			state_timer = 0.0

	var dist = global_position.distance_to(target_player.global_position)
	var to_player = (target_player.global_position - global_position).normalized()
	# Perpendicular crossing flight
	var perp = Vector3(-to_player.z, 0.0, to_player.x).normalized()
	steer_air_unit(perp * move_speed, 20.0, 48.0, delta)

	match behavior_state:
		BehaviorState.PURSUE:
			not_firing_reason = "COOLDOWN"
			if dist <= 60.0:
				behavior_state = BehaviorState.POSITION
				state_timer = 0.0

		BehaviorState.POSITION:
			drop_timer -= delta
			if drop_timer <= 0.0:
				behavior_state = BehaviorState.FIRE
				state_timer = 0.0
			else:
				not_firing_reason = "COOLDOWN"

		BehaviorState.FIRE:
			not_firing_reason = "OK_FIRING"
			_drop_proximity_mine()
			drop_timer = drop_interval + randf_range(-0.5, 0.5)
			behavior_state = BehaviorState.RECOVER
			state_timer = 0.0

		BehaviorState.RECOVER:
			not_firing_reason = "COOLDOWN"
			if state_timer >= 1.0:
				behavior_state = BehaviorState.POSITION
				state_timer = 0.0

func _drop_proximity_mine() -> void:
	if not is_inside_tree():
		return
	var mine = ProximityMineNode.new()
	var parent_node = get_tree().current_scene if get_tree().current_scene else get_tree().root
	parent_node.add_child(mine)
	mine.global_position = global_position - Vector3(0, 1.5, 0)

class ProximityMineNode extends Area3D:
	var arm_timer: float = 1.5
	var is_armed: bool = false
	var lifetime: float = 25.0

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 1 # detect player
		var col = CollisionShape3D.new()
		var s = SphereShape3D.new()
		s.radius = 12.0
		col.shape = s
		add_child(col)

		var m_inst = MeshInstance3D.new()
		var m = SphereMesh.new()
		m.radius = 0.8
		m.height = 1.6
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.4, 0.1) # Glowing warning orange
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.2, 0.0)
		m.material = mat
		m_inst.mesh = m
		add_child(m_inst)

		body_entered.connect(_on_body_entered)

	func _process(delta: float) -> void:
		lifetime -= delta
		if lifetime <= 0.0:
			queue_free()
			return

		if not is_armed:
			arm_timer -= delta
			if arm_timer <= 0.0:
				is_armed = true

	func _on_body_entered(body: Node3D) -> void:
		if is_armed and body.is_in_group("player"):
			# Cover occlusion check before delivering explosion damage
			var occluded = false
			var space_state = get_world_3d().direct_space_state
			if space_state:
				var occ_q = PhysicsRayQueryParameters3D.create(global_position, body.global_position, 2)
				var hit = space_state.intersect_ray(occ_q)
				if hit.size() > 0:
					occluded = true
			if not occluded:
				if body.has_method("take_damage"):
					body.take_damage(30.0, "Proximity Mine", global_position)
				elif body.has_node("DamageReceiver"):
					var d_rec = body.get_node("DamageReceiver")
					var p_data = DamageDataClass.new(30.0, GameConstants.WeaponType.ROCKET, null, false, 12.0)
					d_rec.take_damage(p_data)
			queue_free()
