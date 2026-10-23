class_name DamageReceiver
extends Node

## DamageReceiver — Manages health, shields, damage affinities, armor reduction,
## status effects (Burn, EMP, Shock), and single-settlement death logic.

const DamageDataClass = preload("res://src/combat/damage_data.gd")

signal damaged(amount: float, remaining_hp: float, data: RefCounted)
signal healed(amount: float, remaining_hp: float)
signal destroyed(data: RefCounted)
signal status_applied(status_name: String, duration: float)

@export var max_health: float = 100.0
@export var target_affinity: int = GameConstants.TargetAffinity.LIGHT
@export var armor_mitigation: float = 0.0 # Capped at 0.24 (24%)

var current_health: float = 100.0
var shield_health: float = 0.0
var is_dead: bool = false
var last_damage_taken: float = 0.0
var last_hit_was_crit: bool = false
var last_damage_data: RefCounted = null

# Status Timers
var burn_timer: float = 0.0
var burn_tick_timer: float = 0.0
var burn_attacker_data: RefCounted = null

var emp_timer: float = 0.0
var is_emp_disabled: bool = false

var shock_timer: float = 0.0
var is_shocked: bool = false

func _ready() -> void:
	current_health = max_health
	set_process(burn_timer > 0 or emp_timer > 0 or shock_timer > 0)

func _process(delta: float) -> void:
	if is_dead:
		set_process(false)
		return
	_process_statuses(delta)
	if burn_timer <= 0 and emp_timer <= 0 and shock_timer <= 0:
		set_process(false)

func take_damage(data: RefCounted) -> float:
	if is_dead:
		return 0.0
	last_damage_data = data

	# 1. Calculate Affinity Multiplier
	var mult: float = 1.0
	var w_type: int = data.weapon_type if "weapon_type" in data else 0
	if GameConstants.DAMAGE_AFFINITY_MATRIX.has(w_type):
		var aff_table: Dictionary = GameConstants.DAMAGE_AFFINITY_MATRIX[w_type]
		if aff_table.has(target_affinity):
			mult = aff_table[target_affinity]

	var effective_damage: float = (data.raw_damage if "raw_damage" in data else 10.0) * mult

	if "armored_bonus" in data and target_affinity in [GameConstants.TargetAffinity.ARMORED, GameConstants.TargetAffinity.BOSS_CORE]:
		effective_damage *= 1.0 + data.armored_bonus
	if "structure_bonus" in data and target_affinity == GameConstants.TargetAffinity.STRUCTURE:
		effective_damage *= 1.0 + data.structure_bonus
	# 2. Armor Mitigation (Capped at 24%)
	var capped_armor: float = clampf(armor_mitigation, 0.0, GameConstants.MAX_ARMOR_MITIGATION)
	effective_damage *= (1.0 - capped_armor)

	# 3. Shield absorption first (Page 10)
	if shield_health > 0.0:
		if shield_health >= effective_damage:
			shield_health -= effective_damage
			effective_damage = 0.0
		else:
			effective_damage -= shield_health
			shield_health = 0.0

	# 4. Apply to Health
	current_health -= effective_damage
	var is_lethal: bool = current_health <= 0.0
	damaged.emit(effective_damage, current_health, data)

	var is_crit: bool = (data != null and "is_crit" in data and data.is_crit)
	last_damage_taken = effective_damage
	last_hit_was_crit = is_crit
	var parent_node = get_parent()

	# Emit to EventBus for combo tracking, audio, and systems
	if is_inside_tree() and has_node("/root/EventBus"):
		var w_name: String = "Weapon"
		if data != null and "weapon_type" in data:
			w_name = GameConstants.WEAPONS.get(data.weapon_type, {}).get("name", "Weapon")
		get_node("/root/EventBus").damage_dealt.emit(parent_node, effective_damage, w_name, is_lethal)

	# Spawn floating combat damage numbers for non-lethal hits
	# (Lethal hits trigger the compliment + kill damage popup sequence on death)
	if is_inside_tree() and has_node("/root/FXManager") and effective_damage > 0.0 and not is_lethal:
		var hit_pos: Vector3 = Vector3.ZERO
		if parent_node is Node3D:
			hit_pos = (parent_node as Node3D).global_position + Vector3(0, 1.2, 0)
		get_node("/root/FXManager").spawn_damage_number(hit_pos, effective_damage, is_crit)

	# Check Status Procs
	_check_status_procs(data)

	# 5. Death Settlement (Atomic, once-only)
	if is_lethal:
		current_health = 0.0
		is_dead = true
		destroyed.emit(data)
		_notify_event_bus(data)

	return effective_damage

