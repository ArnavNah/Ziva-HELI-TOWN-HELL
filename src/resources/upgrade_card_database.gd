class_name UpgradeCardDatabase
extends RefCounted

## UpgradeCardDatabase — Master collection of data-driven UpgradeCard resources
## for the roguelite level-up draft system.

static var _master_deck: Array = []
static var _icons: Dictionary = {}

static func get_eligible_cards(player: Node) -> Array:
	var manager = player.get_node_or_null("SubsystemManager") if player else null
	var result: Array = []
	for card in get_master_deck():
		if manager and not manager.is_card_eligible(card):
			continue
		result.append(card)
	return result

static func _get_icon(subsystem: int) -> Texture2D:
	if not _icons.has(subsystem):
		var names := ["cannon", "rocket", "missile", "tome"]
		var svg = FileAccess.get_file_as_string("res://assets/ui/upgrades/%s.svg" % names[subsystem])
		var image := Image.new()
		if image.load_svg_from_string(svg) == OK:
			_icons[subsystem] = ImageTexture.create_from_image(image)
	return _icons.get(subsystem)

static func get_master_deck() -> Array:
	if _master_deck.is_empty():
		_initialize_master_deck()
	return _master_deck

static func get_cards_by_rarity(rarity: int) -> Array:
	var result: Array = []
	for card in get_master_deck():
		if card.rarity == rarity:
			result.append(card)
	return result

static func get_cards_by_subsystem(subsystem: int) -> Array:
	var result: Array = []
	for card in get_master_deck():
		if card.target_subsystem == subsystem:
			result.append(card)
	return result

