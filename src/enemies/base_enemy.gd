class_name BaseEnemy
extends CharacterBody3D

## BaseEnemy — Common logic for all Heli-Town Hell hostiles.
## Manages state machine, modifiers, death spirals, slot release,
## observable behavior states, readable telegraphs, and persistent pursuit.

const EnemyDataClass = preload("res://src/enemies/enemy_data.gd")
const DamageReceiverClass = preload("res://src/combat/damage_data.gd")
const UrbanPathfinderClass = preload("res://src/world/urban_pathfinder.gd")

enum EnemyState {
	ENTRY = 0,
	APPROACH = 1,
	SETUP = 2,
	ATTACK = 3,
	BREAK_AWAY = 4,
	REPOSITION = 5,
	DEATH_SPIRAL = 6,
	DEAD = 7,
	PURSUE = 1,
	POSITION = 2,
	WINDUP = 8,
	FIRE = 3,
	RECOVER = 4
}

enum BehaviorState {
	ENTER = 0,
	PURSUE = 1,
	POSITION = 2,
	WINDUP = 3,
	FIRE = 4,
	RECOVER = 5,
	DEAD = 6
}

# Reason why unit is not firing (Observability & Dev View)
const REASON_OUT_OF_RANGE = "OUT_OF_RANGE"
const REASON_BLOCKED_SHOT = "BLOCKED_SHOT"
const REASON_TURNING = "TURNING"
const REASON_COOLDOWN = "COOLDOWN"
const REASON_ENTERING = "ENTERING"
const REASON_NO_TARGET = "NO_TARGET"
const REASON_WAITING_PERMISSION = "WAITING_PERMISSION"
const REASON_NO_REACHABLE_POSITION = "NO_REACHABLE_POSITION"
const REASON_OK_FIRING = "OK_FIRING"

@export var variant_id: String = "scout_drone"
@export var modifier: int = EnemyDataClass.ModifierType.NONE

var current_state: EnemyState = EnemyState.ENTRY
var behavior_state: BehaviorState = BehaviorState.ENTER
var state_timer: float = 0.0
var not_firing_reason: String = REASON_ENTERING

var move_speed: float = 30.0
var score_value: int = 100
var xp_value: int = 3
var is_heavy_attacker: bool = false
var has_air_slot: bool = false
var has_heavy_slot: bool = false

# Data-driven combat specifications (Loaded from EnemyData)
var enemy_role: String = EnemyDataClass.ROLE_MOBILE_SHOOTER
var min_engagement_range: float = 20.0
var max_engagement_range: float = 45.0
var retreat_distance: float = 14.0
var weapon_reach_3d: float = 65.0
var combat_windup_time: float = 0.35
var combat_aim_commit_ratio: float = 0.70
var combat_cooldown: float = 2.5
var combat_burst_count: int = 1
var combat_burst_delay: float = 0.12
var combat_proj_speed: float = 140.0
var combat_lead_accuracy: float = 0.88
var combat_spread_rad: float = 0.02
var requires_heavy_slot: bool = false
var requires_air_slot: bool = false
var spawn_wave: int = 1
var combat_damage_multiplier: float = 1.0
var combat_cooldown_multiplier: float = 1.0
var has_closed_to_attack_range: bool = false

# Timers & Flags
var is_air_unit: bool = false
var entry_grace_period: float = 2.0: # Entry protection period
	set(val):
		entry_grace_period = val
		entry_grace_timer = val
var entry_grace_timer: float = 2.0 # Non-attacking entry window
var recover_timer: float = 0.0

# Telegraph and Aim Commitment (Section 6)
var telegraph_timer: float = 0.0
var telegraph_duration: float = 0.0
var telegraph_commit_ratio: float = 0.70
var aim_committed: bool = false
var committed_aim_point: Vector3 = Vector3.ZERO
var telegraph_mesh: MeshInstance3D = null

# Death spiral
var spiral_angular_vel: Vector3 = Vector3.ZERO
var death_crash_timer: float = 0.0
var death_smoke_timer: float = 0.0
var animated_rotor: Node3D
var avoidance_timer := 0.0
var cached_avoidance := Vector3.ZERO
var cached_probe_direction := Vector3.ZERO
var roof_probe_timer := 0.0
var cached_roof_height := -1000.0
var activity_player: Node3D
var activity_timer := 0.0
var stuck_timer: float = 0.0
var stuck_recovery_timer: float = 0.0
var stuck_recovery_dir: Vector3 = Vector3.ZERO
var stuck_recovery_phase: int = 0 # 0 = normal, 1 = reverse backing up, 2 = steer forward to road
var stuck_reverse_timer: float = 0.0
var wall_slide_dir: Vector3 = Vector3.ZERO
var avoidance_latch_timer: float = 0.0
var avoidance_latch_dir: Vector3 = Vector3.ZERO

# Ground movement spatial watchdog
var last_recorded_pos: Vector3 = Vector3.ZERO
var pos_check_timer: float = 0.0
var spatial_stuck_timer: float = 0.0

# Street pathfinding and separate line-of-sight navigation
var nav_path: PackedVector3Array = PackedVector3Array()
var nav_path_index: int = 0
var nav_repath_timer: float = 0.0
var nav_has_los: bool = false # Horizontal road-level clearance
var nav_has_shot_los: bool = false # 3D muzzle-to-player shot clearance
var nav_los_timer: float = 0.0

# Queries run synchronously on this enemy; reuse their parameters between probes.
var _probe_query: PhysicsRayQueryParameters3D

@onready var damage_receiver: DamageReceiver = get_node_or_null("DamageReceiver")
@onready var visual_mesh: Node3D = get_node_or_null("Visuals")

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4 # Layer 3: Hostiles
	collision_mask = 7  # Collides with Player (1), Ground/Buildings (2), Hostiles (3)
	if not damage_receiver:
		damage_receiver = get_node_or_null("DamageReceiver")
	_apply_variant_specs()
	_apply_modifiers()
	_apply_wave_scaling()
	animated_rotor = get_node_or_null("Visuals/AnimatedRotor")
	activity_player = get_tree().get_first_node_in_group("player")
	if damage_receiver and not damage_receiver.destroyed.is_connected(_on_destroyed):
		damage_receiver.destroyed.connect(_on_destroyed)

