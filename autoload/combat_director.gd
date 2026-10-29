extends Node

## CombatDirector — Autonomous data-driven encounter director, coordinating
## wave progression, dual credit economy (fast/slow streams), difficulty scaling,
## wave themes, spawn budgets, and pause-aware attack slot lease scheduler.

const SpawnCardClass = preload("res://src/resources/spawn_card.gd")
const SpawnCardCatalogClass = preload("res://src/enemies/encounter/spawn_card_catalog.gd")
const HeavyGunshipBossScript = preload("res://src/enemies/boss/heavy_gunship_boss.gd")

# Wave State
var current_wave: int = 1
var wave_timer: float = 45.0
var wave_max_duration: float = 45.0
var is_wave_active: bool = false
var active_theme: String = "Normal"
var transition_timer: float = 0.0
var wave_kills: int = 0
var wave_kill_quota: int = 0

# Pause-aware Active Combat Time (seconds)
var active_combat_time: float = 0.0

# Attack Slot Permissions & Pause-Aware Leases (Section 1 & 7)
var max_air_slots: int = 1
var current_air_attackers: Array[Node] = []
var air_slot_leases: Dictionary = {} # Node -> { "granted_at": float, "token": int }

var max_heavy_slots: int = 1
var current_heavy_attackers: Array[Node] = []
var heavy_slot_leases: Dictionary = {} # Node -> { "granted_at": float, "token": int }

# Backward compatibility timestamp dictionary (using active_combat_time * 1000)
var attacker_slot_timestamps: Dictionary = {}

var _next_token: int = 1
const LEASE_TIMEOUT_SECONDS: float = 6.0

# Population targets by wave group (Page 11)
var target_population: int = 5
var base_target_population: int = 5
const MAX_ACTIVE_POPULATION: int = 40

# Difficulty Settings
var difficulty_level: String = "Normal"
var difficulty_pop_factor: float = 1.0 # Casual: 0.65, Normal: 1.0, Hard: 1.12

# Cumulative encounter counters (Section 8 Telemetry)
var cumulative_spawns: int = 0
var cumulative_shots_emitted: int = 0
var cumulative_damage_landed: float = 0.0
var cumulative_stuck_recoveries: int = 0

# ==============================================================================
# AUTONOMOUS CREDIT ECONOMY & DUAL STREAMS (Section 3 & 4)
# ==============================================================================
var use_credit_director: bool = true
var catalog: SpawnCardCatalogClass = null
var seedable_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var encounter_seed: int = 1337

# Wallets and budgets
var fast_wallet: float = 0.0
var slow_wallet: float = 0.0
var fast_wallet_cap: float = 60.0
var slow_wallet_cap: float = 120.0
var fast_base_income: float = 7.0
var slow_base_income: float = 4.5

# Evaluation intervals and work bounds
var fast_eval_timer: float = 0.0
var slow_eval_timer: float = 0.0
const FAST_EVAL_INTERVAL: float = 0.8
const SLOW_EVAL_INTERVAL: float = 2.0
const MAX_FAST_PURCHASES_PER_EVAL: int = 2
const MAX_SLOW_PURCHASES_PER_EVAL: int = 1

# Capacity reservations
var reserved_population: int = 0
var reserved_variants: Dictionary = {}
var spawn_transactions: Dictionary = {}
var next_spawn_transaction: int = 1
var wave_boss_spawned: bool = false
var composition_pool: Array[String] = []
var decision_history: Array[Dictionary] = []
const MAX_HISTORY: int = 128
const MAX_SIMULATION_DELTA: float = 0.1

# Telemetry tracking properties
var telemetry_purchases_fast: int = 0
var telemetry_purchases_slow: int = 0
var telemetry_rejections: int = 0
var telemetry_refunds: int = 0
var telemetry_retirements: int = 0
var telemetry_last_sector: float = 0.0
var telemetry_last_distance: float = 0.0

func set_encounter_seed(seed_val: int) -> void:
	encounter_seed = seed_val
	seedable_rng.seed = seed_val

func record_spawn() -> void:
	cumulative_spawns += 1

