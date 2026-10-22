extends Node3D

@onready var player: CharacterBody3D = $PlayerHelicopter
@onready var weapons: Node = $PlayerHelicopter/Weapons
@onready var salvo: Node = $PlayerHelicopter/Salvo
@onready var hud_label: Label = $UI/HUDLabel

const GameConstants = preload("res://data/game_constants.gd")

func _ready() -> void:
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").start_new_run("apache")

func _process(_delta: float) -> void:
	_update_hud()

func _update_hud() -> void:
	if not hud_label or not weapons or not player:
		return
		
	var w_idx = weapons.current_weapon_idx
	var w_cfg = GameConstants.WEAPONS[w_idx]
	var w_state = weapons.weapon_states[w_idx]
	
	var reload_str = ""
	if w_state["is_reloading"]:
		reload_str = " [RELOADING: %.1fs]" % [w_state["reload_timer"]]
		
	var salvo_cd_str = "READY"
	if salvo.cooldown_timer > 0.0:
		salvo_cd_str = "%.1fs" % [salvo.cooldown_timer]
		
	var text = "=== HELI-TOWN HELL : COMBAT SLICE ===\n"
	text += "ACTIVE WEAPON: %s (Lv.%d | XP: %d)%s\n" % [w_cfg["name"], w_state["level"], w_state["xp"], reload_str]
	text += "AMMO: %d / %d | SALVO COOLDOWN: %s (Locks: %d)\n\n" % [
		w_state["ammo"], w_cfg["ammo_max"], salvo_cd_str, salvo.current_locks.size()
	]
	text += "HULL: %.0f / %.0f | FUEL: %.0f / %.0f\n" % [
		player.current_hull, player.max_hull, player.current_fuel, player.max_fuel
	]
	
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		text += "SCORE: %d | KILLS: %d | COMBO: x%.1f | THREAT: %s\n" % [
			gm.score, gm.kills_count, gm.combo_multiplier, gm.ThreatTier.keys()[gm.threat_tier]
		]
		
	text += "\nCONTROLS: LMB Fire | RMB Paint Salvo | 1-4 Switch Weapon | R Reload | Shift Dash"
	hud_label.text = text
