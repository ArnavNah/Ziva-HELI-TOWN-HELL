class_name UpgradeCatalog
extends RefCounted

## UpgradeCatalog — Authoritative single source of truth for in-run upgrade cards.
## Provides stable IDs, definitions, eligibility filters, effective before/after previews,
## and verified transactional effect handlers (Spec Phase 2 & 3).

const CATALOG: Dictionary = {
	"overclock_rounds": {
		"id": "overclock_rounds",
		"title": "Overclock Rounds",
		"category": "OFFENSE",
		"rarity": "COMMON",
		"icon_key": "bullet",
		"max_rank": 5,
		"scope": "PERMANENT",
		"description": "+15% Weapon Damage across all equipped ordnance.",
		"prerequisites": {}
	},
	"hair_trigger": {
		"id": "hair_trigger",
		"title": "Hair Trigger",
		"category": "OFFENSE",
		"rarity": "COMMON",
		"icon_key": "trigger",
		"max_rank": 5,
		"scope": "PERMANENT",
		"description": "+15% Cyclic Rate of Fire for rapid weapon cycling.",
		"prerequisites": {}
	},
	"extended_mag": {
		"id": "extended_mag",
		"title": "Extended Mag",
		"category": "OFFENSE",
		"rarity": "UNCOMMON",
		"icon_key": "ammo",
		"max_rank": 5,
		"scope": "PERMANENT",
		"description": "+30% Persistent Magazine Capacity with immediate bonus round replenishment.",
		"prerequisites": {}
	},
	"speed_loader": {
		"id": "speed_loader",
		"title": "Speed Loader",
		"category": "OFFENSE",
		"rarity": "COMMON",
		"icon_key": "reload",
		"max_rank": 5,
		"scope": "PERMANENT",
		"description": "+25% Tactical Reload Speed (Duration ÷ 1.25).",
		"prerequisites": {}
	},
	"salvo_overclock": {
		"id": "salvo_overclock",
		"title": "Salvo Overclock",
		"category": "OFFENSE",
		"rarity": "RARE",
		"icon_key": "salvo",
		"max_rank": 5,
		"scope": "PERMANENT",
		"description": "-35% Salvo Missile Lock & Recharge cooldown (floor 1.5s).",
		"prerequisites": {}
	},
	"airstrike": {
		"id": "airstrike",
		"title": "Airstrike",
		"category": "TACTICAL",
		"rarity": "RARE",
		"icon_key": "airstrike",
		"max_rank": 5,
		"scope": "INSTANT",
		"description": "Calls tactical air support striking hostile targets within 160m for 120 damage.",
		"prerequisites": {}
	},
	"reinforced_hull": {
		"id": "reinforced_hull",
		"title": "Reinforced Hull",
		"category": "DEFENSE",
		"rarity": "COMMON",
		"icon_key": "shield",
		"max_rank": 5,
		"scope": "PERMANENT",
		"description": "+20 Airframe Maximum Hull with immediate 20 HP structural repair.",
		"prerequisites": {}
	},
	"reactive_armor": {
		"id": "reactive_armor",
		"title": "Reactive Armor",
		"category": "DEFENSE",
		"rarity": "UNCOMMON",
		"icon_key": "armor",
		"max_rank": 4,
		"scope": "PERMANENT",
		"description": "+6 Percentage Points Armor Mitigation (Hard Cap: 24%).",
		"prerequisites": {}
	},
	"field_repair": {
		"id": "field_repair",
		"title": "Field Repair",
		"category": "DEFENSE",
		"rarity": "COMMON",
		"icon_key": "repair",
		"max_rank": 99,
		"scope": "INSTANT",
		"description": "Emergency field maintenance restoring 25 Hull and servicing airframe subsystems.",
		"prerequisites": {}
	},
	"aegis_field": {
		"id": "aegis_field",
		"title": "Aegis Field",
		"category": "DEFENSE",
		"rarity": "RARE",
		"icon_key": "aegis",
		"max_rank": 99,
		"scope": "TEMPORARY_8S",
		"description": "Deploys an impenetrable 8-second kinetic energy shield absorbing all incoming damage.",
		"prerequisites": {}
	},
	"vector_jets": {
		"id": "vector_jets",
		"title": "Vector Jets",
		"category": "MOBILITY",
		"rarity": "UNCOMMON",
		"icon_key": "jet",
		"max_rank": 5,
		"scope": "PERMANENT",
		"description": "+15% Maximum Cruise Airspeed for high-speed battlefield repositioning.",
		"prerequisites": {}
	},
	"turbine_tune": {
		"id": "turbine_tune",
		"title": "Turbine Tune",
		"category": "MOBILITY",
		"rarity": "COMMON",
		"icon_key": "fuel",
		"max_rank": 5,
		"scope": "PERMANENT",
		"description": "-30% Turbine Fuel Consumption rate (floor 0.4 units/s).",
		"prerequisites": {}
	},
	"evo_vulcan_storm": {
		"id": "evo_vulcan_storm",
		"title": "EVOLUTION: Vulcan Storm",
		"category": "EVOLUTION",
		"rarity": "EPIC",
		"icon_key": "vulcan",
		"max_rank": 1,
		"scope": "PERMANENT",
		"description": "Twin-Rotary Gatling System: doubles cyclic fire rate and fires dual parallel bullet streams.",
		"prerequisites": {"overclock_rounds": 2, "hair_trigger": 2}
	},
	"evo_phantom_tracking": {
		"id": "evo_phantom_tracking",
		"title": "EVOLUTION: Phantom Tracking",
		"category": "EVOLUTION",
		"rarity": "EPIC",
		"icon_key": "phantom",
		"max_rank": 1,
		"scope": "PERMANENT",
		"description": "Phantom Salvo Array: rapid multi-missile salvo recharge with 40% cooldown cut.",
		"prerequisites": {"salvo_overclock": 2, "hair_trigger": 2}
	},
	"evo_juggernaut_frame": {
		"id": "evo_juggernaut_frame",
		"title": "EVOLUTION: Juggernaut Frame",
		"category": "EVOLUTION",
		"rarity": "EPIC",
		"icon_key": "juggernaut",
		"max_rank": 1,
		"scope": "PERMANENT",
		"description": "Heavy Armored Composite Frame: +40 Max Hull, +6% Armor Mitigation, +50% Impact Resistance.",
		"prerequisites": {"reinforced_hull": 2, "reactive_armor": 2}
	},
	"evo_rotor_predator": {
		"id": "evo_rotor_predator",
		"title": "EVOLUTION: Rotor Predator",
		"category": "EVOLUTION",
		"rarity": "EPIC",
		"icon_key": "predator",
		"max_rank": 1,
		"scope": "PERMANENT",
		"description": "Apex Turbine Dynamics: +25% cruise speed, -30% fuel drain, and rapid spool response.",
		"prerequisites": {"turbine_tune": 2, "vector_jets": 2}
	},
	"leg_death_from_above": {
		"id": "leg_death_from_above",
		"title": "LEGENDARY: Death From Above",
		"category": "LEGENDARY",
		"rarity": "LEGENDARY",
		"icon_key": "skull",
		"max_rank": 1,
		"scope": "PERMANENT",
		"description": "+35% Machine Gun Devastation with high-caliber explosive munitions.",
		"prerequisites": {}
	},
	"leg_ghost_rotor": {
		"id": "leg_ghost_rotor",
		"title": "LEGENDARY: Ghost Rotor",
		"category": "LEGENDARY",
		"rarity": "LEGENDARY",
		"icon_key": "ghost",
		"max_rank": 1,
		"scope": "PERMANENT",
		"description": "+20% Airspeed and 35% Aerodynamic Drag Reduction for effortless momentum gliding.",
		"prerequisites": {}
	},
	"leg_war_economy": {
		"id": "leg_war_economy",
		"title": "LEGENDARY: War Economy",
		"category": "LEGENDARY",
		"rarity": "LEGENDARY",
		"icon_key": "economy",
		"max_rank": 1,
		"scope": "INSTANT",
		"description": "+250 Combat Salvage Credits and immediate 1,000 Score bounty payout.",
		"prerequisites": {}
	}
}

