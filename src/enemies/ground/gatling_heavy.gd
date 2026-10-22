class_name GatlingHeavy
extends BaseEnemy

## GatlingHeavy — Tracked rotary autocannon platform (Gate Wave 9).
## Employs sustained high-rate suppressive machine-gun bursts.
## Requires Heavy Attack Slot and features barrel spin-up telegraph (Section 1, 5 & 6).

const ProjectileScene = preload("res://scenes/combat/projectile.tscn")
const DamageDataClass = preload("res://src/combat/damage_data.gd")

var target_player: Node3D = null
var burst_timer: float = 2.0
var burst_shots_remaining: int = 0
var shot_timer: float = 0.0
var cached_aim_point: Vector3 = Vector3.ZERO
var rotary_barrels_node: Node3D = null
var current_barrel_spin_speed: float = 0.0
var target_barrel_spin_speed: float = 0.0

@onready var turret_node: Node3D = $Turret

func _ready() -> void:
	variant_id = "gatling_heavy"
	is_heavy_attacker = true
	super._ready()
	_find_player()
	if turret_node:
		rotary_barrels_node = turret_node.get_node_or_null("GunMount/RotaryBarrels")
		if not rotary_barrels_node:
			rotary_barrels_node = turret_node.get_node_or_null("GunPitch/Recoil/BarrelSpin")
	set_behavior_state(BehaviorState.PURSUE)

func _find_player() -> void:
	target_player = get_tree().get_first_node_in_group("player") as Node3D

func _custom_process(delta: float) -> void:
	if not rotary_barrels_node and turret_node:
		rotary_barrels_node = turret_node.get_node_or_null("GunMount/RotaryBarrels")
		if not rotary_barrels_node:
			rotary_barrels_node = turret_node.get_node_or_null("GunPitch/Recoil/BarrelSpin")

	# Update rotary gatling barrel spin animation based on weapon state
	match behavior_state:
		BehaviorState.WINDUP:
			target_barrel_spin_speed = 28.0
		BehaviorState.FIRE:
			target_barrel_spin_speed = 42.0
		_:
			target_barrel_spin_speed = 0.0

	if turret_node and turret_node.has_method("set_barrel_spin_speed"):
		turret_node.set_barrel_spin_speed(target_barrel_spin_speed)
	else:
		var spin_accel = 45.0 if target_barrel_spin_speed > current_barrel_spin_speed else 22.0
		current_barrel_spin_speed = move_toward(current_barrel_spin_speed, target_barrel_spin_speed, delta * spin_accel)
		if rotary_barrels_node and absf(current_barrel_spin_speed) > 0.01:
			rotary_barrels_node.rotate_z(current_barrel_spin_speed * delta)

	if not target_player or not is_instance_valid(target_player):
		_find_player()
		if not target_player or not is_instance_valid(target_player):
			not_firing_reason = REASON_NO_TARGET
			clear_telegraph()
			return

	var muzzle_pos: Vector3 = turret_node.get_muzzle_position() if (turret_node and turret_node.has_method("get_muzzle_position")) else ((turret_node.global_position if turret_node else global_position) + Vector3.UP * 1.4)
	cached_aim_point = get_predicted_target_position(muzzle_pos, target_player, combat_proj_speed, combat_lead_accuracy, combat_spread_rad)
	var is_aligned := true

	if turret_node:
		if turret_node.has_method("track_aim"):
			is_aligned = turret_node.track_aim(cached_aim_point, delta, 180.0, 24.0)
		else:
			is_aligned = track_turret(turret_node, cached_aim_point, delta, 180.0, 24.0)

	var dist_h = Vector2(global_position.x - target_player.global_position.x, global_position.z - target_player.global_position.z).length()

	# --- 1. BEHAVIOR STATE & HYSTERESIS ---
	if behavior_state == BehaviorState.PURSUE:
		if dist_h <= max_engagement_range:
			set_behavior_state(BehaviorState.POSITION)
	elif behavior_state == BehaviorState.POSITION:
		if dist_h > max_engagement_range * 1.25 + 4.0:
			set_behavior_state(BehaviorState.PURSUE)

	# --- 2. TACTICAL STREET NAVIGATION ---
	var s_sign = 1.0 if sin(state_timer * 0.8) >= 0.0 else -1.0
	var preferred_dist = (min_engagement_range + max_engagement_range) * 0.5
	var move_dir = get_ground_nav_heading(target_player.global_position, delta, preferred_dist, s_sign)
	steer_ground_unit(move_dir, move_speed, delta)

	# --- 3. WINDUP & TELEGRAPH (Rotary Spin-up) ---
	if behavior_state == BehaviorState.WINDUP:
		var windup_done = update_telegraph(muzzle_pos, cached_aim_point, delta)
		if windup_done:
			var shot_clear = check_muzzle_line_of_sight(muzzle_pos, committed_aim_point)
			if not shot_clear:
				not_firing_reason = REASON_BLOCKED_SHOT
				clear_telegraph()
				_release_all_slots()
				set_behavior_state(BehaviorState.POSITION)
				burst_timer = 0.4
				return

			clear_telegraph()
			set_behavior_state(BehaviorState.FIRE)
			burst_shots_remaining = combat_burst_count
			shot_timer = 0.0
			_fire_gatling_bullet(committed_aim_point)
		return

	# --- 4. BURST FIRE HANDLING ---
	if behavior_state == BehaviorState.FIRE:
		if burst_shots_remaining > 1:
			shot_timer -= delta
			if shot_timer <= 0.0:
				shot_timer = combat_burst_delay
				burst_shots_remaining -= 1
				if check_muzzle_line_of_sight(muzzle_pos, cached_aim_point):
					_fire_gatling_bullet(cached_aim_point)
				else:
					burst_shots_remaining = 0
		else:
			burst_shots_remaining = 0
			_release_all_slots()
			burst_timer = combat_cooldown + randf_range(-0.3, 0.3)
			set_behavior_state(BehaviorState.RECOVER)
			recover_timer = 0.35
		return

	# --- 5. FIRING READINESS & PERMISSION CHECKS ---
	burst_timer -= delta
	if burst_timer > 0.0:
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
	start_telegraph(combat_windup_time, combat_aim_commit_ratio, Color("ffaa20"))

