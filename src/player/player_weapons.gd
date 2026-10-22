class_name PlayerWeapons
extends Node

## PlayerWeapons — Manages the 4 weapons, fire rates, reloads, magazine ammo,
## weapon mastery XP, mods, and projectile firing.

const DamageDataClass = preload("res://src/combat/damage_data.gd")
const ProjectileScene = preload("res://scenes/combat/projectile.tscn")

signal weapon_fired(weapon_id: int, ammo_left: int)
signal reload_started(weapon_id: int, duration: float)
signal reload_completed(weapon_id: int)
signal weapon_switched(weapon_id: int)
signal weapon_leveled_up(weapon_id: int, new_level: int)

var current_weapon_idx: int = GameConstants.WeaponType.MACHINE_GUN

# Weapon State: { current_ammo, is_reloading, reload_timer, fire_timer, xp, level, active_mod }
var weapon_states: Dictionary = {}

# Dynamic Upgrade Modifiers (supports RunProgression & Overdrive pickups)
var fire_rates: Dictionary = {
	GameConstants.WeaponType.MACHINE_GUN: 1.0,
	GameConstants.WeaponType.MISSILE: 1.0,
	GameConstants.WeaponType.ROCKET: 1.0,
	GameConstants.WeaponType.SHOTGUN: 1.0
}
var damage_multipliers: Dictionary = {
	GameConstants.WeaponType.MACHINE_GUN: 1.0,
	GameConstants.WeaponType.MISSILE: 1.0,
	GameConstants.WeaponType.ROCKET: 1.0,
	GameConstants.WeaponType.SHOTGUN: 1.0
}
var reload_multipliers: Dictionary = {
	GameConstants.WeaponType.MACHINE_GUN: 1.0,
	GameConstants.WeaponType.MISSILE: 1.0,
	GameConstants.WeaponType.ROCKET: 1.0,
	GameConstants.WeaponType.SHOTGUN: 1.0
}
var magazine_capacity_multipliers: Dictionary = {
	GameConstants.WeaponType.MACHINE_GUN: 1.0,
	GameConstants.WeaponType.MISSILE: 1.0,
	GameConstants.WeaponType.ROCKET: 1.0,
	GameConstants.WeaponType.SHOTGUN: 1.0
}
var has_vulcan_storm: bool = false
var has_phantom_tracking: bool = false
var permanent_emp_chance: float = 0.0
var overdrive_timer: float = 0.0
var subsystem_modifiers: Dictionary = {}
var magazine_capacity_additions: Dictionary = {}

@export var player_helicopter: CharacterBody3D

func get_max_ammo(w_type: int) -> int:
	var base_max: int = GameConstants.WEAPONS[w_type]["ammo_max"]
	var mult: float = magazine_capacity_multipliers.get(w_type, 1.0)
	return int(round(float(base_max) * mult)) + int(magazine_capacity_additions.get(w_type, 0))

func upgrade_weapon_magazine(w_type: int, multiplier_bonus: float = 0.0, flat_bonus: int = 0) -> void:
	var old_max := get_max_ammo(w_type)
	magazine_capacity_multipliers[w_type] = float(magazine_capacity_multipliers.get(w_type, 1.0)) * (1.0 + multiplier_bonus)
	magazine_capacity_additions[w_type] = int(magazine_capacity_additions.get(w_type, 0)) + flat_bonus
	if weapon_states.has(w_type):
		weapon_states[w_type].ammo = clampi(int(weapon_states[w_type].ammo) + get_max_ammo(w_type) - old_max, 0, get_max_ammo(w_type))

func get_subsystem_modifier(w_type: int, key: String) -> float:
	return float(subsystem_modifiers.get(w_type, {}).get(key, 0.0))