static func _initialize_master_deck() -> void:
	_master_deck.clear()

	# ==========================================
	# 1. PRIMARY CANNON SUBSYSTEM
	# ==========================================
	_master_deck.append(UpgradeCard.create(
		"cannon_autoloader", "RAPID FEEDER",
		"+15% Cannon Fire Rate for increased bullet stream density.",
		UpgradeCard.RarityTier.COMMON, UpgradeCard.SubsystemType.PRIMARY_CANNON,
		{"fire_rate_mult": 0.15}
	))
	_master_deck.append(UpgradeCard.create(
		"cannon_heavy_slugs", "HEAVY CALIBER",
		"+15% Cannon Damage per round across all bullet impacts.",
		UpgradeCard.RarityTier.COMMON, UpgradeCard.SubsystemType.PRIMARY_CANNON,
		{"damage_mult": 0.15}
	))
	_master_deck.append(UpgradeCard.create(
		"cannon_depleted_core", "DEPLETED CORE",
		"+25% Cannon Damage and +20% Armor Piercing against hardened targets.",
		UpgradeCard.RarityTier.UNCOMMON, UpgradeCard.SubsystemType.PRIMARY_CANNON,
		{"damage_mult": 0.25, "armor_pierce": 0.20}
	))
	_master_deck.append(UpgradeCard.create(
		"cannon_cooling_shroud", "COOLING SHROUD",
		"+25% Cannon Reload Speed and +10% sustained Fire Rate.",
		UpgradeCard.RarityTier.UNCOMMON, UpgradeCard.SubsystemType.PRIMARY_CANNON,
		{"reload_speed_mult": 0.25, "fire_rate_mult": 0.10}
	))
	_master_deck.append(UpgradeCard.create(
		"cannon_rotary_overdrive", "ROTARY OVERDRIVE",
		"+35% Cannon Fire Rate and +30% expanded Magazine Capacity.",
		UpgradeCard.RarityTier.RARE, UpgradeCard.SubsystemType.PRIMARY_CANNON,
		{"fire_rate_mult": 0.35, "magazine_capacity_mult": 0.30}
	))
	_master_deck.append(UpgradeCard.create(
		"cannon_shredder_rounds", "FLAK SHAPNEL",
		"+25% Cannon Damage and fires +1 parallel bullet stream.",
		UpgradeCard.RarityTier.RARE, UpgradeCard.SubsystemType.PRIMARY_CANNON,
		{"damage_mult": 0.25, "projectile_count": 1}
	))
	_master_deck.append(UpgradeCard.create(
		"cannon_incendiary_cascade", "INCENDIARY MUNITIONS",
		"+35% Cannon Damage and 30% chance to ignite enemies with thermite burn.",
		UpgradeCard.RarityTier.EPIC, UpgradeCard.SubsystemType.PRIMARY_CANNON,
		{"damage_mult": 0.35, "burn_chance": 0.30}
	))
	_master_deck.append(UpgradeCard.create(
		"cannon_emp_shock", "ARC DISRUPTOR",
		"+30% Cannon Fire Rate and 25% chance to inflict EMP shock disabling enemy weapons.",
		UpgradeCard.RarityTier.EPIC, UpgradeCard.SubsystemType.PRIMARY_CANNON,
		{"fire_rate_mult": 0.30, "shock_chance": 0.25}
	))
	_master_deck.append(UpgradeCard.create(
		"cannon_vulcan_apex", "VULCAN APEX PROTOTYPE",
		"+60% Cannon Damage, +2 projectile streams, and +25% Reload Speed.",
		UpgradeCard.RarityTier.LEGENDARY, UpgradeCard.SubsystemType.PRIMARY_CANNON,
		{"damage_mult": 0.60, "projectile_count": 2, "reload_speed_mult": 0.25}
	))

	# ==========================================
	# 2. ROCKET PODS SUBSYSTEM
	# ==========================================
	_master_deck.append(UpgradeCard.create(
		"rocket_extended_pod", "EXPANDED RACK",
		"+4 Maximum Rocket Capacity and +15% Rocket Reload Speed.",
		UpgradeCard.RarityTier.COMMON, UpgradeCard.SubsystemType.ROCKET_PODS,
		{"ammo_max_add": 4, "reload_speed_mult": 0.15}
	))
	_master_deck.append(UpgradeCard.create(
		"rocket_shaped_charge", "HIGH EXPLOSIVE",
		"+20% Rocket Impact and Detonation Damage.",
		UpgradeCard.RarityTier.COMMON, UpgradeCard.SubsystemType.ROCKET_PODS,
		{"damage_mult": 0.20}
	))
	_master_deck.append(UpgradeCard.create(
		"rocket_blast_enhancer", "THERMOBARIC MIX",
		"+25% Rocket Blast Radius and +20% Blast Damage.",
		UpgradeCard.RarityTier.UNCOMMON, UpgradeCard.SubsystemType.ROCKET_PODS,
		{"blast_radius_mult": 0.25, "damage_mult": 0.20}
	))
	_master_deck.append(UpgradeCard.create(
		"rocket_rapid_feeder", "AUTOLOADER RACK",
		"-25% Rocket Salvo Interval and +20% Reload Speed.",
		UpgradeCard.RarityTier.UNCOMMON, UpgradeCard.SubsystemType.ROCKET_PODS,
		{"interval_reduction": 0.25, "reload_speed_mult": 0.20}
	))
	_master_deck.append(UpgradeCard.create(
		"rocket_cluster_bomblets", "CLUSTER DISPERSION",
		"Detonations spawn 3 secondary explosive bomblets with +25% blast coverage.",
		UpgradeCard.RarityTier.RARE, UpgradeCard.SubsystemType.ROCKET_PODS,
		{"cluster_count": 3, "blast_radius_mult": 0.25}
	))
	_master_deck.append(UpgradeCard.create(
		"rocket_tandem_warhead", "TANDEM WARHEAD",
		"+40% Damage vs Structures/Bunkers and +30% Armor-Piercing Damage.",
		UpgradeCard.RarityTier.RARE, UpgradeCard.SubsystemType.ROCKET_PODS,
		{"structure_damage_mult": 0.40, "damage_mult": 0.30}
	))
	_master_deck.append(UpgradeCard.create(
		"rocket_cyclone_salvo", "CYCLONE FEEDER",
		"Fires +2 Rockets per salvo trigger and accelerates reload speed by +35%.",
		UpgradeCard.RarityTier.EPIC, UpgradeCard.SubsystemType.ROCKET_PODS,
		{"projectile_count": 2, "reload_speed_mult": 0.35}
	))
	_master_deck.append(UpgradeCard.create(
		"rocket_plasma_payload", "PLASMA WARHEAD",
		"+50% Blast Radius, +45% Damage, leaving burning incendiary plasma zones.",
		UpgradeCard.RarityTier.EPIC, UpgradeCard.SubsystemType.ROCKET_PODS,
		{"blast_radius_mult": 0.50, "damage_mult": 0.45, "lingering_burn": true}
	))
	_master_deck.append(UpgradeCard.create(
		"rocket_apocalypse_battery", "APOCALYPSE PODS",
		"+75% Rocket Damage, +2 rockets per volley, and +40% apocalyptic Blast Radius.",
		UpgradeCard.RarityTier.LEGENDARY, UpgradeCard.SubsystemType.ROCKET_PODS,
		{"damage_mult": 0.75, "projectile_count": 2, "blast_radius_mult": 0.40}
	))

	# ==========================================
	# 3. GUIDED MISSILES SUBSYSTEM
	# ==========================================
	_master_deck.append(UpgradeCard.create(
		"missile_agile_fins", "AGILE CANARDS",
		"+35% Missile Turn Rate and +15% In-Flight Propulsion Speed.",
		UpgradeCard.RarityTier.COMMON, UpgradeCard.SubsystemType.GUIDED_MISSILES,
		{"turn_speed_mult": 0.35, "speed_mult": 0.15}
	))
	_master_deck.append(UpgradeCard.create(
		"missile_seeker_boost", "SENSOR UPLINK",
		"+25% Lock Acquisition Range and +15% Guided Missile Damage.",
		UpgradeCard.RarityTier.COMMON, UpgradeCard.SubsystemType.GUIDED_MISSILES,
		{"lock_range_mult": 0.25, "damage_mult": 0.15}
	))
	_master_deck.append(UpgradeCard.create(
		"missile_multi_lock", "MULTI-TARGET RADAR",
		"+2 Maximum Simultaneous Locks and -20% Target Painting Interval.",
		UpgradeCard.RarityTier.UNCOMMON, UpgradeCard.SubsystemType.GUIDED_MISSILES,
		{"max_locks_add": 2, "paint_interval_reduction": 0.20}
	))
	_master_deck.append(UpgradeCard.create(
		"missile_payload_boost", "HEAVY HE WARHEAD",
		"+30% Guided Missile Damage and +15% Blast Area.",
		UpgradeCard.RarityTier.UNCOMMON, UpgradeCard.SubsystemType.GUIDED_MISSILES,
		{"damage_mult": 0.30, "blast_radius_mult": 0.15}
	))
	_master_deck.append(UpgradeCard.create(
		"missile_swarm_rack", "MICRO-SWARM PODS",
		"+3 Missiles launched per salvo barrage and -25% Salvo Cooldown.",
		UpgradeCard.RarityTier.RARE, UpgradeCard.SubsystemType.GUIDED_MISSILES,
		{"missile_count_add": 3, "cooldown_reduction": 0.25}
	))
	_master_deck.append(UpgradeCard.create(
		"missile_emp_guidance", "EMP PULSE GUIDANCE",
		"Guided hits trigger a 3.5s EMP outage on target vehicle electronics, +25% damage.",
		UpgradeCard.RarityTier.RARE, UpgradeCard.SubsystemType.GUIDED_MISSILES,
		{"emp_duration": 3.5, "damage_mult": 0.25}
	))
	_master_deck.append(UpgradeCard.create(
		"missile_hyper_penetrator", "HYPERSONIC THRUST",
		"+50% Missile Velocity, +40% Missile Damage, and enhanced target kinetic penetration.",
		UpgradeCard.RarityTier.EPIC, UpgradeCard.SubsystemType.GUIDED_MISSILES,
		{"speed_mult": 0.50, "damage_mult": 0.40}
	))
	_master_deck.append(UpgradeCard.create(
		"missile_neural_link", "NEURO-TARGETING ARRAY",
		"+4 Max Locks, -35% Target Painting Delay, and -30% Salvo System Cooldown.",
		UpgradeCard.RarityTier.EPIC, UpgradeCard.SubsystemType.GUIDED_MISSILES,
		{"max_locks_add": 4, "paint_interval_reduction": 0.35, "cooldown_reduction": 0.30}
	))
	_master_deck.append(UpgradeCard.create(
		"missile_hellfire_omega", "HELLFIRE SWARM MATRIX",
		"+4 Simultaneous Target Locks, +60% Salvo Missile Damage, and -45% Base Cooldown.",
		UpgradeCard.RarityTier.LEGENDARY, UpgradeCard.SubsystemType.GUIDED_MISSILES,
		{"max_locks_add": 4, "damage_mult": 0.60, "cooldown_reduction": 0.45}
	))

	# ==========================================
	# 4. GLOBAL TOME SUBSYSTEM
	# ==========================================
	_master_deck.append(UpgradeCard.create(
		"tome_magnetic_collector", "MAGNETIC RADAR TOME",
		"+40% Planar XP Magnet Attraction Range across battlefield drops.",
		UpgradeCard.RarityTier.COMMON, UpgradeCard.SubsystemType.GLOBAL_TOME,
		{"magnet_radius_mult": 0.40}
	))
	_master_deck.append(UpgradeCard.create(
		"tome_aerodynamic_trim", "AERODYNAMIC TOME",
		"+12% Maximum Cruise Airspeed and improved flight stabilization.",
		UpgradeCard.RarityTier.COMMON, UpgradeCard.SubsystemType.GLOBAL_TOME,
		{"speed_mult": 0.12}
	))
	_master_deck.append(UpgradeCard.create(
		"tome_vector_thrusters", "VECTOR AFTERBURNERS",
		"+20% Top Airspeed and -25% Tactical Dash Evasive Cooldown.",
		UpgradeCard.RarityTier.UNCOMMON, UpgradeCard.SubsystemType.GLOBAL_TOME,
		{"speed_mult": 0.20, "dash_cooldown_reduction": 0.25}
	))
	_master_deck.append(UpgradeCard.create(
		"tome_composite_armor", "TITANIUM PLATING TOME",
		"+6% Direct Armor Mitigation (Hard Cap 24%) and +20 Max Airframe Hull.",
		UpgradeCard.RarityTier.UNCOMMON, UpgradeCard.SubsystemType.GLOBAL_TOME,
		{"armor_mitigation_add": 0.06, "max_hull_add": 20.0}
	))
	_master_deck.append(UpgradeCard.create(
		"tome_nanite_hull", "NANITE REPAIR MATRIX",
		"+2.0 HP/s Active Airframe Self-Repair and +30 Max Hull integrity.",
		UpgradeCard.RarityTier.RARE, UpgradeCard.SubsystemType.GLOBAL_TOME,
		{"hull_regen": 2.0, "max_hull_add": 30.0}
	))
	_master_deck.append(UpgradeCard.create(
		"tome_fortunes_favor", "FORTUNE'S FAVOR (LUCK TOME)",
		"+1.0 Global Luck Level improving Epic & Legendary card draft odds by +25%, +20% XP bonus.",
		UpgradeCard.RarityTier.RARE, UpgradeCard.SubsystemType.GLOBAL_TOME,
		{"luck_level_add": 1.0, "xp_gain_mult": 0.20}
	))
	_master_deck.append(UpgradeCard.create(
		"tome_aegis_overdrive", "AEGIS CORE TOME",
		"+10s Defense Energy Shield duration and +50 Shield Absorption hitpoints.",
		UpgradeCard.RarityTier.EPIC, UpgradeCard.SubsystemType.GLOBAL_TOME,
		{"shield_duration_add": 10.0, "shield_capacity_add": 50.0}
	))
	_master_deck.append(UpgradeCard.create(
		"tome_quantum_luck", "CHRONOS FORTUNE TOME",
		"+2.5 Global Luck Level significantly elevating Epic & Legendary card draft weights, +35% XP bonus.",
		UpgradeCard.RarityTier.EPIC, UpgradeCard.SubsystemType.GLOBAL_TOME,
		{"luck_level_add": 2.5, "xp_gain_mult": 0.35}
	))
	_master_deck.append(UpgradeCard.create(
		"tome_ghost_rotor", "GHOST ROTOR PROTOTYPE",
		"-35% Aerodynamic Drag, +25% Cruise Airspeed, and 15% Evasive incoming fire deflection.",
		UpgradeCard.RarityTier.LEGENDARY, UpgradeCard.SubsystemType.GLOBAL_TOME,
		{"drag_mult": -0.35, "speed_mult": 0.25, "evasion": 0.15}
	))

	for card in _master_deck:
		card.icon = _get_icon(card.target_subsystem)
		card.min_level = [1, 1, 2, 4, 6][card.rarity]
		if card.rarity == UpgradeCard.RarityTier.LEGENDARY:
			card.max_stacks = 1
		elif card.stat_changes.has("lingering_burn") or card.stat_changes.has("emp_duration"):
			card.max_stacks = 1
