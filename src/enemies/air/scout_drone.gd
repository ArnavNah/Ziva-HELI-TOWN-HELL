class_name ScoutDrone
extends BaseEnemy

## ScoutDrone — Light, nimble reconnaissance drone (Gate Wave 2).
## Employs rapid evasive orbits and quick telegraphed double-pulse pecks.

const ProjectileScene = preload("res://scenes/combat/projectile.tscn")
const DamageDataClass = preload("res://src/combat/damage_data.gd")

var target_player: Node3D = null
var orbit_angle: float = 0.0
var fire_timer: float = 1.5
var fire_interval: float = 2.2
var burst_shots: int = 0
var burst_timer: float = 0.0

var windup_duration: float = 0.25
var aim_commit_ratio: float = 0.60
var cached_aim_point: Vector3 = Vector3.ZERO

func _ready() -> void:
	variant_id = "scout_drone"
	is_air_unit = true
	super._ready()
	fire_interval *= combat_cooldown_multiplier
	_find_player()
	orbit_angle = randf() * TAU
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

	# Evasive circling orbit around player with reactive jinking
	orbit_angle += delta * 1.3
	var orbit_radius: float = 28.0 + sin(orbit_angle * 2.5) * 6.0
	var target_x: float = target_player.global_position.x + cos(orbit_angle) * orbit_radius
	var target_z: float = target_player.global_position.z + sin(orbit_angle) * orbit_radius
	var target_y: float = clampf(target_player.global_position.y + sin(orbit_angle * 3.2) * 5.0, 18.0, 48.0)
	var target_pos: Vector3 = Vector3(target_x, target_y, target_z)

	var move_dir: Vector3 = (target_pos - global_position).normalized()

	# Reactive evasion if player reticle bears down on drone
	var to_drone = (global_position - target_player.global_position).normalized()
	var player_fwd = -target_player.global_transform.basis.z
	if player_fwd.dot(to_drone) > 0.84:
		var dodge_lat = Vector3(-to_drone.z, 0.3, to_drone.x).normalized() * 15.0
		move_dir = (move_dir * 0.6 + dodge_lat * 0.4).normalized()

	steer_air_unit(move_dir * move_speed, 18.0, 52.0, delta)

	var aim_lead := get_predicted_target_position(global_position, target_player, 180.0, 0.88, deg_to_rad(1.8))
	cached_aim_point = aim_lead

	match behavior_state:
		BehaviorState.PURSUE:
			not_firing_reason = REASON_OUT_OF_RANGE
			if dist <= 35.0:
				set_behavior_state(BehaviorState.POSITION)

		BehaviorState.POSITION:
			fire_timer -= delta
			if fire_timer > 0.0:
				not_firing_reason = REASON_COOLDOWN
			elif dist > 45.0:
				not_firing_reason = REASON_OUT_OF_RANGE
				set_behavior_state(BehaviorState.PURSUE)
			elif not check_muzzle_line_of_sight(global_position, target_player.global_position):
				not_firing_reason = REASON_BLOCKED_SHOT
			else:
				# Begin telegraphed peck
				set_behavior_state(BehaviorState.WINDUP)
				start_telegraph(windup_duration, aim_commit_ratio, Color(1.0, 0.8, 0.2, 0.7))

		BehaviorState.WINDUP:
			var windup_done = update_telegraph(global_position, cached_aim_point, delta)
			if windup_done:
				clear_telegraph()
				set_behavior_state(BehaviorState.FIRE)
				burst_shots = 2
				burst_timer = 0.0

		BehaviorState.FIRE:
			not_firing_reason = REASON_OK_FIRING
			burst_timer -= delta
			if burst_timer <= 0.0 and burst_shots > 0:
				burst_timer = 0.12
				burst_shots -= 1
				_fire_scout_pulse()
				if burst_shots <= 0:
					set_behavior_state(BehaviorState.RECOVER)
					fire_timer = fire_interval + randf_range(-0.3, 0.4)

		BehaviorState.RECOVER:
			not_firing_reason = REASON_COOLDOWN
			if state_timer >= 0.4:
				set_behavior_state(BehaviorState.POSITION)

func _fire_scout_pulse() -> void:
	if not is_inside_tree() or not target_player:
		return
	var p = ProjectileScene.instantiate()
	var p_data = DamageDataClass.new(6.0, GameConstants.WeaponType.MACHINE_GUN, self)
	p.position = global_position
	var parent_node: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
	if not parent_node:
		parent_node = get_tree().root
	parent_node.add_child(p)
	if p.is_inside_tree():
		p.global_position = global_position
	var fire_aim = committed_aim_point if aim_committed else cached_aim_point
	var aim_dir = (fire_aim - global_position).normalized()
	p.velocity = aim_dir * 180.0
	p.collision_mask = 3
	p.setup(p_data, null, "enemy_bullet")

	if has_node("/root/FXManager"):
		var up_vec = Vector3.UP if absf(aim_dir.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
		var muzzle_tf = Transform3D(Basis.looking_at(aim_dir, up_vec), global_position)
		get_node("/root/FXManager").play_muzzle("enemy_bullet", muzzle_tf, self, aim_dir)