func _apply_variant_specs() -> void:
	if EnemyDataClass.VARIANTS.has(variant_id):
		var v = EnemyDataClass.VARIANTS[variant_id]
		move_speed = v.get("speed", 30.0)
		score_value = v.get("score", 100)
		xp_value = v.get("xp", 3)
		is_heavy_attacker = v.get("is_heavy", false)
		is_air_unit = v.get("family", "air") == "air"
		enemy_role = v.get("role", EnemyDataClass.ROLE_MOBILE_SHOOTER)
		min_engagement_range = v.get("min_range", 20.0)
		max_engagement_range = v.get("max_range", 45.0)
		retreat_distance = v.get("retreat_dist", 14.0)
		weapon_reach_3d = v.get("weapon_reach", 65.0)
		combat_windup_time = v.get("windup_time", 0.35)
		combat_aim_commit_ratio = v.get("aim_commit_ratio", 0.70)
		combat_cooldown = v.get("fire_cooldown", 2.5)
		combat_burst_count = v.get("burst_count", 1)
		combat_burst_delay = v.get("burst_delay", 0.12)
		combat_proj_speed = v.get("proj_speed", 140.0)
		combat_lead_accuracy = v.get("lead_accuracy", 0.88)
		combat_spread_rad = v.get("spread_rad", 0.02)
		requires_heavy_slot = v.get("requires_heavy_slot", is_heavy_attacker)
		requires_air_slot = v.get("requires_air_slot", v.get("family", "air") == "air")

		if damage_receiver:
			damage_receiver.max_health = v.get("base_hull", 50.0)
			damage_receiver.current_health = damage_receiver.max_health
			damage_receiver.target_affinity = v.get("affinity", GameConstants.TargetAffinity.LIGHT)

func _apply_wave_scaling() -> void:
	var director := get_node_or_null("/root/CombatDirector")
	var difficulty := "Normal"
	if director:
		spawn_wave = director.current_wave
		difficulty = director.difficulty_level
	var scaling := EnemyDataClass.get_wave_scaling(spawn_wave, difficulty)
	move_speed *= float(scaling.speed)
	combat_damage_multiplier = scaling.damage
	combat_cooldown_multiplier = scaling.cooldown
	combat_cooldown *= combat_cooldown_multiplier
	if damage_receiver:
		damage_receiver.max_health *= float(scaling.health)
		damage_receiver.current_health = damage_receiver.max_health
		damage_receiver.shield_health *= float(scaling.health)

func _apply_modifiers() -> void:
	match modifier:
		EnemyDataClass.ModifierType.ELITE:
			if damage_receiver:
				damage_receiver.max_health *= 1.7
				damage_receiver.current_health = damage_receiver.max_health
			score_value = int(float(score_value) * 2.2)
			xp_value += 3
			if visual_mesh:
				visual_mesh.scale *= 1.2
			for col in get_children():
				if not col is CollisionShape3D or not col.shape: continue
				col.shape = col.shape.duplicate()
				if col.shape is BoxShape3D:
					col.shape.size *= 1.2
				elif col.shape is CylinderShape3D:
					col.shape.radius *= 1.2
					col.shape.height *= 1.2
				else:
					col.scale *= 1.2
				col.position *= 1.2
			var scaled_turret := get_node_or_null("Turret") as Node3D
			if scaled_turret:
				scaled_turret.scale *= 1.2
				scaled_turret.position *= 1.2
		EnemyDataClass.ModifierType.SHIELDED:
			if damage_receiver:
				damage_receiver.shield_health = damage_receiver.max_health * 0.5
		EnemyDataClass.ModifierType.REGENERATING:
			pass

func _physics_process(delta: float) -> void:
	state_timer += delta
	avoidance_timer -= delta
	roof_probe_timer -= delta
	if animated_rotor:
		animated_rotor.rotation.y += delta * 24.0

	if current_state == EnemyState.DEATH_SPIRAL or behavior_state == BehaviorState.DEAD:
		_process_death_spiral(delta)
		return

	if current_state == EnemyState.DEAD:
		return
	if is_instance_valid(damage_receiver) and (damage_receiver.is_emp_disabled or damage_receiver.is_shocked):
		# Electronics effects must stop the weapon brain, not just set a status flag.
		if has_air_slot:
			on_attack_slot_expired("air")
		if has_heavy_slot:
			on_attack_slot_expired("heavy")
		_release_all_slots()
		clear_telegraph()
		velocity = velocity.move_toward(Vector3.ZERO, 20.0 * delta)
		move_and_slide()
		return

	# Entry protection is independent of subclass state changes.
	entry_grace_timer = maxf(0.0, entry_grace_timer - delta)

	# Behavior State Recovery Countdown
	if behavior_state == BehaviorState.RECOVER and recover_timer > 0.0:
		recover_timer -= delta
		if recover_timer <= 0.0:
			set_behavior_state(BehaviorState.POSITION)

	# Activity / Offscreen Stuck Watchdog
	activity_timer -= delta
	if activity_timer <= 0:
		activity_timer = 0.5
		if not is_instance_valid(activity_player):
			activity_player = get_tree().get_first_node_in_group("player")

		if is_instance_valid(activity_player):
			var offset := global_position - activity_player.global_position
			var dist_h_sq = Vector2(offset.x, offset.z).length_squared()
			# Despawn if far outside the play radius (260m)
			if dist_h_sq > 260.0 * 260.0:
				_release_all_slots()
				clear_telegraph()
				queue_free()
				return
			# Safe retirement of permanently wedged/unreachable offscreen units (>160m away, stuck >12s)
			elif dist_h_sq > 160.0 * 160.0 and spatial_stuck_timer > 12.0:
				_release_all_slots()
				clear_telegraph()
				queue_free()
				return

	# Subclass specific state processing
	if enemy_role != EnemyDataClass.ROLE_SUPPORT and _process_player_pursuit(delta):
		return
	_custom_process(delta)

## All offensive variants must close on the player before their weapon brain runs.
## A wider release radius avoids switching states every frame at the range edge.
func get_approach_range() -> float:
	return clampf(max_engagement_range * 0.90, 18.0, 60.0)

func _process_player_pursuit(delta: float) -> bool:
	if not is_instance_valid(activity_player):
		activity_player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(activity_player):
		_release_all_slots()
		clear_telegraph()
		_on_pursuit_resumed()
		set_behavior_state(BehaviorState.PURSUE)
		has_closed_to_attack_range = false
		not_firing_reason = REASON_NO_TARGET
		return true
	var offset := activity_player.global_position - global_position
	var planar := Vector3(offset.x, 0.0, offset.z)
	var distance := planar.length()
	var approach_range := get_approach_range()
	if has_closed_to_attack_range and distance > approach_range + 12.0:
		has_closed_to_attack_range = false
		_on_pursuit_resumed()
		_release_all_slots()
		clear_telegraph()
		set_behavior_state(BehaviorState.PURSUE)
	if entry_grace_timer <= 0.0 and distance <= approach_range:
		has_closed_to_attack_range = true
	if entry_grace_timer <= 0.0 and has_closed_to_attack_range:
		if behavior_state == BehaviorState.ENTER:
			set_behavior_state(BehaviorState.PURSUE)
		return false
	set_behavior_state(BehaviorState.ENTER if entry_grace_timer > 0.0 else BehaviorState.PURSUE)
	not_firing_reason = REASON_ENTERING if entry_grace_timer > 0.0 else REASON_OUT_OF_RANGE
	if is_air_unit:
		var desired := planar.normalized() * move_speed if distance > approach_range else Vector3.ZERO
		desired.y = (clampf(activity_player.global_position.y + 6.0, 18.0, 46.0) - global_position.y) * 2.0
		steer_air_unit(desired, 18.0, 52.0, delta)
	else:
		var heading := Vector3.ZERO
		if distance > approach_range:
			heading = get_ground_nav_heading(activity_player.global_position, delta, approach_range * 0.70)
		steer_ground_unit(heading, move_speed, delta)
	return true

