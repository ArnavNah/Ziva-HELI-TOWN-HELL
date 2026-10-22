class_name GameConstants
extends RefCounted

## GameConstants — Authoritative rules, configurations, and balance records
## Traced directly to Heli-Town Hell Game Design Dossier (Godot Rebuild Baseline).

# ------------------------------------------------------------------------------
# 1. FLIGHT SPECIFICATIONS (Page 5)
# ------------------------------------------------------------------------------
const HORIZONTAL_CRUISE_CAP: float = 72.0       # world units/second
const THRUST_ACCELERATION: float = 420.0        # units/second²
const DRAG_COEFFICIENT: float = 1.35            # exponential drag factor
const MAX_YAW_RATE: float = 1.85                # rad/s (~106 deg/s)
const CLIMB_SPEED: float = 6.5                  # units/s
const SINK_SPEED: float = 7.0                   # units/s
const VERTICAL_ACCELERATION: float = 9.0        # units/s²
const STARTING_ALTITUDE: float = 14.0           # world units
const FLIGHT_CEILING: float = 60.0              # absolute ceiling
const SURFACE_CLEARANCE: float = 2.4            # floor clearance above roof/terrain
const VISUAL_PITCH_LIMIT_DEG: float = 18.0      # degrees visual pitch tilt
const VISUAL_BANK_LIMIT_DEG: float = 28.0       # degrees visual bank tilt

# Playable Area Boundaries (Spec 12.5 & Implementation Plan)
const BOUNDARY_SAFE_RADIUS: float = 280.0      # Safe inner combat zone (meters)
const BOUNDARY_WARNING_RADIUS: float = 300.0   # Soft warning threshold (meters)
const BOUNDARY_HARD_RADIUS: float = 310.0      # Expanded combat perimeter (meters)
const BOUNDARY_STEERING_FORCE: float = 28.0     # Inward steering acceleration force (m/s²)

# Evasive Dash (Resolved design decision)
const DASH_BURST_SPEED: float = 140.0           # pulse velocity
const DASH_DURATION: float = 0.25               # burst duration (seconds)
const DASH_INVULN_DURATION: float = 0.3         # invulnerability window
const DASH_BASE_COOLDOWN: float = 3.0           # base cooldown

# ------------------------------------------------------------------------------
# 2. WEAPON SPECIFICATIONS (Page 6 & 7)
# ------------------------------------------------------------------------------
enum WeaponType {
	MACHINE_GUN = 0,
	MISSILE = 1,
	ROCKET = 2,
	SHOTGUN = 3
}

const WEAPONS: Dictionary = {
	WeaponType.MACHINE_GUN: {
		"name": "Machine Gun",
		"damage": 13.0,
		"interval": 0.055,
		"ammo_max": 300,
		"reload_time": 1.5,
		"projectile_count": 2,
		"speed": 430.0,
		"blast_radius": 0.0,
		"homing": false,
		"spread": 0.02
	},
	WeaponType.MISSILE: {
		"name": "Missile",
		"damage": 55.0,
		"interval": 0.95,
		"ammo_max": 20,
		"reload_time": 2.5,
		"projectile_count": 1,
		"speed": 260.0,
		"blast_radius": 16.0,
		"homing": true,
		"spread": 0.0
	},
	WeaponType.ROCKET: {
		"name": "Rocket",
		"damage": 80.0,
		"interval": 1.45,
		"ammo_max": 12,
		"reload_time": 3.2,
		"projectile_count": 1,
		"speed": 235.0,
		"blast_radius": 28.0,
		"homing": false,
		"recoil_shove": 18.0,
		"spread": 0.0
	},
	WeaponType.SHOTGUN: {
		"name": "Shotgun",
		"damage": 10.0,
		"interval": 0.45,
		"ammo_max": 40,
		"reload_time": 2.0,
		"projectile_count": 6,
		"speed": 280.0,
		"blast_radius": 0.0,
		"homing": false,
		"spread": 0.30
	}
}

# Salvo System (Page 7)
const SALVO_MAX_LOCKS: int = 6
const SALVO_MAX_PER_TARGET: int = 3
const SALVO_SEARCH_RADIUS: float = 38.0
const SALVO_PAINT_INTERVAL: float = 0.18
const SALVO_BASE_COOLDOWN: float = 5.0
const SALVO_COOLDOWN_FLOOR: float = 1.5
const SALVO_MISSILE_DAMAGE: float = 55.0
const SALVO_MISSILE_SPEED: float = 265.0
const SALVO_MISSILE_BLAST_RADIUS: float = 12.0

# Weapon Mastery (Page 7)
const WEAPON_XP_THRESHOLDS: Array[int] = [0, 6, 14, 24, 36] # Level 1 through 5
const WEAPON_LEVEL_DAMAGE_MULT: float = 0.18               # +18% per level above 1
const WEAPON_LEVEL_INTERVAL_MULT: float = 0.09             # -9% interval per level above 1
const WEAPON_LEVEL_RELOAD_MULT: float = 0.12               # -12% reload time per level above 1

# Weapon Mods (Page 7)
enum WeaponMod {
	NONE = 0,
	MG_INCENDIARY = 1,       # 18% burn chance
	MG_PIERCING = 2,         # +35% damage vs tank and boss hulls
	MISSILE_EMP = 3,         # weapon disruption on hit
	MISSILE_CLUSTER = 4,     # 3 mini-blasts on detonation
	ROCKET_NAPALM = 5,       # +30% blast radius and burning
	ROCKET_SHAPED = 6,       # +45% vs bosses and elites
	SHOTGUN_SHOCK = 7,       # 25% slow chance
	SHOTGUN_SLUG = 8         # +30% damage, spread x0.55
}