func record_shot() -> void:
	cumulative_shots_emitted += 1

func record_damage_landed(amount: float) -> void:
	cumulative_damage_landed += amount

func record_stuck_recovery() -> void:
	cumulative_stuck_recoveries += 1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	catalog = SpawnCardCatalogClass.new()
	seedable_rng.seed = encounter_seed
	if has_node("/root/EventBus"):
		var bus = get_node("/root/EventBus")
		bus.run_state_changed.connect(_on_run_state_changed)
		bus.entity_destroyed.connect(_on_entity_destroyed)

func stop_wave_director() -> void:
	is_wave_active = false
	transition_timer = 0.0
	wave_kills = 0
	wave_kill_quota = 0
	fast_wallet = 0.0
	slow_wallet = 0.0
	reserved_population = 0
	reserved_variants.clear()
	spawn_transactions.clear()
	_notify_and_clear_all_slots()

func _on_run_state_changed(new_state: int, _previous: int) -> void:
	if new_state in [GameManager.RunState.MENU, GameManager.RunState.RESULTS, GameManager.RunState.LOADING]:
		stop_wave_director()

func start_wave_director() -> void:
	stop_wave_director()
	seedable_rng.seed = encounter_seed
	composition_pool.clear()
	decision_history.clear()
	var spawner = _find_enemy_spawner()
	if spawner and spawner.has_method("reset_encounter"):
		spawner.reset_encounter(encounter_seed)
	cumulative_spawns = 0
	cumulative_shots_emitted = 0
	cumulative_damage_landed = 0.0
	cumulative_stuck_recoveries = 0
	telemetry_purchases_fast = 0
	telemetry_purchases_slow = 0
	telemetry_rejections = 0
	telemetry_refunds = 0
	telemetry_retirements = 0
	current_wave = 1
	wave_boss_spawned = false
	active_combat_time = 0.0
	_setup_wave(1)

func _setup_wave(wave_num: int) -> void:
	transition_timer = 0.0
	current_wave = wave_num
	is_wave_active = true
	wave_kills = 0

	# Duration formula: 45s on wave 1, falling 1.5s/wave to 30s floor (Page 11)
	wave_max_duration = maxf(30.0, 45.0 - float(wave_num - 1) * 1.5)
	wave_timer = wave_max_duration

	# Dynamic Kill Quota for responsive pacing:
	if wave_num <= 3:
		wave_kill_quota = [6, 9, 12][wave_num - 1]
	elif wave_num <= 6:
		wave_kill_quota = [15, 18, 22][wave_num - 4]
	elif wave_num <= 9:
		wave_kill_quota = [25, 29, 34][wave_num - 7]
	elif wave_num == 10:
		wave_kill_quota = 0
	else:
		wave_kill_quota = 25 + (wave_num - 10) * 3

	# Determine Wave Theme before calculating theme-scaled population (Page 11)
	_select_wave_theme(wave_num)
	_refresh_composition_pool()

	# Population targets by wave group (Page 11)
	var base_target = 5
	if wave_num <= 3:
		base_target = [5, 7, 10][wave_num - 1]
	elif wave_num <= 6:
		base_target = [12, 14, 16][wave_num - 4]
	elif wave_num <= 9:
		base_target = [18, 21, 24][wave_num - 7]
	elif wave_num == 10:
		base_target = 10 # Boss + 10 background units
	else:
		base_target = 24 + (wave_num - 10) * 2

	base_target_population = base_target

	# Swarm Tide theme factor (+25% population) (Page 11)
	var theme_mult = 1.25 if active_theme == "Swarm Tide" else 1.0
	target_population = clampi(int(float(base_target) * difficulty_pop_factor * theme_mult), 3, MAX_ACTIVE_POPULATION)
	# A wave containing only the five-cap Scout Buggy cannot fill a larger target.
	# Keep real per-variant caps and unlock gates instead of waiting for banned drones.
	target_population = mini(target_population, EnemyData.regular_wave_capacity(wave_num))

	# Air attack slots (1 early up to 4 at wave 9; 2 during boss)
	if wave_num == 10:
		max_air_slots = 2
		max_heavy_slots = 1
	else:
		max_air_slots = mini(4, 1 + int(float(wave_num) / 2.5))
		max_heavy_slots = mini(3, 1 + int(float(wave_num) / 4.0))

	# Seed initial opening wave budget so fast stream deploys initial cohort cleanly
	if use_credit_director:
		fast_wallet = minf(fast_wallet_cap, fast_wallet + 24.0)
		if wave_num >= 3:
			slow_wallet = minf(slow_wallet_cap, slow_wallet + 30.0)

		fast_eval_timer = 0.1
		slow_eval_timer = 0.3

	if wave_num == 10:
		_check_wave_10_boss()

	if is_inside_tree() and has_node("/root/EventBus"):
		get_node("/root/EventBus").wave_started.emit(current_wave, active_theme, wave_max_duration)