func _on_pursuit_resumed() -> void:
	pass

func _custom_process(_delta: float) -> void:
	pass

# ------------------------------------------------------------------------------
# Observable State & Firing Validation
# ------------------------------------------------------------------------------
func set_behavior_state(new_state: BehaviorState) -> void:
	if behavior_state == new_state:
		return
	behavior_state = new_state
	state_timer = 0.0
	match new_state:
		BehaviorState.ENTER:
			current_state = EnemyState.ENTRY
		BehaviorState.PURSUE:
			current_state = EnemyState.APPROACH
		BehaviorState.POSITION:
			current_state = EnemyState.SETUP
		BehaviorState.WINDUP, BehaviorState.FIRE:
			current_state = EnemyState.ATTACK
		BehaviorState.RECOVER:
			current_state = EnemyState.BREAK_AWAY
		BehaviorState.DEAD:
			current_state = EnemyState.DEAD

## Reusing parameters avoids allocating a Resource and exclusion array per ray.
## Always reset the mask and inside flag: avoidance and weapon LOS differ.
func _cast_probe(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, mask: int, inside: bool = false) -> Dictionary:
	if _probe_query == null:
		_probe_query = PhysicsRayQueryParameters3D.new()
		_probe_query.exclude = [get_rid()]
	_probe_query.from = from
	_probe_query.to = to
	_probe_query.collision_mask = mask
	_probe_query.hit_from_inside = inside
	return space.intersect_ray(_probe_query)

func get_air_weapon_origin() -> Vector3:
	var rig := get_node_or_null("Visuals")
	return rig.get_weapon_origin() if rig and rig.has_method("get_weapon_origin") else global_position

func get_air_weapon_socket() -> Marker3D:
	var rig := get_node_or_null("Visuals")
	return rig.get_weapon_socket() if rig and rig.has_method("get_weapon_socket") else null

func air_weapon_can_fire(aim: Vector3, fixed_gun: bool = false) -> bool:
	if not is_inside_tree() or is_queued_for_deletion(): return false
	if damage_receiver and damage_receiver.is_dead: return false
	var rig := get_node_or_null("Visuals")
	if not rig or not rig.has_method("get_weapon_socket") or not rig.get_weapon_socket(): return false
	if fixed_gun and not rig.is_in_firing_arc(aim):
		not_firing_reason = REASON_TURNING
		return false
	if not check_muzzle_line_of_sight(rig.get_weapon_origin(), aim):
		not_firing_reason = REASON_BLOCKED_SHOT
		return false
	return true

func commit_air_shot() -> void:
	var rig := get_node_or_null("Visuals")
	if rig and rig.has_method("commit_shot"): rig.commit_shot()

## Checks 3D line of sight from muzzle to player (Mask 2: Buildings/Environment)
func check_muzzle_line_of_sight(muzzle_pos: Vector3, target_aim: Variant) -> bool:
	if not is_inside_tree() or get_world_3d() == null:
		return true
	var space = get_world_3d().direct_space_state
	if not space:
		return true
	var target_pos: Vector3
	if target_aim is Vector3:
		target_pos = target_aim
	elif target_aim is Node3D and is_instance_valid(target_aim):
		target_pos = target_aim.global_position
	else:
		return true
	var hit = _cast_probe(space, muzzle_pos, target_pos, 2)
	return hit.is_empty()

## Called by CombatDirector when an attack slot lease expires or is revoked (Section 7)
func on_attack_slot_expired(slot_type: String) -> void:
	if slot_type in ["air", "all"]:
		has_air_slot = false
	if slot_type in ["heavy", "all"]:
		has_heavy_slot = false

	# If interrupted during windup/fire, abort cleanly
	if behavior_state in [BehaviorState.WINDUP, BehaviorState.FIRE]:
		clear_telegraph()
		not_firing_reason = REASON_WAITING_PERMISSION
		set_behavior_state(BehaviorState.POSITION)

# ------------------------------------------------------------------------------
# Telegraphing & Dodgeable Aim Commitment (Section 6)
# ------------------------------------------------------------------------------
func start_telegraph(arg1: Variant, arg2: Variant = 0.70, arg3: Variant = Color(1.0, 0.35, 0.1, 0.85), arg4: Variant = 0.70) -> void:
	var duration: float = 0.5
	var commit_ratio: float = 0.70
	var line_color: Color = Color(1.0, 0.35, 0.1, 0.85)

	if arg1 is Vector3:
		# Format: start_telegraph(target_point, duration, color, commit_ratio)
		duration = maxf(0.1, float(arg2))
		if arg3 is Color:
			line_color = arg3
		if arg4 is float or arg4 is int:
			commit_ratio = float(arg4)
	else:
		# Format: start_telegraph(duration, commit_ratio, color)
		duration = maxf(0.1, float(arg1))
		if arg2 is float or arg2 is int:
			commit_ratio = float(arg2)
		if arg3 is Color:
			line_color = arg3

	# The warning and real firing gate must share the same preparation window.
	if _is_offscreen_threat():
		duration = maxf(1.5, duration)
	telegraph_duration = duration
	telegraph_timer = duration
	telegraph_commit_ratio = clampf(commit_ratio, 0.3, 0.9)
	aim_committed = false

	if not telegraph_mesh:
		telegraph_mesh = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(0.08, 0.08, 1.0)
		telegraph_mesh.mesh = box
		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = line_color
		telegraph_mesh.material_override = mat
		telegraph_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(telegraph_mesh)
		telegraph_mesh.top_level = true
	telegraph_mesh.visible = true

	# Directional off-screen threat warning (Section 7)
	_emit_offscreen_threat_warning(duration)

func _emit_offscreen_threat_warning(duration: float) -> void:
	if _is_offscreen_threat():
		var bus = get_node_or_null("/root/EventBus")
		if bus and bus.has_signal("threat_warning"):
			bus.threat_warning.emit(global_position, variant_id, duration)

func _is_offscreen_threat() -> bool:
	if not is_inside_tree() or get_viewport() == null:
		return false
	var cam: Camera3D = get_viewport().get_camera_3d()
	if not cam:
		return false
	var is_offscreen = not cam.is_position_in_frustum(global_position)
	var is_threatening = is_heavy_attacker or requires_heavy_slot or max_engagement_range >= 55.0 or variant_id in ["rail_crawler", "siege_tank", "gatling_heavy", "rocket_gunship", "heavy_bomber", "torpedo_vtol"]
	return is_offscreen and is_threatening


