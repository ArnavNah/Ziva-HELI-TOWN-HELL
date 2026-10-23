extends Node

## GameManager â€” Authoritative Run Loop & State Machine for Heli-Town Hell

enum RunState {
	MENU = 0,
	TUTORIAL = 1,
	ACTIVE = 2,
	PAUSED = 3,
	UPGRADE_CHOICE = 4,
	BOSS_DECISION = 5,
	EXTRACTION = 6,
	RESULTS = 7,
	LOADING = 8
}

enum ThreatTier {
	LOW = 0,
	ELEVATED = 1,
	HIGH = 2,
	CRITICAL = 3,
	EXTREME = 4
}

# Run State
var current_state: RunState = RunState.MENU
var previous_state: RunState = RunState.MENU
var pending_menu_tab: String = ""
var event_bus: Node = null
var run_id: String = ""
var settled_summary: Dictionary = {}
var pause_return_state: RunState = RunState.ACTIVE

# Run Tracking
var selected_aircraft: String = "apache"
var current_wave: int = 1
var run_time: float = 0.0
var kills_count: int = 0
var coins_collected: int = 0
var ground_kills: int = 0
var air_kills: int = 0
var distance_flown_m: float = 0.0
var score: int = 0
var has_beaten_high_score: bool = false
var run_starting_high_score: int = 0
var counted_objectives: int = 0

# Combo System (Page 21)
var combo_count: int = 0
var combo_timer: float = 0.0
const COMBO_TIMEOUT: float = 3.0
var combo_multiplier: float = 1.0

# Economy & Threat (Page 21)
var banked_credits: int = 0
var at_risk_credits: int = 0
var carried_salvage: int = 0
var threat_points: float = 0.0
var threat_tier: ThreatTier = ThreatTier.LOW

# Leveling & Upgrade Choices (Page 18)
var run_xp: int = 0
var active_run_progression: Node = null

# Frame Pacing & Display Settings (Proper 60 FPS Target)
var target_fps: int = 60
var vsync_enabled: bool = false
var show_fps_telemetry: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	apply_frame_pacing()
	_connect_event_bus()

func apply_frame_pacing() -> void:
	Engine.max_fps = target_fps
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED
	)

func set_target_fps(fps: int) -> void:
	target_fps = fps
	Engine.max_fps = target_fps

func set_vsync(enabled: bool) -> void:
	vsync_enabled = enabled
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED
	)

func _connect_event_bus() -> void:
	if has_node("/root/EventBus"):
		var bus = get_node("/root/EventBus")
		bus.entity_destroyed.connect(_on_entity_destroyed)
		bus.damage_dealt.connect(_on_damage_dealt)
		bus.player_died.connect(_on_player_died)
		bus.wave_cleared.connect(_on_wave_cleared)
		bus.tactical_mission_completed.connect(_on_mission_completed)
		bus.cargo_delivered.connect(_on_cargo_delivered)
		bus.boss_defeated.connect(_on_boss_defeated)

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if current_state == RunState.ACTIVE or current_state == RunState.EXTRACTION:
		run_time += delta
		var player = get_tree().get_first_node_in_group("player")
		if player and "velocity" in player:
			var v: Vector3 = player.velocity
			distance_flown_m += Vector2(v.x, v.z).length() * delta
		_process_combo(delta)
		_process_threat(delta)

func change_state(new_state: RunState) -> void:
	if current_state == new_state:
		get_tree().paused = new_state in [RunState.PAUSED, RunState.UPGRADE_CHOICE, RunState.BOSS_DECISION, RunState.RESULTS, RunState.LOADING]
		return
	previous_state = current_state
	current_state = new_state
	
	match new_state:
		RunState.ACTIVE:
			get_tree().paused = false
		RunState.PAUSED, RunState.UPGRADE_CHOICE, RunState.BOSS_DECISION, RunState.RESULTS, RunState.LOADING:
			get_tree().paused = true
		RunState.EXTRACTION:
			get_tree().paused = false
		RunState.MENU:
			get_tree().paused = false

	if has_node("/root/EventBus"):
		get_node("/root/EventBus").run_state_changed.emit(new_state, previous_state)

