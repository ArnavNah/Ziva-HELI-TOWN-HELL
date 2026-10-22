class_name SpawnCardCatalog
extends RefCounted

## SpawnCardCatalog — Master repository of validated SpawnCards for the autonomous director.
## Guarantees roster integrity: only the five active ground vehicles, active air/support variants,
## and strictly rejects all eight disabled ground types.

const EnemyDataClass = preload("res://src/enemies/enemy_data.gd")
const SpawnCardClass = preload("res://src/resources/spawn_card.gd")

var _cards: Array[SpawnCard] = []
var _cards_by_id: Dictionary = {}

func _init() -> void:
	_build_catalog()

func _create_card(
	card_id: String,
	variant_id: String,
	category: String,
	cost: int,
	weight: float,
	allowed_streams: Array[String],
	group_size: int = 1,
	modifier: int = 0,
	allowed_themes: Array[String] = []
) -> SpawnCard:
	var spec: Dictionary = EnemyDataClass.get_spec(variant_id)
	var card := SpawnCardClass.new()
	card.card_id = card_id
	card.variant_id = variant_id
	card.category = category
	card.cost = cost
	card.weight = weight
	card.allowed_streams = allowed_streams
	card.allowed_themes = allowed_themes
	card.group_size = group_size
	card.modifier_type = modifier

	# Inherit authoritative specs from EnemyData
	card.gate_wave = int(spec.get("gate_wave", 1))
	card.max_cap = int(spec.get("max_cap", 4))
	card.is_heavy = bool(spec.get("is_heavy", false))
	card.is_air = (spec.get("family", "air") != "ground")
	card.requires_heavy_slot = bool(spec.get("requires_heavy_slot", false))
	card.requires_air_slot = bool(spec.get("requires_air_slot", false))

	return card

func _build_catalog() -> void:
	_cards.clear()
	_cards_by_id.clear()

	# =========================================================================
	# ACTIVE GROUND VEHICLES (Exactly 7 variants)
	# =========================================================================
	# 1. Scout Buggy (Light Mobile)
	_add_card(_create_card("scout_buggy_solo", "scout_buggy", "light_mobile", 12, 3.5, ["fast"], 1))
	# Cost is per member; the group purchase reserves cost * group_size.
	_add_card(_create_card("scout_buggy_duo", "scout_buggy", "light_mobile", 12, 1.6, ["fast"], 2))
	# Elite shielded buggy (Wave 4+)
	var buggy_shield = _create_card("scout_buggy_shielded", "scout_buggy", "light_mobile", 20, 1.0, ["fast"], 1, EnemyDataClass.ModifierType.SHIELDED)
	buggy_shield.gate_wave = 4
	_add_card(buggy_shield)

	# 2. Assault APC (Heavy Armor / Mobile Pressure)
	_add_card(_create_card("assault_apc_solo", "assault_apc", "heavy_armor", 28, 2.2, ["slow"], 1))
	var apc_elite = _create_card("assault_apc_elite", "assault_apc", "heavy_armor", 42, 0.9, ["slow"], 1, EnemyDataClass.ModifierType.ELITE)
	apc_elite.gate_wave = 5
	_add_card(apc_elite)

	# 3. Azure Siege Tank (Rail Crawler - Heavy Armor / Long Range Rail Threat)
	_add_card(_create_card("rail_crawler_solo", "rail_crawler", "heavy_armor", 45, 1.6, ["slow"], 1))

	# 4. Desert Ironclad (Siege Tank - Heavy Armor Artillery Threat)
	_add_card(_create_card("siege_tank_solo", "siege_tank", "heavy_armor", 55, 1.2, ["slow"], 1))

	# 5. Ironclad Sentinel (Gatling Heavy - Rotary Autocannon Threat)
	_add_card(_create_card("gatling_heavy_solo", "gatling_heavy", "heavy_armor", 50, 1.4, ["slow"], 1))

	# 6. Raptor Raider (Mobile Cannon Raider)
	_add_card(_create_card("raptor_raider_solo", "raptor_raider", "light_mobile", 20, 2.8, ["fast"], 1))
	var raptor_duo = _create_card("raptor_raider_duo", "raptor_raider", "light_mobile", 20, 1.4, ["fast"], 2)
	raptor_duo.gate_wave = 3
	_add_card(raptor_duo)
	var raptor_shield = _create_card("raptor_raider_shielded", "raptor_raider", "light_mobile", 30, 0.9, ["fast"], 1, EnemyDataClass.ModifierType.SHIELDED)
	raptor_shield.gate_wave = 4
	_add_card(raptor_shield)

	# 7. Desert Barrage Rover (Wheeled Missile Barrage Vehicle)
	_add_card(_create_card("desert_barrage_rover_solo", "desert_barrage_rover", "heavy_armor", 38, 1.6, ["slow"], 1))
	var rover_elite = _create_card("desert_barrage_rover_elite", "desert_barrage_rover", "heavy_armor", 52, 0.8, ["slow"], 1, EnemyDataClass.ModifierType.ELITE)
	rover_elite.gate_wave = 6
	_add_card(rover_elite)

	# =========================================================================
	# ACTIVE AIR VARIANTS (12 variants)
	# =========================================================================
	# Light / Close Pursuer Drones & Light Aircraft (Fast Stream)
	_add_card(_create_card("hunter_drone_solo", "hunter_drone", "light_mobile", 10, 3.0, ["fast"], 1))
	_add_card(_create_card("scout_drone_solo", "scout_drone", "light_mobile", 8, 3.5, ["fast"], 1))
	var scout_pair = _create_card("scout_drone_pair", "scout_drone", "light_mobile", 8, 1.8, ["fast"], 2)
	scout_pair.gate_wave = 3
	_add_card(scout_pair)
	_add_card(_create_card("attack_wing_solo", "attack_wing", "light_mobile", 18, 2.4, ["fast"], 1))
	_add_card(_create_card("kamikaze_drone_solo", "kamikaze_drone", "light_mobile", 14, 2.0, ["fast"], 1))

	# Attack Aircraft (Slow Stream)
	_add_card(_create_card("escort_fighter_solo", "escort_fighter", "attack_aircraft", 26, 2.2, ["fast", "slow"], 1))
	_add_card(_create_card("stealth_vtol_solo", "stealth_vtol", "attack_aircraft", 32, 1.8, ["slow"], 1))
	_add_card(_create_card("torpedo_vtol_solo", "torpedo_vtol", "attack_aircraft", 38, 1.6, ["slow"], 1))
	_add_card(_create_card("attack_gunship_solo", "attack_gunship", "attack_aircraft", 35, 2.2, ["slow"], 1))
	var gunship_shield = _create_card("attack_gunship_shielded", "attack_gunship", "attack_aircraft", 50, 0.8, ["slow"], 1, EnemyDataClass.ModifierType.SHIELDED)
	gunship_shield.gate_wave = 7
	_add_card(gunship_shield)
	_add_card(_create_card("rocket_gunship_solo", "rocket_gunship", "attack_aircraft", 48, 1.5, ["slow"], 1))
	_add_card(_create_card("heavy_bomber_solo", "heavy_bomber", "attack_aircraft", 52, 1.2, ["slow"], 1))
	_add_card(_create_card("interceptor_solo", "interceptor", "attack_aircraft", 42, 1.6, ["slow"], 1))

	# Support Variants (Slow Stream)
	_add_card(_create_card("shield_drone_solo", "shield_drone", "support", 25, 1.2, ["slow"], 1))
	_add_card(_create_card("repair_drone_solo", "repair_drone", "support", 30, 0.9, ["slow"], 1))

	# Area Denial (Slow Stream)
	_add_card(_create_card("minelayer_solo", "minelayer", "area_denial", 36, 1.2, ["slow"], 1))

