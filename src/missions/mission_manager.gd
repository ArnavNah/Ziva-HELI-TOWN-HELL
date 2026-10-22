class_name MissionManager
extends Node

## MissionManager — Oversees tactical mission generation, objective tracking,
## optional bonus evaluation, and reward claims (Page 14).

const MissionSpecsClass = preload("res://src/missions/mission_specs.gd")

signal mission_started(mission_id: String, details: Dictionary)
signal mission_progressed(current_val: float, target_val: float)
signal mission_completed(details: Dictionary, bonus_won: bool)
signal mission_failed(details: Dictionary)

var active_mission_id: String = ""
var active_mission_data: Dictionary = {}
var is_mission_active: bool = false
var mission_timer: float = 0.0
var hold_progress: float = 0.0
var current_kills: int = 0
var sam_damage_taken: bool = false

var inter_mission_cooldown: float = 20.0
var cooldown_timer: float = 5.0 # Start initial mission after 5s

func _process(delta: float) -> void:
	if is_mission_active:
		mission_timer += delta
		_process_active_mission(delta)
	else:
		cooldown_timer -= delta
		if cooldown_timer <= 0.0:
			_generate_next_mission()

func _generate_next_mission() -> void:
	var keys = MissionSpecsClass.MISSIONS.keys()
	var chosen_key = keys.pick_random()
	start_mission(chosen_key)

func start_mission(mission_key: String) -> void:
	if not MissionSpecsClass.MISSIONS.has(mission_key):
		return
	active_mission_id = mission_key
	active_mission_data = MissionSpecsClass.MISSIONS[mission_key].duplicate()
	is_mission_active = true
	mission_timer = 0.0
	hold_progress = 0.0
	current_kills = 0
	sam_damage_taken = false

	mission_started.emit(active_mission_id, active_mission_data)
	if is_inside_tree() and has_node("/root/EventBus"):
		get_node("/root/EventBus").tactical_mission_started.emit(active_mission_data)

func _process_active_mission(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	match active_mission_id:
		"defend_beacon", "rescue_crew":
			# Proximity hold timer
			var target_pos = Vector3.ZERO # In live world, beacon or crash position
			var req_hold = active_mission_data.get("hold_time", 20.0)
			var radius = active_mission_data.get("radius", 34.0)
			if player.global_position.distance_to(target_pos) <= radius:
				hold_progress += delta
				mission_progressed.emit(hold_progress, req_hold)
				if is_inside_tree() and has_node("/root/EventBus"):
					get_node("/root/EventBus").tactical_mission_updated.emit(hold_progress, req_hold)
				if hold_progress >= req_hold:
					complete_active_mission()

		"clear_airspace":
			var req_kills = active_mission_data.get("target_kills", 10)
			mission_progressed.emit(float(current_kills), float(req_kills))
			if current_kills >= req_kills:
				complete_active_mission()

func register_kill_for_mission() -> void:
	if is_mission_active:
		current_kills += 1
		if active_mission_id == "clear_airspace":
			var req_kills = active_mission_data.get("target_kills", 10)
			if current_kills >= req_kills:
				complete_active_mission()

func complete_active_mission() -> void:
	if not is_mission_active:
		return
	is_mission_active = false
	cooldown_timer = inter_mission_cooldown

	var player = get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	var bonus_won = false

	# Evaluate optional bonus (Page 14)
	match active_mission_id:
		"destroy_sam", "destroy_radar":
			bonus_won = not sam_damage_taken
		"high_value_target":
			bonus_won = (mission_timer <= 65.0)
		"bounty_leader":
			bonus_won = (mission_timer <= 75.0)
		"clear_airspace", "defend_beacon", "escort_convoy", "rescue_crew":
			if player and "current_hull" in player and "max_hull" in player:
				bonus_won = (player.current_hull >= player.max_hull * 0.5)

	# Payout rewards
	var base_cr = active_mission_data.get("base_cr", 0)
	var base_salvage = active_mission_data.get("base_salvage", 0)

	if is_inside_tree() and has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		gm.add_banked_credits(base_cr)
		gm.add_salvage(base_salvage)
		if bonus_won:
			var bonus_cr = active_mission_data.get("bonus_cr", 0)
			var bonus_salvage = active_mission_data.get("bonus_salvage", 0)
			gm.add_at_risk_credits(bonus_cr)
			gm.add_salvage(bonus_salvage)

	# Flare rewards
	if active_mission_data.has("flare_reward") and player and player.has_node("Countermeasures"):
		player.get_node("Countermeasures").replenish_charges(active_mission_data["flare_reward"])

	# Repair rewards
	if active_mission_data.has("repair_reward") and player and player.has_method("repair"):
		player.repair(active_mission_data["repair_reward"])

	mission_completed.emit(active_mission_data, bonus_won)
	if is_inside_tree() and has_node("/root/EventBus"):
		get_node("/root/EventBus").tactical_mission_completed.emit(active_mission_data, bonus_won)