# ------------------------------------------------------------------------------
# 3. DAMAGE, AFFINITY & STATUS EFFECTS (Page 8)
# ------------------------------------------------------------------------------
enum TargetAffinity {
	LIGHT = 0,
	ARMORED = 1,
	STRUCTURE = 2,
	AIR = 3,
	BOSS_CORE = 4
}

const DAMAGE_AFFINITY_MATRIX: Dictionary = {
	WeaponType.MACHINE_GUN: {
		TargetAffinity.LIGHT: 1.10,
		TargetAffinity.ARMORED: 0.85,
		TargetAffinity.STRUCTURE: 0.80,
		TargetAffinity.AIR: 1.25,
		TargetAffinity.BOSS_CORE: 1.00
	},
	WeaponType.MISSILE: {
		TargetAffinity.LIGHT: 1.00,
		TargetAffinity.ARMORED: 1.45,
		TargetAffinity.STRUCTURE: 1.35,
		TargetAffinity.AIR: 1.00,
		TargetAffinity.BOSS_CORE: 1.30
	},
	WeaponType.ROCKET: {
		TargetAffinity.LIGHT: 1.20,
		TargetAffinity.ARMORED: 1.40,
		TargetAffinity.STRUCTURE: 1.40,
		TargetAffinity.AIR: 0.90,
		TargetAffinity.BOSS_CORE: 1.00
	},
	WeaponType.SHOTGUN: {
		TargetAffinity.LIGHT: 1.30,
		TargetAffinity.ARMORED: 0.90,
		TargetAffinity.STRUCTURE: 1.00,
		TargetAffinity.AIR: 1.15,
		TargetAffinity.BOSS_CORE: 1.00
	}
}

# Status Effects
const STATUS_BURN_DPS: float = 14.0
const STATUS_BURN_DURATION: float = 3.0
const STATUS_EMP_DURATION: float = 2.0
const STATUS_SHOCK_SPEED_MULT: float = 0.55
const STATUS_SHOCK_DURATION: float = 2.5
const STATUS_PROC_CAP: float = 0.95

# Player Survivability & Subsystems
const PLAYER_BASE_HULL: float = 100.0
const MAX_ARMOR_MITIGATION: float = 0.24 # Max 24% damage reduction
const PLAYER_BASE_FUEL: float = 100.0
const FUEL_DRAIN_PER_SECOND: float = 0.85
const FUEL_STARVATION_DAMAGE_INTERVAL: float = 1.0
const FUEL_STARVATION_DAMAGE_AMOUNT: float = 8.0
const SUBSYSTEM_DAMAGE_CHANCE: float = 0.40
const SUBSYSTEM_DAMAGE_FACTOR: float = 0.50

# ------------------------------------------------------------------------------
# 4. COUNTERMEASURES & SAMS (Page 13)
# ------------------------------------------------------------------------------
const FLARE_BASE_CHARGES: int = 3
const FLARE_BASE_COOLDOWN: float = 6.5
const FLARE_BASE_DECOY_WINDOW: float = 1.05
const FLARE_DIVERSION_CLOSE_RADIUS: float = 135.0
const FLARE_DIVERSION_OUTER_RADIUS: float = 190.0

const SAM_SEARCH_RANGE: float = 330.0
const SAM_FIRE_MIN_RANGE: float = 38.0
const SAM_FIRE_MAX_RANGE: float = 255.0
const SAM_BASE_LOCK_TIME: float = 1.15
const SAM_BASE_RELOAD_TIME: float = 5.5
const SAM_MISSILE_SPEED: float = 155.0
const SAM_MISSILE_LIFETIME: float = 4.8
const SAM_RADAR_ACCELERATION_MULT: float = 1.20

# ------------------------------------------------------------------------------
# 5. ENEMY HULLS & ROSTER (Page 9)
# ------------------------------------------------------------------------------
const ENEMY_BASE_HULLS: Dictionary = {
	"infantry": 25.0,
	"shooter_air": 30.0,
	"tank": 100.0,
	"light_air": 22.0,
	"boss": 260.0
}

# ------------------------------------------------------------------------------
# 6. RUN ECONOMY & PROGRESSION (Page 18, 20, 21)
# ------------------------------------------------------------------------------
const RUN_XP_THRESHOLDS: Array[int] = [
	10, 25, 45, 70, 100, 135, 175, 220, 270, 325, 385, 450, 520, 595
]
const MAX_RUN_LEVEL: int = 15
const STARTER_CREDIT_GRANT: int = 150
const SALVAGE_TO_CREDIT_RATE: int = 5
const NORMAL_SALVAGE_CACHE_VALUE: int = 10

# Devastation Super (Page 20)
const SUPER_MAX_CHARGE: float = 100.0
const SUPER_KILL_CHARGE_NORMAL: float = 4.0
const SUPER_KILL_CHARGE_ELITE: float = 12.0
const SUPER_KILL_CHARGE_BOSS: float = 40.0
const SUPER_DURATION: float = 5.0
const SUPER_FIRE_RATE_MULT: float = 2.2
const SUPER_PULSE_RADIUS: float = 240.0
const SUPER_PULSE_DAMAGE: float = 200.0
const SUPER_COOLDOWN: float = 8.0

# Combat Pay Calculator (Page 21)
static func calculate_combat_pay(kills: int, cleared_waves: int, objectives: int, survival_time_sec: float) -> int:
	if kills <= 0:
		return 0
	var time_blocks: int = int(survival_time_sec / 30.0)
	return (2 * kills) + (12 * cleared_waves) + (15 * objectives) + (4 * time_blocks)
