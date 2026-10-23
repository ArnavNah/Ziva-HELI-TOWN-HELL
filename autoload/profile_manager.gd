extends Node

## ProfileManager — Authoritative persistent user profile, hangar upgrades, pilot perks,
## and JSON save/load system (Page 19, 20 & 35).

const Storage = preload("res://src/ui/menus/game_storage.gd")
const Specs = preload("res://data/aircraft_specs.gd")
var SAVE_PATH: String = Storage.path_for("heli_town_profile.json")
var selected_aircraft_id: String = "apache"
var last_error: String = ""
var profile_valid: bool = true
var _transaction_locked: bool = false
var recorded_run_ids: Array[String] = []
signal profile_changed
signal save_failed(message: String)

# Wallet
var wallet_credits: int = 150 # New profiles receive a one-time 150-credit grant (Page 3)
var banked_credits: int:
	get: return wallet_credits
	set(v): wallet_credits = v
var salvage: int = 0
var high_score: int = 0
var high_scores: Array[Dictionary] = []
const MAX_HIGH_SCORES: int = 10

# 8 Hangar Systems (Page 19)
# Prices: rank 1 to 5
const HANGAR_PRICES: Dictionary = {
	"engine": [190, 460, 810, 1240, 1740],
	"rotor": [180, 440, 780, 1180, 1660],
	"armor": [210, 510, 880, 1330, 1850],
	"airframe": [195, 480, 840, 1280, 1780],
	"fuel": [200, 490, 860, 1300, 1800],
	"targeting": [195, 480, 860, 1320, 1840],
	"weapon_system": [220, 540, 930, 1400, 1930],
	"countermeasures": [170, 430, 780, 1230, 1830]
}

var hangar_ranks: Dictionary = {
	"engine": 0, "rotor": 0, "armor": 0, "airframe": 0,
	"fuel": 0, "targeting": 0, "weapon_system": 0, "countermeasures": 0
}

# 8 Pilot Perks (Page 20)
const PERK_PRICES: Dictionary = {
	"magnet_radius": [100, 220, 420, 700, 1100],
	"vector_thrusters": [110, 240, 450, 750, 1150],
	"scavenger_rig": [120, 260, 480, 800, 1200],
	"rotor_armor": [130, 280, 500, 820, 1250],
	"combat_computer": [130, 280, 500, 820, 1250],
	"lean_burn": [100, 220, 420, 700, 1100],
	"devastator_core": [140, 300, 520, 850, 1300],
	"emp_rounds": [140, 300, 520, 850, 1300]
}

var perk_ranks: Dictionary = {
	"magnet_radius": 0, "vector_thrusters": 0, "scavenger_rig": 0, "rotor_armor": 0,
	"combat_computer": 0, "lean_burn": 0, "devastator_core": 0, "emp_rounds": 0
}

# Weapon Mods Selected (0 = None, 1 = Mod A, 2 = Mod B)
var equipped_mods: Dictionary = {
	GameConstants.WeaponType.MACHINE_GUN: GameConstants.WeaponMod.NONE,
	GameConstants.WeaponType.MISSILE: GameConstants.WeaponMod.NONE,
	GameConstants.WeaponType.ROCKET: GameConstants.WeaponMod.NONE,
	GameConstants.WeaponType.SHOTGUN: GameConstants.WeaponMod.NONE
}

# Achievements & Records
var unlocked_achievements: Array[String] = []
var run_history: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_profile()
	get_node("/root/GameManager").selected_aircraft = selected_aircraft_id
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").run_completed.connect(_on_run_completed)

func _on_run_completed(_success: bool, summary: Dictionary) -> void:
	record_run(summary)

func record_run(summary: Dictionary) -> Dictionary:
	var identity: String = summary.get("run_id", "")
	if not identity.is_empty() and recorded_run_ids.has(identity):
		return {"duplicate": true}
	if not profile_valid:
		return {"error": last_error}
	var previous := {"wallet": wallet_credits, "salvage": salvage, "high": high_score, "scores": high_scores.duplicate(true), "history": run_history.duplicate(true)}
	if not identity.is_empty():
		recorded_run_ids.append(identity)
	var payout: int = maxi(0, int(summary.get("total_payout", 0)))
	wallet_credits += payout
	var s_salvage: int = maxi(0, int(summary.get("salvage", 0))) if summary.get("successful", false) else 0
	salvage += s_salvage
	var s: int = summary.get("score", 0)
	var prev_high: int = high_score
	var is_new_high: bool = s > high_score and s > 0
	if is_new_high:
		high_score = s
	
	# Leaderboard Record
	var rank_achieved: int = -1
	if s > 0:
		var raw_aircraft: String = summary.get("selected_aircraft", "apache")
		var entry: Dictionary = {
			"entry_id": identity if not identity.is_empty() else str(Time.get_ticks_usec()),
			"score": s,
			"aircraft": raw_aircraft.to_upper(),
			"wave": summary.get("wave_reached", 1),
			"kills": summary.get("kills", 0),
			"time_seconds": summary.get("survival_time", 0.0),
			"outcome": "EXTRACTED" if summary.get("successful", false) else "KIA",
			"date": Time.get_datetime_string_from_system(false, true).substr(0, 16)
		}
		rank_achieved = _insert_high_score_entry(entry)
	
	run_history.append(summary.duplicate(true))
	if not save_profile():
		wallet_credits = previous.wallet
		salvage = previous.salvage
		high_score = previous.high
		high_scores.assign(previous.scores)
		run_history.assign(previous.history)
		recorded_run_ids.erase(identity)
		return {"error": last_error}
	profile_changed.emit()
	return {
		"is_new_high_score": is_new_high,
		"previous_high_score": prev_high,
		"rank_achieved": rank_achieved,
		"score": s
	}

