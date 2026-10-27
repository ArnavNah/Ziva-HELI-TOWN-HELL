extends BaseEnemy

## ProceduralRaider — Multi-role procedural enemy controller for ground and air raiders.
## Supports: scout_buggy, assault_apc, raptor_raider, desert_barrage_rover, rail_crawler,
## attack_wing, stealth_vtol, heavy_bomber, hunter_drone, torpedo_vtol, escort_fighter.

const Shot = preload("res://scenes/combat/projectile.tscn")
const Hit = preload("res://src/combat/damage_data.gd")

var target: Node3D
var fire_timer := 2.0
var phase := 0.0
var orbit_sign := 1.0
var burst_count := 0
var burst_timer := 0.0
var active_aim_target := Vector3.ZERO
var _turret_node: Node3D = null
var _muzzle_marker: Marker3D = null
var _has_resolved_turret: bool = false

func _resolve_turret() -> void:
	_has_resolved_turret = true
	_turret_node = get_node_or_null("Turret") as Node3D
	if _turret_node:
		_muzzle_marker = _turret_node.get_node_or_null("GunPitch/Recoil/Muzzle") as Marker3D
		if not _muzzle_marker:
			_muzzle_marker = _turret_node.get_node_or_null("Muzzle") as Marker3D

func _ready() -> void:
	super._ready()
	target = get_tree().get_first_node_in_group("player") if get_tree() else null
	phase = randf() * TAU
	orbit_sign = -1.0 if randf() < 0.5 else 1.0
	fire_timer = randf_range(0.8, 1.8) # Stagger initial attacks across enemies