func _select_wave_theme(wave_num: int) -> void:
	if wave_num >= 11:
		active_theme = "Endless Overdrive"
	elif wave_num == 3:
		active_theme = "Storm Surge" # Forced storm theme (Page 11)
	elif wave_num <= 2 or wave_num == 10:
		active_theme = "Normal" # Early learning protection & milestone boss (Page 11)
	elif wave_num >= 8 and seedable_rng.randf() < 0.25:
		active_theme = "Night Surge" # Seeded 25% night operations
	elif wave_num % 3 == 0:
		active_theme = "Armored Column"
	elif wave_num % 2 == 0:
		active_theme = "Swarm Tide"
	else:
		active_theme = "Normal"

## Section 4: Run-tied difficulty formula D
func get_difficulty_multiplier() -> float:
	var active_minutes: float = active_combat_time / 60.0
	var d_factor: float = 1.0
	match difficulty_level:
		"Casual": d_factor = 0.75
		"Hard": d_factor = 1.20
		_: d_factor = 1.0
	var progress_waves: float = float(maxi(0, current_wave - 1))
	var d_val = d_factor * (1.0 + 0.08 * active_minutes + 0.06 * progress_waves)
	return clampf(d_val, 0.5, 3.0)

func get_theme_income_factor(stream: String) -> float:
	match active_theme:
		"Swarm Tide":
			return 1.35 if stream == "fast" else 0.80
		"Armored Column":
			return 0.80 if stream == "fast" else 1.35
		"Storm Surge":
			return 1.10
		"Night Surge":
			return 1.15
		"Endless Overdrive":
			return 1.30
		_:
			return 1.0

func is_active_combat_eligible() -> bool:
	return is_wave_active and is_encounter_clock_eligible()

func is_encounter_clock_eligible() -> bool:
	if get_tree().paused:
		return false
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if not (gm.current_state in [gm.RunState.ACTIVE, gm.RunState.EXTRACTION]):
			return false
	return true

func get_active_enemy_count() -> int:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var count = 0
	for e in enemies:
		if is_instance_valid(e) and not e.is_queued_for_deletion():
			if not (e.has_node("DamageReceiver") and e.get_node("DamageReceiver").is_dead):
				count += 1
	return count

func get_active_variant_counts() -> Dictionary:
	var counts: Dictionary = {}
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if is_instance_valid(e) and not e.is_queued_for_deletion():
			if not (e.has_node("DamageReceiver") and e.get_node("DamageReceiver").is_dead):
				var v_id = e.variant_id if "variant_id" in e else ""
				if not v_id.is_empty():
					counts[v_id] = counts.get(v_id, 0) + 1
	return counts

