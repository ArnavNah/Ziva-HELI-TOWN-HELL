class_name WeaponFXProfile
extends RefCounted

## WeaponFXProfile — Authoritative presentation configuration for weapon firing,
## tracers, exhaust trails, impact flashes, surface light patches, and real light budgets.
## Preserves Megabonk chunky readability and Nuclear Strike military identity.

var id: String = ""
var faction: String = "player" # "player" or "enemy"
var family: String = "mg"      # "mg", "shotgun", "missile", "rocket", "heavy", "energy"

# Muzzle Flash
var muzzle_core_color: Color = Color(1.0, 0.94, 0.69, 1.0) # #FFF0B0
var muzzle_edge_color: Color = Color(1.0, 0.68, 0.28, 1.0) # #FFAD48
var muzzle_width: float = 0.55
var muzzle_length: float = 1.10
var muzzle_duration: float = 0.05
var muzzle_shape: int = 0 # 0=radial star, 1=pointed diamond, 2=directional fan, 3=patch
var muzzle_cross_quads: bool = true
var muzzle_intensity: float = 2.4
var muzzle_light_radius: float = 0.0
var muzzle_light_energy: float = 0.0
var muzzle_light_duration: float = 0.0

# Projectile / Tracer
var tracer_color: Color = Color(1.0, 0.75, 0.2, 1.0)
var tracer_scale: Vector3 = Vector3.ONE
var has_trail: bool = false
var trail_color: Color = Color(1.0, 0.55, 0.15, 0.8)
var trail_width: float = 0.18
var trail_lifetime: float = 0.25

# Impact & Surface Patches
var impact_color: Color = Color(1.0, 0.85, 0.4, 1.0)
var impact_size: float = 1.2
var impact_duration: float = 0.08
var impact_patch_size: float = 1.4 # Ground / wall fake light patch
var impact_patch_duration: float = 0.10
var impact_sparks_count: int = 10
var impact_real_light_radius: float = 0.0
var impact_real_light_energy: float = 0.0
var impact_real_light_duration: float = 0.0
var impact_real_light_priority: int = 0

static var _registry: Dictionary = {}

static func get_profile(profile_id: String) -> RefCounted:
	if _registry.is_empty():
		_init_registry()
	return _registry.get(profile_id, _registry["player_mg"])

static func _create() -> RefCounted:
	return (load("res://src/effects/weapon_fx_profile.gd") as GDScript).new()

