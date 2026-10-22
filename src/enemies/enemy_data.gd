class_name EnemyData
extends RefCounted

## EnemyData — Authoritative variant specifications, wave gates, caps, combat roles,
## and engagement parameters.

# High-level behavioral archetypes (Section 5)
const ROLE_CLOSE_PURSUER = "close_pursuer"
const ROLE_MOBILE_SHOOTER = "mobile_shooter"
const ROLE_GROUND_HEAVY = "ground_heavy"
const ROLE_RANGED_SPECIALIST = "ranged_specialist"
const ROLE_ATTACK_AIRCRAFT = "attack_aircraft"
const ROLE_SUPPORT = "support"
const ROLE_SUICIDE = "suicide"
const ROLE_AREA_HAZARD = "area_hazard"

# Final seven active ground roster.
const ACTIVE_GROUND_VARIANTS: Array[String] = [
	"scout_buggy", "assault_apc", "rail_crawler", "siege_tank", "gatling_heavy",
	"raptor_raider", "desert_barrage_rover"
]

const VARIANTS: Dictionary = {
	"rocket_buggy": {
		"name": "Rocket Buggy", "family": "ground", "base_hull": 42.0,
		"gate_wave": 2, "max_cap": 4, "speed": 12.0,
		"affinity": GameConstants.TargetAffinity.LIGHT, "score": 110, "xp": 3, "is_heavy": false,
		"role": ROLE_MOBILE_SHOOTER, "min_range": 28.0, "max_range": 48.0, "retreat_dist": 18.0, "weapon_reach": 75.0,
		"windup_time": 0.40, "aim_commit_ratio": 0.65, "fire_cooldown": 3.0, "burst_count": 2, "burst_delay": 0.20,
		"proj_speed": 72.0, "lead_accuracy": 0.85, "spread_rad": 0.02, "requires_heavy_slot": false, "requires_air_slot": false
	},
	"flame_tank": {
		"name": "Incendiary Tank", "family": "ground", "base_hull": 115.0,
		"gate_wave": 5, "max_cap": 2, "speed": 7.5,
		"affinity": GameConstants.TargetAffinity.ARMORED, "score": 230, "xp": 7, "is_heavy": true,
		"role": ROLE_GROUND_HEAVY, "min_range": 16.0, "max_range": 28.0, "retreat_dist": 10.0, "weapon_reach": 34.0,
		"windup_time": 0.30, "aim_commit_ratio": 0.70, "fire_cooldown": 3.2, "burst_count": 5, "burst_delay": 0.08,
		"proj_speed": 85.0, "lead_accuracy": 0.82, "spread_rad": 0.06, "requires_heavy_slot": false, "requires_air_slot": false
	},
	"rail_crawler": {
		"name": "Rail Crawler", "family": "ground", "base_hull": 90.0,
		"gate_wave": 6, "max_cap": 2, "speed": 5.5,
		"affinity": GameConstants.TargetAffinity.ARMORED, "score": 240, "xp": 7, "is_heavy": true,
		"role": ROLE_RANGED_SPECIALIST, "min_range": 55.0, "max_range": 85.0, "retreat_dist": 40.0, "weapon_reach": 130.0,
		"windup_time": 1.0, "aim_commit_ratio": 0.50, "fire_cooldown": 5.2, "burst_count": 1, "burst_delay": 0.0,
		"proj_speed": 220.0, "lead_accuracy": 0.92, "spread_rad": 0.0, "requires_heavy_slot": true, "requires_air_slot": false
	},
	"hunter_drone": {
		"name": "Hunter Drone", "family": "air", "base_hull": 28.0,
		"gate_wave": 1, "max_cap": 5, "speed": 30.0,
		"affinity": GameConstants.TargetAffinity.AIR, "score": 95, "xp": 3, "is_heavy": false,
		"role": ROLE_CLOSE_PURSUER, "min_range": 18.0, "max_range": 30.0, "retreat_dist": 12.0, "weapon_reach": 45.0,
		"windup_time": 0.25, "aim_commit_ratio": 0.70, "fire_cooldown": 2.2, "burst_count": 3, "burst_delay": 0.12,
		"proj_speed": 135.0, "lead_accuracy": 0.85, "spread_rad": 0.03, "requires_heavy_slot": false, "requires_air_slot": true
	},
	"torpedo_vtol": {
		"name": "Torpedo VTOL", "family": "air", "base_hull": 68.0,
		"gate_wave": 5, "max_cap": 3, "speed": 27.0,
		"affinity": GameConstants.TargetAffinity.AIR, "score": 220, "xp": 6, "is_heavy": true,
		"role": ROLE_ATTACK_AIRCRAFT, "min_range": 35.0, "max_range": 60.0, "retreat_dist": 22.0, "weapon_reach": 85.0,
		"windup_time": 0.60, "aim_commit_ratio": 0.65, "fire_cooldown": 4.0, "burst_count": 2, "burst_delay": 0.25,
		"proj_speed": 72.0, "lead_accuracy": 0.88, "spread_rad": 0.02, "requires_heavy_slot": true, "requires_air_slot": true
	},
	"escort_fighter": {
		"name": "Escort Fighter", "family": "air", "base_hull": 44.0,
		"gate_wave": 3, "max_cap": 4, "speed": 42.0,
		"affinity": GameConstants.TargetAffinity.AIR, "score": 160, "xp": 5, "is_heavy": false,
		"role": ROLE_ATTACK_AIRCRAFT, "min_range": 22.0, "max_range": 50.0, "retreat_dist": 15.0, "weapon_reach": 70.0,
		"windup_time": 0.30, "aim_commit_ratio": 0.70, "fire_cooldown": 2.6, "burst_count": 3, "burst_delay": 0.12,
		"proj_speed": 150.0, "lead_accuracy": 0.88, "spread_rad": 0.025, "requires_heavy_slot": false, "requires_air_slot": true
	},
	"scout_buggy": {
		"name": "Scout Buggy", "family": "ground", "base_hull": 38.0,
		"gate_wave": 1, "max_cap": 5, "speed": 11.5,
		"affinity": GameConstants.TargetAffinity.LIGHT, "score": 90, "xp": 3, "is_heavy": false,
		"role": ROLE_MOBILE_SHOOTER, "min_range": 25.0, "max_range": 42.0, "retreat_dist": 16.0, "weapon_reach": 60.0,
		"windup_time": 0.25, "aim_commit_ratio": 0.75, "fire_cooldown": 2.0, "burst_count": 2, "burst_delay": 0.14,
		"proj_speed": 140.0, "lead_accuracy": 0.85, "spread_rad": 0.03, "requires_heavy_slot": false, "requires_air_slot": false
	},
	"attack_wing": {
		"name": "Attack Wing", "family": "air", "base_hull": 32.0,
		"gate_wave": 2, "max_cap": 4, "speed": 32.0,
		"affinity": GameConstants.TargetAffinity.AIR, "score": 130, "xp": 4, "is_heavy": false,
		"role": ROLE_ATTACK_AIRCRAFT, "min_range": 25.0, "max_range": 55.0, "retreat_dist": 18.0, "weapon_reach": 70.0,
		"windup_time": 0.35, "aim_commit_ratio": 0.70, "fire_cooldown": 2.8, "burst_count": 4, "burst_delay": 0.15,
		"proj_speed": 150.0, "lead_accuracy": 0.88, "spread_rad": 0.025, "requires_heavy_slot": false, "requires_air_slot": true
	},
	"mortar_crawler": {
		"name": "Mortar Crawler", "family": "ground", "base_hull": 85.0,
		"gate_wave": 4, "max_cap": 3, "speed": 5.0,
		"affinity": GameConstants.TargetAffinity.ARMORED, "score": 190, "xp": 6, "is_heavy": true,
		"role": ROLE_RANGED_SPECIALIST, "min_range": 55.0, "max_range": 85.0, "retreat_dist": 38.0, "weapon_reach": 115.0,
		"windup_time": 0.85, "aim_commit_ratio": 0.60, "fire_cooldown": 4.5, "burst_count": 1, "burst_delay": 0.0,
		"proj_speed": 65.0, "lead_accuracy": 0.90, "spread_rad": 0.02, "requires_heavy_slot": true, "requires_air_slot": false
	},
	"assault_apc": {
		"name": "Assault APC", "family": "ground", "base_hull": 75.0,
		"gate_wave": 3, "max_cap": 4, "speed": 9.5,
		"affinity": GameConstants.TargetAffinity.ARMORED, "score": 160, "xp": 5, "is_heavy": false,
		"role": ROLE_MOBILE_SHOOTER, "min_range": 28.0, "max_range": 45.0, "retreat_dist": 18.0, "weapon_reach": 70.0,
		"windup_time": 0.35, "aim_commit_ratio": 0.70, "fire_cooldown": 2.2, "burst_count": 3, "burst_delay": 0.12,
		"proj_speed": 160.0, "lead_accuracy": 0.88, "spread_rad": 0.02, "requires_heavy_slot": false, "requires_air_slot": false
	},
	"sam_launcher": {
		"name": "SAM Launcher", "family": "ground", "base_hull": 105.0,
		"gate_wave": 5, "max_cap": 3, "speed": 6.0,
		"affinity": GameConstants.TargetAffinity.ARMORED, "score": 260, "xp": 8, "is_heavy": true,
		"role": ROLE_RANGED_SPECIALIST, "min_range": 55.0, "max_range": 85.0, "retreat_dist": 38.0, "weapon_reach": 120.0,
		"windup_time": 1.0, "aim_commit_ratio": 0.60, "fire_cooldown": 5.0, "burst_count": 1, "burst_delay": 0.0,
		"proj_speed": 68.0, "lead_accuracy": 0.90, "spread_rad": 0.0, "requires_heavy_slot": true, "requires_air_slot": false
	},
	"technical_truck": {
		"name": "Raider Technical", "family": "ground", "base_hull": 32.0,
		"gate_wave": 1, "max_cap": 6, "speed": 12.0,
		"affinity": GameConstants.TargetAffinity.LIGHT, "score": 75, "xp": 2, "is_heavy": false,
		"role": ROLE_MOBILE_SHOOTER, "min_range": 25.0, "max_range": 42.0, "retreat_dist": 15.0, "weapon_reach": 60.0,
		"windup_time": 0.25, "aim_commit_ratio": 0.75, "fire_cooldown": 1.8, "burst_count": 3, "burst_delay": 0.10,
		"proj_speed": 140.0, "lead_accuracy": 0.82, "spread_rad": 0.035, "requires_heavy_slot": false, "requires_air_slot": false
	},
	"stealth_vtol": {
		"name": "Stealth VTOL", "family": "air", "base_hull": 48.0,
		"gate_wave": 4, "max_cap": 4, "speed": 38.0,
		"affinity": GameConstants.TargetAffinity.AIR, "score": 175, "xp": 5, "is_heavy": false,
		"role": ROLE_ATTACK_AIRCRAFT, "min_range": 25.0, "max_range": 50.0, "retreat_dist": 18.0, "weapon_reach": 70.0,
		"windup_time": 0.35, "aim_commit_ratio": 0.70, "fire_cooldown": 2.5, "burst_count": 2, "burst_delay": 0.14,
		"proj_speed": 150.0, "lead_accuracy": 0.90, "spread_rad": 0.02, "requires_heavy_slot": false, "requires_air_slot": true
	},
	"heavy_bomber": {
		"name": "Heavy Bomber", "family": "air", "base_hull": 95.0,
		"gate_wave": 7, "max_cap": 2, "speed": 22.0,
		"affinity": GameConstants.TargetAffinity.AIR, "score": 280, "xp": 8, "is_heavy": true,
		"role": ROLE_ATTACK_AIRCRAFT, "min_range": 25.0, "max_range": 55.0, "retreat_dist": 15.0, "weapon_reach": 65.0,
		"windup_time": 0.50, "aim_commit_ratio": 0.60, "fire_cooldown": 4.0, "burst_count": 3, "burst_delay": 0.18,
		"proj_speed": 35.0, "lead_accuracy": 0.80, "spread_rad": 0.05, "requires_heavy_slot": true, "requires_air_slot": true
	},
	"scout_drone": {
		"name": "Scout Drone",
		"family": "air",
		"base_hull": 22.0,
		"gate_wave": 2,
		"max_cap": 10,
		"speed": 34.0,
		"affinity": GameConstants.TargetAffinity.AIR,
		"score": 80,
		"xp": 3,
		"is_heavy": false,
		"role": ROLE_CLOSE_PURSUER, "min_range": 18.0, "max_range": 30.0, "retreat_dist": 12.0, "weapon_reach": 45.0,
		"windup_time": 0.25, "aim_commit_ratio": 0.70, "fire_cooldown": 2.0, "burst_count": 2, "burst_delay": 0.12,
		"proj_speed": 150.0, "lead_accuracy": 0.85, "spread_rad": 0.03, "requires_heavy_slot": false, "requires_air_slot": false
	},
	"flak_tank": {
		"name": "Flak Tank",
		"family": "ground",
		"base_hull": 100.0,
		"gate_wave": 3,
		"max_cap": 6,
		"speed": 8.0,
		"affinity": GameConstants.TargetAffinity.ARMORED,
		"score": 150,
		"xp": 5,
		"is_heavy": false,
		"role": ROLE_GROUND_HEAVY, "min_range": 35.0, "max_range": 65.0, "retreat_dist": 24.0, "weapon_reach": 85.0,
		"windup_time": 0.50, "aim_commit_ratio": 0.65, "fire_cooldown": 2.5, "burst_count": 3, "burst_delay": 0.14,
		"proj_speed": 140.0, "lead_accuracy": 0.88, "spread_rad": 0.03, "requires_heavy_slot": false, "requires_air_slot": false
	},
	"missile_carrier": {
		"name": "Missile Carrier",
		"family": "ground",
		"base_hull": 120.0,
		"gate_wave": 5,
		"max_cap": 2,
		"speed": 6.5,
		"affinity": GameConstants.TargetAffinity.ARMORED,
		"score": 250,
		"xp": 8,
		"is_heavy": true,
		"role": ROLE_RANGED_SPECIALIST, "min_range": 50.0, "max_range": 80.0, "retreat_dist": 35.0, "weapon_reach": 120.0,
		"windup_time": 0.90, "aim_commit_ratio": 0.60, "fire_cooldown": 5.0, "burst_count": 1, "burst_delay": 0.0,
		"proj_speed": 45.0, "lead_accuracy": 0.85, "spread_rad": 0.0, "requires_heavy_slot": true, "requires_air_slot": false
	},
	"attack_gunship": {
		"name": "Attack Gunship",
		"family": "air",
		"base_hull": 55.0,
		"gate_wave": 6,
		"max_cap": 8,
		"speed": 40.0,
		"affinity": GameConstants.TargetAffinity.AIR,
		"score": 200,
		"xp": 6,
		"is_heavy": false,
		"role": ROLE_ATTACK_AIRCRAFT, "min_range": 25.0, "max_range": 55.0, "retreat_dist": 18.0, "weapon_reach": 75.0,
		"windup_time": 0.40, "aim_commit_ratio": 0.70, "fire_cooldown": 3.0, "burst_count": 6, "burst_delay": 0.18,
		"proj_speed": 180.0, "lead_accuracy": 0.88, "spread_rad": 0.02, "requires_heavy_slot": false, "requires_air_slot": true
	},
	"shield_drone": {
		"name": "Shield Drone",
		"family": "support",
		"base_hull": 35.0,
		"gate_wave": 6,
		"max_cap": 2,
		"speed": 28.0,
		"affinity": GameConstants.TargetAffinity.AIR,
		"score": 180,
		"xp": 5,
		"is_heavy": false,
		"role": ROLE_SUPPORT, "min_range": 15.0, "max_range": 35.0, "retreat_dist": 8.0, "weapon_reach": 0.0,
		"windup_time": 0.0, "aim_commit_ratio": 1.0, "fire_cooldown": 999.0, "burst_count": 0, "burst_delay": 0.0,
		"proj_speed": 0.0, "lead_accuracy": 0.0, "spread_rad": 0.0, "requires_heavy_slot": false, "requires_air_slot": false
	},
	"rocket_gunship": {
		"name": "Rocket Gunship",
		"family": "air",
		"base_hull": 70.0,
		"gate_wave": 7,
		"max_cap": 5,
		"speed": 32.0,
		"affinity": GameConstants.TargetAffinity.AIR,
		"score": 280,
		"xp": 7,
		"is_heavy": true,
		"role": ROLE_ATTACK_AIRCRAFT, "min_range": 35.0, "max_range": 65.0, "retreat_dist": 22.0, "weapon_reach": 90.0,
		"windup_time": 0.70, "aim_commit_ratio": 0.60, "fire_cooldown": 4.2, "burst_count": 3, "burst_delay": 0.28,
		"proj_speed": 135.0, "lead_accuracy": 0.90, "spread_rad": 0.02, "requires_heavy_slot": true, "requires_air_slot": true
	},
	"repair_drone": {
		"name": "Repair Drone",
		"family": "support",
		"base_hull": 30.0,
		"gate_wave": 7,
		"max_cap": 1,
		"speed": 30.0,
		"affinity": GameConstants.TargetAffinity.AIR,
		"score": 220,
		"xp": 6,
		"is_heavy": false,
		"role": ROLE_SUPPORT, "min_range": 15.0, "max_range": 35.0, "retreat_dist": 8.0, "weapon_reach": 0.0,
		"windup_time": 0.0, "aim_commit_ratio": 1.0, "fire_cooldown": 999.0, "burst_count": 0, "burst_delay": 0.0,
		"proj_speed": 0.0, "lead_accuracy": 0.0, "spread_rad": 0.0, "requires_heavy_slot": false, "requires_air_slot": false
	},
	"kamikaze_drone": {
		"name": "Kamikaze Drone",
		"family": "air",
		"base_hull": 20.0,
		"gate_wave": 8,
		"max_cap": 6,
		"speed": 58.0,
		"affinity": GameConstants.TargetAffinity.AIR,
		"score": 120,
		"xp": 4,
		"is_heavy": false,
		"role": ROLE_SUICIDE, "min_range": 4.0, "max_range": 50.0, "retreat_dist": 0.0, "weapon_reach": 55.0,
		"windup_time": 0.60, "aim_commit_ratio": 0.50, "fire_cooldown": 99.0, "burst_count": 1, "burst_delay": 0.0,
		"proj_speed": 68.0, "lead_accuracy": 0.92, "spread_rad": 0.0, "requires_heavy_slot": false, "requires_air_slot": false
	},
	"interceptor": {
		"name": "Interceptor",
		"family": "air",
		"base_hull": 40.0,
		"gate_wave": 10,
		"max_cap": 4,
		"speed": 52.0,
		"affinity": GameConstants.TargetAffinity.AIR,
		"score": 240,
		"xp": 6,
		"is_heavy": false,
		"role": ROLE_ATTACK_AIRCRAFT, "min_range": 30.0, "max_range": 65.0, "retreat_dist": 20.0, "weapon_reach": 85.0,
		"windup_time": 0.30, "aim_commit_ratio": 0.65, "fire_cooldown": 3.0, "burst_count": 6, "burst_delay": 0.07,
		"proj_speed": 280.0, "lead_accuracy": 0.92, "spread_rad": 0.02, "requires_heavy_slot": false, "requires_air_slot": true
	},
	"infantry_squad": {
		"name": "Infantry Squad",
		"family": "ground",
		"base_hull": 20.0,
		"gate_wave": 1,
		"max_cap": 8,
		"speed": 5.0,
		"affinity": GameConstants.TargetAffinity.LIGHT,
		"score": 60,
		"xp": 2,
		"is_heavy": false,
		"role": ROLE_MOBILE_SHOOTER, "min_range": 20.0, "max_range": 35.0, "retreat_dist": 14.0, "weapon_reach": 55.0,
		"windup_time": 0.25, "aim_commit_ratio": 0.70, "fire_cooldown": 2.2, "burst_count": 3, "burst_delay": 0.10,
		"proj_speed": 160.0, "lead_accuracy": 0.80, "spread_rad": 0.045, "requires_heavy_slot": false, "requires_air_slot": false
	},
	"siege_tank": {
		"name": "Siege Tank",
		"family": "ground",
		"base_hull": 160.0,
		"gate_wave": 8,
		"max_cap": 1,
		"speed": 5.5,
		"affinity": GameConstants.TargetAffinity.ARMORED,
		"score": 320,
		"xp": 9,
		"is_heavy": true,
		"is_rare": true,
		"role": ROLE_GROUND_HEAVY, "min_range": 40.0, "max_range": 65.0, "retreat_dist": 28.0, "weapon_reach": 105.0,
		"windup_time": 0.80, "aim_commit_ratio": 0.60, "fire_cooldown": 4.5, "burst_count": 1, "burst_delay": 0.0,
		"proj_speed": 110.0, "lead_accuracy": 0.90, "spread_rad": 0.015, "requires_heavy_slot": true, "requires_air_slot": false
	},
	"gatling_heavy": {
		"name": "Gatling Heavy",
		"family": "ground",
		"base_hull": 140.0,
		"gate_wave": 9,
		"max_cap": 2,
		"speed": 7.5,
		"affinity": GameConstants.TargetAffinity.ARMORED,
		"score": 290,
		"xp": 8,
		"is_heavy": true,
		"role": ROLE_GROUND_HEAVY, "min_range": 32.0, "max_range": 55.0, "retreat_dist": 22.0, "weapon_reach": 80.0,
		"windup_time": 0.50, "aim_commit_ratio": 0.70, "fire_cooldown": 3.5, "burst_count": 12, "burst_delay": 0.08,
		"proj_speed": 220.0, "lead_accuracy": 0.88, "spread_rad": 0.035, "requires_heavy_slot": true, "requires_air_slot": false
	},
	"minelayer": {
		"name": "Minelayer",
		"family": "air",
		"base_hull": 45.0,
		"gate_wave": 11,
		"max_cap": 2,
		"speed": 26.0,
		"affinity": GameConstants.TargetAffinity.AIR,
		"score": 260,
		"xp": 7,
		"is_heavy": false,
		"role": ROLE_AREA_HAZARD, "min_range": 20.0, "max_range": 50.0, "retreat_dist": 15.0, "weapon_reach": 50.0,
		"windup_time": 0.30, "aim_commit_ratio": 1.0, "fire_cooldown": 4.5, "burst_count": 1, "burst_delay": 0.0,
		"proj_speed": 0.0, "lead_accuracy": 0.0, "spread_rad": 0.0, "requires_heavy_slot": false, "requires_air_slot": false
	},
	"raptor_raider": {
		"name": "Raptor Raider",
		"family": "ground",
		"base_hull": 68.0,
		"gate_wave": 2,
		"max_cap": 3,
		"speed": 10.5,
		"affinity": GameConstants.TargetAffinity.LIGHT,
		"score": 140,
		"xp": 4,
		"is_heavy": false,
		"role": ROLE_MOBILE_SHOOTER, "min_range": 22.0, "max_range": 40.0, "retreat_dist": 15.0, "weapon_reach": 65.0,
		"windup_time": 0.30, "aim_commit_ratio": 0.70, "fire_cooldown": 2.4, "burst_count": 2, "burst_delay": 0.16,
		"proj_speed": 175.0, "lead_accuracy": 0.86, "spread_rad": 0.025, "requires_heavy_slot": false, "requires_air_slot": false
	},
	"desert_barrage_rover": {
		"name": "Desert Barrage Rover",
		"family": "ground",
		"base_hull": 95.0,
		"gate_wave": 4,
		"max_cap": 2,
		"speed": 8.5,
		"affinity": GameConstants.TargetAffinity.ARMORED,
		"score": 210,
		"xp": 6,
		"is_heavy": true,
		"role": ROLE_RANGED_SPECIALIST, "min_range": 42.0, "max_range": 70.0, "retreat_dist": 30.0, "weapon_reach": 95.0,
		"windup_time": 0.70, "aim_commit_ratio": 0.60, "fire_cooldown": 3.8, "burst_count": 4, "burst_delay": 0.22,
		"proj_speed": 78.0, "lead_accuracy": 0.88, "spread_rad": 0.03, "requires_heavy_slot": true, "requires_air_slot": false
	}
}