func apply_subsystem_upgrade(w_type: int, stats: Dictionary) -> void:
	var mods: Dictionary = subsystem_modifiers.get(w_type, {})
	var previous_interval := maxf(0.15, 1.0 - float(mods.get("interval_reduction", 0.0)))
	for key in stats:
		if stats[key] is bool:
			mods[key] = bool(mods.get(key, false)) or stats[key]
		else:
			mods[key] = float(mods.get(key, 0.0)) + float(stats[key])
	subsystem_modifiers[w_type] = mods
	damage_multipliers[w_type] += float(stats.get("damage_mult", 0.0))
	fire_rates[w_type] += float(stats.get("fire_rate_mult", 0.0))
	if stats.has("interval_reduction"):
		fire_rates[w_type] *= previous_interval / maxf(0.15, 1.0 - float(mods.interval_reduction))
	reload_multipliers[w_type] += float(stats.get("reload_speed_mult", 0.0))
	if stats.has("ammo_max_add") or stats.has("magazine_capacity_mult"):
		upgrade_weapon_magazine(w_type, float(stats.get("magazine_capacity_mult", 0.0)), int(stats.get("ammo_max_add", 0)))

func apply_subsystem_damage(w_type: int, data: RefCounted) -> void:
	data.blast_radius *= 1.0 + get_subsystem_modifier(w_type, "blast_radius_mult")
	data.armored_bonus += get_subsystem_modifier(w_type, "armor_pierce")
	data.structure_bonus += get_subsystem_modifier(w_type, "structure_damage_mult")
	data.burn_chance = clampf(data.burn_chance + get_subsystem_modifier(w_type, "burn_chance"), 0.0, 1.0)
	data.shock_chance = clampf(data.shock_chance + get_subsystem_modifier(w_type, "shock_chance"), 0.0, 1.0)
	data.cluster_count += mini(12, int(get_subsystem_modifier(w_type, "cluster_count")))
	data.lingering_fire = data.lingering_fire or bool(subsystem_modifiers.get(w_type, {}).get("lingering_burn", false))
	var emp_duration := get_subsystem_modifier(w_type, "emp_duration")
	if emp_duration > 0.0:
		data.emp_chance = 1.0
		data.emp_duration = emp_duration

func configure_subsystem_projectile(w_type: int, projectile: Node3D) -> void:
	projectile.velocity *= 1.0 + get_subsystem_modifier(w_type, "speed_mult")
	projectile.speed *= 1.0 + get_subsystem_modifier(w_type, "speed_mult")
	projectile.homing_turn_rate *= 1.0 + get_subsystem_modifier(w_type, "turn_speed_mult")

func upgrade_magazine_capacity(multiplier_bonus: float = 1.30) -> void:
	for w_type in weapon_states:
		var old_max = get_max_ammo(w_type)
		magazine_capacity_multipliers[w_type] = magazine_capacity_multipliers.get(w_type, 1.0) * multiplier_bonus
		var new_max = get_max_ammo(w_type)
		var bonus_rounds = new_max - old_max
		var current = weapon_states[w_type]["ammo"]
		if current == 0:
			weapon_states[w_type]["ammo"] = bonus_rounds
		else:
			weapon_states[w_type]["ammo"] = clampi(current + bonus_rounds, bonus_rounds, new_max)

func refill_all_ammo() -> void:
	for w_type in weapon_states:
		weapon_states[w_type]["ammo"] = get_max_ammo(w_type)
		weapon_states[w_type]["is_reloading"] = false
		weapon_states[w_type]["reload_timer"] = 0.0

func _init() -> void:
	_init_weapons()

func _ready() -> void:
	_init_weapons()
	_connect_event_bus()

func _init_weapons() -> void:
	for w_type in [GameConstants.WeaponType.MACHINE_GUN, GameConstants.WeaponType.MISSILE, GameConstants.WeaponType.ROCKET, GameConstants.WeaponType.SHOTGUN]:
		var current_ammo = get_max_ammo(w_type)
		if weapon_states.has(w_type):
			current_ammo = clampi(weapon_states[w_type]["ammo"], 0, get_max_ammo(w_type))
		weapon_states[w_type] = {
			"ammo": current_ammo,
			"is_reloading": false,
			"reload_timer": 0.0,
			"fire_timer": 0.0,
			"xp": 0,
			"level": 1,
			"active_mod": GameConstants.WeaponMod.NONE
		}

