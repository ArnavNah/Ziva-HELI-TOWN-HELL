class_name InfantrySquad
extends BaseEnemy

## InfantrySquad — Ground infantry combat squad (Gate Wave 1).
## Disperses in urban terrain and fires small-arms rifle bursts with readable telegraphs.

const ProjectileScene = preload("res://scenes/combat/projectile.tscn")
const DamageDataClass = preload("res://src/combat/damage_data.gd")

var target_player: Node3D = null
var fire_timer: float = 1.0
var fire_interval: float = 2.4

var windup_duration: float = 0.35
var aim_commit_ratio: float = 0.65
var cached_aim_point: Vector3 = Vector3.ZERO
var burst_count: int = 0
var burst_delay: float = 0.0

func _ready() -> void:
	variant_id = "infantry_squad"
	is_air_unit = false
	super._ready()
	fire_interval *= combat_cooldown_multiplier
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
	var muzzle := global_position + Vector3(0, 1.0, 0)

	# Tactical street navigation using UrbanPathfinder
	var s_sign = 1.0 if sin(state_timer * 0.9) >= 0.0 else -1.0
	var move_dir = get_ground_nav_heading(target_player.global_position, delta, 28.0, s_sign)
	steer_ground_unit(move_dir, move_speed, delta)

	var aim_lead := get_predicted_target_position(muzzle, target_player, 190.0, 0.85, deg_to_rad(2.5))
	cached_aim_point = aim_lead

	match behavior_state:
		BehaviorState.PURSUE:
			if dist <= 40.0:
				set_behavior_state(BehaviorState.POSITION)
			else:
				not_firing_reason = REASON_OUT_OF_RANGE

		BehaviorState.POSITION:
			fire_timer -= delta
			if fire_timer > 0.0:
				not_firing_reason = REASON_COOLDOWN
			elif dist > 55.0:
				not_firing_reason = REASON_OUT_OF_RANGE
				set_behavior_state(BehaviorState.PURSUE)
			elif not check_muzzle_line_of_sight(muzzle, target_player.global_position):
				not_firing_reason = REASON_BLOCKED_SHOT
			else:
				# Begin telegraphed rifle burst
				set_behavior_state(BehaviorState.WINDUP)
				start_telegraph(windup_duration, aim_commit_ratio, Color(1.0, 0.85, 0.3, 0.7))

		BehaviorState.WINDUP:
			var windup_done = update_telegraph(muzzle, cached_aim_point, delta)
			if windup_done:
				clear_telegraph()
				set_behavior_state(BehaviorState.FIRE)
				burst_count = 3
				burst_delay = 0.0

		BehaviorState.FIRE:
			not_firing_reason = REASON_OK_FIRING
			burst_delay -= delta
			if burst_delay <= 0.0 and burst_count > 0:
				burst_delay = 0.12
				burst_count -= 1
				if check_muzzle_line_of_sight(muzzle, target_player.global_position):
					_fire_single_round(muzzle)
				else:
					not_firing_reason = REASON_BLOCKED_SHOT

				if burst_count <= 0:
					set_behavior_state(BehaviorState.RECOVER)
					fire_timer = fire_interval + randf_range(-0.4, 0.4)

		BehaviorState.RECOVER:
			not_firing_reason = REASON_COOLDOWN
			if state_timer >= 0.5:
				set_behavior_state(BehaviorState.POSITION)

func _fire_single_round(muzzle: Vector3) -> void:
	if not is_inside_tree() or not target_player:
		return
	var p = ProjectileScene.instantiate()
	var p_data = DamageDataClass.new(4.0, GameConstants.WeaponType.MACHINE_GUN, self)
	var parent_node = get_tree().current_scene if get_tree().current_scene else get_tree().root
	parent_node.add_child(p)
	p.global_position = muzzle
	var fire_aim = committed_aim_point if aim_committed else cached_aim_point
	var aim_dir = (fire_aim - muzzle).normalized()
	aim_dir += Vector3(randf_range(-0.03, 0.03), randf_range(-0.02, 0.02), randf_range(-0.03, 0.03))
	var final_dir = aim_dir.normalized()
	p.velocity = final_dir * 190.0
	p.collision_mask = 3
	p.setup(p_data, null, "enemy_bullet")

	if has_node("/root/FXManager"):
		var up_vec = Vector3.UP if absf(final_dir.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
		var muzzle_tf = Transform3D(Basis.looking_at(final_dir, up_vec), muzzle)
		get_node("/root/FXManager").play_muzzle("enemy_bullet", muzzle_tf, self, final_dir)