func get_top_high_scores(limit: int = 10) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(mini(limit, high_scores.size())):
		result.append(high_scores[i])
	return result

func is_new_high_score(check_score: int) -> bool:
	return check_score > high_score and check_score > 0

func _insert_high_score_entry(entry: Dictionary) -> int:
	high_scores.append(entry)
	high_scores.sort_custom(func(a, b): return a.get("score", 0) > b.get("score", 0))
	if high_scores.size() > MAX_HIGH_SCORES:
		high_scores.resize(MAX_HIGH_SCORES)
	for i in high_scores.size():
		high_scores[i]["rank"] = i + 1
	var position := high_scores.find(entry)
	return position + 1 if position >= 0 else -1

func clear_high_scores() -> void:
	high_scores.clear()
	high_score = 0
	save_profile()

func can_afford(cost: int) -> bool:
	return wallet_credits >= cost

func _buy(key: String, prices: Dictionary, ranks: Dictionary) -> bool:
	if _transaction_locked or not profile_valid or not prices.has(key):
		return false
	var rank: int = clampi(int(ranks.get(key, 0)), 0, 5)
	if rank >= 5:
		return false
	var cost: int = prices[key][rank]
	if not can_afford(cost):
		return false
	_transaction_locked = true
	wallet_credits -= cost
	ranks[key] = rank + 1
	var saved := save_profile()
	if not saved:
		wallet_credits += cost
		ranks[key] = rank
	call_deferred("_unlock_transaction")
	if saved:
		profile_changed.emit()
	return saved

func _unlock_transaction() -> void:
	_transaction_locked = false

func buy_hangar_upgrade(key: String) -> bool:
	return _buy(key, HANGAR_PRICES, hangar_ranks)

func buy_perk(key: String) -> bool:
	return _buy(key, PERK_PRICES, perk_ranks)

func valid_mod(weapon: int, mod: int) -> bool:
	return equipped_mods.has(weapon) and (mod == 0 or mod in [weapon * 2 + 1, weapon * 2 + 2])

func equip_mod(weapon_type: int, mod_id: int) -> bool:
	if _transaction_locked or not profile_valid or not valid_mod(weapon_type, mod_id):
		return false
	var old: int = equipped_mods[weapon_type]
	equipped_mods[weapon_type] = mod_id
	if not save_profile():
		equipped_mods[weapon_type] = old
		return false
	profile_changed.emit()
	return true

func get_equipped_mod(weapon_type: int) -> int:
	return equipped_mods.get(weapon_type, GameConstants.WeaponMod.NONE)

func save_profile() -> bool:
	if not profile_valid:
		save_failed.emit(last_error)
		return false
	var data: Dictionary = {
		"selected_aircraft_id": selected_aircraft_id,
		"recorded_run_ids": recorded_run_ids,
		"wallet_credits": wallet_credits,
		"salvage": salvage,
		"high_score": high_score,
		"high_scores": high_scores,
		"hangar_ranks": hangar_ranks,
		"perk_ranks": perk_ranks,
		"equipped_mods": equipped_mods,
		"unlocked_achievements": unlocked_achievements,
		"run_history": run_history
	}
	var error := Storage.write_json(SAVE_PATH, data)
	last_error = "" if error == OK else "Profile was not saved: " + error_string(error)
	if error != OK:
		save_failed.emit(last_error)
	return error == OK