func _connect_event_bus() -> void:
	if is_inside_tree() and has_node("/root/EventBus"):
		get_node("/root/EventBus").entity_destroyed.connect(_on_entity_destroyed)

func _process(delta: float) -> void:
	_process_timers(delta)
	_handle_input()

func _process_timers(delta: float) -> void:
	if overdrive_timer > 0.0:
		overdrive_timer -= delta
	for w_type in weapon_states:
		var st = weapon_states[w_type]
		if st["fire_timer"] > 0.0:
			st["fire_timer"] -= delta
		if st["is_reloading"]:
			st["reload_timer"] -= delta
			if st["reload_timer"] <= 0.0:
				_complete_reload(w_type)

func _handle_input() -> void:
	if has_node("/root/UIFlow") and not get_node("/root/UIFlow").gameplay_input_allowed():
		return
	# Weapon Switching (1-4, mouse wheel)
	if Input.is_action_just_pressed("weapon_1"):
		switch_weapon(GameConstants.WeaponType.MACHINE_GUN)
	elif Input.is_action_just_pressed("weapon_2"):
		switch_weapon(GameConstants.WeaponType.MISSILE)
	elif Input.is_action_just_pressed("weapon_3"):
		switch_weapon(GameConstants.WeaponType.ROCKET)
	elif Input.is_action_just_pressed("weapon_4"):
		switch_weapon(GameConstants.WeaponType.SHOTGUN)
	elif Input.is_action_just_pressed("next_weapon"):
		switch_weapon((current_weapon_idx + 1) % 4)
	elif Input.is_action_just_pressed("prev_weapon"):
		switch_weapon((current_weapon_idx + 3) % 4)

	# Manual Reload (R)
	if Input.is_action_just_pressed("reload"):
		start_reload()

	# Fire Primary (Hold LMB)
	if Input.is_action_pressed("fire_primary"):
		try_fire()

func switch_weapon(new_idx: int) -> void:
	if not weapon_states.has(current_weapon_idx):
		_init_weapons()
	if new_idx == current_weapon_idx:
		return
	# Switching weapons cancels active reload (Page 6)
	var old_st = weapon_states[current_weapon_idx]
	if old_st["is_reloading"]:
		old_st["is_reloading"] = false
		old_st["reload_timer"] = 0.0

	current_weapon_idx = new_idx
	weapon_switched.emit(current_weapon_idx)
	if is_inside_tree() and has_node("/root/EventBus"):
		get_node("/root/EventBus").weapon_switched.emit(current_weapon_idx)

func try_fire() -> bool:
	if not weapon_states.has(current_weapon_idx):
		_init_weapons()
	var st = weapon_states[current_weapon_idx]
	if st["is_reloading"] or st["fire_timer"] > 0.0:
		return false

	if st["ammo"] <= 0:
		start_reload()
		return false

	# Consume ammo (infinite ammo during Overdrive)
	if overdrive_timer <= 0.0:
		st["ammo"] -= 1
	var cfg = GameConstants.WEAPONS[current_weapon_idx]
	
	# Apply mastery fire interval modifier (-9% per level above 1), fire rate upgrades, and overdrive
	var interval_mult = 1.0 - (float(st["level"] - 1) * GameConstants.WEAPON_LEVEL_INTERVAL_MULT)
	var rate_mult = fire_rates.get(current_weapon_idx, 1.0)
	if overdrive_timer > 0.0:
		rate_mult *= 2.0
	st["fire_timer"] = (cfg["interval"] * interval_mult) / maxf(rate_mult, 0.1)

	# Launch projectiles
	_launch_weapon_projectiles(current_weapon_idx, st)
	
	weapon_fired.emit(current_weapon_idx, st["ammo"])
	if is_inside_tree() and has_node("/root/EventBus"):
		get_node("/root/EventBus").weapon_fired.emit(current_weapon_idx, st["ammo"])

	# Auto reload if empty
	if st["ammo"] <= 0:
		start_reload()

	return true

