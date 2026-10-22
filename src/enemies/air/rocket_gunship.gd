class_name RocketGunship
extends BaseEnemy

## RocketGunship — Heavy aerial fire-support gunship (Gate Wave 7).
## Requests Air + Heavy Attack Slots, hovers in standoff position, and fires volleys of explosive rockets.

const ProjectileScene = preload("res://scenes/combat/projectile.tscn")
const DamageDataClass = preload("res://src/combat/damage_data.gd")

var target_player: Node3D = null
var standoff_distance: float = 68.0
var salvo_timer: float = 3.5
var salvo_count: int = 0
var salvo_burst_delay: float = 0.0

var cached_lead_aim: Vector3 = Vector3.ZERO
var salvo_index: int = 0

# Windup and telegraph settings
var windup_duration: float = 0.70
var aim_commit_ratio: float = 0.65

func _ready() -> void:
	variant_id = "rocket_gunship"
	is_air_unit = true
	is_heavy_attacker = true
	super._ready()
	_find_player()
	set_behavior_state(BehaviorState.ENTER)

func _find_player() -> void:
	target_player = get_tree().get_first_node_in_group("player") as Node3D

func on_attack_slot_expired(slot_type: String) -> void:
	if slot_type == "heavy" or slot_type == "air":
		if behavior_state == BehaviorState.WINDUP or behavior_state == BehaviorState.FIRE:
			clear_telegraph()
			salvo_count = 0
			_release_all_slots()
			set_behavior_state(BehaviorState.RECOVER)
			salvo_timer = 2.0

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

	# Standoff positioning with tactical lateral strafing
	var flank_perp = Vector3(-to_player.z, 0.0, to_player.x) * (1.0 if int(get_instance_id()) % 2 == 0 else -1.0)
	var strafe_offset = flank_perp * (sin(state_timer * 1.4) * 16.0)
	var target_pos = target_player.global_position - to_player * standoff_distance + strafe_offset
	target_pos.y = clampf(target_player.global_position.y + 6.0, 22.0, 52.0)
	var move_dir = (target_pos - global_position).normalized()
	steer_air_unit(move_dir * move_speed, 22.0, 52.0, delta)

	# Aim point calculation with near-zero quadratic guard
	var lead_aim = get_predicted_target_position(global_position, target_player, 135.0, 0.92, 0.0)
	cached_lead_aim = lead_aim

	match behavior_state:
		BehaviorState.PURSUE:
			if dist <= 85.0:
				set_behavior_state(BehaviorState.POSITION)

		BehaviorState.POSITION:
			salvo_timer -= delta
			if salvo_timer > 0.0:
				not_firing_reason = REASON_COOLDOWN
			elif dist > 100.0:
				not_firing_reason = REASON_OUT_OF_RANGE
				set_behavior_state(BehaviorState.PURSUE)
			else:
				# Check 3D line of sight
				var muzzle_pos = global_position + Vector3(0.0, -0.5, 0.0)
				if not check_muzzle_line_of_sight(muzzle_pos, target_player.global_position):
					not_firing_reason = REASON_BLOCKED_SHOT
				else:
					# Request combined air and heavy attack slots atomically
					var director = get_node_or_null("/root/CombatDirector")
					var can_fire = true
					if director:
						can_fire = director.request_combined_attack_slots(self, true, true)

					if can_fire:
						has_air_slot = true
						has_heavy_slot = true
						set_behavior_state(BehaviorState.WINDUP)
						start_telegraph(windup_duration, aim_commit_ratio, Color(1.0, 0.25, 0.1, 0.85))
					else:
						not_firing_reason = REASON_WAITING_PERMISSION

		BehaviorState.WINDUP:
			var windup_done = update_telegraph(global_position, cached_lead_aim, delta)
			if windup_done:
				clear_telegraph()
				set_behavior_state(BehaviorState.FIRE)
				salvo_count = 3
				salvo_index = 0
				salvo_burst_delay = 0.0

		BehaviorState.FIRE:
			not_firing_reason = REASON_OK_FIRING
			salvo_burst_delay -= delta
			if salvo_burst_delay <= 0.0 and salvo_count > 0:
				salvo_burst_delay = 0.28
				salvo_count -= 1
				salvo_index += 1
				_fire_rocket(salvo_index)
				if salvo_count <= 0:
					_release_all_slots()
					set_behavior_state(BehaviorState.RECOVER)
					salvo_timer = 4.2 * combat_cooldown_multiplier + randf_range(-0.4, 0.4)

		BehaviorState.RECOVER:
			not_firing_reason = REASON_COOLDOWN
			if state_timer >= 1.0:
				set_behavior_state(BehaviorState.POSITION)

func _fire_rocket(shot_idx: int) -> void:
	if not is_inside_tree() or not target_player:
		return
	var p = ProjectileScene.instantiate()
	var p_data = DamageDataClass.new(24.0, GameConstants.WeaponType.ROCKET, self, false, 14.0)
	var spawn_pos = global_position + Vector3(randf_range(-1.2, 1.2), -0.5, 0.0)
	p.position = spawn_pos
	var parent_node: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
	if not parent_node:
		parent_node = get_tree().root
	parent_node.add_child(p)
	if p.is_inside_tree():
		p.global_position = spawn_pos
	
	# Bracket the player's path: -3 deg, 0 deg, +3 deg spread
	var to_player = (target_player.global_position - global_position).normalized()
	var perp = Vector3(-to_player.z, 0.0, to_player.x).normalized()
	var bracket_offset = Vector3.ZERO
	if shot_idx == 1:
		bracket_offset = -perp * 5.5
	elif shot_idx == 3:
		bracket_offset = perp * 5.5

	var fire_lead = committed_aim_point if aim_committed else cached_lead_aim
	var target_spot = fire_lead + bracket_offset
	var aim_dir = (target_spot - spawn_pos).normalized()
	p.velocity = aim_dir * 135.0
	p.blast_radius = 14.0
	p.collision_mask = 3
	p.setup(p_data, null, "enemy_rocket")

	if has_node("/root/FXManager"):
		var up_vec = Vector3.UP if absf(aim_dir.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
		var muzzle_tf = Transform3D(Basis.looking_at(aim_dir, up_vec), spawn_pos)
		get_node("/root/FXManager").play_muzzle("enemy_rocket", muzzle_tf, self, aim_dir)