enum ModifierType {
	NONE = 0,
	SHIELDED = 1,
	REGENERATING = 2,
	ELITE = 3,
	EXPLOSIVE = 4,
	SPLITTER = 5,
	VAMPIRIC = 6
}

static func get_spec(v_id: String) -> Dictionary:
	return VARIANTS.get(v_id, {})

static func is_variant_enabled(v_id: String) -> bool:
	var spec: Dictionary = get_spec(v_id)
	if spec.is_empty():
		return false
	return spec.get("family", "") != "ground" or v_id in ACTIVE_GROUND_VARIANTS

static func get_role(v_id: String) -> String:
	return VARIANTS.get(v_id, {}).get("role", ROLE_MOBILE_SHOOTER)

## Spawn-time progression. Warnings, weapon reach and burst sizes stay readable.
static func get_wave_scaling(wave: int, difficulty: String = "Normal") -> Dictionary:
	var progress := float(maxi(0, wave - 1))
	var strength := 0.85 if difficulty == "Casual" else (1.12 if difficulty == "Hard" else 1.0)
	return {
		"health": (1.0 + minf(progress * 0.07, 1.4)) * strength,
		"speed": 1.0 + minf(progress * 0.012, 0.24),
		"damage": (1.0 + minf(progress * 0.025, 0.45)) * strength,
		"cooldown": maxf(0.68, 1.0 - progress * 0.0175),
		"spawn_interval": maxf(0.60, 1.0 - progress * 0.025)
	}
