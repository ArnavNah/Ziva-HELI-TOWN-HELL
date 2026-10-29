class_name AttackGunship
extends BaseEnemy

## AttackGunship — Implements the full aerial attack run sequence:
## Entry -> Approach -> Setup -> Attack Run -> Break Away -> Reposition.
## Requires air attack slot permission with telegraph before firing (Section 1 & 5).

const ProjectileScene = preload("res://scenes/combat/projectile.tscn")
const DamageDataClass = preload("res://src/combat/damage_data.gd")

var target_player: Node3D = null
var attack_fire_timer: float = 0.0
var attack_shots_fired: int = 0
const MAX_ATTACK_SHOTS: int = 6
var windup_in_progress: bool = false

func _ready() -> void:
	variant_id = "attack_gunship"
	super._ready()
	_find_player()
	current_state = EnemyState.APPROACH
	set_behavior_state(BehaviorState.PURSUE)

func _find_player() -> void:
	target_player = get_tree().get_first_node_in_group("player") as Node3D

var reposition_quadrant: float = 0.0

func _on_pursuit_resumed() -> void:
	windup_in_progress = false
	attack_shots_fired = 0

func on_attack_slot_expired(slot_type: String) -> void:
	super.on_attack_slot_expired(slot_type)
	windup_in_progress = false