func _add_card(card: SpawnCard) -> void:
	if card.validate() and not _cards_by_id.has(card.card_id):
		_cards.append(card)
		_cards_by_id[card.card_id] = card
	else:
		push_error("SpawnCardCatalog: Card failed validation: %s" % card.card_id)

func get_all_cards() -> Array[SpawnCard]:
	return _cards

func get_card_by_id(card_id: String) -> SpawnCard:
	return _cards_by_id.get(card_id, null)

## Filters cards by wave gate, stream, theme, wallet budget, variant caps, and population space.
func get_affordable_eligible_cards(
	wave: int,
	theme: String,
	stream: String,
	wallet_balance: float,
	active_counts: Dictionary,
	current_active_total: int,
	target_population: int,
	max_active_population: int
) -> Array[SpawnCard]:
	var eligible: Array[SpawnCard] = []

	for card in _cards:
		# 1. Eligibility gate & stream
		if not card.is_eligible(wave, theme, stream):
			continue

		# 2. Affordability
		var total_cost = card.cost * card.group_size
		if float(total_cost) > wallet_balance:
			continue

		# 3. Population capacity check
		if current_active_total + card.group_size > target_population:
			continue
		if current_active_total + card.group_size > max_active_population:
			continue

		# 4. Variant cap check
		var current_variant_count = int(active_counts.get(card.variant_id, 0))
		if current_variant_count + card.group_size > card.max_cap:
			continue

		eligible.append(card)

	return eligible

## Calculates dynamic selection weight adjusted for active theme and role representation
func get_card_weight(card: SpawnCard, theme: String, active_counts: Dictionary) -> float:
	var base_w: float = card.weight

	# Theme weighting adjustments
	match theme:
		"Swarm Tide":
			if card.category == "light_mobile":
				base_w *= 1.8
			elif card.category == "heavy_armor":
				base_w *= 0.4
		"Armored Column":
			if card.category == "heavy_armor":
				base_w *= 2.2
			elif card.category == "light_mobile" and not card.is_air:
				base_w *= 1.3
			elif card.category == "light_mobile" and card.is_air:
				base_w *= 0.5
		"Storm Surge":
			if card.variant_id in ["attack_gunship", "rocket_gunship", "assault_apc"]:
				base_w *= 1.6
		"Night Surge":
			if card.variant_id in ["interceptor", "gatling_heavy", "stealth_vtol"]:
				base_w *= 1.6
		"Endless Overdrive":
			if card.category in ["heavy_armor", "attack_aircraft"]:
				base_w *= 1.4

	# Underrepresented variants get slight boost
	var count = int(active_counts.get(card.variant_id, 0))
	if count == 0:
		base_w *= 1.35
	elif count == 1:
		base_w *= 1.1

	return maxf(0.01, base_w)
