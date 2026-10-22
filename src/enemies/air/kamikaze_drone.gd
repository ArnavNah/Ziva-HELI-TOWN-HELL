class_name KamikazeDrone
extends BaseEnemy

## KamikazeDrone — Fast, suicidal collision attack drone (Gate Wave 8).
## Stalks player, sounds collision alert, and commits to a high-speed explosive ram dive with readable telegraph.

const DamageDataClass = preload("res://src/combat/damage_data.gd")

var target_player: Node3D = null
var charge_direction: Vector3 = Vector3.ZERO
var charge_speed: float = 68.0
var windup_duration: float = 0.60
var aim_commit_ratio: float = 0.65
var cached_charge_point: Vector3 = Vector3.ZERO
var charge_timeout: float = 0.0

func _ready() -> void:
	variant_id = "kamikaze_drone"
	is_air_unit = true
	super._ready()
	_find_player()
	set_behavior_state(BehaviorState.ENTER)

func _find_player() -> void:
	target_player = get_tree().get_first_node_in_group("player") as Node3D

func _custom_process(delta: float) -> void:
	if not target_player or not is_instance_valid(target_player):
		_find_player()
		not_firing_reason = REASON_NO_TARGET
		set_behavior_state(BehaviorState.PURSUE)
		return

	# Handle entry protection state
	if behavior_state == BehaviorState.ENTER:
		not_firing_reason = REASON_ENTERING
		if state_timer >= entry_grace_period:
			set_behavior_state(BehaviorState.PURSUE)

	var dist = global_position.distance_to(target_player.global_position)
	var to_player = (target_player.global_position - global_position).normalized()
	var intercept_pt := get_predicted_target_position(global_position, target_player, charge_speed, 0.95, 0.0)
	cached_charge_point = intercept_pt

	match behavior_state:
		BehaviorState.PURSUE:
			not_firing_reason = REASON_OUT_OF_RANGE
			steer_air_unit(to_player * move_speed, 18.0, 52.0, delta)
			if dist <= 55.0:
				set_behavior_state(BehaviorState.POSITION)

		BehaviorState.POSITION:
			# Flank/maneuver slightly before committing to dive
			var flank_perp = Vector3(-to_player.z, 0.0, to_player.x) * (1.0 if int(get_instance_id()) % 2 == 0 else -1.0)
			var desired_pos = target_player.global_position - to_player * 40.0 + flank_perp * 10.0
			desired_pos.y = clampf(target_player.global_position.y + 10.0, 22.0, 52.0)
			var move_dir = (desired_pos - global_position).normalized()
			steer_air_unit(move_dir * move_speed, 22.0, 52.0, delta)

			if dist > 65.0:
				set_behavior_state(BehaviorState.PURSUE)
				not_firing_reason = REASON_OUT_OF_RANGE
			elif not check_muzzle_line_of_sight(global_position, target_player.global_position):
				not_firing_reason = REASON_BLOCKED_SHOT
			else:
				# Begin telegraphed charge dive
				set_behavior_state(BehaviorState.WINDUP)
				start_telegraph(windup_duration, aim_commit_ratio, Color(1.0, 0.1, 0.1, 0.9))
				if has_node("/root/AudioManager"):
					get_node("/root/AudioManager").trigger_alarm("sam_lock")

		BehaviorState.WINDUP:
			# Hover / orient during windup
			var hover_pos = global_position + Vector3(0, 0.5 * delta, 0)
			steer_air_unit((hover_pos - global_position).normalized() * (move_speed * 0.4), 18.0, 55.0, delta)

			var windup_done = update_telegraph(global_position, cached_charge_point, delta)
			if windup_done:
				clear_telegraph()
				set_behavior_state(BehaviorState.FIRE)
				var dive_target = committed_aim_point if aim_committed else cached_charge_point
				charge_direction = (dive_target - global_position).normalized()
				charge_timeout = 2.5

		BehaviorState.FIRE:
			not_firing_reason = REASON_OK_FIRING
			charge_timeout -= delta
			# Committed straight ballistic charge along locked charge_direction (no continuous tracking, allowing dodge!)
			velocity = charge_direction * charge_speed
			if charge_direction.length_squared() > 0.01:
				look_at(global_position + charge_direction, Vector3.UP)
			move_and_slide()

			if dist <= 4.2 or is_on_wall() or is_on_floor() or charge_timeout <= 0.0:
				_detonate()

func _detonate() -> void:
	if not is_inside_tree():
		return
	# Area explosion damage with building cover occlusion
	if target_player and is_instance_valid(target_player):
		var dist = global_position.distance_to(target_player.global_position)
		if dist <= 12.0:
			var occluded = false
			var space_state = get_world_3d().direct_space_state
			if space_state:
				var occ_q = PhysicsRayQueryParameters3D.create(global_position, target_player.global_position, 2)
				var hit = space_state.intersect_ray(occ_q)
				if hit.size() > 0:
					occluded = true
			if not occluded:
				var dmg = 35.0 * (1.0 - (dist / 12.0) * 0.5)
				if target_player.has_method("take_damage"):
					target_player.take_damage(dmg, "Kamikaze Drone", global_position)
				elif target_player.has_node("DamageReceiver"):
					var d_rec = target_player.get_node("DamageReceiver")
					var payload = DamageDataClass.new(dmg, GameConstants.WeaponType.ROCKET, self, false, 12.0)
					d_rec.take_damage(payload)

	if damage_receiver:
		damage_receiver.take_damage(DamageDataClass.new(999.0, GameConstants.WeaponType.ROCKET, self))