func update_telegraph(origin: Vector3, live_aim: Vector3, delta: float = 0.016) -> bool:
	if telegraph_timer <= 0.0:
		return true

	telegraph_timer -= delta
	var elapsed_ratio = 1.0 - (telegraph_timer / maxf(telegraph_duration, 0.001))

	if elapsed_ratio < telegraph_commit_ratio:
		committed_aim_point = live_aim
		aim_committed = false
	else:
		aim_committed = true # Aim freezes in final response window!

	if is_instance_valid(telegraph_mesh):
		var offset = committed_aim_point - origin
		telegraph_mesh.global_position = origin + offset * 0.5
		var length = maxf(offset.length(), 0.1)
		telegraph_mesh.scale = Vector3(1.0, 1.0, length)
		if offset.length_squared() > 0.01:
			telegraph_mesh.look_at(committed_aim_point, Vector3.UP)

	if telegraph_timer <= 0.0:
		return true
	return false

func clear_telegraph() -> void:
	telegraph_timer = 0.0
	aim_committed = false
	if is_instance_valid(telegraph_mesh):
		telegraph_mesh.visible = false

# ------------------------------------------------------------------------------
# Steering & Whisker Avoidance
# ------------------------------------------------------------------------------
## Whisker raycasts against urban buildings & structures (Mask 2)
func get_avoidance_steering(forward_dir: Vector3, probe_dist: float = 16.0) -> Vector3:
	if not is_inside_tree() or get_world_3d() == null:
		return Vector3.ZERO

	var space = get_world_3d().direct_space_state
	if space == null:
		return Vector3.ZERO

	var horiz_fwd = Vector3(forward_dir.x, 0.0, forward_dir.z)
	if horiz_fwd.length_squared() < 0.01:
		return Vector3.ZERO
	horiz_fwd = horiz_fwd.normalized()
	if avoidance_timer > 0 and horiz_fwd.dot(cached_probe_direction) > 0.94:
		return cached_avoidance
	avoidance_timer = 0.12 + randf_range(0.0, 0.03)
	cached_probe_direction = horiz_fwd

	var origin = global_position + Vector3(0.0, 1.2, 0.0)
	var steer = Vector3.ZERO

	var right_perp = Vector3(horiz_fwd.z, 0.0, -horiz_fwd.x)
	var left_perp = Vector3(-horiz_fwd.z, 0.0, horiz_fwd.x)

	# 1. Center probe (Mask 6: Buildings 2 + Hostiles 4)
	var hit_center = _cast_probe(space, origin, origin + horiz_fwd * probe_dist, 6, true)

	# 2. Left whisker (+26 deg)
	var left_dir = horiz_fwd.rotated(Vector3.UP, deg_to_rad(26.0))
	var hit_left = _cast_probe(space, origin, origin + left_dir * (probe_dist * 0.92), 6, true)

	# 3. Right whisker (-26 deg)
	var right_dir = horiz_fwd.rotated(Vector3.UP, deg_to_rad(-26.0))
	var hit_right = _cast_probe(space, origin, origin + right_dir * (probe_dist * 0.92), 6, true)

	# 4, 5, 6. Wide and lateral whiskers (Air units only; ground units stay in road corridor)
	var hit_wleft := {}
	var hit_wright := {}
	var hit_lleft := {}
	var hit_lright := {}

	if is_air_unit:
		# 4. Wide-left whisker (+56 deg)
		var wide_left_dir = horiz_fwd.rotated(Vector3.UP, deg_to_rad(56.0))
		hit_wleft = _cast_probe(space, origin, origin + wide_left_dir * (probe_dist * 0.70), 2, true)

		# 5. Wide-right whisker (-56 deg)
		var wide_right_dir = horiz_fwd.rotated(Vector3.UP, deg_to_rad(-56.0))
		hit_wright = _cast_probe(space, origin, origin + wide_right_dir * (probe_dist * 0.70), 2, true)

		# 6. Lateral side whiskers (+88 deg / -88 deg at 4.5m)
		var lat_left_dir = horiz_fwd.rotated(Vector3.UP, deg_to_rad(88.0))
		hit_lleft = _cast_probe(space, origin, origin + lat_left_dir * 4.5, 6, true)

		var lat_right_dir = horiz_fwd.rotated(Vector3.UP, deg_to_rad(-88.0))
		hit_lright = _cast_probe(space, origin, origin + lat_right_dir * 4.5, 6, true)

	# Roadside buildings outside a clear forward corridor are not obstacles.
	if not is_air_unit and hit_center.is_empty() and hit_left.is_empty() and hit_right.is_empty():
		cached_avoidance = Vector3.ZERO
		return cached_avoidance

	# Wedged pocket / dead-end check: center, left, and right blocked
	if not hit_center.is_empty() and not hit_left.is_empty() and not hit_right.is_empty():
		var cd = (hit_center.get("position", origin) - origin).length()
		var ld = (hit_left.get("position", origin) - origin).length()
		var rd = (hit_right.get("position", origin) - origin).length()
		if cd < 3.2 and ld < 3.2 and rd < 3.2:
			return -horiz_fwd * 3.5

	# Center hit response: slide tangent
	if not hit_center.is_empty():
		var hit_norm: Vector3 = hit_center.get("normal", Vector3.ZERO)
		var wall_norm = Vector3(hit_norm.x, 0.0, hit_norm.z).normalized()
		if wall_norm.length_squared() > 0.05:
			steer += wall_norm * 2.8
			var t1 = Vector3(-wall_norm.z, 0.0, wall_norm.x)
			var t2 = -t1
			var chosen_tan = Vector3.ZERO
			if hit_left.is_empty() and not hit_right.is_empty():
				chosen_tan = t1 if t1.dot(left_perp) > 0.0 else t2
			elif hit_right.is_empty() and not hit_left.is_empty():
				chosen_tan = t1 if t1.dot(right_perp) > 0.0 else t2
			else:
				var d1 = t1.dot(horiz_fwd)
				var d2 = t2.dot(horiz_fwd)
				if absf(d1 - d2) > 0.05:
					chosen_tan = t1 if d1 > d2 else t2
				else:
					chosen_tan = t1 if (int(get_instance_id()) % 2 == 0) else t2
			steer += chosen_tan * 3.2

	if not hit_left.is_empty():
		var l_dist = (hit_left.get("position", origin) - origin).length()
		var weight_l = clampf(1.0 - l_dist / (probe_dist * 0.92), 0.35, 1.0)
		steer += right_perp * (weight_l * 2.6)

	if not hit_right.is_empty():
		var r_dist = (hit_right.get("position", origin) - origin).length()
		var weight_r = clampf(1.0 - r_dist / (probe_dist * 0.92), 0.35, 1.0)
		steer += left_perp * (weight_r * 2.6)

	if not hit_wleft.is_empty():
		steer += right_perp * 1.5
	if not hit_wright.is_empty():
		steer += left_perp * 1.5

	if not hit_lleft.is_empty():
		steer += right_perp * 2.2
	if not hit_lright.is_empty():
		steer += left_perp * 2.2

	if not hit_left.is_empty() and not hit_right.is_empty() and steer.length_squared() < 0.2:
		var l_dist = (hit_left.get("position", origin) - origin).length()
		var r_dist = (hit_right.get("position", origin) - origin).length()
		steer += right_perp * 2.8 if l_dist < r_dist else left_perp * 2.8

	cached_avoidance = steer
	return steer

