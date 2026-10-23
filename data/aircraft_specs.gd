class_name AircraftSpecs
extends RefCounted

## AircraftSpecs — Authoritative single source of truth for aircraft performance,
## visual configurations, modular airframe components, and pre-run stat calculations.

const AIRCRAFT: Dictionary = {
	"apache": {
		"id": "apache",
		"name": "AH-64 APACHE",
		"role": "ALL-WEATHER ASSAULT GUNSHIP",
		"status": "COMBAT READY // BALANCED AIRFRAME",
		"tagline": "BALANCED ASSAULT",
		"doctrine": "Frontline twin-turboshaft attack helicopter engineered for armored breakthrough. Delivers the tactical baseline balance of cruise speed, composite hull durability, and sustained fuel reserves.",
		"speed": 36.0,
		"hull": 100.0,
		"fuel": 100.0,
		"yaw_mult": 1.0,
		"scale_mult": 1.0,
		"preview_scale": 0.38,
		"hull_color": Color(0.85, 0.88, 0.82, 1.0), # Authentic olive-drab CARC finish
		"canopy_color": Color(0.20, 0.75, 0.90, 1.0), # Tactical cyan avionics
		"has_mast_radar": true,
		"has_stealth_fins": false,
		"has_titanium_plates": false
	},
	"nighthawk": {
		"id": "nighthawk",
		"name": "RAH-66 NIGHTHAWK",
		"role": "STEALTH RECON & HIGH-SPEED INTERCEPTOR",
		"status": "SPECIAL OPS // OVERCLOCKED ROTOR",
		"tagline": "+15% SPEED // AGILE",
		"doctrine": "Low-observable carbon reconnaissance airframe. Overclocked turbines deliver +15% cruise speed (41.4 m/s) and +20% yaw turning rate, trading away 15% hull armor durability.",
		"speed": 41.4,
		"hull": 85.0,
		"fuel": 90.0,
		"yaw_mult": 1.20,
		"scale_mult": 0.92,
		"preview_scale": 0.35,
		"hull_color": Color(0.32, 0.35, 0.39, 1.0), # Low-observable matte carbon graphite
		"canopy_color": Color(0.15, 0.90, 0.75, 1.0), # High-contrast emerald HUD glow
		"has_mast_radar": false,
		"has_stealth_fins": true,
		"has_titanium_plates": false
	},
	"warlock": {
		"id": "warlock",
		"name": "MI-28 WARLOCK",
		"role": "HEAVY ARMORED SIEGE GUNSHIP",
		"status": "FORTIFIED SIEGE // HEAVY WEAPONS PLATFORM",
		"tagline": "+30% HULL // FORTIFIED",
		"doctrine": "Fortified heavy gunship encased in an all-titanium cockpit bathtub. Features +30% hull durability (130 HP) and +20% fuel capacity (120 L), with heavier yaw turning inertia (-15%).",
		"speed": 31.7,
		"hull": 130.0,
		"fuel": 120.0,
		"yaw_mult": 0.85,
		"scale_mult": 1.08,
		"preview_scale": 0.42,
		"hull_color": Color(0.55, 0.58, 0.62, 1.0), # Fortified titanium armored slate
		"canopy_color": Color(1.0, 0.50, 0.15, 1.0), # Combat amber HUD glow
		"has_mast_radar": false,
		"has_stealth_fins": false,
		"has_titanium_plates": true
	}
}

static func get_specs(id: String) -> Dictionary:
	var key = id.to_lower()
	if AIRCRAFT.has(key):
		return AIRCRAFT[key].duplicate(true)
	return AIRCRAFT["apache"].duplicate(true)