func _process(delta: float) -> void:
	if not is_encounter_clock_eligible():
		# Freezes completely on pause, upgrade choice, boss decision, results, and transitions.
		# No catch-up income or leases expire!
		return

	# Discard stall time instead of paying banked income/spawning on resume.
	delta = clampf(delta, 0.0, MAX_SIMULATION_DELTA)

	# Intermission uses the same pausable game clock as active waves.
	if transition_timer > 0.0:
		transition_timer = maxf(0.0, transition_timer - delta)
		if transition_timer <= 0.0:
			_setup_wave(current_wave + 1)
		return

	if not is_wave_active:
		return
	active_combat_time += delta
	if current_wave == 10 and not wave_boss_spawned:
		_check_wave_10_boss()

	# Wave timer countdown
	wave_timer = maxf(0.0, wave_timer - delta)
	if wave_timer <= 0.0:
		_complete_current_wave()
		if not is_wave_active:
			return

	# Periodic cleanup of dead or expired attacker references
	_cleanup_attack_slots()

	# --------------------------------------------------------------------------
	# Dual-Stream Economy Accumulation & Evaluation (Section 3 & 4)
	# --------------------------------------------------------------------------
	if not use_credit_director:
		return

	var active_count = get_active_enemy_count()
	var current_total = active_count + reserved_population
	var d_mult = get_difficulty_multiplier()

	if current_total < target_population and current_total < MAX_ACTIVE_POPULATION:
		var fast_inc = fast_base_income * d_mult * get_theme_income_factor("fast")
		var slow_inc = slow_base_income * d_mult * get_theme_income_factor("slow")
		fast_wallet = minf(fast_wallet_cap, fast_wallet + fast_inc * delta)
		slow_wallet = minf(slow_wallet_cap, slow_wallet + slow_inc * delta)
	else:
		# Anti-avalanche: Clamp to caps without endless accumulation
		fast_wallet = minf(fast_wallet_cap, fast_wallet)
		slow_wallet = minf(slow_wallet_cap, slow_wallet)

	fast_eval_timer -= delta
	if fast_eval_timer <= 0.0:
		fast_eval_timer = FAST_EVAL_INTERVAL
		_evaluate_stream("fast")

	slow_eval_timer -= delta
	if slow_eval_timer <= 0.0:
		slow_eval_timer = SLOW_EVAL_INTERVAL
		_evaluate_stream("slow")

func _evaluate_stream(stream: String) -> void:
	if catalog == null or not is_active_combat_eligible():
		return
	var spawner = _find_enemy_spawner()
	if not spawner:
		return

	var active_counts = get_population_counts_with_reservations()
	var active_total = get_active_enemy_count()
	var current_total = active_total + reserved_population
	if current_total >= target_population or current_total >= MAX_ACTIVE_POPULATION:
		telemetry_rejections += 1
		return

	var wallet_balance = fast_wallet if stream == "fast" else slow_wallet
	var eligible_cards = catalog.get_affordable_eligible_cards(
		current_wave,
		active_theme,
		stream,
		wallet_balance,
		active_counts,
		current_total,
		target_population,
		MAX_ACTIVE_POPULATION
	)

	if eligible_cards.is_empty():
		telemetry_rejections += 1
		return

	var max_purchases = MAX_FAST_PURCHASES_PER_EVAL if stream == "fast" else MAX_SLOW_PURCHASES_PER_EVAL
	for _p in range(max_purchases):
		current_total = get_active_enemy_count() + reserved_population
		if current_total >= target_population or current_total >= MAX_ACTIVE_POPULATION:
			break
		wallet_balance = fast_wallet if stream == "fast" else slow_wallet
		eligible_cards = catalog.get_affordable_eligible_cards(
			current_wave,
			active_theme,
			stream,
			wallet_balance,
			active_counts,
			current_total,
			target_population,
			MAX_ACTIVE_POPULATION
		)
		if eligible_cards.is_empty():
			break
		eligible_cards = filter_composition(eligible_cards)
		if eligible_cards.is_empty():
			break

		var chosen_card = _select_weighted_card(eligible_cards)
		if not chosen_card:
			break

		spawner.spawn_director_card(chosen_card, stream)
		active_counts = get_population_counts_with_reservations()