## Computes predictive lead position with near-zero quadratic coefficient guard (Section 1 & 6).
## Solves: |(P_target + V_target * t) - P_origin| = proj_speed * t
func get_predicted_target_position(origin: Vector3, target: Node3D, proj_speed: float, lead_accuracy: float = 0.90, spread_rad: float = 0.0) -> Vector3:
	if not is_instance_valid(target):
		return origin + Vector3.FORWARD * 20.0

	var target_pos := target.global_position
	var target_vel := Vector3.ZERO
	if "velocity" in target and target.velocity is Vector3:
		target_vel = target.velocity

	if target_vel.length_squared() < 0.25 or proj_speed <= 1.0:
		if spread_rad > 0.0:
			var spread_offset = Vector3(randf_range(-1.0, 1.0), randf_range(-0.5, 0.5), randf_range(-1.0, 1.0)).normalized()
			return target_pos + spread_offset * (target_pos.distance_to(origin) * tan(spread_rad))
		return target_pos

	var D := target_pos - origin
	var a := target_vel.length_squared() - (proj_speed * proj_speed)
	var b := 2.0 * D.dot(target_vel)
	var c := D.length_squared()

	var t := -1.0

	# Quadratic coefficient near-zero guard (when target speed ~ proj speed)
	if absf(a) < 0.01:
		if absf(b) > 0.01:
			t = -c / b
		else:
			t = D.length() / maxf(proj_speed, 10.0)
	else:
		var disc := b * b - 4.0 * a * c
		if disc >= 0.0:
			var sqrt_disc := sqrt(disc)
			var t1 := (-b - sqrt_disc) / (2.0 * a)
			var t2 := (-b + sqrt_disc) / (2.0 * a)
			if t1 > 0.0 and t2 > 0.0:
				t = minf(t1, t2)
			elif t1 > 0.0:
				t = t1
			elif t2 > 0.0:
				t = t2

	# Bound prediction time to prevent infinite leading
	if t <= 0.0 or t > 1.8:
		t = clampf(D.length() / maxf(proj_speed, 10.0), 0.0, 1.8)

	var predicted := target_pos + target_vel * (t * clampf(lead_accuracy, 0.0, 1.0))
	predicted.y = maxf(predicted.y, 1.2)

	if spread_rad > 0.0:
		var dist_pred := origin.distance_to(predicted)
		var spread_offset = Vector3(randf_range(-1.0, 1.0), randf_range(-0.6, 0.6), randf_range(-1.0, 1.0)).normalized()
		predicted += spread_offset * (dist_pred * tan(spread_rad))

	return predicted

## Smoothly tracks a 3D turret node toward a target position.
## Clamps elevation (-15 to +75 deg) and returns true when aligned within tolerance_deg.
func track_turret(turret: Node3D, target_pos: Vector3, delta: float, turn_speed_deg: float = 140.0, tolerance_deg: float = 24.0) -> bool:
	if not turret or not is_instance_valid(turret):
		return false
	var turret_pos := turret.global_position
	var to_target := target_pos - turret_pos
	if to_target.length_squared() < 0.01:
		return true

	var horiz_dir := Vector3(to_target.x, 0.0, to_target.z)
	var dist_h := horiz_dir.length()
	var raw_elev := atan2(to_target.y, maxf(dist_h, 0.1))

	# Elevation limit check: if target is steeper than +76 deg, vehicle cannot elevate to fire
	if rad_to_deg(raw_elev) > 76.0:
		return false

	var to_target_norm := to_target.normalized()
	var current_facing := -turret.global_transform.basis.z
	var angle_err_rad := current_facing.angle_to(to_target_norm)
	var max_turn_rad := deg_to_rad(turn_speed_deg) * delta

	if angle_err_rad > 0.001:
		var step = minf(max_turn_rad, angle_err_rad)
		var rot_axis = current_facing.cross(to_target_norm)
		if rot_axis.length_squared() > 0.0001:
			turret.global_rotate(rot_axis.normalized(), step)

	current_facing = -turret.global_transform.basis.z
	var final_angle_err_deg := rad_to_deg(current_facing.angle_to(to_target_norm))
	return final_angle_err_deg <= tolerance_deg

## Returns a deterministic tactical flank angle offset based on instance ID.
func get_flank_angle_offset() -> float:
	var slot := int(get_instance_id()) % 6
	match slot:
		0: return 0.0
		1: return deg_to_rad(45.0)
		2: return deg_to_rad(-45.0)
		3: return deg_to_rad(75.0)
		4: return deg_to_rad(-75.0)
		5: return deg_to_rad(20.0)
		_: return 0.0