## Pure, side-effect-free calculation of pre-run effective stats accounting for
## permanent hangar ranks and perks. Both menu preview and runtime apply_loadout() use this.
static func calculate_effective_stats(aircraft_id: String, hangar_ranks: Dictionary = {}, perk_ranks: Dictionary = {}) -> Dictionary:
	var base: Dictionary = get_specs(aircraft_id)
	var e_rank: int = hangar_ranks.get("engine", 0)
	var a_rank: int = hangar_ranks.get("armor", 0)
	var f_rank: int = hangar_ranks.get("fuel", 0)
	var r_rank: int = hangar_ranks.get("rotor", 0)
	var w_rank: int = hangar_ranks.get("weapon_system", 0)
	var af_rank: int = hangar_ranks.get("airframe", 0)

	var base_speed: float = float(base.get("speed", 36.0))
	var effective_speed: float = base_speed * (1.0 + e_rank * 0.08)
	var speed_bonus: float = effective_speed - base_speed

	var base_hull: float = float(base.get("hull", 100.0))
	var effective_hull: float = base_hull + a_rank * 15.0
	var hull_bonus: float = effective_hull - base_hull

	var base_fuel: float = float(base.get("fuel", 100.0))
	var effective_fuel: float = base_fuel + f_rank * 15.0
	var fuel_bonus: float = effective_fuel - base_fuel

	var base_yaw_mult: float = float(base.get("yaw_mult", 1.0))
	var effective_handling: float = base_yaw_mult * (1.0 + r_rank * 0.10)
	var handling_bonus: float = effective_handling - base_yaw_mult

	var damage_bonus_pct: float = float(w_rank * 6)
	var armor_mitigation_pct: float = minf(0.24, af_rank * 0.04) * 100.0

	return {
		"id": base.id,
		"name": base.name,
		"role": base.role,
		"status": base.status,
		"tagline": base.tagline,
		"doctrine": base.doctrine,
		"base_speed": base_speed,
		"speed": effective_speed,
		"speed_bonus": speed_bonus,
		"has_speed_upgrade": e_rank > 0,
		"base_hull": base_hull,
		"hull": effective_hull,
		"hull_bonus": hull_bonus,
		"has_hull_upgrade": a_rank > 0,
		"base_fuel": base_fuel,
		"fuel": effective_fuel,
		"fuel_bonus": fuel_bonus,
		"has_fuel_upgrade": f_rank > 0,
		"base_handling": base_yaw_mult,
		"handling": effective_handling,
		"handling_bonus": handling_bonus,
		"has_handling_upgrade": r_rank > 0,
		"damage_bonus_pct": damage_bonus_pct,
		"armor_mitigation_pct": armor_mitigation_pct,
		"scale_mult": base.scale_mult,
		"preview_scale": base.preview_scale,
		"hull_color": base.hull_color,
		"canopy_color": base.canopy_color
	}

## Single shared visual configurator for player airframes.
## Configures PBR materials, modular components, and lighting so that the 3D preview
## in the hangar and the helicopter deployed into gameplay look 100% identical.
static func configure_airframe_visuals(visuals_root: Node3D, aircraft_id: String, is_preview: bool = false) -> void:
	if not visuals_root or not is_instance_valid(visuals_root):
		return

	var spec: Dictionary = get_specs(aircraft_id)
	var target_scale: float = spec.preview_scale if is_preview else spec.scale_mult
	var target_color: Color = spec.hull_color
	var canopy_color: Color = spec.canopy_color

	# 1. Update scale on the main visual container or model
	var apache_model = visuals_root.find_child("ApacheModel", true, false)
	if apache_model and not is_preview:
		apache_model.scale = Vector3(0, 0, -7.2 * target_scale) if apache_model.scale.z < 0 else Vector3.ONE * (7.2 * target_scale)

	# 2. PBR Materials setup
	var base_tex: Texture2D = null
	if ResourceLoader.exists("res://assets/player/player_apache_basecolor.png"):
		base_tex = load("res://assets/player/player_apache_basecolor.png")
	var norm_tex: Texture2D = null
	if ResourceLoader.exists("res://assets/player/player_apache_normal.png"):
		norm_tex = load("res://assets/player/player_apache_normal.png")
	var orm_tex: Texture2D = null
	if ResourceLoader.exists("res://assets/player/player_apache_orm.png"):
		orm_tex = load("res://assets/player/player_apache_orm.png")

	var airframe_mat = StandardMaterial3D.new()
	airframe_mat.resource_name = "Airframe_Mat_" + spec.id
	if base_tex:
		airframe_mat.albedo_texture = base_tex
	airframe_mat.albedo_color = target_color
	if norm_tex:
		airframe_mat.normal_enabled = true
		airframe_mat.normal_texture = norm_tex
		airframe_mat.normal_scale = 1.0
	if orm_tex:
		airframe_mat.orm_texture = orm_tex
	airframe_mat.metallic = 0.12 if spec.id != "warlock" else 0.35
	airframe_mat.roughness = 0.65 if spec.id != "nighthawk" else 0.80
	airframe_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	airframe_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	airframe_mat.rim_enabled = false

	var rotor_mat = StandardMaterial3D.new()
	rotor_mat.resource_name = "Rotor_Mat"
	rotor_mat.albedo_color = Color(0.16, 0.18, 0.20, 1.0)
	rotor_mat.metallic = 0.10
	rotor_mat.roughness = 0.40
	rotor_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var meshes = visuals_root.find_children("", "MeshInstance3D", true, false)
	for m in meshes:
		if m.name in ["RotorDisc", "TailRotorDisc", "MainRotorBlurPlane", "TailRotorBlurPlane"]:
			continue
		elif m.name in ["Main_Rotor", "Tail_Rotor", "MainRotor", "TailRotor"]:
			m.material_override = rotor_mat
		elif m.get_parent() and m.get_parent().name in ["ModularAddons", "LeftMainGear", "RightMainGear", "TailGear", "ChinTurret"]:
			continue
		else:
			m.material_override = airframe_mat

	# 3. Cockpit & searchlight colors
	var cockpit_light = visuals_root.find_child("CockpitLight", true, false) as OmniLight3D
	if cockpit_light:
		cockpit_light.light_color = canopy_color
	var search_light = visuals_root.find_child("SearchLight", true, false) as SpotLight3D
	if search_light:
		search_light.light_color = Color(1.0, 0.98, 0.90)

	# 4. Modular Airframe Components
	_update_modular_addons(visuals_root, spec, airframe_mat, rotor_mat, is_preview)