func _fire_gatling_bullet(aim_point: Vector3) -> void:
	if not is_inside_tree() or not target_player:
		return

	if turret_node and turret_node.has_method("play_recoil"):
		turret_node.play_recoil()

	var p = ProjectileScene.instantiate()
	var p_data = DamageDataClass.new(5.5, GameConstants.WeaponType.MACHINE_GUN, self)
	var spawn_pos: Vector3 = turret_node.get_muzzle_position() if (turret_node and turret_node.has_method("get_muzzle_position")) else ((turret_node.global_position if turret_node else global_position) + Vector3.UP * 1.4)
	p.position = spawn_pos
	var parent_node: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
	if not parent_node:
		parent_node = get_tree().root
	parent_node.add_child(p)
	if p.is_inside_tree():
		p.global_position = spawn_pos
	var aim_dir = (aim_point - spawn_pos).normalized()
	aim_dir += Vector3(randf_range(-0.035, 0.035), randf_range(-0.025, 0.025), randf_range(-0.035, 0.035))
	var final_dir = aim_dir.normalized()
	p.velocity = final_dir * combat_proj_speed
	p.collision_mask = 3
	p.setup(p_data, null, "enemy_gatling")

	if has_node("/root/FXManager"):
		var up_vec = Vector3.UP if absf(final_dir.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
		var muzzle_tf = Transform3D(Basis.looking_at(final_dir, up_vec), spawn_pos)
		get_node("/root/FXManager").play_muzzle("enemy_gatling", muzzle_tf, turret_node if turret_node else self, final_dir)