func _select_weighted_card(cards: Array[SpawnCard]) -> SpawnCard:
	if cards.is_empty():
		return null
	# Pick a category first so adding cards does not multiply its weight.
	var categories: Dictionary = {}
	for card in cards:
		if not categories.has(card.category):
			categories[card.category] = []
		categories[card.category].append(card)
	var category_total := 0.0
	var category_weights: Dictionary = {}
	for category in categories:
		var value := 0.0
		for card in categories[category]:
			value += catalog.get_card_weight(card, active_theme, get_active_variant_counts())
		value /= categories[category].size()
		category_weights[category] = value
		category_total += value
	var category_roll := seedable_rng.randf() * category_total
	for category in categories:
		category_roll -= category_weights[category]
		if category_roll <= 0.0:
			cards = []
			cards.assign(categories[category])
			break
	var total_w = 0.0
	var weights: Array[float] = []
	var active_counts = get_active_variant_counts()
	for c in cards:
		var w = catalog.get_card_weight(c, active_theme, active_counts)
		weights.append(w)
		total_w += w
	if total_w <= 0.0:
		return cards[0]
	var roll = seedable_rng.randf() * total_w
	var accum = 0.0
	for i in range(cards.size()):
		accum += weights[i]
		if roll <= accum:
			return cards[i]
	return cards[cards.size() - 1]

func record_decision(reason: String, details: Dictionary = {}) -> void:
	var entry = details.duplicate()
	entry.merge({"reason": reason, "time": active_combat_time, "wave": current_wave,
		"seed": encounter_seed, "fast": fast_wallet, "slow": slow_wallet,
		"reserved": reserved_population}, true)
	decision_history.append(entry)
	if decision_history.size() > MAX_HISTORY:
		decision_history.pop_front()

func get_population_counts_with_reservations() -> Dictionary:
	var counts = get_active_variant_counts()
	for key in reserved_variants:
		counts[key] = counts.get(key, 0) + reserved_variants[key]
	return counts

func can_spawn_variant(variant_id: String, count: int = 1, launch_source: Node3D = null) -> bool:
	if not EnemyData.is_variant_enabled(variant_id) or count < 1:
		return false
	if not EnemyData.is_regular_wave_variant(variant_id) and not _is_living_carrier_launch(launch_source):
		return false
	var spec = EnemyData.get_spec(variant_id)
	if current_wave < int(spec.get("gate_wave", 1)):
		return false
	var total := get_active_enemy_count() + reserved_population
	if total + count > mini(target_population, MAX_ACTIVE_POPULATION):
		return false
	var counts = get_population_counts_with_reservations()
	if int(counts.get(variant_id, 0)) + count > int(spec.get("max_cap", 4)):
		return false
	var ground := 0
	var support := 0
	for key in counts:
		var other = EnemyData.get_spec(key)
		if other.get("family", "") == "ground":
			ground += int(counts[key])
		if key in ["shield_drone", "repair_drone"]:
			support += int(counts[key])
	if spec.get("family", "") == "ground" and EnemyData.has_regular_wave_air(current_wave):
		var share := 0.8 if active_theme == "Armored Column" else 0.65
		if ground + count > maxi(2, ceili(target_population * share)):
			return false
	if variant_id in ["shield_drone", "repair_drone"] and support + count > 2:
		return false
	return true

func _is_living_carrier_launch(source: Node3D) -> bool:
	return is_instance_valid(source) and not source.is_queued_for_deletion() and source.is_in_group("bosses") and source.has_method("escort_launch_position") and source.has_node("DamageReceiver") and not source.get_node("DamageReceiver").is_dead

func reserve_spawn_card(card: SpawnCard, stream: String, launch_source: Node3D = null) -> int:
	if not is_active_combat_eligible() or catalog == null or card == null:
		return 0
	if catalog.get_card_by_id(card.card_id) != card or not card.is_eligible(current_wave, active_theme, stream):
		return 0
	if stream not in ["fast", "slow"] or not can_spawn_variant(card.variant_id, card.group_size, launch_source):
		record_decision("capacity_or_gate", {"card": card.card_id})
		return 0
	var cost := card.cost * card.group_size
	var wallet := fast_wallet if stream == "fast" else slow_wallet
	if cost > wallet:
		return 0
	if stream == "fast":
		fast_wallet -= cost
	else:
		slow_wallet -= cost
	var token := next_spawn_transaction
	next_spawn_transaction += 1
	spawn_transactions[token] = {"card": card, "stream": stream, "remaining": card.group_size, "settled": {}}
	reserved_population += card.group_size
	reserved_variants[card.variant_id] = int(reserved_variants.get(card.variant_id, 0)) + card.group_size
	record_decision("reserved", {"card": card.card_id, "token": token})
	return token

