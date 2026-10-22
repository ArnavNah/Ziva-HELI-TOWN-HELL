class_name ShieldDrone
extends BaseEnemy

## ShieldDrone — Projects an energy shield barrier onto nearby allies (Page 9 & 10).
## Follows allies near the fight; repositions and reacquires if allies die.

@export var shield_radius: float = 22.0
@export var shield_bonus: float = 40.0

var shielded_allies: Array[Node] = []
var shield_update_timer := 0.0

func _ready() -> void:
	variant_id = "shield_drone"
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

	_update_escort_flight(delta)
	shield_update_timer -= delta
	if shield_update_timer <= 0:
		shield_update_timer = 0.12
		_update_shield_bubble()

func _update_escort_flight(delta: float) -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var target_anchor = Vector3.ZERO
	var ally_count = 0

	for e in enemies:
		if e != self and e is Node3D and is_instance_valid(e):
			var rec = e.get_node_or_null("DamageReceiver")
			if rec and not rec.is_dead:
				target_anchor += e.global_position
				ally_count += 1

	var target_pos = Vector3.ZERO
	if ally_count > 0:
		target_anchor /= float(ally_count)
		target_pos = target_anchor + Vector3(0.0, 10.0, 0.0)
		var dist_to_anchor = global_position.distance_to(target_pos)
		if dist_to_anchor > 15.0:
			behavior_state = BehaviorState.PURSUE
			not_firing_reason = "OUT_OF_RANGE"
		else:
			behavior_state = BehaviorState.POSITION
			not_firing_reason = "OK_FIRING"
	else:
		# No surviving allies to shield: shadow the player at standoff distance
		behavior_state = BehaviorState.PURSUE
		not_firing_reason = "NO_TARGET"
		var p = get_tree().get_first_node_in_group("player") as Node3D
		if p and is_instance_valid(p):
			var to_p = (p.global_position - global_position).normalized()
			target_pos = p.global_position - to_p * 45.0
			target_pos.y = clampf(p.global_position.y + 8.0, 22.0, 48.0)
		else:
			target_pos = global_position

	var dir = (target_pos - global_position).normalized()
	steer_air_unit(dir * move_speed, 20.0, 48.0, delta)

func _update_shield_bubble() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var current_valid_allies: Array[Node] = []

	for e in enemies:
		if e != self and e is Node3D and is_instance_valid(e):
			var rec = e.get_node_or_null("DamageReceiver")
			if rec != null and not rec.is_dead:
				var dist = global_position.distance_to(e.global_position)
				if dist <= shield_radius:
					current_valid_allies.append(e)
					if not shielded_allies.has(e):
						shielded_allies.append(e)
						rec.shield_health = maxf(rec.shield_health, shield_bonus)

	# Clean up allies that moved away or died
	var to_remove: Array[Node] = []
	for a in shielded_allies:
		if not is_instance_valid(a) or not current_valid_allies.has(a):
			to_remove.append(a)
			if is_instance_valid(a):
				var rec = a.get_node_or_null("DamageReceiver")
				if rec != null:
					rec.shield_health = 0.0

	for r in to_remove:
		shielded_allies.erase(r)

func _finalize_death() -> void:
	# Clear shield buffs on all allies when killed
	for a in shielded_allies:
		if is_instance_valid(a):
			var rec = a.get_node_or_null("DamageReceiver")
			if rec != null:
				rec.shield_health = 0.0
	shielded_allies.clear()
	super._finalize_death()