static func _init_registry() -> void:
	# --------------------------------------------------------------------------
	# 1. PLAYER WEAPONS
	# --------------------------------------------------------------------------
	# 1.1 Machine Gun (Amber star, restrained directional pulses)
	var p_mg = _create()
	p_mg.id = "player_mg"
	p_mg.faction = "player"
	p_mg.family = "mg"
	p_mg.muzzle_core_color = Color("fff0b0")
	p_mg.muzzle_edge_color = Color("ffad48")
	p_mg.muzzle_width = 0.50
	p_mg.muzzle_length = 1.15
	p_mg.muzzle_duration = 0.05
	p_mg.muzzle_shape = 0
	p_mg.tracer_color = Color(1.0, 0.80, 0.35, 1.0)
	p_mg.impact_color = Color(1.0, 0.90, 0.45, 1.0)
	p_mg.impact_size = 0.95
	p_mg.impact_duration = 0.06
	p_mg.impact_patch_size = 1.10
	p_mg.impact_patch_duration = 0.08
	p_mg.impact_sparks_count = 8
	_registry["player_mg"] = p_mg

	# 1.2 Shotgun (Wide fan burst per trigger, bounded impacts)
	var p_sg = _create()
	p_sg.id = "player_shotgun"
	p_sg.faction = "player"
	p_sg.family = "shotgun"
	p_sg.muzzle_core_color = Color("ffe490")
	p_sg.muzzle_edge_color = Color("ff9632")
	p_sg.muzzle_width = 0.95
	p_sg.muzzle_length = 1.30
	p_sg.muzzle_duration = 0.07
	p_sg.muzzle_shape = 2 # Directional fan
	p_sg.tracer_color = Color(1.0, 0.78, 0.30, 1.0)
	p_sg.impact_color = Color(1.0, 0.88, 0.40, 1.0)
	p_sg.impact_size = 0.80 # Bounded per pellet
	p_sg.impact_duration = 0.06
	p_sg.impact_patch_size = 0.90
	p_sg.impact_patch_duration = 0.08
	p_sg.impact_sparks_count = 4
	_registry["player_shotgun"] = p_sg

	# 1.3 Missile (Brief launcher flare, orange exhaust core, smoke/exhaust trail)
	var p_ms = _create()
	p_ms.id = "player_missile"
	p_ms.faction = "player"
	p_ms.family = "missile"
	p_ms.muzzle_core_color = Color("ffe090")
	p_ms.muzzle_edge_color = Color("ff7818")
	p_ms.muzzle_width = 0.70
	p_ms.muzzle_length = 1.10
	p_ms.muzzle_duration = 0.08
	p_ms.muzzle_shape = 2
	p_ms.has_trail = true
	p_ms.trail_color = Color(1.0, 0.58, 0.12, 0.85)
	p_ms.trail_width = 0.18
	p_ms.trail_lifetime = 0.28
	p_ms.impact_color = Color(1.0, 0.65, 0.15, 1.0)
	p_ms.impact_size = 2.4
	p_ms.impact_duration = 0.12
	p_ms.impact_patch_size = 2.8
	p_ms.impact_patch_duration = 0.14
	p_ms.impact_sparks_count = 14
	p_ms.impact_real_light_radius = 8.0
	p_ms.impact_real_light_energy = 3.2
	p_ms.impact_real_light_duration = 0.12
	p_ms.impact_real_light_priority = 2
	_registry["player_missile"] = p_ms

	# 1.4 Rocket (Forceful launcher flash, warm exhaust, compact blast burst)
	var p_rk = _create()
	p_rk.id = "player_rocket"
	p_rk.faction = "player"
	p_rk.family = "rocket"
	p_rk.muzzle_core_color = Color("fff5a0")
	p_rk.muzzle_edge_color = Color("ff6010")
	p_rk.muzzle_width = 0.85
	p_rk.muzzle_length = 1.45
	p_rk.muzzle_duration = 0.10
	p_rk.muzzle_shape = 2
	p_rk.muzzle_light_radius = 7.0
	p_rk.muzzle_light_energy = 2.4
	p_rk.muzzle_light_duration = 0.08
	p_rk.has_trail = true
	p_rk.trail_color = Color(1.0, 0.52, 0.10, 0.90)
	p_rk.trail_width = 0.24
	p_rk.trail_lifetime = 0.32
	p_rk.impact_color = Color(1.0, 0.55, 0.10, 1.0)
	p_rk.impact_size = 3.2
	p_rk.impact_duration = 0.14
	p_rk.impact_patch_size = 3.4
	p_rk.impact_patch_duration = 0.16
	p_rk.impact_sparks_count = 18
	p_rk.impact_real_light_radius = 10.0
	p_rk.impact_real_light_energy = 4.2
	p_rk.impact_real_light_duration = 0.15
	p_rk.impact_real_light_priority = 3
	_registry["player_rocket"] = p_rk

	# 1.5 Painted Salvo (Coalesced launcher flare, thin smoke/exhaust trail)
	var p_sl = _create()
	p_sl.id = "player_salvo"
	p_sl.faction = "player"
	p_sl.family = "missile"
	p_sl.muzzle_core_color = Color("ffeaa0")
	p_sl.muzzle_edge_color = Color("ff7014")
	p_sl.muzzle_width = 0.75
	p_sl.muzzle_length = 1.20
	p_sl.muzzle_duration = 0.08
	p_sl.muzzle_shape = 2
	p_sl.has_trail = true
	p_sl.trail_color = Color(1.0, 0.60, 0.15, 0.85)
	p_sl.trail_width = 0.16
	p_sl.trail_lifetime = 0.26
	p_sl.impact_color = Color(1.0, 0.65, 0.18, 1.0)
	p_sl.impact_size = 2.2
	p_sl.impact_duration = 0.10
	p_sl.impact_patch_size = 2.6
	p_sl.impact_patch_duration = 0.12
	p_sl.impact_sparks_count = 12
	p_sl.impact_real_light_radius = 7.5
	p_sl.impact_real_light_energy = 2.8
	p_sl.impact_real_light_duration = 0.10
	p_sl.impact_real_light_priority = 2
	_registry["player_salvo"] = p_sl

	# --------------------------------------------------------------------------
	# 2. ENEMY WEAPONS
	# --------------------------------------------------------------------------
	# 2.1 Standard Hostile Bullet (Orange-red pointed diamond burst)
	var e_bl = _create()
	e_bl.id = "enemy_bullet"
	e_bl.faction = "enemy"
	e_bl.family = "mg"
	e_bl.muzzle_core_color = Color("ffa040")
	e_bl.muzzle_edge_color = Color("ff3210") # Distinct crimson/orange
	e_bl.muzzle_width = 0.48
	e_bl.muzzle_length = 0.85
	e_bl.muzzle_duration = 0.05
	e_bl.muzzle_shape = 1 # Pointed diamond burst
	e_bl.tracer_color = Color(1.0, 0.45, 0.18, 1.0)
	e_bl.impact_color = Color(1.0, 0.50, 0.20, 1.0)
	e_bl.impact_size = 0.85
	e_bl.impact_duration = 0.06
	e_bl.impact_patch_size = 1.0
	e_bl.impact_patch_duration = 0.07
	e_bl.impact_sparks_count = 6
	_registry["enemy_bullet"] = e_bl

	# 2.2 Gatling Heavy (Rapid pointed bursts)
	var e_gt = _create()
	e_gt.id = "enemy_gatling"
	e_gt.faction = "enemy"
	e_gt.family = "mg"
	e_gt.muzzle_core_color = Color("ffb050")
	e_gt.muzzle_edge_color = Color("ff4015")
	e_gt.muzzle_width = 0.55
	e_gt.muzzle_length = 0.95
	e_gt.muzzle_duration = 0.045
	e_gt.muzzle_shape = 1
	e_gt.tracer_color = Color(1.0, 0.48, 0.16, 1.0)
	e_gt.impact_color = Color(1.0, 0.55, 0.22, 1.0)
	e_gt.impact_size = 0.90
	e_gt.impact_duration = 0.06
	e_gt.impact_patch_size = 1.10
	e_gt.impact_patch_duration = 0.07
	e_gt.impact_sparks_count = 7
	_registry["enemy_gatling"] = e_gt

	# 2.3 Flak Tank (Heavy AA shell burst)
	var e_fk = _create()
	e_fk.id = "enemy_flak"
	e_fk.faction = "enemy"
	e_fk.family = "rocket"
	e_fk.muzzle_core_color = Color("ffd060")
	e_fk.muzzle_edge_color = Color("ff3b10")
	e_fk.muzzle_width = 0.90
	e_fk.muzzle_length = 1.50
	e_fk.muzzle_duration = 0.08
	e_fk.muzzle_shape = 1
	e_fk.muzzle_light_radius = 6.5
	e_fk.muzzle_light_energy = 2.2
	e_fk.muzzle_light_duration = 0.08
	e_fk.tracer_color = Color(1.0, 0.50, 0.15, 1.0)
	e_fk.impact_color = Color(1.0, 0.48, 0.12, 1.0)
	e_fk.impact_size = 2.2
	e_fk.impact_duration = 0.10
	e_fk.impact_patch_size = 2.6
	e_fk.impact_patch_duration = 0.12
	e_fk.impact_sparks_count = 14
	e_fk.impact_real_light_radius = 7.5
	e_fk.impact_real_light_energy = 2.6
	e_fk.impact_real_light_duration = 0.10
	e_fk.impact_real_light_priority = 2
	_registry["enemy_flak"] = e_fk

	# 2.4 Siege Tank (Massive 125mm heavy cannon blast)
	var e_hv = _create()
	e_hv.id = "enemy_heavy"
	e_hv.faction = "enemy"
	e_hv.family = "heavy"
	e_hv.muzzle_core_color = Color("fff080")
	e_hv.muzzle_edge_color = Color("ff2808")
	e_hv.muzzle_width = 1.30
	e_hv.muzzle_length = 2.40
	e_hv.muzzle_duration = 0.10
	e_hv.muzzle_shape = 1
	e_hv.muzzle_light_radius = 9.0
	e_hv.muzzle_light_energy = 3.6
	e_hv.muzzle_light_duration = 0.12
	e_hv.tracer_color = Color(1.0, 0.40, 0.10, 1.0)
	e_hv.impact_color = Color(1.0, 0.35, 0.08, 1.0)
	e_hv.impact_size = 3.6
	e_hv.impact_duration = 0.15
	e_hv.impact_patch_size = 4.0
	e_hv.impact_patch_duration = 0.18
	e_hv.impact_sparks_count = 20
	e_hv.impact_real_light_radius = 11.0
	e_hv.impact_real_light_energy = 4.5
	e_hv.impact_real_light_duration = 0.16
	e_hv.impact_real_light_priority = 3
	_registry["enemy_heavy"] = e_hv

	# 2.5 SAM Launcher & Missile Carrier (Homing missile exhaust)
	var e_ms = _create()
	e_ms.id = "enemy_sam"
	e_ms.faction = "enemy"
	e_ms.family = "missile"
	e_ms.muzzle_core_color = Color("ffe070")
	e_ms.muzzle_edge_color = Color("ff4010")
	e_ms.muzzle_width = 0.75
	e_ms.muzzle_length = 1.30
	e_ms.muzzle_duration = 0.09
	e_ms.muzzle_shape = 2
	e_ms.has_trail = true
	e_ms.trail_color = Color(1.0, 0.45, 0.12, 0.85)
	e_ms.trail_width = 0.20
	e_ms.trail_lifetime = 0.30
	e_ms.impact_color = Color(1.0, 0.50, 0.15, 1.0)
	e_ms.impact_size = 2.4
	e_ms.impact_duration = 0.11
	e_ms.impact_patch_size = 2.8
	e_ms.impact_patch_duration = 0.13
	e_ms.impact_sparks_count = 14
	e_ms.impact_real_light_radius = 8.0
	e_ms.impact_real_light_energy = 3.0
	e_ms.impact_real_light_duration = 0.11
	e_ms.impact_real_light_priority = 2
	_registry["enemy_sam"] = e_ms

	# 2.6 Rocket Gunship / Buggy (Rocket exhaust)
	var e_rk = _create()
	e_rk.id = "enemy_rocket"
	e_rk.faction = "enemy"
	e_rk.family = "rocket"
	e_rk.muzzle_core_color = Color("ffdd70")
	e_rk.muzzle_edge_color = Color("ff4410")
	e_rk.muzzle_width = 0.80
	e_rk.muzzle_length = 1.35
	e_rk.muzzle_duration = 0.09
	e_rk.muzzle_shape = 2
	e_rk.has_trail = true
	e_rk.trail_color = Color(1.0, 0.48, 0.12, 0.85)
	e_rk.trail_width = 0.22
	e_rk.trail_lifetime = 0.28
	e_rk.impact_color = Color(1.0, 0.52, 0.14, 1.0)
	e_rk.impact_size = 2.8
	e_rk.impact_duration = 0.12
	e_rk.impact_patch_size = 3.0
	e_rk.impact_patch_duration = 0.14
	e_rk.impact_sparks_count = 16
	e_rk.impact_real_light_radius = 8.5
	e_rk.impact_real_light_energy = 3.4
	e_rk.impact_real_light_duration = 0.12
	e_rk.impact_real_light_priority = 2
	_registry["enemy_rocket"] = e_rk

	# 2.7 Boss Volley (Wave 10 Heavy Gunship Boss spread volley)
	var e_bs = _create()
	e_bs.id = "enemy_boss"
	e_bs.faction = "enemy"
	e_bs.family = "heavy"
	e_bs.muzzle_core_color = Color("ffe080")
	e_bs.muzzle_edge_color = Color("ff2008")
	e_bs.muzzle_width = 1.40
	e_bs.muzzle_length = 2.50
	e_bs.muzzle_duration = 0.10
	e_bs.muzzle_shape = 1
	e_bs.muzzle_light_radius = 10.0
	e_bs.muzzle_light_energy = 4.0
	e_bs.muzzle_light_duration = 0.14
	e_bs.has_trail = true
	e_bs.trail_color = Color(1.0, 0.35, 0.08, 0.90)
	e_bs.trail_width = 0.24
	e_bs.trail_lifetime = 0.30
	e_bs.impact_color = Color(1.0, 0.40, 0.10, 1.0)
	e_bs.impact_size = 3.0
	e_bs.impact_duration = 0.12
	e_bs.impact_patch_size = 3.4
	e_bs.impact_patch_duration = 0.15
	e_bs.impact_sparks_count = 18
	e_bs.impact_real_light_radius = 9.5
	e_bs.impact_real_light_energy = 3.8
	e_bs.impact_real_light_duration = 0.14
	e_bs.impact_real_light_priority = 3
	_registry["enemy_boss"] = e_bs

	# 2.8 Flame Tank (Warm orange flame burst)
	var e_fl = _create()
	e_fl.id = "enemy_flame"
	e_fl.faction = "enemy"
	e_fl.family = "energy"
	e_fl.muzzle_core_color = Color("ffd060")
	e_fl.muzzle_edge_color = Color("ff6018")
	e_fl.muzzle_width = 1.20
	e_fl.muzzle_length = 2.60
	e_fl.muzzle_duration = 0.14
	e_fl.muzzle_shape = 2 # Fan
	e_fl.tracer_color = Color("ff913e")
	e_fl.impact_color = Color(1.0, 0.55, 0.15, 1.0)
	e_fl.impact_size = 2.0
	e_fl.impact_duration = 0.12
	e_fl.impact_patch_size = 2.4
	e_fl.impact_patch_duration = 0.16
	e_fl.impact_sparks_count = 12
	_registry["enemy_flame"] = e_fl

	# 2.9 Rail Crawler (Cyan electric discharge)
	var e_rl = _create()
	e_rl.id = "enemy_rail"
	e_rl.faction = "enemy"
	e_rl.family = "energy"
	e_rl.muzzle_core_color = Color("c8faff")
	e_rl.muzzle_edge_color = Color("40b8c8")
	e_rl.muzzle_width = 0.65
	e_rl.muzzle_length = 2.40
	e_rl.muzzle_duration = 0.07
	e_rl.muzzle_shape = 1
	e_rl.muzzle_light_radius = 6.0
	e_rl.muzzle_light_energy = 2.5
	e_rl.muzzle_light_duration = 0.07
	e_rl.tracer_color = Color("78d8e0")
	e_rl.impact_color = Color("90e8f0")
	e_rl.impact_size = 1.8
	e_rl.impact_duration = 0.08
	e_rl.impact_patch_size = 2.0
	e_rl.impact_patch_duration = 0.10
	e_rl.impact_sparks_count = 12
	_registry["enemy_rail"] = e_rl