func _custom_process(delta: float) -> void:
	if not is_instance_valid(target) or (target.has_node("DamageReceiver") and target.get_node("DamageReceiver").is_dead):
		target = get_tree().get_first_node_in_group("player") if get_tree() else null
		if not is_instance_valid(target):
			not_firing_reason = REASON_NO_TARGET
			clear_telegraph()
			return

	var offset := target.global_position - global_position
	var planar := Vector3(offset.x, 0, offset.z)
	var distance := planar.length()
	var heading := planar.normalized()
	phase += delta

	# --- 1. BEHAVIOR STATE & HYSTERESIS MANAGEMENT ---
	if behavior_state == BehaviorState.PURSUE:
		if distance <= max_engagement_range:
			set_behavior_state(BehaviorState.POSITION)
	elif behavior_state == BehaviorState.POSITION:
		# Range hysteresis: resume pursuit only if target moves substantially farther away
		if distance > max_engagement_range * 1.25 + 4.0:
			set_behavior_state(BehaviorState.PURSUE)

	# --- 2. MOVEMENT & STEERING ---
	match variant_id:
		"hunter_drone":
			var tangent := Vector3(-heading.z, 0, heading.x) * orbit_sign
			var close_in = clampf((distance - min_engagement_range) / 12.0, 0.0, 1.0)
			var desired := (heading * lerpf(0.5, 0.95, close_in) + tangent * lerpf(0.7, 0.2, close_in)).normalized() * move_speed
			desired.y = (clampf(target.global_position.y + sin(phase * 2.0) * 3.0, 12, 38) - global_position.y) * 2.5
			steer_air_unit(desired, 12.0, 42.0, delta)

		"escort_fighter":
			# Reliable close-in phase before tactical weave / pass (Section 1 & 5)
			var tangent := Vector3(-heading.z, 0, heading.x) * orbit_sign
			var close_in = clampf((distance - max_engagement_range) / 20.0, 0.0, 1.0)
			var desired := (heading * lerpf(0.65, 0.95, close_in) + tangent * lerpf(0.75, 0.15, close_in)).normalized() * move_speed
			desired.y = (clampf(target.global_position.y + 6.0, 20.0, 48.0) - global_position.y) * 1.8
			steer_air_unit(desired, 20.0, 48.0, delta)

		"torpedo_vtol":
			var tangent := Vector3(-heading.z, 0, heading.x) * sin(phase)
			var close_in = clampf((distance - max_engagement_range) / 20.0, 0.0, 1.0)
			var desired := (heading * lerpf(0.60, 0.95, close_in) + tangent * lerpf(0.65, 0.15, close_in)).normalized() * move_speed
			desired.y = (clampf(target.global_position.y + 10.0, 24, 42) - global_position.y) * 1.8
			steer_air_unit(desired, 24.0, 46.0, delta)

		"rail_crawler":
			var preferred := (min_engagement_range + max_engagement_range) * 0.5
			var dir := get_ground_nav_heading(target.global_position, delta, preferred, orbit_sign)
			var spd_mult = 0.50 if behavior_state == BehaviorState.WINDUP else 1.0 # Braces while charging!
			steer_ground_unit(dir, move_speed * spd_mult, delta)

		"scout_buggy", "assault_apc", "raptor_raider":
			var preferred := (min_engagement_range + max_engagement_range) * 0.5
			var dir := get_ground_nav_heading(target.global_position, delta, preferred, orbit_sign)
			steer_ground_unit(dir, move_speed, delta)

		"desert_barrage_rover":
			var preferred := (min_engagement_range + max_engagement_range) * 0.5
			var dir := get_ground_nav_heading(target.global_position, delta, preferred, orbit_sign)
			var spd_mult = 0.50 if behavior_state == BehaviorState.WINDUP else 1.0
			steer_ground_unit(dir, move_speed * spd_mult, delta)

		_:
			var preferred := (min_engagement_range + max_engagement_range) * 0.5
			var dir := get_ground_nav_heading(target.global_position, delta, preferred, orbit_sign)
			steer_ground_unit(dir, move_speed, delta)

	# Turret Aiming with smooth tracking and predictive lead
	if not _has_resolved_turret:
		_resolve_turret()
	var muzzle_origin := get_muzzle_origin()
	var turret := _turret_node
	var is_aligned := true
	if turret:
		active_aim_target = get_predicted_target_position(muzzle_origin, target, combat_proj_speed, combat_lead_accuracy, combat_spread_rad)
		if turret.has_method("track_aim"):
			is_aligned = turret.track_aim(active_aim_target, delta, 150.0, 24.0)
		else:
			is_aligned = track_turret(turret, active_aim_target, delta, 150.0, 24.0)
	else:
		active_aim_target = get_predicted_target_position(muzzle_origin, target, combat_proj_speed, combat_lead_accuracy, combat_spread_rad)

	# --- 3. WINDUP & TELEGRAPH HANDLING ---
	if behavior_state == BehaviorState.WINDUP:
		var cue_color = Color("ff913e") if variant_id == "rail_crawler" else Color("ef8b49")
		if not telegraph_mesh or not telegraph_mesh.visible:
			start_telegraph(combat_windup_time, combat_aim_commit_ratio, cue_color)

		var windup_finished = update_telegraph(muzzle_origin, active_aim_target, delta)
		if windup_finished:
			# Verify line of sight to committed aim point before firing
			var shot_clear = check_muzzle_line_of_sight(muzzle_origin, committed_aim_point)
			if not shot_clear:
				not_firing_reason = REASON_BLOCKED_SHOT
				clear_telegraph()
				_release_all_slots()
				set_behavior_state(BehaviorState.POSITION)
				fire_timer = 0.4 # Re-evaluate position briefly
				return

			clear_telegraph()
			set_behavior_state(BehaviorState.FIRE)
			burst_count = combat_burst_count
			burst_timer = 0.0
			_fire_single_shot(committed_aim_point)
		return

	# --- 4. BURST FIRE HANDLING ---
	if behavior_state == BehaviorState.FIRE:
		if burst_count > 1:
			burst_timer -= delta
			if burst_timer <= 0.0:
				burst_timer = combat_burst_delay
				burst_count -= 1
				# Re-evaluate line of sight for each burst round (Section 6)
				var shot_clear = check_muzzle_line_of_sight(muzzle_origin, active_aim_target)
				if shot_clear:
					_fire_single_shot(active_aim_target)
				else:
					# Shot blocked mid-burst: abort remainder
					burst_count = 0
		else:
			burst_count = 0
			_release_all_slots()
			fire_timer = combat_cooldown + randf_range(-0.3, 0.3)
			set_behavior_state(BehaviorState.RECOVER)
			recover_timer = 0.35
		return

	# --- 5. ATTACK READINESS & PERMISSION CHECKS ---
	fire_timer -= delta
	if fire_timer > 0.0:
		not_firing_reason = REASON_COOLDOWN
		return

	if behavior_state == BehaviorState.ENTER:
		not_firing_reason = REASON_ENTERING
		return

	# 3D Weapon reach validation
	var dist_3d = global_position.distance_to(target.global_position)
	if dist_3d > weapon_reach_3d:
		not_firing_reason = REASON_OUT_OF_RANGE
		return

	# Turret alignment check
	if not is_aligned:
		not_firing_reason = REASON_TURNING
		return

	# 3D Line of Sight check from muzzle
	var los_clear = check_muzzle_line_of_sight(muzzle_origin, active_aim_target)
	if not los_clear:
		not_firing_reason = REASON_BLOCKED_SHOT
		return

	# CombatDirector attack slot acquisition (Atomic & pause-aware)
	if requires_heavy_slot or requires_air_slot:
		var director := get_node_or_null("/root/CombatDirector")
		if director:
			var slot_granted = director.request_combined_attack_slots(self, requires_air_slot, requires_heavy_slot)
			if not slot_granted:
				not_firing_reason = REASON_WAITING_PERMISSION
				return
			has_air_slot = requires_air_slot
			has_heavy_slot = requires_heavy_slot

	# All permissions and conditions satisfied -> Initiate Windup!
	not_firing_reason = REASON_OK_FIRING
	set_behavior_state(BehaviorState.WINDUP)
	var cue_col = Color("ff913e") if variant_id == "rail_crawler" else Color("ef8b49")
	start_telegraph(combat_windup_time, combat_aim_commit_ratio, cue_col)