func _custom_process(delta: float) -> void:
	if not target_player or not is_instance_valid(target_player):
		_find_player()
		if not target_player or not is_instance_valid(target_player):
			not_firing_reason = REASON_NO_TARGET
			clear_telegraph()
			return

	var dist = global_position.distance_to(target_player.global_position)
	var to_player = (target_player.global_position - global_position).normalized()
	var muzzle_pos := get_air_weapon_origin()

	match current_state:
		EnemyState.APPROACH:
			set_behavior_state(BehaviorState.PURSUE)
			not_firing_reason = REASON_OUT_OF_RANGE
			var target_altitude = clampf(target_player.global_position.y + 6.0, 20.0, 48.0)
			var approach_dir = -to_player
			if reposition_quadrant != 0.0:
				approach_dir = approach_dir.rotated(Vector3.UP, reposition_quadrant)
			var target_pos = target_player.global_position + approach_dir * 55.0
			target_pos.y = target_altitude

			var dir = (target_pos - global_position).normalized()
			steer_air_unit(dir * move_speed, 20.0, 52.0, delta)

			if dist < 65.0:
				current_state = EnemyState.SETUP
				set_behavior_state(BehaviorState.POSITION)
				state_timer = 0.0
				windup_in_progress = false

		EnemyState.SETUP:
			if not windup_in_progress:
				set_behavior_state(BehaviorState.POSITION)
			# Active combat hover with strafe weave while requesting attack slot
			var perp := Vector3(-to_player.z, 0.0, to_player.x) * (1.0 if int(get_instance_id()) % 2 == 0 else -1.0)
			var hover_vel := (perp * sin(state_timer * 2.8) * 8.0)
			hover_vel.y = (clampf(target_player.global_position.y + 4.0, 20.0, 48.0) - global_position.y) * 2.0
			steer_air_unit(hover_vel, 18.0, 52.0, delta, target_player.global_position)

			# Strict permission check: NO timeout bypass! Waiting enemies continue useful positioning (Section 1)
			var slot_granted = false
			if has_node("/root/CombatDirector"):
				var cd = get_node("/root/CombatDirector")
				if cd.request_air_attack_slot(self):
					has_air_slot = true
					slot_granted = true

			if not slot_granted and not has_air_slot:
				not_firing_reason = REASON_WAITING_PERMISSION
				return

			# Check 3D line of sight
			var aim_lead = get_predicted_target_position(muzzle_pos, target_player, 180.0, combat_lead_accuracy, combat_spread_rad)
			if not check_muzzle_line_of_sight(muzzle_pos, aim_lead):
				not_firing_reason = REASON_BLOCKED_SHOT
				return

			# Telegraph before committing attack run
			if not windup_in_progress:
				windup_in_progress = true
				set_behavior_state(BehaviorState.WINDUP)
				# SETUP owns the complete warning; WINDUP's legacy alias is ATTACK.
				current_state = EnemyState.SETUP
				start_telegraph(combat_windup_time, combat_aim_commit_ratio, Color("ef8b49"))

			var windup_done = update_telegraph(muzzle_pos, aim_lead, delta)
			if windup_done:
				clear_telegraph()
				current_state = EnemyState.ATTACK
				set_behavior_state(BehaviorState.FIRE)
				state_timer = 0.0
				attack_shots_fired = 0
				attack_fire_timer = 0.0
				windup_in_progress = false

		EnemyState.ATTACK:
			set_behavior_state(BehaviorState.FIRE)
			not_firing_reason = REASON_OK_FIRING
			var run_dir = to_player
			var player_facing = -target_player.global_transform.basis.z
			var to_gunship = -to_player

			# Evasive Jink: if player aims directly at this gunship, execute reactive lateral roll
			var jink_offset = Vector3.ZERO
			if player_facing.dot(to_gunship) > 0.85:
				var dodge_perp = Vector3(-to_player.z, 0.15, to_player.x).normalized()
				var jink_sign = 1.0 if int(get_instance_id()) % 2 == 0 else -1.0
				jink_offset = dodge_perp * jink_sign * 12.0

			var run_vel = (run_dir * (move_speed * 1.35) + jink_offset)
			steer_air_unit(run_vel, 18.0, 55.0, delta)

			attack_fire_timer -= delta
			if attack_fire_timer <= 0.0 and attack_shots_fired < MAX_ATTACK_SHOTS:
				attack_fire_timer = combat_burst_delay
				attack_shots_fired += 1
				var aim_point := get_predicted_target_position(muzzle_pos, target_player, 180.0, combat_lead_accuracy, combat_spread_rad)
				if check_muzzle_line_of_sight(muzzle_pos, aim_point):
					_fire_gun(aim_point)

			if attack_shots_fired >= MAX_ATTACK_SHOTS or dist < 18.0 or state_timer > 3.0:
				_release_all_slots()
				clear_telegraph()
				current_state = EnemyState.BREAK_AWAY
				set_behavior_state(BehaviorState.RECOVER)
				recover_timer = 0.0 # This aircraft times its own peel-away phase.
				state_timer = 0.0

		EnemyState.BREAK_AWAY:
			set_behavior_state(BehaviorState.RECOVER)
			not_firing_reason = REASON_COOLDOWN
			var peel_tangent = Vector3(-to_player.z, 0.0, to_player.x) * (1.0 if int(get_instance_id()) % 2 == 0 else -1.0)
			var peel_dir = (-to_player * 0.70 + peel_tangent * 0.85 + Vector3.UP * 0.45).normalized()
			steer_air_unit(peel_dir * (move_speed * 1.4), 22.0, 55.0, delta)

			if dist > 65.0 or state_timer > 2.5:
				set_behavior_state(BehaviorState.POSITION)
				current_state = EnemyState.REPOSITION
				state_timer = 0.0
				reposition_quadrant = randf_range(-PI * 0.6, PI * 0.6)

		EnemyState.REPOSITION:
			set_behavior_state(BehaviorState.POSITION)
			current_state = EnemyState.REPOSITION
			not_firing_reason = REASON_COOLDOWN
			var orbit_perp = Vector3(-to_player.z, 0.0, to_player.x).normalized()
			var repo_vel = (orbit_perp * (move_speed * 1.1) + (-to_player * 0.3)).normalized() * move_speed
			steer_air_unit(repo_vel, 22.0, 50.0, delta)

			if state_timer > 1.8 * combat_cooldown_multiplier:
				current_state = EnemyState.APPROACH
				set_behavior_state(BehaviorState.PURSUE)
				state_timer = 0.0

func _fire_gun(aim_point: Vector3) -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	if not target_player or not is_instance_valid(target_player):
		return
	if not air_weapon_can_fire(aim_point, true): return
	var muzzle_socket := get_air_weapon_socket()
	var muzzle_pos := get_air_weapon_origin()

	var p = ProjectileScene.instantiate()
	var p_data = DamageDataClass.new(8.0, GameConstants.WeaponType.MACHINE_GUN, self)
	p.position = muzzle_pos
	var parent_node: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
	if not parent_node:
		parent_node = get_tree().root
	parent_node.add_child(p)
	if p.is_inside_tree():
		p.global_position = muzzle_pos
	var aim_dir = (aim_point - muzzle_pos).normalized()
	p.velocity = aim_dir * 180.0
	p.collision_mask = 3
	p.setup(p_data, null, "enemy_bullet")
	commit_air_shot()

	if has_node("/root/FXManager"):
		var up_vec = Vector3.UP if absf(aim_dir.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
		var muzzle_tf = Transform3D(Basis.looking_at(aim_dir, up_vec), muzzle_pos)
		get_node("/root/FXManager").play_muzzle("enemy_bullet", muzzle_tf, muzzle_socket, aim_dir)