func load_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		save_profile()
		return
	var parser := JSON.new()
	var parsed := parser.parse(FileAccess.get_file_as_string(SAVE_PATH))
	var data = parser.data if parsed == OK else null
	if not data is Dictionary:
		profile_valid = false
		last_error = "Your profile could not be read. The original file was preserved; purchases are disabled."
		save_failed.emit(last_error)
		return
	var saved_aircraft = data.get("selected_aircraft_id", "apache")
	selected_aircraft_id = saved_aircraft if saved_aircraft in Specs.AIRCRAFT else "apache"
	wallet_credits = _integer(data.get("wallet_credits", 150), 150, 2147483647)
	salvage = _integer(data.get("salvage", 0), 0, 2147483647)
	high_score = _integer(data.get("high_score", 0), 0, 2147483647)
	for category in ["hangar_ranks", "perk_ranks"]:
		var ranks: Dictionary = hangar_ranks if category == "hangar_ranks" else perk_ranks
		var incoming = data.get(category, {})
		if incoming is Dictionary:
			for key in ranks:
				ranks[key] = _integer(incoming.get(key, 0), 0, 5)
	var mods = data.get("equipped_mods", {})
	if mods is Dictionary:
		for key in mods:
			var weapon := int(str(key))
			var mod := _integer(mods[key], 0, 8)
			if valid_mod(weapon, mod):
				equipped_mods[weapon] = mod
	high_scores.clear()
	var scores = data.get("high_scores", [])
	if scores is Array:
		for item in scores:
			if item is Dictionary and (item.get("score", 0) is int or item.get("score", 0) is float):
				high_scores.append(item)
	high_scores.sort_custom(func(a, b): return a.get("score", 0) > b.get("score", 0))
	if high_scores.size() > MAX_HIGH_SCORES:
		high_scores.resize(MAX_HIGH_SCORES)
	for i in high_scores.size():
		high_scores[i]["rank"] = i + 1
	if high_scores.is_empty() and high_score > 0:
		_insert_high_score_entry({"score": high_score, "aircraft": "APACHE", "wave": 1, "kills": 0, "outcome": "RECORD"})
	run_history.clear()
	var history = data.get("run_history", [])
	if history is Array:
		for item in history:
			if item is Dictionary:
				run_history.append(item)
	for field in ["unlocked_achievements", "recorded_run_ids"]:
		var entries = data.get(field, [])
		var target: Array[String] = unlocked_achievements if field == "unlocked_achievements" else recorded_run_ids
		target.clear()
		if entries is Array:
			for entry in entries:
				if entry is String:
					target.append(entry)

func _integer(value: Variant, fallback: int, upper: int) -> int:
	return clampi(int(value), 0, upper) if value is int or value is float else fallback

func preview_stats(aircraft: String) -> Dictionary:
	return Specs.calculate_effective_stats(aircraft, hangar_ranks, perk_ranks)

func apply_loadout(player: Node) -> void:
	if player.has_meta("permanent_loadout_applied"):
		return
	player.set_meta("permanent_loadout_applied", true)
	var h := hangar_ranks
	var p := perk_ranks
	var stats := preview_stats(player.aircraft_type)
	player.cruise_speed = stats.speed
	player.max_hull = stats.hull
	player.current_hull = stats.hull
	player.max_fuel = stats.fuel
	player.current_fuel = stats.fuel
	player.armor_mitigation = minf(0.24, h.airframe * 0.04)
	player.small_arms_armor = h.armor * 0.5
	player.radar_range_multiplier = 1.0 + h.targeting * 0.10
	player.handling_multiplier = 1.0 + h.rotor * 0.10
	player.thrust_multiplier = 1.0 + h.engine * 0.08
	player.dash_speed_multiplier = 1.0 + p.vector_thrusters * 0.20
	player.dash_cooldown_reduction = p.vector_thrusters * 0.4
	player.collision_resistance = minf(1.0, p.rotor_armor * 0.20)
	player.pickup_radius_multiplier = 1.0 + p.magnet_radius * 0.25
	player.loot_multiplier = 1.0 + p.scavenger_rig * 0.15
	player.fuel_drain_rate = GameConstants.FUEL_DRAIN_PER_SECOND / (1.0 + p.lean_burn * 0.12)

	# Synchronize gameplay airframe visuals to match selection preview
	var visuals = player.get_node_or_null("Visuals")
	if visuals:
		Specs.configure_airframe_visuals(visuals, player.aircraft_type, false)
	var weapons = player.get_node_or_null("Weapons")
	if weapons:
		weapons.permanent_emp_chance = minf(1.0, p.emp_rounds * 0.12)
		for weapon in weapons.weapon_states:
			weapons.weapon_states[weapon].active_mod = get_equipped_mod(weapon)
			weapons.damage_multipliers[weapon] *= 1.0 + h.weapon_system * 0.06
	var turret = player.get_node_or_null("Turret")
	if turret:
		turret.tracking_speed *= 1.0 + h.targeting * 0.15
	var salvo = player.get_node_or_null("Salvo")
	if salvo:
		salvo.paint_speed_multiplier = 1.0 + h.targeting * 0.15
		salvo.lock_range_multiplier = 1.0 + p.combat_computer * 0.10
	var counter = player.get_node_or_null("Countermeasures")
	if counter:
		counter.max_charges += h.countermeasures
		counter.current_charges = counter.max_charges
		counter.cooldown_duration = maxf(1.0, counter.cooldown_duration - h.countermeasures * 0.5)
		counter.auto_chaff_enabled = h.countermeasures >= 3
	var super_node = player.get_node_or_null("DevastationSuper")
	if super_node:
		super_node.damage_multiplier = 1.0 + h.weapon_system * 0.06
		super_node.charge_multiplier = 1.0 + p.devastator_core * 0.20

func remember_aircraft(id: String) -> void:
	if selected_aircraft_id == id or not Specs.AIRCRAFT.has(id) or not profile_valid:
		return
	var old := selected_aircraft_id
	selected_aircraft_id = id
	if not save_profile():
		selected_aircraft_id = old