## Calculates tactical street navigation direction towards target_pos.
## Uses UrbanPathfinder road waypoints with Pure Pursuit lookahead and lane discipline
## when line-of-sight is blocked by buildings, seeking valid firing positions.
func get_ground_nav_heading(target_pos: Vector3, delta: float, preferred_dist: float = 30.0, orbit_sign: float = 1.0) -> Vector3:
	var offset := target_pos - global_position
	var dist_h := Vector2(offset.x, offset.z).length()
	var direct_heading := Vector3(offset.x, 0.0, offset.z).normalized()

	# 0. Off-Road Recovery: navigate back to road centerline if pushed into lot
	var road_dist = UrbanPathfinderClass.distance_to_nearest_road(global_position)
	if road_dist > 2.8:
		var road_target = UrbanPathfinderClass.get_nearest_road_point(global_position)
		var to_road_vec = road_target - global_position
		to_road_vec.y = 0.0
		if to_road_vec.length_squared() > 0.5:
			nav_path.clear()
			nav_repath_timer = 0.0
			return to_road_vec.normalized()

	# 1. Ground-level Road Clearance Check (Horizontal vehicle clearance)
	nav_los_timer -= delta
	if nav_los_timer <= 0.0:
		nav_los_timer = 0.15 + randf_range(0.0, 0.04)
		if is_inside_tree() and get_world_3d() != null:
			var space = get_world_3d().direct_space_state
			if space:
				var ground_target = Vector3(target_pos.x, global_position.y, target_pos.z)
				nav_has_los = _cast_probe(space,
					global_position + Vector3(0.0, 1.2, 0.0),
					ground_target + Vector3(0.0, 1.2, 0.0),
					2).is_empty()

				# Also check 3D muzzle-to-player shot clearance separately
				nav_has_shot_los = _cast_probe(space,
					global_position + Vector3(0.0, 1.8, 0.0),
					target_pos + Vector3(0.0, 0.5, 0.0),
					2).is_empty()

	# 2. Open Plaza tactical engagement
	var in_open_fob = global_position.length() < 24.0 and target_pos.length() < 28.0
	if in_open_fob and nav_has_los and dist_h < preferred_dist + 16.0:
		nav_path.clear()
		nav_path_index = 0
		var tangent := Vector3(-direct_heading.z, 0, direct_heading.x) * orbit_sign
		var approach := direct_heading * clampf((dist_h - preferred_dist) / 14.0, -1.0, 1.0)
		return (approach * 0.75 + tangent * 0.35).normalized()

	# 3. Urban Corridor Street Navigation: seek reachable road position with line-of-sight
	nav_repath_timer -= delta
	if nav_repath_timer <= 0.0 or nav_path.is_empty() or nav_path_index >= nav_path.size():
		nav_repath_timer = 0.45 + randf_range(0.0, 0.15)
		var tactical_target := target_pos

		# Ground units pursue road positions that can shoot at helicopter, not rooftop center
		if not in_open_fob:
			var flank_angle = get_flank_angle_offset()
			var flank_dir = direct_heading.rotated(Vector3.UP, flank_angle)
			tactical_target = target_pos - flank_dir * (preferred_dist * 0.75)
			# Snap tactical goal to nearest road network point
			tactical_target = UrbanPathfinderClass.get_nearest_road_point(tactical_target)

		nav_path = UrbanPathfinderClass.find_street_path(global_position, tactical_target)
		nav_path_index = 0
		if nav_path.size() > 1:
			var d0 = Vector2(nav_path[0].x - global_position.x, nav_path[0].z - global_position.z).length()
			if d0 < 4.5:
				nav_path_index = 1

	if nav_path.is_empty():
		var cur_road_pt = UrbanPathfinderClass.get_nearest_road_point(global_position)
		var tgt_road_pt = UrbanPathfinderClass.get_nearest_road_point(target_pos)
		var to_tgt = tgt_road_pt - cur_road_pt
		to_tgt.y = 0.0
		if to_tgt.length_squared() > 1.0:
			return to_tgt.normalized()
		return direct_heading

	# Pure Pursuit Lookahead with intersection corner discipline
	while nav_path_index < nav_path.size() - 1:
		var wp = nav_path[nav_path_index]
		var d = Vector2(wp.x - global_position.x, wp.z - global_position.z).length()
		var next_wp = nav_path[nav_path_index + 1]
		var cur_seg = (wp - global_position).normalized()
		var next_seg = (next_wp - wp).normalized()
		var is_turn = cur_seg.dot(next_seg) < 0.75
		var threshold = 3.2 if is_turn else clampf(move_speed * 0.35, 4.0, 7.0)
		if d < threshold:
			nav_path_index += 1
		else:
			break

	var target_wp := nav_path[nav_path_index]

	# Lane Offset (Right-Hand Traffic)
	if nav_path.size() > 1:
		var segment_dir = Vector3.ZERO
		if nav_path_index > 0:
			segment_dir = (nav_path[nav_path_index] - nav_path[nav_path_index - 1]).normalized()
		else:
			segment_dir = (nav_path[nav_path_index] - global_position).normalized()
		segment_dir.y = 0.0
		if segment_dir.length_squared() > 0.01:
			var right_offset = Vector3(segment_dir.z, 0.0, -segment_dir.x) * 1.4
			target_wp += right_offset

	var to_wp := target_wp - global_position
	var wp_dir := Vector3(to_wp.x, 0.0, to_wp.z)
	if wp_dir.length_squared() > 0.01:
		var dir_norm = wp_dir.normalized()
		# Range hysteresis & backing away when too close or target directly overhead
		if nav_has_shot_los and dist_h < preferred_dist + 12.0:
			if dist_h < retreat_distance or dist_h < 12.0:
				# Target hovering overhead or inside minimum range: back away along street
				return -dir_norm * 0.85
			elif dist_h <= preferred_dist + 4.0:
				# Optimal engagement range: slow creep or hold stance
				return dir_norm * 0.35
		return dir_norm

	return direct_heading

## Trigger emergency two-phase unstick maneuver
func _trigger_ground_unstick(contact_normal: Vector3 = Vector3.ZERO) -> void:
	stuck_recovery_phase = 1
	stuck_recovery_timer = 0.42
	stuck_reverse_timer = 0.0
	stuck_timer = 0.0
	spatial_stuck_timer = 0.0
	var road_pt = UrbanPathfinderClass.get_nearest_road_point(global_position)
	var to_road = road_pt - global_position
	to_road.y = 0.0
	if to_road.length_squared() > 0.1:
		stuck_recovery_dir = (to_road.normalized() * 0.75 + contact_normal * 0.65).normalized()
	else:
		stuck_recovery_dir = contact_normal if contact_normal.length_squared() > 0.1 else -transform.basis.z
	if has_node("/root/CombatDirector"):
		get_node("/root/CombatDirector").record_stuck_recovery()

