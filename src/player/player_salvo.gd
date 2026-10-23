class_name PlayerSalvo
extends Node

## PlayerSalvo — Implements the 6-lock painted salvo missile system (Page 7).

const DamageDataClass = preload("res://src/combat/damage_data.gd")
const ProjectileScene = preload("res://scenes/combat/projectile.tscn")

signal lock_acquired(target: Node3D, target_locks: int, total_locks: int)
signal locks_cleared()
signal salvo_fired(missile_count: int)

@export var player_helicopter: CharacterBody3D

var current_locks: Array = []
var paint_timer: float = 0.0
var cooldown_timer: float = 0.0
var cooldown_duration: float = GameConstants.SALVO_BASE_COOLDOWN
var is_painting: bool = false
var paint_speed_multiplier: float = 1.0
var lock_range_multiplier: float = 1.0
var max_locks: int = GameConstants.SALVO_MAX_LOCKS
var extra_missiles: int = 0

func apply_subsystem_upgrade(stats: Dictionary) -> void:
	max_locks += int(stats.get("max_locks_add", 0))
	extra_missiles += int(stats.get("missile_count_add", 0))
	if stats.has("cooldown_reduction"):
		cooldown_duration = maxf(0.5, cooldown_duration * (1.0 - float(stats.cooldown_reduction)))
		cooldown_timer = minf(cooldown_timer, cooldown_duration)
	if stats.has("paint_interval_reduction"):
		paint_speed_multiplier /= maxf(0.15, 1.0 - float(stats.paint_interval_reduction))
	lock_range_multiplier += float(stats.get("lock_range_mult", 0.0))

func _process(delta: float) -> void:
	if has_node("/root/UIFlow") and not get_node("/root/UIFlow").gameplay_input_allowed():
		return
	if cooldown_timer > 0.0:
		cooldown_timer -= delta

	# Clean up any dead targets from lock array
	_cleanup_locks()

	# Process input
	if Input.is_action_pressed("paint_salvo"):
		if cooldown_timer <= 0.0:
			is_painting = true
			paint_timer -= delta
			if paint_timer <= 0.0:
				paint_timer = GameConstants.SALVO_PAINT_INTERVAL / paint_speed_multiplier
				_attempt_paint_lock()
	elif Input.is_action_just_released("paint_salvo"):
		if is_painting:
			is_painting = false
			_fire_salvo()

func _attempt_paint_lock() -> void:
	if current_locks.size() >= max_locks:
		return

	var turret = player_helicopter.turret if player_helicopter else null
	if not turret:
		return

	var aim_center: Vector3 = turret.target_world_pos
	var candidate = _find_valid_lock_target(aim_center)
	if candidate != null:
		current_locks.append(candidate)
		var per_target = _count_locks_for_target(candidate)
		lock_acquired.emit(candidate, per_target, current_locks.size())
		if is_inside_tree() and has_node("/root/EventBus"):
			get_node("/root/EventBus").salvo_lock_added.emit(candidate, per_target)

func _find_valid_lock_target(aim_center: Vector3) -> Node3D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	enemies.append_array(get_tree().get_nodes_in_group("hostile_mission_targets"))
	var best_enemy: Node3D = null
	var min_dist: float = GameConstants.SALVO_SEARCH_RADIUS * lock_range_multiplier

	for e in enemies:
		if e is Node3D and is_instance_valid(e):
			# Enforce max 3 locks on same target
			if _count_locks_for_target(e) >= GameConstants.SALVO_MAX_PER_TARGET:
				continue
			var d = aim_center.distance_to(e.global_position)
			if d < min_dist:
				min_dist = d
				best_enemy = e
	return best_enemy

func _count_locks_for_target(target: Node3D) -> int:
	var count = 0
	for l in current_locks:
		if is_instance_valid(l) and l == target:
			count += 1
	return count

func _cleanup_locks() -> void:
	var valid_locks: Array = []
	for l in current_locks:
		if is_instance_valid(l) and l is Node3D:
			# Also ensure not dead
			var rec = l.get_node_or_null("DamageReceiver")
			if rec == null or not rec.is_dead:
				valid_locks.append(l)
	current_locks = valid_locks

func _fire_salvo() -> void:
	_cleanup_locks()
	if not is_inside_tree() or get_tree() == null or current_locks.size() == 0:
		return

	var launch_targets: Array = current_locks.duplicate()
	for index in range(mini(extra_missiles, 12)):
		launch_targets.append(current_locks[index % current_locks.size()])
	var salvo_count = launch_targets.size()
	cooldown_timer = cooldown_duration

	var turret = player_helicopter.turret if player_helicopter else null
	var spawn_tf = turret.get_active_muzzle_transform() if turret else player_helicopter.global_transform

	# Play one coalesced muzzle flash for the salvo swarm
	if has_node("/root/FXManager"):
		var aim_fwd = -player_helicopter.global_transform.basis.z if player_helicopter else Vector3.FORWARD
		get_node("/root/FXManager").play_muzzle("player_salvo", spawn_tf, player_helicopter, aim_fwd)

	for target in launch_targets:
		if not is_instance_valid(target) or not (target is Node3D):
			continue
		var p = ProjectileScene.instantiate()
		var is_salvo_crit: bool = (randf() < 0.25)
		var salvo_dmg: float = GameConstants.SALVO_MISSILE_DAMAGE * (1.75 if is_salvo_crit else 1.0)
		var p_data = DamageDataClass.new(
			salvo_dmg,
			GameConstants.WeaponType.MISSILE,
			player_helicopter,
			true,
			GameConstants.SALVO_MISSILE_BLAST_RADIUS
		)
		p_data.is_crit = is_salvo_crit
		var weapons = player_helicopter.get_node_or_null("Weapons")
		if weapons:
			p_data.raw_damage *= weapons.damage_multipliers[GameConstants.WeaponType.MISSILE]
			weapons._apply_mods_to_damage(GameConstants.WeaponType.MISSILE, weapons.weapon_states[GameConstants.WeaponType.MISSILE].active_mod, p_data)
			weapons.apply_subsystem_damage(GameConstants.WeaponType.MISSILE, p_data)
		
		get_tree().root.add_child(p)
		p.global_transform = spawn_tf
		p.speed = GameConstants.SALVO_MISSILE_SPEED
		p.is_homing = true
		p.homing_turn_rate = 8.0
		# Add initial upward/outward spread arc
		var arc_dir = (-player_helicopter.global_transform.basis.z + Vector3(randf_range(-0.5, 0.5), randf_range(0.3, 0.8), randf_range(-0.5, 0.5))).normalized()
		p.velocity = arc_dir * p.speed
		p.setup(p_data, target, "player_salvo")
		if weapons:
			weapons.configure_subsystem_projectile(GameConstants.WeaponType.MISSILE, p)

	current_locks.clear()
	locks_cleared.emit()
	salvo_fired.emit(salvo_count)
	if is_inside_tree() and has_node("/root/EventBus"):
		get_node("/root/EventBus").salvo_launched.emit(salvo_count)

func add_target_lock(target: Node3D) -> void:
	if is_instance_valid(target) and current_locks.size() < max_locks and _count_locks_for_target(target) < GameConstants.SALVO_MAX_PER_TARGET:
		current_locks.append(target)

func launch_salvo() -> void:
	_fire_salvo()