static func get_entry(identifier: String) -> Dictionary:
	if CATALOG.has(identifier):
		return CATALOG[identifier]
	# Try matching by title
	for key in CATALOG:
		var item: Dictionary = CATALOG[key]
		if item.get("title", "") == identifier:
			return item
	return {}

static func resolve_id(identifier: String) -> String:
	var entry = get_entry(identifier)
	return entry.get("id", "")

static func is_eligible(entry_or_id: Variant, player: Node3D, progression: Node) -> bool:
	var entry = entry_or_id if entry_or_id is Dictionary else get_entry(str(entry_or_id))
	if entry.is_empty():
		return false
	var item_id = entry.get("id", "")
	var current_stacks: int = progression.upgrade_stacks.get(item_id, 0) if progression and "upgrade_stacks" in progression else 0
	var max_rank: int = entry.get("max_rank", 5)

	# 1. Cap checks
	if current_stacks >= max_rank:
		return false

	# Reactive armor hard cap
	if item_id == "reactive_armor":
		if player and "armor_mitigation" in player and player.armor_mitigation >= 0.239:
			return false

	# 2. Legendary limit: 1 per run, requires level 5+
	if entry.get("category") == "LEGENDARY":
		if progression and ("has_legendary" in progression and progression.has_legendary):
			return false
		if progression and ("current_run_level" in progression and progression.current_run_level < 5):
			return false

	# 3. Evolution checks: one per weapon type, check prerequisites
	if entry.get("category") == "EVOLUTION":
		if progression and "evolved_weapons" in progression and progression.evolved_weapons.has(entry.get("title")):
			return false
		var prereqs: Dictionary = entry.get("prerequisites", {})
		for req_id in prereqs:
			var req_val: int = prereqs[req_id]
			var cur_val: int = progression.upgrade_stacks.get(req_id, 0) if progression and "upgrade_stacks" in progression else 0
			if cur_val < req_val:
				return false

	return true