func start_new_run(aircraft: String = "apache") -> void:
	run_id = str(Time.get_unix_time_from_system()) + "-" + str(Time.get_ticks_usec())
	settled_summary.clear()
	selected_aircraft = aircraft
	current_wave = 1
	run_time = 0.0
	kills_count = 0
	coins_collected = 0
	ground_kills = 0
	air_kills = 0
	distance_flown_m = 0.0
	score = 0
	has_beaten_high_score = false
	if has_node("/root/ProfileManager"):
		run_starting_high_score = get_node("/root/ProfileManager").high_score
	else:
		run_starting_high_score = 0
	counted_objectives = 0
	combo_count = 0
	combo_timer = 0.0
	combo_multiplier = 1.0
	banked_credits = 0
	at_risk_credits = 0
	carried_salvage = 0
	threat_points = 0.0
	threat_tier = ThreatTier.LOW
	run_xp = 0
	if has_node("/root/XpManager"):
		get_node("/root/XpManager").reset_run()
	
	change_state(RunState.ACTIVE)

func toggle_pause() -> void:
	if current_state in [RunState.ACTIVE, RunState.EXTRACTION]:
		pause_return_state = current_state
		change_state(RunState.PAUSED)
	elif current_state == RunState.PAUSED:
		change_state(pause_return_state)
		if has_node("/root/UIFlow"):
			get_node("/root/UIFlow").block_held_input()

func _get_event_bus() -> Node:
	if event_bus and is_instance_valid(event_bus):
		return event_bus
	if get_parent() and get_parent().has_node("EventBus"):
		event_bus = get_parent().get_node("EventBus")
	elif get_tree() and get_tree().root and get_tree().root.has_node("EventBus"):
		event_bus = get_tree().root.get_node("EventBus")
	elif is_inside_tree() and has_node("/root/EventBus"):
		event_bus = get_node("/root/EventBus")
	return event_bus

func add_score(base_points: int, low_hull_bonus: float = 0.0) -> void:
	if base_points <= 0:
		return
	var final_points: int = int(base_points * combo_multiplier * (1.0 + low_hull_bonus))
	score += final_points
	
	var eb = _get_event_bus()
	if eb:
		eb.score_updated.emit(score, final_points)
		
	# Check if high score was surpassed for the first time this run
	if run_starting_high_score > 0 and score > run_starting_high_score and not has_beaten_high_score:
		has_beaten_high_score = true
		if eb:
			eb.high_score_beaten.emit(score, run_starting_high_score)
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("new_high_score")

func _process_combo(delta: float) -> void:
	if combo_count > 0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo_count = 0
			combo_multiplier = 1.0
			if has_node("/root/EventBus"):
				get_node("/root/EventBus").combo_updated.emit(0, 1.0)

func register_hit() -> void:
	combo_count += 1
	combo_timer = COMBO_TIMEOUT
	# Multiplier = 1 + min(combo * 0.1, 5), capped at 6x (Page 21)
	combo_multiplier = minf(1.0 + minf(combo_count * 0.1, 5.0), 6.0)
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").combo_updated.emit(combo_count, combo_multiplier)

func _process_threat(delta: float) -> void:
	# Passive threat growth + time factor
	threat_points += delta * 0.15
	_update_threat_tier()

func add_threat(amount: float) -> void:
	threat_points += amount
	_update_threat_tier()

func _update_threat_tier() -> void:
	# Page 21: Low 0, Elevated 30, High 80, Critical 150, Extreme 240
	var _old_tier = threat_tier
	if threat_points >= 240.0:
		threat_tier = ThreatTier.EXTREME
	elif threat_points >= 150.0:
		threat_tier = ThreatTier.CRITICAL
	elif threat_points >= 80.0:
		threat_tier = ThreatTier.HIGH
	elif threat_points >= 30.0:
		threat_tier = ThreatTier.ELEVATED
	else:
		threat_tier = ThreatTier.LOW

func get_threat_reward_factor() -> float:
	match threat_tier:
		ThreatTier.EXTREME: return 1.70
		ThreatTier.CRITICAL: return 1.45
		ThreatTier.HIGH: return 1.25
		ThreatTier.ELEVATED: return 1.10
		_: return 1.00

# ------------------------------------------------------------------------------
# Economy & Settlement (Page 21 & 22)
# ------------------------------------------------------------------------------
func collect_coins(amount: int) -> void:
	if amount <= 0:
		return
	coins_collected += amount
	add_banked_credits(amount)

