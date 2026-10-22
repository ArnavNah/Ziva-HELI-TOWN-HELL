class_name FlakTank
extends BaseEnemy

## FlakTank — Anti-air armored ground combat vehicle with independent rotating turret.
## Fires timed proximity flak bursts with clear visual telegraph and turret alignment.

const ProjectileScene = preload("res://scenes/combat/projectile.tscn")
const DamageDataClass = preload("res://src/combat/damage_data.gd")

var target_player: Node3D = null
var fire_timer: float = 1.0
var flak_burst_remaining: int = 0
var flak_burst_delay: float = 0.0
var cached_aim_point: Vector3 = Vector3.ZERO

@onready var turret_node: Node3D = $Turret

func _ready() -> void:
	variant_id = "flak_tank"
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

	var muzzle_pos: Vector3 = (turret_node.global_position if turret_node else global_position) + Vector3.UP * 1.5
	cached_aim_point = get_predicted_target_position(muzzle_pos, target_player, combat_proj_speed, combat_lead_accuracy, combat_spread_rad)
	var is_aligned := true

	# Turret independent fast AA tracking with elevation limits
	if turret_node:
		is_aligned = track_turret(turret_node, cached_aim_point, delta, 160.0, 22.0)

	var dist_h = Vector2(global_position.x - target_player.global_position.x, global_position.z - target_player.global_position.z).length()

	# --- 1. BEHAVIOR STATE & HYSTERESIS ---
	if behavior_state == BehaviorState.PURSUE:
		if dist_h <= max_engagement_range:
			set_behavior_state(BehaviorState.POSITION)
	elif behavior_state == BehaviorState.POSITION:
		if dist_h > max_engagement_range * 1.25 + 4.0:
			set_behavior_state(BehaviorState.PURSUE)

	# --- 2. TACTICAL STREET NAVIGATION ---
	var strafe_sign = 1.0 if sin(state_timer * 0.7) >= 0.0 else -1.0
	var preferred_dist = (min_engagement_range + max_engagement_range) * 0.5
	var move_dir = get_ground_nav_heading(target_player.global_position, delta, preferred_dist, strafe_sign)
	var spd_mult = 0.35 if behavior_state == BehaviorState.WINDUP else 1.0 # Creep stance while aiming
	steer_ground_unit(move_dir, move_speed * spd_mult, delta)

	# --- 3. WINDUP & TELEGRAPH ---
	if behavior_state == BehaviorState.WINDUP:
		var windup_done = update_telegraph(muzzle_pos, cached_aim_point, delta)
		if windup_done:
			var shot_clear = check_muzzle_line_of_sight(muzzle_pos, committed_aim_point)
			if not shot_clear:
				not_firing_reason = REASON_BLOCKED_SHOT
				clear_telegraph()
				set_behavior_state(BehaviorState.POSITION)
				fire_timer = 0.4
				return

			clear_telegraph()
			set_behavior_state(BehaviorState.FIRE)
			flak_burst_remaining = combat_burst_count
			flak_burst_delay = 0.0
			_fire_single_flak(committed_aim_point)
		return

	# --- 4. BURST FIRE HANDLING ---
	if behavior_state == BehaviorState.FIRE:
		if flak_burst_remaining > 1:
			flak_burst_delay -= delta
			if flak_burst_delay <= 0.0:
				flak_burst_delay = combat_burst_delay
				flak_burst_remaining -= 1
				# Re-evaluate line of sight on each flak round
				if check_muzzle_line_of_sight(muzzle_pos, cached_aim_point):
					_fire_single_flak(cached_aim_point)
				else:
					flak_burst_remaining = 0
		else:
			flak_burst_remaining = 0
			_release_all_slots()
			fire_timer = combat_cooldown + randf_range(-0.3, 0.3)
			set_behavior_state(BehaviorState.RECOVER)
			recover_timer = 0.4
		return

	# --- 5. FIRING READINESS CHECKS ---
	fire_timer -= delta
	if fire_timer > 0.0:
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

	# 3D Muzzle-to-player line of sight check (separate from road clearance)
	var los_clear = check_muzzle_line_of_sight(muzzle_pos, cached_aim_point)
	if not los_clear:
		not_firing_reason = REASON_BLOCKED_SHOT
		return

	# Start Flak telegraph (0.50s windup, aim freezes in final reaction window)
	not_firing_reason = REASON_OK_FIRING
	set_behavior_state(BehaviorState.WINDUP)
	start_telegraph(combat_windup_time, combat_aim_commit_ratio, Color("ef8b49"))

func _fire_single_flak(aim_point: Vector3) -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	if not target_player or not is_instance_valid(target_player):
		return

	var p = ProjectileScene.instantiate()
	var p_data = DamageDataClass.new(16.0, GameConstants.WeaponType.ROCKET, self, false, 8.0)
	var spawn_pos: Vector3 = turret_node.global_position if turret_node else global_position + Vector3.UP * 1.5
	p.position = spawn_pos
	var parent_node: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
	if not parent_node:
		parent_node = get_tree().root
	parent_node.add_child(p)
	if p.is_inside_tree():
		p.global_position = spawn_pos
	var aim_dir = (aim_point - spawn_pos).normalized()
	# Micro spread for flak burst coverage
	aim_dir += Vector3(randf_range(-0.03, 0.03), randf_range(-0.02, 0.02), randf_range(-0.03, 0.03))
	var final_dir = aim_dir.normalized()
	p.velocity = final_dir * combat_proj_speed
	p.blast_radius = 8.0
	p.collision_mask = 3
	p.setup(p_data, null, "enemy_flak")

	if has_node("/root/FXManager"):
		var up_vec = Vector3.UP if absf(final_dir.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
		var muzzle_tf = Transform3D(Basis.looking_at(final_dir, up_vec), spawn_pos)
		get_node("/root/FXManager").play_muzzle("enemy_flak", muzzle_tf, turret_node if turret_node else self, final_dir)