static func get_effective_preview(entry_or_id: Variant, player: Node3D, current_rank: int) -> Dictionary:
	var entry = entry_or_id if entry_or_id is Dictionary else get_entry(str(entry_or_id))
	if entry.is_empty():
		return {"current_text": "--", "next_text": "--", "change_text": ""}

	var item_id = entry.get("id", "")
	var wp = player.get_node_or_null("Weapons") if player else null
	var salvo = player.get_node_or_null("Salvo") if player else null

	match item_id:
		"overclock_rounds":
			var cur_mult: float = wp.damage_multipliers.get(0, 1.0) if wp else 1.0
			return {
				"current_text": "%.2fx Dmg" % cur_mult,
				"next_text": "%.2fx Dmg" % (cur_mult * 1.15),
				"change_text": "+15% Damage"
			}
		"hair_trigger":
			var cur_rate: float = wp.fire_rates.get(0, 1.0) if wp else 1.0
			return {
				"current_text": "%.2fx Rate" % cur_rate,
				"next_text": "%.2fx Rate" % (cur_rate * 1.15),
				"change_text": "+15% Fire Rate"
			}
		"extended_mag":
			var cur_max: int = wp.get_max_ammo(0) if (wp and wp.has_method("get_max_ammo")) else 300
			var next_max: int = int(round(float(cur_max) * 1.30))
			return {
				"current_text": "%d Rds" % cur_max,
				"next_text": "%d Rds" % next_max,
				"change_text": "+30% Capacity"
			}
		"speed_loader":
			var cur_mult: float = wp.reload_multipliers.get(0, 1.0) if wp else 1.0
			return {
				"current_text": "%.2fx Spd" % cur_mult,
				"next_text": "%.2fx Spd" % (cur_mult * 1.25),
				"change_text": "+25% Reload"
			}
		"salvo_overclock":
			var cur_cd: float = salvo.cooldown_duration if salvo else 4.0
			var next_cd: float = maxf(1.5, cur_cd * 0.65)
			return {
				"current_text": "%.1fs CD" % cur_cd,
				"next_text": "%.1fs CD" % next_cd,
				"change_text": "-35% Cooldown"
			}
		"reinforced_hull":
			var cur_hp: float = player.max_hull if player else 100.0
			return {
				"current_text": "%d HP" % int(cur_hp),
				"next_text": "%d HP" % int(cur_hp + 20.0),
				"change_text": "+20 Max HP & Repair"
			}
		"reactive_armor":
			var cur_mit: float = player.armor_mitigation if player else 0.0
			var next_mit: float = minf(0.24, cur_mit + 0.06)
			return {
				"current_text": "%d%% Mit" % int(round(cur_mit * 100.0)),
				"next_text": "%d%% Mit" % int(round(next_mit * 100.0)),
				"change_text": "+6% Mitigation"
			}
		"field_repair":
			var cur_h: float = player.current_hull if player else 100.0
			var max_h: float = player.max_hull if player else 100.0
			return {
				"current_text": "%d HP" % int(cur_h),
				"next_text": "%d HP" % int(minf(max_h, cur_h + 25.0)),
				"change_text": "+25 HP Restored"
			}
		"aegis_field":
			return {
				"current_text": "Inactive",
				"next_text": "8.0s Active",
				"change_text": "Shield Invulnerable"
			}
		"vector_jets":
			var cur_spd: float = player.cruise_speed if player else 36.0
			return {
				"current_text": "%.1f m/s" % cur_spd,
				"next_text": "%.1f m/s" % (cur_spd * 1.15),
				"change_text": "+15% Airspeed"
			}
		"turbine_tune":
			var cur_dr: float = player.fuel_drain_rate if player else 0.55
			var next_dr: float = maxf(0.25, cur_dr * 0.70)
			return {
				"current_text": "%.2f/s" % cur_dr,
				"next_text": "%.2f/s" % next_dr,
				"change_text": "-30% Fuel Drain"
			}
		"airstrike":
			return {
				"current_text": "Ready",
				"next_text": "160m Strike",
				"change_text": "120 Damage Volley"
			}
		"evo_vulcan_storm":
			return {
				"current_text": "Single Stream",
				"next_text": "Twin Rotary",
				"change_text": "2x Fire Rate & Dual Stream"
			}
		"evo_phantom_tracking":
			return {
				"current_text": "Standard Salvo",
				"next_text": "Phantom Salvo",
				"change_text": "-40% CD & Agility"
			}
		"evo_juggernaut_frame":
			return {
				"current_text": "Standard Frame",
				"next_text": "Juggernaut",
				"change_text": "+40 HP, +6% Mit, +50% Crash Res"
			}
		"evo_rotor_predator":
			return {
				"current_text": "Standard Turbine",
				"next_text": "Rotor Predator",
				"change_text": "+25% Spd, -30% Fuel"
			}
		"leg_death_from_above":
			return {
				"current_text": "Standard MG",
				"next_text": "Devastator MG",
				"change_text": "+35% Gun Damage"
			}
		"leg_ghost_rotor":
			return {
				"current_text": "100% Drag",
				"next_text": "65% Drag",
				"change_text": "-35% Drag, +20% Spd"
			}
		"leg_war_economy":
			return {
				"current_text": "+0",
				"next_text": "+250 Credits",
				"change_text": "+250 Salvage & +1k Score"
			}
		_:
			return {
				"current_text": "Rank %d" % current_rank,
				"next_text": "Rank %d" % (current_rank + 1),
				"change_text": "Augmentation"
			}