func settle_spawn_member(token: int, committed: bool, member_index: int = 0) -> bool:
	if not spawn_transactions.has(token):
		return false
	var transaction: Dictionary = spawn_transactions[token]
	var card: SpawnCard = transaction.card
	if member_index < 0 or member_index >= card.group_size or transaction.settled.has(member_index):
		return false
	transaction.settled[member_index] = true
	var stream: String = transaction.stream
	transaction.remaining -= 1
	reserved_population -= 1
	reserved_variants[card.variant_id] -= 1
	if committed:
		cumulative_spawns += 1
		if stream == "fast": telemetry_purchases_fast += 1
		else: telemetry_purchases_slow += 1
	else:
		if stream == "fast": fast_wallet = minf(fast_wallet_cap, fast_wallet + card.cost)
		else: slow_wallet = minf(slow_wallet_cap, slow_wallet + card.cost)
		telemetry_refunds += 1
	record_decision("committed" if committed else "refunded", {"card": card.card_id, "token": token})
	if transaction.remaining == 0:
		spawn_transactions.erase(token)
	return true

func _refresh_composition_pool() -> void:
	composition_pool.clear()
	if catalog == null:
		return
	var groups: Dictionary = {}
	for card in catalog.get_all_cards():
		if card.gate_wave > current_wave or not EnemyData.is_regular_wave_variant(card.variant_id):
			continue
		var role := "ground" if not card.is_air else ("light_air" if card.category == "light_mobile" else "air")
		if not groups.has(role): groups[role] = []
		if card.variant_id not in groups[role]: groups[role].append(card.variant_id)
	# Always retain basic pressure and an affordable fast-stream option.
	composition_pool.append("scout_buggy")
	for role in groups:
		var choices: Array = groups[role].duplicate()
		while not choices.is_empty() and composition_pool.size() < 5:
			var index := seedable_rng.randi_range(0, choices.size() - 1)
			var chosen: String = choices.pop_at(index)
			if chosen not in composition_pool:
				composition_pool.append(chosen)
				break
	# Newly unlocked variants participate immediately rather than waiting for a reroll.
	for card in catalog.get_all_cards():
		if EnemyData.is_regular_wave_variant(card.variant_id) and card.gate_wave == current_wave and card.variant_id not in composition_pool:
			composition_pool.append(card.variant_id)

func filter_composition(cards: Array[SpawnCard]) -> Array[SpawnCard]:
	var result: Array[SpawnCard] = []
	for card in cards:
		if card.variant_id in composition_pool and can_spawn_variant(card.variant_id, card.group_size):
			result.append(card)
	return result

func _find_enemy_spawner() -> Node:
	var spawners = get_tree().get_nodes_in_group("enemy_spawners")
	if not spawners.is_empty() and is_instance_valid(spawners[0]):
		return spawners[0]
	var player = get_tree().get_first_node_in_group("player")
	if player and player.get_parent():
		var sp = player.get_parent().get_node_or_null("EnemySpawner")
		if sp:
			return sp
	var scene = get_tree().current_scene
	if scene:
		var sp = scene.get_node_or_null("EnemySpawner")
		if sp:
			return sp
	return null

