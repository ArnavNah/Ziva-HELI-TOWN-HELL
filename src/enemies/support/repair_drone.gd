class_name RepairDrone
extends BaseEnemy

## RepairDrone — Restores health to damaged allies at up to 5% max HP/s (Page 9 & 10).
## Prioritizes the lowest % HP ally, establishes healing link, and repositions when target dies.

@export var heal_range: float = 28.0

func _ready() -> void:
	variant_id = "repair_drone"
	is_air_unit = true
	super._ready()
	behavior_state = BehaviorState.ENTER
	state_timer = 0.0

func _custom_process(delta: float) -> void:
	# Handle entry protection state
	if behavior_state == BehaviorState.ENTER:
		not_firing_reason = "ENTERING"
		if state_timer >= entry_grace_period:
			behavior_state = BehaviorState.PURSUE
			state_timer = 0.0

	_update_medic_flight(delta)
	_heal_nearby_ally(delta)

func _update_medic_flight(delta: float) -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var target_ally: Node3D = null
	var lowest_ratio: float = 1.0

	for e in enemies:
		if e != self and e is Node3D and is_instance_valid(e):
			var rec = e.get_node_or_null("DamageReceiver")
			if rec and not rec.is_dead:
				var ratio = rec.current_health / rec.max_health
				if ratio < lowest_ratio:
					lowest_ratio = ratio
					target_ally = e

	var target_pos: Vector3
	if target_ally:
		target_pos = target_ally.global_position + Vector3(0.0, 8.0, 0.0)
		var dist_to_ally = global_position.distance_to(target_ally.global_position)
		if dist_to_ally > heal_range:
			behavior_state = BehaviorState.PURSUE
			not_firing_reason = "OUT_OF_RANGE"
		else:
			behavior_state = BehaviorState.POSITION
			not_firing_reason = "OK_FIRING"
	else:
		behavior_state = BehaviorState.PURSUE
		not_firing_reason = "NO_TARGET"
		var p = get_tree().get_first_node_in_group("player") as Node3D
		if p and is_instance_valid(p):
			var to_p = (p.global_position - global_position).normalized()
			target_pos = p.global_position - to_p * 50.0
			target_pos.y = clampf(p.global_position.y + 8.0, 22.0, 48.0)
		else:
			target_pos = global_position

	var dir = (target_pos - global_position).normalized()
	steer_air_unit(dir * move_speed, 20.0, 48.0, delta)

func _heal_nearby_ally(delta: float) -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var best_target: Node = null
	var lowest_hp_ratio: float = 1.0

	for e in enemies:
		if e != self and e is Node3D and is_instance_valid(e):
			var dist = global_position.distance_to(e.global_position)
			if dist <= heal_range:
				var rec = e.get_node_or_null("DamageReceiver")
				if rec != null and not rec.is_dead:
					var ratio = rec.current_health / rec.max_health
					if ratio < lowest_hp_ratio:
						lowest_hp_ratio = ratio
						best_target = e

	if best_target != null:
		var target_rec = best_target.get_node("DamageReceiver")
		# 5% max hull per second
		var heal_amount = target_rec.max_health * 0.05 * delta
		target_rec.heal(heal_amount)