static func apply_effect(item_id: String, player: Node3D, progression: Node) -> bool:
	var wp = player.get_node_or_null("Weapons") if player else null
	var salvo = player.get_node_or_null("Salvo") if player else null

	match item_id:
		"overclock_rounds":
			if wp:
				for k in wp.damage_multipliers:
					wp.damage_multipliers[k] = wp.damage_multipliers.get(k, 1.0) * 1.15
			return true
		"hair_trigger":
			if wp:
				for k in wp.fire_rates:
					wp.fire_rates[k] = wp.fire_rates.get(k, 1.0) * 1.15
			return true
		"extended_mag":
			if wp:
				if wp.has_method("upgrade_magazine_capacity"):
					wp.upgrade_magazine_capacity(1.30)
				else:
					for k in wp.weapon_states:
						wp.weapon_states[k]["ammo"] = int(wp.weapon_states[k]["ammo"] * 1.30)
			return true
		"speed_loader":
			if wp:
				for k in wp.reload_multipliers:
					wp.reload_multipliers[k] = wp.reload_multipliers.get(k, 1.0) * 1.25
			return true
		"salvo_overclock":
			if salvo:
				salvo.cooldown_duration = maxf(1.5, salvo.cooldown_duration * 0.65)
			return true
		"reinforced_hull":
			if player:
				player.max_hull += 20.0
				player.repair(20.0)
			return true
		"reactive_armor":
			if player:
				player.armor_mitigation = minf(0.24, player.armor_mitigation + 0.06)
			return true
		"field_repair":
			if player:
				player.repair(25.0)
			return true
		"aegis_field":
			if player:
				player.activate_shield(8.0)
			return true
		"vector_jets":
			if player:
				player.cruise_speed *= 1.15
			return true
		"turbine_tune":
			if player:
				player.fuel_drain_rate = maxf(0.25, player.fuel_drain_rate * 0.70)
			return true
		"airstrike":
			if player and player.is_inside_tree():
				var enemies = player.get_tree().get_nodes_in_group("enemies")
				var damage_data_class = preload("res://src/combat/damage_data.gd")
				for e in enemies:
					if is_instance_valid(e) and player.global_position.distance_to(e.global_position) <= 160.0:
						if e.has_node("DamageReceiver"):
							var hit = damage_data_class.new(120.0, 2, player, false, 25.0)
							e.get_node("DamageReceiver").take_damage(hit)
			return true
		"evo_vulcan_storm":
			if progression:
				progression.evolved_weapons.append("EVOLUTION: Vulcan Storm")
			if wp:
				wp.fire_rates[0] = wp.fire_rates.get(0, 1.0) * 2.0
				wp.has_vulcan_storm = true
			return true
		"evo_phantom_tracking":
			if progression:
				progression.evolved_weapons.append("EVOLUTION: Phantom Tracking")
			if wp:
				wp.has_phantom_tracking = true
			if salvo:
				salvo.cooldown_duration = maxf(1.0, salvo.cooldown_duration * 0.60)
			return true
		"evo_juggernaut_frame":
			if progression:
				progression.evolved_weapons.append("EVOLUTION: Juggernaut Frame")
			if player:
				player.max_hull += 40.0
				player.repair(40.0)
				player.armor_mitigation = minf(0.24, player.armor_mitigation + 0.06)
				player.collision_resistance = minf(0.85, player.collision_resistance + 0.50)
			return true
		"evo_rotor_predator":
			if progression:
				progression.evolved_weapons.append("EVOLUTION: Rotor Predator")
			if player:
				player.cruise_speed *= 1.25
				player.fuel_drain_rate = maxf(0.25, player.fuel_drain_rate * 0.70)
			return true
		"leg_death_from_above":
			if progression:
				progression.has_legendary = true
			if wp:
				wp.damage_multipliers[0] = wp.damage_multipliers.get(0, 1.0) * 1.35
			return true
		"leg_ghost_rotor":
			if progression:
				progression.has_legendary = true
			if player:
				player.cruise_speed *= 1.20
				player.drag_multiplier = 0.65
			return true
		"leg_war_economy":
			if progression:
				progression.has_legendary = true
			if player and player.is_inside_tree() and player.has_node("/root/GameManager"):
				var gm = player.get_node("/root/GameManager")
				gm.add_salvage(250)
				gm.add_score(1000)
			return true
		_:
			return false