func _check_wave_10_boss() -> void:
	if current_wave != 10 or wave_boss_spawned:
		return
	var bosses = get_tree().get_nodes_in_group("bosses")
	for b in bosses:
		if is_instance_valid(b) and not (b.has_node("DamageReceiver") and b.get_node("DamageReceiver").is_dead):
			wave_boss_spawned = true
			return
	if get_active_enemy_count() >= MAX_ACTIVE_POPULATION:
		return
	var player = get_tree().get_first_node_in_group("player")
	var center = player.global_position if player else Vector3.ZERO
	var gm = get_node_or_null("/root/GameManager")
	var biome: String = gm.selected_biome if gm else "town"
	var boss_pos = center + Vector3(0, 26, 75)
	var spawner = _find_enemy_spawner()
	if spawner and player:
		var boss_key := "boss_ground_fortress" if biome == "desert" else ("boss_air_titan" if biome == "harbor" else "attack_gunship")
		boss_pos = spawner.find_valid_spawn_position("ground" if biome == "desert" else "air", center, boss_key)
		if boss_pos == Vector3.INF:
			return
	var boss = HeavyGunshipBossScript.new()
	if biome in ["desert", "harbor"]:
		boss.free()
		boss = preload("res://src/enemies/boss/modular_fortress_boss.gd").new()
		boss.fortress_kind = "ground" if biome == "desert" else "air"
	boss.position = boss_pos
	var parent = get_tree().current_scene if get_tree().current_scene else get_tree().root
	parent.add_child(boss)
	boss.global_position = boss_pos
	wave_boss_spawned = true
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").boss_spawned.emit(boss)

func _on_entity_destroyed(entity: Node, _killer: String, _score: int, _xp: int) -> void:
	if not is_wave_active or current_wave == 10:
		return
	if is_instance_valid(entity) and entity.is_in_group("enemies"):
		wave_kills += 1
		if wave_kill_quota > 0 and wave_kills >= wave_kill_quota:
			var active_enemies = get_active_enemy_count()
			if active_enemies <= 1 or (wave_max_duration - wave_timer >= 8.0):
				_complete_current_wave()

func _complete_current_wave() -> void:
	if not is_wave_active:
		return
	# Wave 10 requires defeating the Heavy Gunship boss before clearing
	if current_wave == 10:
		if not wave_boss_spawned:
			wave_timer = 5.0
			return
		var bosses = get_tree().get_nodes_in_group("bosses")
		var boss_alive = false
		for b in bosses:
			if is_instance_valid(b) and not (b.has_node("DamageReceiver") and b.get_node("DamageReceiver").is_dead):
				boss_alive = true
				break
		if boss_alive:
			wave_timer = 5.0
			return

	is_wave_active = false

	# Modest repair of 10 + new wave number (Page 11)
	var heal_amt = 10.0 + float(current_wave + 1)
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("repair"):
		player.repair(heal_amt)

	if is_inside_tree() and has_node("/root/EventBus"):
		get_node("/root/EventBus").wave_cleared.emit(current_wave)

	# Transition to next wave after 3 seconds (unless wave 10 where boss decision modal controls transition)
	if current_wave != 10:
		transition_timer = 3.0

func start_overdrive_wave(wave_num: int, _scale_mult: float = 1.25) -> void:
	_setup_wave(wave_num)

# ------------------------------------------------------------------------------
# Attack Slot Management (Page 10, Section 1 & 7)
# ------------------------------------------------------------------------------
func request_air_attack_slot(enemy: Node) -> bool:
	_cleanup_attack_slots()
	if not is_instance_valid(enemy):
		return false
	if air_slot_leases.has(enemy):
		air_slot_leases[enemy]["granted_at"] = active_combat_time
		return true
	if current_air_attackers.size() < max_air_slots:
		_next_token += 1
		air_slot_leases[enemy] = { "granted_at": active_combat_time, "token": _next_token }
		current_air_attackers.append(enemy)
		attacker_slot_timestamps[enemy] = Time.get_ticks_msec()
		return true
	return false

func release_air_attack_slot(enemy: Node) -> void:
	if not enemy:
		return
	air_slot_leases.erase(enemy)
	current_air_attackers.erase(enemy)
	attacker_slot_timestamps.erase(enemy)

func request_heavy_attack_slot(enemy: Node) -> bool:
	_cleanup_attack_slots()
	if not is_instance_valid(enemy):
		return false
	if heavy_slot_leases.has(enemy):
		heavy_slot_leases[enemy]["granted_at"] = active_combat_time
		return true
	if current_heavy_attackers.size() < max_heavy_slots:
		_next_token += 1
		heavy_slot_leases[enemy] = { "granted_at": active_combat_time, "token": _next_token }
		current_heavy_attackers.append(enemy)
		attacker_slot_timestamps[enemy] = Time.get_ticks_msec()
		return true
	return false