func add_banked_credits(amount: int) -> void:
	banked_credits += amount
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").credits_banked.emit(banked_credits)

func add_at_risk_credits(amount: int) -> void:
	at_risk_credits += amount
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").at_risk_credits_changed.emit(at_risk_credits)

func add_salvage(amount: int) -> void:
	carried_salvage += amount
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").salvage_collected.emit(carried_salvage)

func settle_extraction(is_successful: bool, death_cause: String = "") -> Dictionary:
	if not settled_summary.is_empty():
		return settled_summary.duplicate(true)
	var combat_pay: int = GameConstants.calculate_combat_pay(
		kills_count, current_wave - 1, counted_objectives, run_time
	)
	var salvage_credits: int = 0
	var secured_from_risk: int = 0
	
	if is_successful:
		# Convert salvage (5 credits each) and secure all at-risk earnings
		salvage_credits = carried_salvage * GameConstants.SALVAGE_TO_CREDIT_RATE
		secured_from_risk = at_risk_credits
	else:
		# At-risk credits and salvage are LOST on destruction!
		salvage_credits = 0
		secured_from_risk = 0
	
	var total_payout: int = banked_credits + secured_from_risk + salvage_credits + combat_pay
	
	var run_summary: Dictionary = {
		"run_id": run_id,
		"waves_cleared": maxi(0, current_wave - 1),
		"successful": is_successful,
		"cause_of_death": death_cause if not is_successful else "Extracted Safely",
		"survival_time": run_time,
		"distance_flown_m": distance_flown_m,
		"wave_reached": current_wave,
		"kills": kills_count,
		"coins_collected": coins_collected,
		"ground_kills": ground_kills,
		"air_kills": air_kills,
		"selected_aircraft": selected_aircraft,
		"score": score,
		"is_new_high_score": score > run_starting_high_score and score > 0,
		"previous_high_score": run_starting_high_score,
		"high_score": maxi(score, run_starting_high_score),
		"combat_pay": combat_pay,
		"banked_credits": banked_credits,
		"salvage_credits": salvage_credits,
		"at_risk_recovered": secured_from_risk,
		"at_risk_lost": at_risk_credits if not is_successful else 0,
		"salvage_lost": carried_salvage if not is_successful else 0,
		"total_payout": total_payout
	}
	
	settled_summary = run_summary.duplicate(true)
	change_state(RunState.RESULTS)
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").run_completed.emit(is_successful, run_summary)
	
	return run_summary

# ------------------------------------------------------------------------------
# Event Listeners
# ------------------------------------------------------------------------------
func _on_entity_destroyed(_entity: Node, _weapon: String, score_val: int, _xp_val: int) -> void:
	# World destruction still awards score, but only hostiles count as enemy kills.
	if is_instance_valid(_entity) and _entity.is_in_group("enemies"):
		kills_count += 1
		var family := "air"
		if "variant_id" in _entity:
			family = EnemyData.VARIANTS.get(_entity.variant_id, {}).get("family", "air")
		if family == "ground":
			ground_kills += 1
		else:
			air_kills += 1
	add_score(score_val)
	add_threat(2.0)
	# LootManager drops physical XP. Collection is the only XP award path.

func _on_damage_dealt(_target: Node, _amount: float, _weapon: String, _is_lethal: bool) -> void:
	register_hit()

func _on_player_died(cause: String) -> void:
	settle_extraction(false, cause)

func _on_wave_cleared(wave_number: int) -> void:
	current_wave = wave_number + 1
	counted_objectives += 1
	add_score(500 * wave_number)

func _on_mission_completed(mission_data: Dictionary, bonus_achieved: bool) -> void:
	counted_objectives += 1
	var payout: int = mission_data.get("base_payout", 200)
	if bonus_achieved:
		payout += mission_data.get("bonus_payout", 100)
	add_banked_credits(payout)
	add_score(payout * 2)

func _on_cargo_delivered(cargo_data: Dictionary, speed_bonus: bool, sam_bonus: bool) -> void:
	counted_objectives += 1
	var payout: int = cargo_data.get("payout", 300)
	if speed_bonus:
		payout = int(payout * 1.25)
	if sam_bonus:
		payout = int(payout * 1.15)
	add_banked_credits(payout)
	add_score(payout * 2)

func _on_boss_defeated() -> void:
	counted_objectives += 1
	add_score(5000)
	add_threat(15.0)