func get_muzzle_origin() -> Vector3:
	if not _has_resolved_turret:
		_resolve_turret()
	if _muzzle_marker and is_instance_valid(_muzzle_marker):
		return _muzzle_marker.global_position
	if _turret_node and is_instance_valid(_turret_node):
		if _turret_node.has_method("get_muzzle_position"):
			return _turret_node.get_muzzle_position()
		return _turret_node.global_position
	return global_position + Vector3.UP * 1.8

func _fire_single_shot(aim_point: Vector3 = Vector3.ZERO) -> void:
	if not is_inside_tree() or not is_instance_valid(target):
		return

	var muzzle_pos := get_muzzle_origin()
	var turret := get_node_or_null("Turret") as Node3D
	if turret and turret.has_method("play_recoil"):
		turret.play_recoil()

	var shot_aim = aim_point if aim_point != Vector3.ZERO else active_aim_target

	var shot := Shot.instantiate()
	var scene := get_tree().current_scene if get_tree().current_scene else get_parent()
	if not scene:
		scene = get_tree().root
	scene.add_child(shot)

	shot.global_position = muzzle_pos
	shot.collision_mask = 3 # Player + Environment
	shot.add_to_group("enemy_projectiles")

	var tracer := shot.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if tracer and variant_id in ["rail_crawler", "torpedo_vtol", "desert_barrage_rover"]:
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color("ff913e") if variant_id == "desert_barrage_rover" else Color("78d8e0")
		tracer.material_override = material
		tracer.scale *= 1.8

	var aim_dir = (shot_aim - muzzle_pos).normalized()

	var profile_id: String = "enemy_bullet"
	match variant_id:
		"torpedo_vtol", "desert_barrage_rover":
			profile_id = "enemy_rocket"
		"rail_crawler":
			profile_id = "enemy_rail"
		"heavy_bomber":
			profile_id = "enemy_heavy"
		"scout_buggy", "assault_apc", "raptor_raider", "stealth_vtol":
			profile_id = "enemy_bullet"
		_:
			profile_id = "enemy_bullet"

	if has_node("/root/FXManager"):
		var up_vec = Vector3.UP if absf(aim_dir.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
		var muzzle_tf = Transform3D(Basis.looking_at(aim_dir, up_vec), muzzle_pos)
		get_node("/root/FXManager").play_muzzle(profile_id, muzzle_tf, turret if turret else self, aim_dir)

	match variant_id:
		"torpedo_vtol":
			shot.speed = 72.0
			shot.blast_radius = 3.5
			shot.is_homing = true
			shot.homing_turn_rate = 1.6
			shot.velocity = aim_dir * shot.speed
			shot.setup(Hit.new(14.0, GameConstants.WeaponType.MISSILE, self, false, shot.blast_radius), target, profile_id)
			shot.add_to_group("homing_missiles")

		"rail_crawler":
			shot.velocity = aim_dir * 220.0
			shot.setup(Hit.new(26.0, GameConstants.WeaponType.MACHINE_GUN, self), null, profile_id)

		"heavy_bomber":
			shot.global_position = global_position + Vector3.DOWN * 1.5
			shot.velocity = Vector3(randf_range(-3, 3), -35.0, randf_range(-3, 3))
			shot.blast_radius = 6.0
			shot.setup(Hit.new(22.0, GameConstants.WeaponType.ROCKET, self, false, shot.blast_radius), null, profile_id)

		"assault_apc":
			shot.velocity = aim_dir * 160.0
			shot.blast_radius = 0.0
			shot.setup(Hit.new(9.0, GameConstants.WeaponType.MACHINE_GUN, self, false, 0.0), null, profile_id)

		"scout_buggy":
			shot.velocity = aim_dir * 140.0
			shot.blast_radius = 0.0
			shot.setup(Hit.new(7.0, GameConstants.WeaponType.MACHINE_GUN, self, false, 0.0), null, profile_id)

		"raptor_raider":
			shot.velocity = aim_dir * 175.0
			shot.blast_radius = 0.0
			shot.setup(Hit.new(12.0, GameConstants.WeaponType.MACHINE_GUN, self, false, 0.0), null, profile_id)

		"desert_barrage_rover":
			shot.speed = 78.0
			shot.blast_radius = 3.5
			shot.velocity = aim_dir * shot.speed
			shot.setup(Hit.new(15.0, GameConstants.WeaponType.MISSILE, self, false, shot.blast_radius), target, profile_id)

		"stealth_vtol":
			shot.velocity = aim_dir * 150.0
			shot.blast_radius = 0.0
			shot.setup(Hit.new(11.0, GameConstants.WeaponType.MACHINE_GUN, self, false, 0.0), null, profile_id)

		_:
			shot.velocity = aim_dir * combat_proj_speed
			shot.blast_radius = 0.0
			shot.setup(Hit.new(5.0, GameConstants.WeaponType.MACHINE_GUN, self, false, 0.0), null, profile_id)