func _check_status_procs(data: RefCounted) -> void:
	if "burn_chance" in data and data.burn_chance > 0.0 and randf() < data.burn_chance:
		apply_burn(GameConstants.STATUS_BURN_DURATION, data)
	if "emp_chance" in data and data.emp_chance > 0.0 and randf() < data.emp_chance:
		apply_emp(data.emp_duration if "emp_duration" in data else GameConstants.STATUS_EMP_DURATION)
	if "shock_chance" in data and data.shock_chance > 0.0 and randf() < data.shock_chance:
		apply_shock(GameConstants.STATUS_SHOCK_DURATION)

func apply_burn(duration: float, source_data: RefCounted) -> void:
	set_process(true)
	burn_timer = duration
	burn_attacker_data = source_data
	status_applied.emit("burn", duration)

func apply_emp(duration: float) -> void:
	set_process(true)
	emp_timer = duration
	is_emp_disabled = true
	status_applied.emit("emp", duration)

func apply_shock(duration: float) -> void:
	set_process(true)
	shock_timer = duration
	is_shocked = true
	status_applied.emit("shock", duration)

func _process_statuses(delta: float) -> void:
	# Burn processing (14 dmg/s)
	if burn_timer > 0.0:
		burn_timer -= delta
		burn_tick_timer += delta
		if burn_tick_timer >= 0.25: # Tick 4 times a second
			burn_tick_timer = 0.0
			var tick_dmg: float = GameConstants.STATUS_BURN_DPS * 0.25
			current_health -= tick_dmg
			damaged.emit(tick_dmg, current_health, burn_attacker_data)
			if is_inside_tree() and has_node("/root/FXManager") and tick_dmg > 0.0:
				var parent_node = get_parent()
				var h_pos: Vector3 = (parent_node as Node3D).global_position + Vector3(0, 1.2, 0) if parent_node is Node3D else Vector3.ZERO
				get_node("/root/FXManager").spawn_damage_number(h_pos, tick_dmg, false)
			if current_health <= 0.0 and not is_dead:
				current_health = 0.0
				is_dead = true
				destroyed.emit(burn_attacker_data)
				_notify_event_bus(burn_attacker_data)

	# EMP processing
	if emp_timer > 0.0:
		emp_timer -= delta
		if emp_timer <= 0.0:
			is_emp_disabled = false

	# Shock processing
	if shock_timer > 0.0:
		shock_timer -= delta
		if shock_timer <= 0.0:
			is_shocked = false

func heal(amount: float) -> void:
	if is_dead:
		return
	current_health = minf(max_health, current_health + amount)
	healed.emit(amount, current_health)

func _notify_event_bus(data: RefCounted) -> void:
	if is_inside_tree() and has_node("/root/EventBus"):
		var w_name: String = "Unknown"
		if data != null and "weapon_type" in data:
			w_name = GameConstants.WEAPONS.get(data.weapon_type, {}).get("name", "Weapon")
		var is_enemy: bool = get_parent() != null and get_parent().is_in_group("enemies")
		var score_val: int = 50 if is_enemy else 25
		if is_enemy and "score_value" in get_parent():
			score_val = maxi(0, int(get_parent().score_value))
		# Physical XP gems dropped by LootManager govern in-run leveling; emit 0 direct XP to avoid double attribution
		get_node("/root/EventBus").entity_destroyed.emit(get_parent(), w_name, score_val, 0)