## Builds or updates modular components (Radar dome, stealth winglets, titanium cheek armor)
static func _update_modular_addons(root_node: Node3D, spec: Dictionary, body_mat: Material, dark_mat: Material, is_preview: bool) -> void:
	var addons = root_node.find_child("ModularAddons", true, false)
	if not addons:
		addons = Node3D.new()
		addons.name = "ModularAddons"
		root_node.add_child(addons)

	# Clear previous modular addons
	for child in addons.get_children():
		addons.remove_child(child)
		child.queue_free()

	# Addon 1: Mast-Mounted Longbow Radar Dome
	# (The base player.glb already incorporates the authentic AH-64 Longbow mast radome)

	# Addon 2: Swept Stealth Winglets & Canted Tail Fins (Nighthawk)
	if spec.has_stealth_fins:
		var stealth_kit = Node3D.new()
		stealth_kit.name = "StealthKit"
		addons.add_child(stealth_kit)

		# Canted outward vertical tail stabilizers (V-tail stealth fins)
		for side in [-1.0, 1.0]:
			var fin = MeshInstance3D.new()
			var f_mesh = BoxMesh.new()
			f_mesh.size = Vector3(0.06, 0.70, 0.42)
			fin.mesh = f_mesh
			fin.material_override = dark_mat
			fin.position = Vector3(side * 0.38, 1.35, 4.30) if is_preview else Vector3(side * 0.42, 1.45, 5.80)
			fin.rotation_degrees = Vector3(10.0, 0.0, side * -24.0)
			stealth_kit.add_child(fin)

			# Wingtip stealth winglets
			var winglet = MeshInstance3D.new()
			var w_mesh = BoxMesh.new()
			w_mesh.size = Vector3(0.05, 0.32, 0.28)
			winglet.mesh = w_mesh
			winglet.material_override = body_mat
			winglet.position = Vector3(side * 2.15, -0.15, -0.10) if is_preview else Vector3(side * 3.60, -0.20, -0.10)
			winglet.rotation_degrees = Vector3(0.0, 0.0, side * 35.0)
			stealth_kit.add_child(winglet)

	# Addon 3: Titanium Heavy Rocket Pods (Warlock)
	if spec.has_titanium_plates:
		var heavy_kit = Node3D.new()
		heavy_kit.name = "HeavyArmorKit"
		addons.add_child(heavy_kit)

		var armor_mat = StandardMaterial3D.new()
		armor_mat.albedo_color = Color(0.42, 0.45, 0.48, 1.0)
		armor_mat.metallic = 0.65
		armor_mat.roughness = 0.45

		for side in [-1.0, 1.0]:

			# Auxiliary Heavy Blast Pods mounted under sponson wings
			var pod = MeshInstance3D.new()
			var pod_mesh = CylinderMesh.new()
			pod_mesh.top_radius = 0.20
			pod_mesh.bottom_radius = 0.20
			pod_mesh.height = 1.25
			pod_mesh.radial_segments = 12
			pod.mesh = pod_mesh
			pod.material_override = dark_mat
			pod.rotation_degrees = Vector3(90.0, 0.0, 0.0)
			pod.position = Vector3(side * 1.60, -0.62, -0.20) if is_preview else Vector3(side * 2.60, -0.68, -0.20)
			heavy_kit.add_child(pod)