## Ground vehicle steering with two-phase unstick, displacement watchdog, and wall sliding
func steer_ground_unit(desired_direction: Vector3, target_speed: float, delta: float) -> void:
	# --- 1. TWO-PHASE STUCK RECOVERY WATCHDOG ---
	if stuck_recovery_phase > 0:
		stuck_recovery_timer -= delta
		stuck_reverse_timer += delta

		if stuck_recovery_phase == 1:
			var rev_dir = -transform.basis.z
			rev_dir.y = 0.0
			if rev_dir.length_squared() < 0.01:
				rev_dir = -stuck_recovery_dir
			if wall_slide_dir.length_squared() > 0.01:
				rev_dir = (rev_dir * 0.70 + wall_slide_dir * 0.30).normalized()
			var rev_speed = maxf(target_speed, move_speed) * 0.70
			velocity.x = move_toward(velocity.x, rev_dir.x * rev_speed, 25.0 * delta)
			velocity.z = move_toward(velocity.z, rev_dir.z * rev_speed, 25.0 * delta)
			velocity.y = -15.0
			move_and_slide()

			if stuck_recovery_timer <= 0.0 or (stuck_reverse_timer > 0.20 and is_on_wall()):
				stuck_recovery_phase = 2
				stuck_recovery_timer = 0.55
				var road_pt = UrbanPathfinderClass.get_nearest_road_point(global_position)
				var to_road = road_pt - global_position
				to_road.y = 0.0
				if to_road.length_squared() > 0.1:
					stuck_recovery_dir = to_road.normalized()
				else:
					stuck_recovery_dir = -rev_dir
			return

		elif stuck_recovery_phase == 2:
			var target_yaw = atan2(-stuck_recovery_dir.x, -stuck_recovery_dir.z)
			rotation.y = rotate_toward(rotation.y, target_yaw, delta * 8.0)
			rotation.x = 0.0
			rotation.z = 0.0
			var fwd_rec = -transform.basis.z
			fwd_rec.y = 0.0
			fwd_rec = fwd_rec.normalized()
			var fwd_speed = maxf(target_speed, move_speed)
			velocity.x = move_toward(velocity.x, fwd_rec.x * fwd_speed, 25.0 * delta)
			velocity.z = move_toward(velocity.z, fwd_rec.z * fwd_speed, 25.0 * delta)
			velocity.y = -15.0
			move_and_slide()

			if stuck_recovery_timer <= 0.0:
				stuck_recovery_phase = 0
				stuck_timer = 0.0
				spatial_stuck_timer = 0.0
				nav_repath_timer = 0.0
				nav_path.clear()
				last_recorded_pos = global_position
			return

	if avoidance_latch_timer > 0.0:
		avoidance_latch_timer -= delta

	var horiz_des = Vector3(desired_direction.x, 0.0, desired_direction.z)
	var move_dir = Vector3.ZERO
	var active_speed = target_speed

	if horiz_des.length_squared() > 0.01:
		horiz_des = horiz_des.normalized()
		var probe_len = clampf(target_speed * 0.40, 3.5, 6.5)
		var avoid = get_avoidance_steering(horiz_des, probe_len)

		if avoid.length_squared() > 0.01:
			move_dir = (horiz_des * 1.5 + avoid).normalized()
			avoidance_latch_timer = 0.35
			avoidance_latch_dir = move_dir
		elif avoidance_latch_timer > 0.0:
			move_dir = (avoidance_latch_dir * 0.75 + horiz_des * 0.25).normalized()
		elif wall_slide_dir.length_squared() > 0.01 and stuck_timer > 0.05:
			move_dir = (horiz_des * 0.25 + wall_slide_dir * 0.75).normalized()
		else:
			move_dir = horiz_des
	else:
		if velocity.length_squared() > 0.5:
			move_dir = Vector3(velocity.x, 0.0, velocity.z).normalized()
			active_speed = maxf(target_speed, move_speed * 0.4)

	# --- REALISTIC VEHICLE DRIVING PHYSICS (No crab-walking sideways) ---
	var fwd = -transform.basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.01:
		fwd = Vector3.FORWARD
	else:
		fwd = fwd.normalized()

	if move_dir.length_squared() > 0.01:
		# 1. Steer chassis yaw towards move_dir
		var target_yaw = atan2(-move_dir.x, -move_dir.z)
		var turn_rate = 3.2 if is_heavy_attacker else 5.2
		rotation.y = rotate_toward(rotation.y, target_yaw, delta * turn_rate)
		rotation.x = 0.0
		rotation.z = 0.0

		fwd = -transform.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()

		# 2. Modulate drive speed by turn alignment: slow down during sharp turns
		var align = clampf(fwd.dot(move_dir), 0.0, 1.0)
		var drive_speed = active_speed * (0.35 + 0.65 * align)

		# 3. Accelerate forward along vehicle heading with realistic inertia
		var target_h_vel = fwd * drive_speed
		var accel = 18.0 if is_heavy_attacker else 28.0
		velocity.x = move_toward(velocity.x, target_h_vel.x, accel * delta)
		velocity.z = move_toward(velocity.z, target_h_vel.z, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 22.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 22.0 * delta)

	velocity.y = -15.0 # Keep on ground
	move_and_slide()

	# Spatial progress watchdog: detects wedging, incline stalls
	pos_check_timer -= delta
	if pos_check_timer <= 0.0:
		pos_check_timer = 0.20
		if last_recorded_pos != Vector3.ZERO:
			var h_dist = Vector2(global_position.x - last_recorded_pos.x, global_position.z - last_recorded_pos.z).length()
			# Exclude deliberate firing holds / slow crawl
			if active_speed > 2.5 and h_dist < 0.22 and behavior_state != BehaviorState.WINDUP:
				spatial_stuck_timer += 0.20
				if spatial_stuck_timer >= 0.38:
					var raw_norm = get_wall_normal() if is_on_wall() else Vector3.ZERO
					_trigger_ground_unstick(Vector3(raw_norm.x, 0.0, raw_norm.z).normalized())
					return
			else:
				spatial_stuck_timer = maxf(0.0, spatial_stuck_timer - 0.20)
		last_recorded_pos = global_position

	# Wall collision response & sliding
	if is_on_wall():
		var raw_norm = get_wall_normal()
		var wall_norm = Vector3(raw_norm.x, 0.0, raw_norm.z).normalized()
		if wall_norm.length_squared() > 0.05:
			var t1 = Vector3(-wall_norm.z, 0.0, wall_norm.x)
			var t2 = -t1
			var slide_tan = t1 if t1.dot(horiz_des) >= t2.dot(horiz_des) else t2
			if absf(slide_tan.dot(horiz_des)) < 0.05:
				slide_tan = t1 if (int(get_instance_id()) % 2 == 0) else t2

			wall_slide_dir = (slide_tan * 0.85 + wall_norm * 0.50).normalized()
			avoidance_latch_dir = wall_slide_dir
			avoidance_latch_timer = 0.40

			stuck_timer += delta
			if stuck_timer > 0.22:
				_trigger_ground_unstick(wall_norm)
				return
	else:
		wall_slide_dir = Vector3.ZERO
		stuck_timer = maxf(0.0, stuck_timer - delta * 2.0)