func _launch_weapon_projectiles(w_type: int, st: Dictionary) -> void:
	var cfg = GameConstants.WEAPONS[w_type]
	var turret = player_helicopter.turret if player_helicopter else null
	if not is_inside_tree() or get_tree() == null or not turret:
		return

	# Calculate damage with mastery bonus (+18% per level above 1, +25% at lvl 5 for MG), upgrades, and overdrive
	var dmg = cfg["damage"] * (1.0 + float(st["level"] - 1) * GameConstants.WEAPON_LEVEL_DAMAGE_MULT)
	dmg *= damage_multipliers.get(w_type, 1.0)
	if overdrive_timer > 0.0:
		dmg *= 1.25
	if st["level"] >= 5 and w_type == GameConstants.WeaponType.MACHINE_GUN:
		dmg *= 1.25 # MG L5 signature
	elif st["level"] >= 5 and w_type == GameConstants.WeaponType.SHOTGUN:
		dmg *= 1.15 # Shotgun L5 signature

	# Projectile count (+1 at level 4, +1 extra for missile at level 5)
	var proj_count: int = cfg["projectile_count"]
	if st["level"] >= 4:
		proj_count += 1
	if st["level"] >= 5 and w_type == GameConstants.WeaponType.MISSILE:
		proj_count += 1
	if has_vulcan_storm and w_type == GameConstants.WeaponType.MACHINE_GUN:
		proj_count = 2 # Twin-rotary dual bullet stream
	proj_count += mini(12, int(get_subsystem_modifier(w_type, "projectile_count")))

	var blast_rad: float = cfg["blast_radius"]
	if st["level"] >= 5 and w_type == GameConstants.WeaponType.ROCKET:
		blast_rad = maxf(blast_rad, 40.0) # Rocket L5 signature

	# Recoil shove (Rocket)
	if "recoil_shove" in cfg and player_helicopter:
		var shove_dir = turret.get_aim_direction()
		player_helicopter.velocity -= shove_dir * cfg["recoil_shove"]

	# Spawn projectiles
	var muzzle_tf = turret.get_active_muzzle_transform()
	var base_aim_dir = turret.get_aim_direction()

	var profile_id: String = "player_mg"
	match w_type:
		GameConstants.WeaponType.MACHINE_GUN:
			profile_id = "player_mg"
		GameConstants.WeaponType.SHOTGUN:
			profile_id = "player_shotgun"
		GameConstants.WeaponType.MISSILE:
			profile_id = "player_missile"
		GameConstants.WeaponType.ROCKET:
			profile_id = "player_rocket"

	# Exactly one muzzle burst per trigger pull, reusing the active muzzle transform
	if has_node("/root/FXManager"):
		get_node("/root/FXManager").play_muzzle(profile_id, muzzle_tf, turret, base_aim_dir)

	for i in range(proj_count):
		var p = ProjectileScene.instantiate()
		var aim_dir = base_aim_dir
		
		# Spread calculation
		if cfg["spread"] > 0.0:
			var spread_angle = cfg["spread"] * (0.55 if st["active_mod"] == GameConstants.WeaponMod.SHOTGUN_SLUG else 1.0)
			aim_dir += Vector3(
				randf_range(-spread_angle, spread_angle),
				randf_range(-spread_angle, spread_angle),
				randf_range(-spread_angle, spread_angle)
			)
			aim_dir = aim_dir.normalized()

		# Critical hit roll (20% base chance, 1.75x damage)
		var is_crit: bool = (randf() < 0.20)
		var effective_dmg: float = dmg * (1.75 if is_crit else 1.0)
		var p_data = DamageDataClass.new(effective_dmg, w_type, player_helicopter, false, blast_rad)
		p_data.is_crit = is_crit
		
		# Check active mods
		_apply_mods_to_damage(w_type, st["active_mod"], p_data)
		apply_subsystem_damage(w_type, p_data)

		get_tree().root.add_child(p)
		p.global_transform = muzzle_tf
		p.velocity = aim_dir * cfg["speed"]
		var target_node: Node3D = null
		if turret and is_instance_valid(turret.current_target_node) and turret.current_target_node is Node3D:
			target_node = turret.current_target_node
		p.setup(p_data, target_node, profile_id)
		configure_subsystem_projectile(w_type, p)

