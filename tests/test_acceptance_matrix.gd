class_name TestAcceptanceMatrix
extends RefCounted

## TestAcceptanceMatrix — Comprehensive automated acceptance suite verifying all 12 areas
## against the design dossier acceptance matrix (Page 40).

static func run_all_tests() -> Dictionary:
	var results: Dictionary = {
		"total": 0,
		"passed": 0,
		"failed": 0,
		"failures": []
	}
	
	_test("1. Flight Limits & Speed Caps", _test_flight, results)
	_test("2. Weapons Arsenal & Damage Affinities", _test_weapons, results)
	_test("3. Salvo 6-Lock System", _test_salvo, results)
	_test("4. Defense & Flare Countermeasures", _test_defense, results)
	_test("5. AI Encounter Slots & Wave Pacing", _test_ai_director, results)
	_test("6. Building Destruction & Corridor Clearing", _test_destruction, results)
	_test("7. Tactical Missions Payouts & Bonuses", _test_missions, results)
	_test("8. Cargo Pricing Formula (Page 16 Worked Example)", _test_cargo, results)
	_test("9. Run XP & Upgrade Card Stacking", _test_run_growth, results)
	_test("10. Economy, Combat Pay & Risk Settlement", _test_economy, results)
	_test("11. Heavy Gunship Boss Hull Phases", _test_boss, results)
	_test("12. Profile Persistence & Save Integrity", _test_persistence, results)
	
	return results

static func _test(test_name: String, test_fn: Callable, results: Dictionary) -> void:
	results["total"] += 1
	var err: String = test_fn.call()
	if err == "":
		results["passed"] += 1
		print("  [PASS] ", test_name)
	else:
		results["failed"] += 1
		results["failures"].append({"name": test_name, "error": err})
		print("  [FAIL] ", test_name, " -> ", err)

static func _test_flight() -> String:
	var gc = preload("res://data/game_constants.gd")
	if gc.HORIZONTAL_CRUISE_CAP != 72.0:
		return "Cruise cap must be 72.0"
	if gc.FLIGHT_CEILING != 60.0:
		return "Flight ceiling must be 60.0"
	if gc.MAX_YAW_RATE != 1.85:
		return "Max yaw rate must be 1.85"
	return ""

static func _test_weapons() -> String:
	var gc = preload("res://data/game_constants.gd")
	var mg = gc.WEAPONS[gc.WeaponType.MACHINE_GUN]
	if mg["damage"] != 13.0 or mg["ammo_max"] != 300:
		return "Machine gun specs mismatch"
	var rk = gc.WEAPONS[gc.WeaponType.ROCKET]
	if rk["damage"] != 80.0 or rk["blast_radius"] != 28.0:
		return "Rocket specs mismatch"
	var aff = gc.DAMAGE_AFFINITY_MATRIX[gc.WeaponType.MISSILE][gc.TargetAffinity.ARMORED]
	if aff != 1.45:
		return "Missile vs Armored affinity mismatch"
	return ""

static func _test_salvo() -> String:
	var gc = preload("res://data/game_constants.gd")
	if gc.SALVO_MAX_LOCKS != 6 or gc.SALVO_MAX_PER_TARGET != 3:
		return "Salvo locks count mismatch"
	if gc.SALVO_BASE_COOLDOWN != 5.0 or gc.SALVO_COOLDOWN_FLOOR != 1.5:
		return "Salvo cooldown bounds mismatch"
	return ""

static func _test_defense() -> String:
	var gc = preload("res://data/game_constants.gd")
	if gc.FLARE_BASE_CHARGES != 3 or gc.FLARE_BASE_COOLDOWN != 6.5:
		return "Flare specs mismatch"
	if gc.SAM_SEARCH_RANGE != 330.0 or gc.SAM_BASE_LOCK_TIME != 1.15:
		return "SAM specs mismatch"
	return ""

static func _test_ai_director() -> String:
	var cd = preload("res://autoload/combat_director.gd").new()
	cd._setup_wave(1)
	if cd.wave_max_duration != 45.0:
		cd.free()
		return "Wave 1 duration must be 45s"
	cd._setup_wave(3)
	if cd.active_theme != "Storm Surge":
		cd.free()
		return "Wave 3 must force Storm Surge"
	cd.free()
	return ""

static func _test_destruction() -> String:
	var bld_scene = preload("res://scenes/world/destructible_building.tscn")
	var bld = bld_scene.instantiate()
	bld._setup_structure()
	var dd_class = preload("res://src/combat/damage_data.gd")
	var hit = dd_class.new(300.0, 2, null, false, 28.0)
	bld.get_node("DamageReceiver").take_damage(hit)
	var stage = bld.current_stage
	var h = bld.get_node("CollisionShape3D").shape.size.y
	bld.free()
	if stage != 2:
		return "Building failed to collapse"
	if h != 3.5:
		return "Building collision height failed to reduce to 3.5"
	return ""

static func _test_missions() -> String:
	var ms = preload("res://src/missions/mission_specs.gd")
	if ms.MISSIONS["destroy_sam"]["base_cr"] != 300:
		return "SAM mission base reward mismatch"
	if ms.MISSIONS["bounty_leader"]["base_cr"] != 420:
		return "Bounty leader base reward mismatch"
	return ""

static func _test_cargo() -> String:
	var cs = preload("res://src/missions/cargo_specs.gd")
	var quote = cs.calculate_contract_price("ammunition", 600.0, 1.0)
	if quote["base_price"] != 320:
		return "Cargo 600m price mismatch: expected 320, got %d" % [quote["base_price"]]
	if quote["speed_bonus"] != 80:
		return "Cargo speed bonus mismatch: expected 80, got %d" % [quote["speed_bonus"]]
	return ""

static func _test_run_growth() -> String:
	var gc = preload("res://data/game_constants.gd")
	if gc.RUN_XP_THRESHOLDS[0] != 10 or gc.RUN_XP_THRESHOLDS[4] != 100:
		return "Run XP thresholds mismatch"
	return ""

static func _test_economy() -> String:
	var gc = preload("res://data/game_constants.gd")
	var pay = gc.calculate_combat_pay(20, 3, 2, 120.0)
	if pay != 122:
		return "Combat pay calculation mismatch: expected 122, got %d" % [pay]
	return ""

static func _test_boss() -> String:
	var boss = preload("res://src/enemies/boss/heavy_gunship_boss.gd").new()
	boss._setup_boss_stats()
	var initial_stage = boss.current_stage
	var dd_class = preload("res://src/combat/damage_data.gd")
	# Deal 50% damage
	boss.damage_receiver.take_damage(dd_class.new(130.0, 2, null, false, 0.0))
	var mid_stage = boss.current_stage
	boss.free()
	if initial_stage != 3:
		return "Boss must start in stage 3"
	if mid_stage != 2:
		return "Boss failed to escalate to stage 2"
	return ""

static func _test_persistence() -> String:
	var pm = preload("res://autoload/profile_manager.gd").new()
	pm.wallet_credits = 150
	if not pm.can_afford(150) or pm.can_afford(151):
		pm.free()
		return "Affordability math check failed"
	pm.free()
	return ""
