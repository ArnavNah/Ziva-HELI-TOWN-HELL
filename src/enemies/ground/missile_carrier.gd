class_name MissileCarrier
extends BaseEnemy

## MissileCarrier — Armored mobile surface-to-air missile launcher (Gate Wave 5).
## Deploys long-range homing SAM missiles with lock-on warning telegraph (Section 1, 5 & 6).

const ProjectileScene = preload("res://scenes/combat/projectile.tscn")
const DamageDataClass = preload("res://src/combat/damage_data.gd")

var target_player: Node3D = null
var launch_timer: float = 2.0
var cached_aim_point: Vector3 = Vector3.ZERO

@onready var turret_node: Node3D = $Turret

func _ready() -> void:
	variant_id = "missile_carrier"
	is_heavy_attacker = true
	super._ready()
	_find_player()
	set_behavior_state(BehaviorState.PURSUE)

func _find_player() -> void:
	target_player = get_tree().get_first_node_in_group("player") as Node3D

func _custom_process(delta: float) -> void:
	if not target_player or not is_instance_valid(target_player):
		_find_player()
		if not target_player or not is_instance_valid(target_player):
			not_firing_reason = REASON_NO_TARGET
			clear_telegraph()
			return

	var muzzle_pos: Vector3 = (turret_node.global_position if turret_node else global_position) + Vector3.UP * 1.8
	cached_aim_point = get_predicted_target_position(muzzle_pos, target_player, combat_proj_speed, combat_lead_accuracy, combat_spread_rad)
	var is_aligned := true

	if turret_node:
		is_aligned = track_turret(turret_node, cached_aim_point, delta, 110.0, 26.0)

	var dist_h = Vector2(global_position.x - target_player.global_position.x, global_position.z - target_player.global_position.z).length()

	# --- 1. BEHAVIOR STATE & HYSTERESIS ---
	if behavior_state == BehaviorState.PURSUE:
		if dist_h <= max_engagement_range:
			set_behavior_state(BehaviorState.POSITION)
	elif behavior_state == BehaviorState.POSITION:
		if dist_h > max_engagement_range * 1.25 + 4.0:
			set_behavior_state(BehaviorState.PURSUE)

	# --- 2. TACTICAL STREET NAVIGATION ---
	var s_sign = 1.0 if sin(state_timer * 0.5) >= 0.0 else -1.0
	var preferred_dist = (min_engagement_range + max_engagement_range) * 0.5
	var move_dir = get_ground_nav_heading(target_player.global_position, delta, preferred_dist, s_sign)
	steer_ground_unit(move_dir, move_speed, delta)

	# --- 3. WINDUP & TELEGRAPH ---
	if behavior_state == BehaviorState.WINDUP:
		var windup_done = update_telegraph(muzzle_pos, cached_aim_point, delta)
		if windup_done:
			var shot_clear = check_muzzle_line_of_sight(muzzle_pos, committed_aim_point)
			if not shot_clear:
				not_firing_reason = REASON_BLOCKED_SHOT
				clear_telegraph()
				_release_all_slots()
				set_behavior_state(BehaviorState.POSITION)
				launch_timer = 0.4
				return

			clear_telegraph()
			set_behavior_state(BehaviorState.FIRE)
			_launch_homing_sam(committed_aim_point)
			_release_all_slots()
			launch_timer = combat_cooldown + randf_range(-0.4, 0.4)
			set_behavior_state(BehaviorState.RECOVER)
			recover_timer = 0.5
		return

	if behavior_state == BehaviorState.FIRE:
		return

	# --- 4. FIRING READINESS CHECKS ---
	launch_timer -= delta
	if launch_timer > 0.0:
		not_firing_reason = REASON_COOLDOWN
		return

	if behavior_state == BehaviorState.ENTER:
		not_firing_reason = REASON_ENTERING
		return

	var dist_3d = global_position.distance_to(target_player.global_position)
	if dist_3d > weapon_reach_3d:
		not_firing_reason = REASON_OUT_OF_RANGE
		return

	if not is_aligned:
		not_firing_reason = REASON_TURNING
		return

	var los_clear = check_muzzle_line_of_sight(muzzle_pos, cached_aim_point)
	if not los_clear:
		not_firing_reason = REASON_BLOCKED_SHOT
		return

	# Heavy slot permission
	var director := get_node_or_null("/root/CombatDirector")
	if director:
		if not director.request_heavy_attack_slot(self):
			not_firing_reason = REASON_WAITING_PERMISSION
			return
		has_heavy_slot = true

	not_firing_reason = REASON_OK_FIRING
	set_behavior_state(BehaviorState.WINDUP)
	start_telegraph(combat_windup_time, combat_aim_commit_ratio, Color("ff3300"))

	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").trigger_alarm("sam_lock")

func _launch_homing_sam(aim_point: Vector3) -> void:
	if not is_inside_tree() or not target_player:
		return

	var p = ProjectileScene.instantiate()
	var p_data = DamageDataClass.new(32.0, GameConstants.WeaponType.MISSILE, self, false, 8.0)
	var spawn_pos: Vector3 = (turret_node.global_position if turret_node else global_position) + Vector3.UP * 1.8
	p.position = spawn_pos
	var parent_node: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
	if not parent_node:
		parent_node = get_tree().root
	parent_node.add_child(p)
	if p.is_inside_tree():
		p.global_position = spawn_pos
	var launch_dir = (aim_point - spawn_pos).normalized()
	launch_dir = (launch_dir + Vector3(0.0, 0.35, 0.0)).normalized()
	p.velocity = launch_dir * combat_proj_speed
	p.is_homing = true
	p.homing_turn_rate = 3.8
	p.target_node = target_player
	p.collision_mask = 3
	p.blast_radius = 8.0
	p.setup(p_data, target_player, "enemy_sam")

	if has_node("/root/FXManager"):
		var up_vec = Vector3.UP if absf(launch_dir.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
		var muzzle_tf = Transform3D(Basis.looking_at(launch_dir, up_vec), spawn_pos)
		get_node("/root/FXManager").play_muzzle("enemy_sam", muzzle_tf, turret_node if turret_node else self, launch_dir)
