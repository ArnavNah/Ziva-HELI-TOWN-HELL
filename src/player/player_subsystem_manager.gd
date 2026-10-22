class_name PlayerSubsystemManager
extends Node

## Resource payloads modify the real controllers; the ledger is a readout.
signal upgrade_applied(card: UpgradeCard)
@export var player_helicopter: CharacterBody3D = null
@export var unlocked_subsystems: Array[int] = [0, 1, 2, 3]
var applied_cards: Array = []
var card_stacks: Dictionary = {}
var active_stats: Dictionary = {
	"luck_level": 0.0, "magnet_radius_mult": 1.0,
	"cannon_damage_mult": 1.0, "cannon_fire_rate_mult": 1.0,
	"rocket_damage_mult": 1.0, "rocket_blast_mult": 1.0,
	"missile_damage_mult": 1.0, "missile_max_locks": 6,
	"salvo_cooldown_mult": 1.0, "hull_regen_rate": 0.0
}

func _ready() -> void:
	if not player_helicopter and get_parent() is CharacterBody3D:
		player_helicopter = get_parent()

func get_luck_level() -> float:
	return active_stats.luck_level

func is_card_eligible(card: UpgradeCard) -> bool:
	if not card or card.target_subsystem not in unlocked_subsystems:
		return false
	var xp = get_node_or_null("/root/XpManager")
	if xp and xp.current_level < card.min_level:
		return false
	if card.max_stacks > 0 and int(card_stacks.get(card.card_id, 0)) >= card.max_stacks:
		return false
	for required in card.required_cards:
		if int(card_stacks.get(required, 0)) == 0:
			return false
	return true

func apply_upgrade(card: UpgradeCard) -> bool:
	var heli = _get_heli_node()
	if not heli or not is_card_eligible(card):
		return false
	var stats: Dictionary = card.stat_changes
	if card.target_subsystem == UpgradeCard.SubsystemType.GLOBAL_TOME:
		_apply_global_tome_upgrade(stats, heli)
	else:
		var weapons = heli.get_node_or_null("Weapons")
		if not weapons:
			return false
		var weapon_type := GameConstants.WeaponType.MACHINE_GUN
		if card.target_subsystem == UpgradeCard.SubsystemType.ROCKET_PODS:
			weapon_type = GameConstants.WeaponType.ROCKET
		elif card.target_subsystem == UpgradeCard.SubsystemType.GUIDED_MISSILES:
			weapon_type = GameConstants.WeaponType.MISSILE
		weapons.apply_subsystem_upgrade(weapon_type, stats)
		if weapon_type == GameConstants.WeaponType.MISSILE:
			var salvo = heli.get_node_or_null("Salvo")
			if salvo:
				salvo.apply_subsystem_upgrade(stats)
				active_stats.missile_max_locks = salvo.max_locks
				active_stats.salvo_cooldown_mult = salvo.cooldown_duration / GameConstants.SALVO_BASE_COOLDOWN
			active_stats.missile_damage_mult = weapons.damage_multipliers[weapon_type]
		elif weapon_type == GameConstants.WeaponType.ROCKET:
			active_stats.rocket_damage_mult = weapons.damage_multipliers[weapon_type]
			active_stats.rocket_blast_mult = 1.0 + weapons.get_subsystem_modifier(weapon_type, "blast_radius_mult")
		else:
			active_stats.cannon_damage_mult = weapons.damage_multipliers[weapon_type]
			active_stats.cannon_fire_rate_mult = weapons.fire_rates[weapon_type]
	applied_cards.append(card)
	card_stacks[card.card_id] = int(card_stacks.get(card.card_id, 0)) + 1
	upgrade_applied.emit(card)
	return true

func _apply_global_tome_upgrade(stats: Dictionary, heli: CharacterBody3D) -> void:
	active_stats.luck_level += float(stats.get("luck_level_add", 0.0))
	if stats.has("magnet_radius_mult"):
		active_stats.magnet_radius_mult += float(stats.magnet_radius_mult)
		heli.update_magnet_sensor_radius(active_stats.magnet_radius_mult)
	if stats.has("xp_gain_mult") and has_node("/root/XpManager"):
		get_node("/root/XpManager").xp_multiplier += float(stats.xp_gain_mult)
	if stats.has("speed_mult"):
		heli.cruise_speed *= 1.0 + float(stats.speed_mult)
	if stats.has("drag_mult"):
		heli.drag_multiplier = maxf(0.35, heli.drag_multiplier + float(stats.drag_mult))
	if stats.has("dash_cooldown_reduction"):
		heli.dash_cooldown_reduction += GameConstants.DASH_BASE_COOLDOWN * float(stats.dash_cooldown_reduction)
	if stats.has("armor_mitigation_add"):
		heli.armor_mitigation = minf(GameConstants.MAX_ARMOR_MITIGATION, heli.armor_mitigation + float(stats.armor_mitigation_add))
	if stats.has("max_hull_add"):
		heli.max_hull += float(stats.max_hull_add)
		heli.repair(float(stats.max_hull_add))
	if stats.has("repair_hull"):
		heli.repair(float(stats.repair_hull))
	active_stats.hull_regen_rate += float(stats.get("hull_regen", 0.0))
	if stats.has("evasion"):
		heli.evasion_chance = clampf(heli.evasion_chance + float(stats.evasion), 0.0, 0.75)
	if stats.has("shield_capacity_add") or stats.has("shield_duration_add"):
		heli.shield_capacity_bonus += float(stats.get("shield_capacity_add", 0.0))
		heli.shield_duration_bonus += float(stats.get("shield_duration_add", 0.0))
		heli.activate_shield(0.0)

func _process(delta: float) -> void:
	var regen: float = active_stats.hull_regen_rate
	var heli = _get_heli_node()
	if regen > 0.0 and heli and not heli.is_dying and heli.current_hull < heli.max_hull:
		heli.repair(regen * delta)

func _get_heli_node() -> CharacterBody3D:
	if is_instance_valid(player_helicopter):
		return player_helicopter
	if get_parent() is CharacterBody3D:
		player_helicopter = get_parent()
	elif is_inside_tree():
		player_helicopter = get_tree().get_first_node_in_group("player") as CharacterBody3D
	return player_helicopter
