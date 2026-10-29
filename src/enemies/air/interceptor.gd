class_name Interceptor
extends BaseEnemy

## Interceptor — High-speed supersonic attack fighter (Gate Wave 10).
## Executes high-velocity strafing passes across player airspace, telegraphs bursts, and peels away.

const ProjectileScene = preload("res://scenes/combat/projectile.tscn")
const DamageDataClass = preload("res://src/combat/damage_data.gd")
# The dedicated controller has shipped at 310; EnemyData's 280 is legacy metadata.
# Keep this live value authoritative during model integration (no balance change).
const PROJECTILE_SPEED: float = 310.0

var target_player: Node3D = null
var strafe_state: int = 0 # 0: Ingress, 1: Attack Run, 2: Egress Loop
var strafe_timer: float = 0.0
var gun_timer: float = 0.0
var strafe_vector: Vector3 = Vector3.ZERO

var windup_duration: float = 0.30
var aim_commit_ratio: float = 0.60
var cached_aim_point: Vector3 = Vector3.ZERO
var burst_shots_remaining: int = 0

func _ready() -> void:
	variant_id = "interceptor"
	is_air_unit = true
	super._ready()
	_find_player()
	strafe_state = 0
	set_behavior_state(BehaviorState.ENTER)

func _find_player() -> void:
	target_player = get_tree().get_first_node_in_group("player") as Node3D

func _on_pursuit_resumed() -> void:
	strafe_state = 0
	strafe_timer = 0.0
	burst_shots_remaining = 0

func on_attack_slot_expired(slot_type: String) -> void:
	if slot_type == "air":
		clear_telegraph()
		burst_shots_remaining = 0
		_release_all_slots()
		strafe_state = 2 # Force egress
		strafe_timer = 0.0
		set_behavior_state(BehaviorState.RECOVER)

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

	strafe_timer += delta
	var to_player = (target_player.global_position - global_position).normalized()
	var dist = global_position.distance_to(target_player.global_position)
	var lead_aim := get_predicted_target_position(get_air_weapon_origin(), target_player, PROJECTILE_SPEED, 0.95, deg_to_rad(1.0))
	cached_aim_point = lead_aim

	match strafe_state:
		0: # Ingress (Compute supersonic lead intercept vector)
			set_behavior_state(BehaviorState.PURSUE)
			not_firing_reason = REASON_OUT_OF_RANGE if dist > 65.0 else REASON_COOLDOWN
			var lead_target := get_predicted_target_position(global_position, target_player, move_speed * 1.35, 0.95, 0.0)
			var to_intercept := (lead_target - global_position).normalized()
			steer_air_unit(to_intercept * move_speed, 22.0, 52.0, delta)

			if dist < 65.0 or strafe_timer > 4.5:
				# Request air attack slot
				var director = get_node_or_null("/root/CombatDirector")
				var can_fire = true
				if director:
					can_fire = director.request_air_attack_slot(self)

				if can_fire:
					has_air_slot = true
					strafe_state = 1
					strafe_timer = 0.0
					strafe_vector = to_intercept
					set_behavior_state(BehaviorState.WINDUP)
					start_telegraph(windup_duration, aim_commit_ratio, Color(1.0, 0.3, 0.2, 0.8))
				else:
					not_firing_reason = REASON_WAITING_PERMISSION

		1: # High-Speed Attack Run
			steer_air_unit(strafe_vector * (move_speed * 1.35), 20.0, 55.0, delta)

			if behavior_state == BehaviorState.WINDUP:
				var windup_done = update_telegraph(get_air_weapon_origin(), cached_aim_point, delta)
				if windup_done:
					clear_telegraph()
					set_behavior_state(BehaviorState.FIRE)
					burst_shots_remaining = 6
					gun_timer = 0.0

			elif behavior_state == BehaviorState.FIRE:
				not_firing_reason = REASON_OK_FIRING
				gun_timer -= delta
				if gun_timer <= 0.0 and burst_shots_remaining > 0:
					gun_timer = 0.07
					burst_shots_remaining -= 1
					if check_muzzle_line_of_sight(get_air_weapon_origin(), target_player.global_position):
						_fire_interceptor_round()
					else:
						not_firing_reason = REASON_BLOCKED_SHOT

					if burst_shots_remaining <= 0:
						_release_all_slots()

			if dist > 70.0 and strafe_timer > 1.8:
				_release_all_slots()
				clear_telegraph()
				strafe_state = 2
				strafe_timer = 0.0
				set_behavior_state(BehaviorState.RECOVER)

		2: # Egress Loop (Chandelle turn and reset)
			set_behavior_state(BehaviorState.RECOVER)
			not_firing_reason = REASON_COOLDOWN
			var egress_dir = (-to_player * 0.6 + Vector3.UP * 0.8).normalized()
			steer_air_unit(egress_dir * (move_speed * 1.2), 26.0, 60.0, delta)

			if strafe_timer > 2.8 * combat_cooldown_multiplier:
				strafe_state = 0
				strafe_timer = 0.0
				set_behavior_state(BehaviorState.PURSUE)

func _fire_interceptor_round() -> void:
	if not is_inside_tree() or not target_player:
		return
	var fire_aim = committed_aim_point if aim_committed else cached_aim_point
	if not air_weapon_can_fire(fire_aim, true): return
	var muzzle_socket := get_air_weapon_socket()
	var p = ProjectileScene.instantiate()
	var p_data = DamageDataClass.new(9.0, GameConstants.WeaponType.MACHINE_GUN, self)
	var spawn_pos := get_air_weapon_origin()
	p.position = spawn_pos
	var parent_node: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
	if not parent_node:
		parent_node = get_tree().root
	parent_node.add_child(p)
	if p.is_inside_tree():
		p.global_position = spawn_pos
	var aim_dir = (fire_aim - spawn_pos).normalized()
	p.velocity = aim_dir * PROJECTILE_SPEED
	p.collision_mask = 3
	p.setup(p_data, null, "enemy_bullet")
	commit_air_shot()

	if has_node("/root/FXManager"):
		var up_vec = Vector3.UP if absf(aim_dir.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
		var muzzle_tf = Transform3D(Basis.looking_at(aim_dir, up_vec), spawn_pos)
		get_node("/root/FXManager").play_muzzle("enemy_bullet", muzzle_tf, muzzle_socket, aim_dir)