## Aerial craft steering with altitude safety floor, true roof clearance, and building avoidance
func steer_air_unit(desired_vel: Vector3, min_alt: float, max_alt: float, delta: float, facing_target: Vector3 = Vector3.INF) -> void:
	var horiz_vel = Vector3(desired_vel.x, 0.0, desired_vel.z)
	var h_speed = horiz_vel.length()
	var horiz_dir = horiz_vel.normalized() if h_speed > 0.5 else -global_transform.basis.z

	# Horizontal building avoidance
	if horiz_dir.length_squared() > 0.1:
		var avoid = get_avoidance_steering(horiz_dir, 24.0)
		if avoid.length_squared() > 0.01:
			var blended_h = (horiz_dir * 0.30 + avoid * 2.0).normalized()
			desired_vel.x = blended_h.x * maxf(h_speed, move_speed * 0.9)
			desired_vel.z = blended_h.z * maxf(h_speed, move_speed * 0.9)

	# 3D Probes: Forward elevated/downward whisker & true rooftop clearance (Mask 2)
	if roof_probe_timer <= 0 and is_inside_tree() and get_world_3d() != null:
		roof_probe_timer = 0.20 + randf_range(0.0, 0.04)
		cached_roof_height = -1000.0
		var space = get_world_3d().direct_space_state
		if space != null:
			var down_hit = _cast_probe(space, global_position, global_position + Vector3(0.0, -25.0, 0.0), 2)
			if not down_hit.is_empty():
				cached_roof_height = down_hit.get("position", Vector3.ZERO).y

			var fwd_hit = _cast_probe(space, global_position, global_position + horiz_dir * 28.0, 2)
			if not fwd_hit.is_empty():
				var fwd_pos: Vector3 = fwd_hit.get("position", Vector3.ZERO)
				var top_hit = _cast_probe(space, Vector3(fwd_pos.x, 60.0, fwd_pos.z), Vector3(fwd_pos.x, 0.0, fwd_pos.z), 2)
				if not top_hit.is_empty():
					cached_roof_height = maxf(cached_roof_height, top_hit.get("position", Vector3.ZERO).y)
				else:
					cached_roof_height = maxf(cached_roof_height, fwd_pos.y + 6.0)

			var fwd_up_hit = _cast_probe(space, global_position, global_position + horiz_dir * 28.0 + Vector3(0.0, 8.0, 0.0), 2)
			if not fwd_up_hit.is_empty():
				var up_pos: Vector3 = fwd_up_hit.get("position", Vector3.ZERO)
				var top_up_hit = _cast_probe(space, Vector3(up_pos.x, 60.0, up_pos.z), Vector3(up_pos.x, 0.0, up_pos.z), 2)
				if not top_up_hit.is_empty():
					cached_roof_height = maxf(cached_roof_height, top_up_hit.get("position", Vector3.ZERO).y)
				else:
					cached_roof_height = maxf(cached_roof_height, up_pos.y + 4.0)

	# Aggressive climb if near rooftop
	if global_position.y - cached_roof_height < 8.0:
		desired_vel.y = maxf(desired_vel.y, 25.0)

	# Altitude safety envelope
	if global_position.y < min_alt:
		desired_vel.y = maxf(desired_vel.y, 18.0)
	elif global_position.y > max_alt:
		desired_vel.y = minf(desired_vel.y, -10.0)

	velocity = velocity.lerp(desired_vel, delta * 5.0)
	move_and_slide()

	if is_on_wall():
		var wall_n = get_wall_normal()
		var horiz_n = Vector3(wall_n.x, 0.0, wall_n.z).normalized()
		velocity = horiz_n * 20.0 + Vector3.UP * 25.0
		desired_vel.y = maxf(desired_vel.y, 28.0)

	var current_h_vel = Vector3(velocity.x, 0.0, velocity.z)
	if current_h_vel.length_squared() > 1.0:
		# Fixed airframe guns track with the aircraft's existing yaw/bank controller.
		# Translational tactics stay independent; do not rotate a combined gun mesh.
		var facing: Vector3 = current_h_vel if facing_target == Vector3.INF else facing_target - global_position
		var target_yaw = atan2(-facing.x, -facing.z)
		rotation.y = rotate_toward(rotation.y, target_yaw, delta * 6.5)

		var target_pitch = clampf(-velocity.y / (h_speed + 0.1) * 0.45, -0.35, 0.35)
		rotation.x = rotate_toward(rotation.x, target_pitch, delta * 5.0)

		var yaw_diff = wrapf(target_yaw - rotation.y, -PI, PI)
		var target_roll = clampf(-yaw_diff * 1.5, -0.42, 0.42)
		rotation.z = rotate_toward(rotation.z, target_roll, delta * 6.0)

func _process_death_spiral(delta: float) -> void:
	death_crash_timer += delta
	death_smoke_timer += delta

	# Trail dark segmented smoke puffs
	if death_smoke_timer >= 0.12:
		death_smoke_timer = 0.0
		if has_node("/root/FXManager"):
			var fx = get_node("/root/FXManager")
			if fx.fragment_trail_emitter:
				fx.fragment_trail_emitter.spawn_smoke_puff(global_position + Vector3(0, 0.2, 0), 0.55, 1.0)

	rotate_y(spiral_angular_vel.y * delta)
	rotate_x(spiral_angular_vel.x * delta)
	velocity.y -= 25.0 * delta # Gravity fall
	move_and_slide()

	var has_hit_surface = is_on_floor() or get_slide_collision_count() > 0 or global_position.y <= 1.0
	var timed_out = death_crash_timer >= 2.5

	if has_hit_surface or timed_out:
		var contact_pos = global_position
		var contact_normal = Vector3.UP
		var is_surface = false

		if get_slide_collision_count() > 0:
			var col = get_slide_collision(0)
			contact_pos = col.get_position()
			contact_normal = col.get_normal()
			is_surface = true
		elif global_position.y <= 1.0:
			contact_pos = Vector3(global_position.x, 0.0, global_position.z)
			contact_normal = Vector3.UP
			is_surface = true
		elif is_on_floor():
			contact_pos = global_position
			contact_normal = get_floor_normal()
			is_surface = true
		elif timed_out:
			var space_state = get_world_3d().direct_space_state if is_inside_tree() and get_world_3d() else null
			if space_state:
				var ray_query = PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * 3.5, 2)
				var hit = space_state.intersect_ray(ray_query)
				if not hit.is_empty():
					contact_pos = hit.position
					contact_normal = hit.normal
					is_surface = true
				else:
					is_surface = false
			else:
				is_surface = false

		if has_node("/root/FXManager"):
			get_node("/root/FXManager").play_destruction(self, contact_pos, contact_normal, is_surface)
		_finalize_death()

func _on_destroyed(_data: RefCounted) -> void:
	_release_all_slots()
	clear_telegraph()

	if modifier == EnemyDataClass.ModifierType.EXPLOSIVE:
		_trigger_explosive_death()

	collision_layer = 0 # No longer blocks shots
	collision_mask = 0

	if not is_air_unit:
		# GROUND VEHICLE DESTRUCTION:
		# Ground vehicles do not tumble into the sky.
		# They detonate immediately with signature explosion and clear cleanly.
		current_state = EnemyState.DEAD
		behavior_state = BehaviorState.DEAD
		velocity = Vector3.ZERO

		if has_node("/root/FXManager"):
			get_node("/root/FXManager").play_destruction(self, global_position, Vector3.UP, true)

		# Hide visuals so the explosion is the focal point
		for c in get_children():
			if c is VisualInstance3D or c.name.begins_with("Visual") or c.name.begins_with("Model"):
				c.visible = false

		_finalize_death()
	else:
		# AIR UNIT DESTRUCTION:
		# Air vehicles enter a smoking, uncontrolled death tumble until ground impact.
		current_state = EnemyState.DEATH_SPIRAL
		behavior_state = BehaviorState.DEAD
		collision_mask = 2 # Collide only with environment (Layer 2)
		spiral_angular_vel = Vector3(randf_range(3.0, 6.0), randf_range(5.0, 10.0), 0.0)
		velocity = Vector3(randf_range(-8.0, 8.0), -5.0, randf_range(-8.0, 8.0))

func _finalize_death() -> void:
	current_state = EnemyState.DEAD
	behavior_state = BehaviorState.DEAD
	clear_telegraph()
	queue_free()

func _trigger_explosive_death() -> void:
	var space = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 26.0
	query.shape = sphere
	query.transform = global_transform
	query.collision_mask = 5 # Enemies + player
	var results = space.intersect_shape(query, 16)
	for r in results:
		var c = r.get("collider")
		if c and c != self and is_instance_valid(c):
			if c.has_method("take_damage"):
				if c.is_in_group("player"):
					c.take_damage(30.0, "Explosive Enemy", global_position)
				else:
					c.take_damage(30.0, "Explosive Enemy")

func _release_all_slots() -> void:
	if is_inside_tree() and has_node("/root/CombatDirector"):
		var cd = get_node("/root/CombatDirector")
		if has_air_slot:
			cd.release_air_attack_slot(self)
			has_air_slot = false
		if has_heavy_slot:
			cd.release_heavy_attack_slot(self)
			has_heavy_slot = false

func _exit_tree() -> void:
	clear_telegraph()
	_release_all_slots()