func _apply_mods_to_damage(_w_type: int, active_mod: int, p_data: RefCounted) -> void:
	if _w_type == GameConstants.WeaponType.MACHINE_GUN:
		p_data.emp_chance = permanent_emp_chance
	match active_mod:
		GameConstants.WeaponMod.MG_INCENDIARY:
			p_data.burn_chance = 0.18
		GameConstants.WeaponMod.ROCKET_NAPALM:
			p_data.blast_radius *= 1.30
			p_data.burn_chance = 0.40
			p_data.lingering_fire = true
		GameConstants.WeaponMod.SHOTGUN_SHOCK:
			p_data.shock_chance = 0.25
		GameConstants.WeaponMod.MG_PIERCING:
			p_data.armored_bonus = 0.35
		GameConstants.WeaponMod.ROCKET_SHAPED:
			p_data.armored_bonus = 0.45
			p_data.structure_bonus = 0.45
		GameConstants.WeaponMod.MISSILE_CLUSTER:
			p_data.cluster_count = 3
		GameConstants.WeaponMod.SHOTGUN_SLUG:
			p_data.raw_damage *= 1.30
		GameConstants.WeaponMod.MISSILE_EMP:
			p_data.emp_chance = 1.0

func start_reload() -> void:
	if not weapon_states.has(current_weapon_idx):
		_init_weapons()
	var st = weapon_states[current_weapon_idx]
	var cfg = GameConstants.WEAPONS[current_weapon_idx]
	if st["is_reloading"] or st["ammo"] >= get_max_ammo(current_weapon_idx):
		return

	st["is_reloading"] = true
	var reload_mult = 1.0 - (float(st["level"] - 1) * GameConstants.WEAPON_LEVEL_RELOAD_MULT)
	var speed_mult = reload_multipliers.get(current_weapon_idx, 1.0)
	st["reload_timer"] = (cfg["reload_time"] * maxf(0.5, reload_mult)) / maxf(speed_mult, 0.1)
	reload_started.emit(current_weapon_idx, st["reload_timer"])

func activate_overdrive(duration: float = 8.0) -> void:
	overdrive_timer = maxf(overdrive_timer, duration)
	refill_all_ammo()

func _complete_reload(w_type: int) -> void:
	var st = weapon_states[w_type]
	st["is_reloading"] = false
	st["ammo"] = get_max_ammo(w_type)
	reload_completed.emit(w_type)
	if is_inside_tree() and has_node("/root/EventBus"):
		get_node("/root/EventBus").weapon_reloaded.emit(w_type)

func _on_entity_destroyed(_entity: Node, killer_weapon: String, _score: int, _xp: int) -> void:
	# Award 1 Weapon XP strictly to the weapon that scored the kill! (Page 7)
	for w_type in weapon_states:
		var cfg = GameConstants.WEAPONS[w_type]
		if cfg["name"] == killer_weapon:
			var st = weapon_states[w_type]
			st["xp"] += 1
			_check_weapon_level_up(w_type, st)
			break

func _check_weapon_level_up(w_type: int, st: Dictionary) -> void:
	var curr_lvl = st["level"]
	if curr_lvl < 5:
		var next_thresh = GameConstants.WEAPON_XP_THRESHOLDS[curr_lvl]
		if st["xp"] >= next_thresh:
			st["level"] += 1
			weapon_leveled_up.emit(w_type, st["level"])
			if player_helicopter and st["level"] == 5:
				player_helicopter.max_hull += 10.0 # L5 signature hull bonus
				player_helicopter.repair(10.0)