func release_heavy_attack_slot(enemy: Node) -> void:
	if not enemy:
		return
	heavy_slot_leases.erase(enemy)
	current_heavy_attackers.erase(enemy)
	attacker_slot_timestamps.erase(enemy)

func has_air_attack_slot(enemy: Node) -> bool:
	return current_air_attackers.has(enemy) or air_slot_leases.has(enemy)

func has_heavy_attack_slot(enemy: Node) -> bool:
	return current_heavy_attackers.has(enemy) or heavy_slot_leases.has(enemy)

## Atomic acquisition of multiple budget resources (Section 7)
## Grants both or neither to prevent deadlocks and indefinite starvation.
func request_combined_attack_slots(enemy: Node, need_air: bool, need_heavy: bool) -> bool:
	_cleanup_attack_slots()
	if not is_instance_valid(enemy):
		return false

	var can_air = not need_air or air_slot_leases.has(enemy) or current_air_attackers.size() < max_air_slots
	var can_heavy = not need_heavy or heavy_slot_leases.has(enemy) or current_heavy_attackers.size() < max_heavy_slots

	if can_air and can_heavy:
		if need_air:
			request_air_attack_slot(enemy)
		if need_heavy:
			request_heavy_attack_slot(enemy)
		return true

	return false

func has_air_slot(enemy: Node) -> bool:
	return air_slot_leases.has(enemy)

func has_heavy_slot(enemy: Node) -> bool:
	return heavy_slot_leases.has(enemy)

func _notify_and_clear_all_slots() -> void:
	var all_enemies: Dictionary = {}
	for e in current_air_attackers:
		all_enemies[e] = true
	for e in current_heavy_attackers:
		all_enemies[e] = true

	current_air_attackers.clear()
	air_slot_leases.clear()
	current_heavy_attackers.clear()
	heavy_slot_leases.clear()
	attacker_slot_timestamps.clear()

	for e in all_enemies:
		if is_instance_valid(e) and e.has_method("on_attack_slot_expired"):
			e.on_attack_slot_expired("all")

func _cleanup_attack_slots() -> void:
	# 1. Cleanup Air slots
	for i in range(current_air_attackers.size() - 1, -1, -1):
		var enemy: Node = current_air_attackers[i]
		var is_dead_or_invalid = not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or (enemy.has_node("DamageReceiver") and enemy.get_node("DamageReceiver").is_dead)
		var lease_info = air_slot_leases.get(enemy, {})
		var granted_at: float = lease_info.get("granted_at", active_combat_time)
		var expired = (active_combat_time - granted_at) > LEASE_TIMEOUT_SECONDS

		if is_dead_or_invalid or expired:
			current_air_attackers.remove_at(i)
			air_slot_leases.erase(enemy)
			attacker_slot_timestamps.erase(enemy)
			if not is_dead_or_invalid and is_instance_valid(enemy) and enemy.has_method("on_attack_slot_expired"):
				enemy.on_attack_slot_expired("air")

	# 2. Cleanup Heavy slots
	for i in range(current_heavy_attackers.size() - 1, -1, -1):
		var enemy: Node = current_heavy_attackers[i]
		var is_dead_or_invalid = not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or (enemy.has_node("DamageReceiver") and enemy.get_node("DamageReceiver").is_dead)
		var lease_info = heavy_slot_leases.get(enemy, {})
		var granted_at: float = lease_info.get("granted_at", active_combat_time)
		var expired = (active_combat_time - granted_at) > LEASE_TIMEOUT_SECONDS

		if is_dead_or_invalid or expired:
			current_heavy_attackers.remove_at(i)
			heavy_slot_leases.erase(enemy)
			attacker_slot_timestamps.erase(enemy)
			if not is_dead_or_invalid and is_instance_valid(enemy) and enemy.has_method("on_attack_slot_expired"):
				enemy.on_attack_slot_expired("heavy")
