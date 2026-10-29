class_name PlayerHelicopter
extends CharacterBody3D

const DamageDataClass = preload("res://src/combat/damage_data.gd")
const XpDropClass = preload("res://src/loot/xp_drop.gd")

## PlayerHelicopter — Physics-based 3D helicopter flight model.
## Implements rotor thrust vectoring, second-order attitude dynamics (pitch/bank),
## aerodynamic drag, ground effect cushion, subsystem degradation, and fuel starvation.

@export var aircraft_type: String = "apache"
@export var cruise_speed: float = 36.0 # Base combat cruise speed (units/s)
@export var strafe_acceleration: float = 52.0 # m/s², bounded independently of forward thrust
@export var strafe_braking: float = 90.0
@export var strafe_response: float = 18.0 # Rotor response to lateral cyclic changes
@export var yaw_acceleration_deg: float = 260.0
@export var yaw_braking_deg: float = 600.0

# Hull & Survivability
var max_hull: float = GameConstants.PLAYER_BASE_HULL
var current_hull: float = GameConstants.PLAYER_BASE_HULL
var armor_mitigation: float = 0.0 # 0.0 to GameConstants.MAX_ARMOR_MITIGATION (0.24)
var is_invulnerable: bool = false
var debug_invulnerable: bool = false
var drag_multiplier: float = 1.0 # Aerodynamic drag modifier (Ghost Rotor perk)
var spawn_grace_timer: float = 0.0
var mortal_protection = preload("res://src/player/mortal_protection.gd").new()
var mortal_alarm_timer := 0.0
var small_arms_armor := 0.0
var radar_range_multiplier := 1.0
var damage_history: Array[Dictionary] = []
const MAX_DAMAGE_HISTORY: int = 50

func has_protection() -> bool:
	var super_controller = get_node_or_null("DevastationSuper")
	return debug_invulnerable or is_dying or (super_controller != null and super_controller.is_active) or mortal_protection.grace_left > 0.0 or (shield_timer > 0.0 and shield_capacity <= 0.0) or spawn_grace_timer > 0.0 or (is_dashing and dash_timer > 0.0)

func update_invulnerability_state() -> void:
	is_invulnerable = has_protection()

func get_protection_reasons() -> Array[String]:
	var reasons: Array[String] = []
	if debug_invulnerable: reasons.append("debug")
	if is_dying: reasons.append("dying")
	if shield_timer > 0.0: reasons.append("shield")
	if spawn_grace_timer > 0.0: reasons.append("spawn_grace")
	if mortal_protection.grace_left > 0.0: reasons.append("mortal_grace")
	var super_controller = get_node_or_null("DevastationSuper")
	if super_controller != null and super_controller.is_active: reasons.append("super")
	if is_dashing and dash_timer > 0.0: reasons.append("dash")
	return reasons

# Subsystem Condition (0 to 100)
var engine_condition: float = 100.0
var rotor_condition: float = 100.0

# Fuel System
var max_fuel: float = GameConstants.PLAYER_BASE_FUEL
var current_fuel: float = GameConstants.PLAYER_BASE_FUEL
var fuel_drain_rate: float = GameConstants.FUEL_DRAIN_PER_SECOND
var fuel_starvation_timer: float = 0.0

# Dash Mechanics
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var is_dashing: bool = false
var dash_direction: Vector3 = Vector3.ZERO

# Handling Modifiers (Cargo, Perks, Hangar)
var handling_multiplier: float = 1.0
var thrust_multiplier: float = 1.0
var dash_speed_multiplier: float = 1.0
var dash_cooldown_reduction: float = 0.0
var collision_resistance: float = 0.0
var pickup_radius_multiplier: float = 1.0
var loot_multiplier: float = 1.0
var cargo_mass_multiplier: float = 1.0
var speed_boost_multiplier: float = 1.0
var speed_boost_timer: float = 0.0
var shield_timer: float = 0.0
var shield_capacity: float = 0.0
var shield_capacity_bonus: float = 0.0
var shield_duration_bonus: float = 0.0
var evasion_chance: float = 0.0

# Physics Flight Variables
var pitch_angle: float = 0.0
var pitch_velocity: float = 0.0
var bank_angle: float = 0.0
var bank_velocity: float = 0.0
var angular_velocity: float = 0.0
var lateral_acceleration: float = 0.0
var yaw_slip_angle: float = 0.0
var yaw_slip_velocity: float = 0.0
var flight_time: float = 0.0

var current_agl: float = 18.5
var in_ground_effect_factor: float = 1.0

# Exported state for camera/HUD
var visual_pitch: float = 0.0
var visual_bank: float = 0.0
var fwd_speed_ratio: float = 0.0
var lat_speed_ratio: float = 0.0
var last_thrust_input: float = 0.0
var last_strafe_input: float = 0.0

# Visual Pointers
@onready var visual_hull: Node3D = $Visuals
@onready var magnet_sensor: Area3D = get_node_or_null("MagnetSensor")
@onready var subsystem_manager: Node = get_node_or_null("SubsystemManager")
var base_magnet_radius: float = 12.0
@onready var side_wings: Node3D = $Visuals.get_node_or_null("SideWings")
@onready var skid_left: Node3D = $Visuals.get_node_or_null("SkidLeft")
@onready var skid_right: Node3D = $Visuals.get_node_or_null("SkidRight")
@onready var tail_strobe: OmniLight3D = $Visuals.get_node_or_null("TailStrobe")
@onready var search_light: SpotLight3D = $Visuals.get_node_or_null("SearchLight")
@onready var turret: Node3D = $Turret
@onready var camera: Camera3D = $PlayerCamera
@onready var ray_ground: RayCast3D = $GroundRayCast

var main_rotor: Node3D = null
var tail_rotor: Node3D = null
var main_rotor_base_pos: Vector3 = Vector3.ZERO
var tail_rotor_base_pos: Vector3 = Vector3.ZERO
var rotor_audio: AudioStreamPlayer = null
var main_rotor_blur_mesh: MeshInstance3D = null
var tail_rotor_blur_mesh: MeshInstance3D = null
var main_rotor_blur_mat: StandardMaterial3D = null
var tail_rotor_blur_mat: StandardMaterial3D = null
var rotor_rpm_ratio: float = 1.0
var ground_dust_particles: CPUParticles3D = null
var is_landed: bool = false

# Airframe Damage FX (Progressive Smoke, Roaring Flames & Flickering Light)
var airframe_smoke: CPUParticles3D = null
var airframe_fire: CPUParticles3D = null
var airframe_fire_light: OmniLight3D = null
var impact_damage_cooldown: float = 0.0
var collision_scrape_timer: float = 0.0
var override_flight_input: Dictionary = {}

# Death Animation & Crash State
var is_dying: bool = false
var death_timer: float = 0.0
var death_spiral_yaw_speed: float = 0.0
var death_spiral_pitch_target: float = 0.0
var death_spiral_roll_target: float = 0.0
var death_smoke_timer: float = 0.0
var death_cause: String = "KIA"
var death_impact_occurred: bool = false

func _ready() -> void:
	add_to_group("player")
	global_position.y = GameConstants.STARTING_ALTITUDE
	if has_node("/root/GameManager"):
		var selected = get_node("/root/GameManager").selected_aircraft
		if selected != "":
			aircraft_type = selected
	_apply_aircraft_baseline()
	_setup_rotors()
	_setup_ground_dust()
	_setup_airframe_damage_effects()
	_setup_helicopter_audio()
	_setup_magnet_sensor()
	if has_node("/root/ShaderManager"):
		get_node("/root/ShaderManager").apply_selective_outline(self, 0.008)

func _setup_helicopter_audio() -> void:
	if rotor_audio and is_instance_valid(rotor_audio):
		return
	rotor_audio = AudioStreamPlayer.new()
	rotor_audio.name = "HelicopterRotorAudio"
	rotor_audio.bus = "Master"
	if has_node("/root/AudioManager"):
		rotor_audio.stream = get_node("/root/AudioManager").get_helicopter_rotor_stream()
	add_child(rotor_audio)
	if rotor_audio.stream:
		rotor_audio.volume_db = -1.5
		rotor_audio.play()

func _setup_magnet_sensor() -> void:
	if not magnet_sensor:
		magnet_sensor = get_node_or_null("MagnetSensor")
	if magnet_sensor:
		var shape_node = magnet_sensor.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if shape_node and shape_node.shape:
			shape_node.shape = shape_node.shape.duplicate()
			shape_node.shape.radius = base_magnet_radius * pickup_radius_multiplier
		if not magnet_sensor.area_entered.is_connected(_on_magnet_sensor_area_entered):
			magnet_sensor.area_entered.connect(_on_magnet_sensor_area_entered)

func _on_magnet_sensor_area_entered(area: Area3D) -> void:
	if not area or not is_instance_valid(area):
		return
	if area is XpDropClass or area.has_method("start_attraction") or "is_being_attracted" in area:
		if "target_player" in area:
			area.target_player = self
		if "is_being_attracted" in area:
			area.is_being_attracted = true

func update_magnet_sensor_radius(multiplier: float) -> void:
	pickup_radius_multiplier = multiplier
	if not magnet_sensor:
		magnet_sensor = get_node_or_null("MagnetSensor")
	if magnet_sensor:
		var col = magnet_sensor.get_node_or_null("CollisionShape3D")
		if col and col.shape is SphereShape3D:
			col.shape.radius = base_magnet_radius * multiplier

func _setup_ground_dust() -> void:
	ground_dust_particles = CPUParticles3D.new()
	ground_dust_particles.name = "RotorWashDust"
	ground_dust_particles.emitting = false
	ground_dust_particles.amount = 36
	ground_dust_particles.lifetime = 0.85
	ground_dust_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	ground_dust_particles.emission_sphere_radius = 4.0
	ground_dust_particles.direction = Vector3.UP
	ground_dust_particles.spread = 85.0
	ground_dust_particles.initial_velocity_min = 7.0
	ground_dust_particles.initial_velocity_max = 14.0
	ground_dust_particles.gravity = Vector3(0.0, -1.5, 0.0)
	ground_dust_particles.scale_amount_min = 1.2
	ground_dust_particles.scale_amount_max = 2.8

	var s_mesh = SphereMesh.new()
	s_mesh.radius = 0.6
	s_mesh.height = 1.2
	var s_mat = StandardMaterial3D.new()
	s_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	s_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	s_mat.albedo_color = Color(0.68, 0.65, 0.60, 0.25)
	s_mesh.material = s_mat
	ground_dust_particles.mesh = s_mesh
	ground_dust_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground_dust_particles.top_level = true
	add_child(ground_dust_particles)

func _setup_airframe_damage_effects() -> void:
	if not visual_hull:
		return

	# 1. Airframe Smoke Particles (Billows below 55% hull)
	if not airframe_smoke or not is_instance_valid(airframe_smoke):
		airframe_smoke = CPUParticles3D.new()
		airframe_smoke.name = "AirframeDamageSmoke"
		airframe_smoke.emitting = false
		airframe_smoke.amount = 36
		airframe_smoke.lifetime = 0.85
		airframe_smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		airframe_smoke.emission_sphere_radius = 0.35
		airframe_smoke.direction = Vector3(0.0, 0.4, 1.0)
		airframe_smoke.spread = 30.0
		airframe_smoke.initial_velocity_min = 2.5
		airframe_smoke.initial_velocity_max = 6.0
		airframe_smoke.gravity = Vector3(0.0, 3.5, 0.0)
		airframe_smoke.damping_min = 3.0
		airframe_smoke.damping_max = 7.0
		airframe_smoke.scale_amount_min = 0.4
		airframe_smoke.scale_amount_max = 1.8
		airframe_smoke.color = Color(0.18, 0.18, 0.20, 0.70)
		
		var s_mesh = SphereMesh.new()
		s_mesh.radial_segments = 6
		s_mesh.rings = 3
		s_mesh.radius = 0.3
		s_mesh.height = 0.6
		var s_mat = StandardMaterial3D.new()
		s_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		s_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		s_mat.albedo_color = Color(0.22, 0.22, 0.24, 0.60)
		s_mesh.material = s_mat
		airframe_smoke.mesh = s_mesh
		airframe_smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		airframe_smoke.position = Vector3(0.0, 0.45, 0.8) # Engine deck behind main rotor
		visual_hull.add_child(airframe_smoke)

	# 2. Airframe Fire Particles (Roaring flames below 28% hull)
	if not airframe_fire or not is_instance_valid(airframe_fire):
		airframe_fire = CPUParticles3D.new()
		airframe_fire.name = "AirframeDamageFire"
		airframe_fire.emitting = false
		airframe_fire.amount = 40
		airframe_fire.lifetime = 0.42
		airframe_fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		airframe_fire.emission_sphere_radius = 0.25
		airframe_fire.direction = Vector3(0.0, 0.7, 0.7)
		airframe_fire.spread = 40.0
		airframe_fire.initial_velocity_min = 3.5
		airframe_fire.initial_velocity_max = 7.5
		airframe_fire.gravity = Vector3(0.0, 6.0, 0.0)
		airframe_fire.scale_amount_min = 0.35
		airframe_fire.scale_amount_max = 1.2
		airframe_fire.color = Color(1.0, 0.65, 0.15, 1.0)
		
		var f_mesh = SphereMesh.new()
		f_mesh.radial_segments = 6
		f_mesh.rings = 3
		f_mesh.radius = 0.22
		f_mesh.height = 0.44
		var f_mat = StandardMaterial3D.new()
		f_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		f_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		f_mat.albedo_color = Color(1.0, 0.55, 0.1, 0.95)
		f_mesh.material = f_mat
		airframe_fire.mesh = f_mesh
		airframe_fire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		airframe_fire.position = Vector3(0.0, 0.48, 0.75)
		visual_hull.add_child(airframe_fire)

	# 3. Roaring Firelight (Flickers on airframe and nearby buildings)
	if not airframe_fire_light or not is_instance_valid(airframe_fire_light):
		airframe_fire_light = OmniLight3D.new()
		airframe_fire_light.name = "AirframeFireLight"
		airframe_fire_light.light_color = Color(1.0, 0.45, 0.08)
		airframe_fire_light.light_energy = 0.0
		airframe_fire_light.omni_range = 10.0
		airframe_fire_light.omni_attenuation = 1.6
		airframe_fire_light.visible = false
		airframe_fire_light.position = Vector3(0.0, 0.7, 0.75)
		visual_hull.add_child(airframe_fire_light)

func _update_damage_effects(_delta: float) -> void:
	if is_dying:
		if airframe_smoke and is_instance_valid(airframe_smoke):
			airframe_smoke.emitting = true
		if airframe_fire and is_instance_valid(airframe_fire):
			airframe_fire.emitting = true
		if airframe_fire_light and is_instance_valid(airframe_fire_light):
			airframe_fire_light.visible = true
			airframe_fire_light.light_energy = 0.4 if get_node("/root/AudioManager").reduce_flashes else randf_range(2.5, 4.5)
		return

	var hp_ratio = clampf(current_hull / max(1.0, max_hull), 0.0, 1.0)

	# 1. Smoke billows below 55% hull
	if airframe_smoke and is_instance_valid(airframe_smoke):
		var should_smoke = (hp_ratio <= 0.55)
		if airframe_smoke.emitting != should_smoke:
			airframe_smoke.emitting = should_smoke
		if should_smoke:
			airframe_smoke.amount = int(lerpf(48, 24, (hp_ratio - 0.28) / 0.27)) if hp_ratio > 0.28 else 48

	# 2. Fire and flame burst below 28% hull ("touch too much and flame effect will appear")
	var should_fire = (hp_ratio <= 0.28)
	if airframe_fire and is_instance_valid(airframe_fire):
		if airframe_fire.emitting != should_fire:
			airframe_fire.emitting = should_fire

	if airframe_fire_light and is_instance_valid(airframe_fire_light):
		if airframe_fire_light.visible != should_fire:
			airframe_fire_light.visible = should_fire
		if should_fire:
			var flame_flicker = sin(flight_time * 26.0) * 0.7 + sin(flight_time * 43.0) * 0.4 + sin(flight_time * 67.0) * 0.25
			airframe_fire_light.light_energy = 0.4 if get_node("/root/AudioManager").reduce_flashes else clampf(2.4 + flame_flicker, 1.2, 3.8)

func _setup_rotors() -> void:
	if visual_hull:
		main_rotor = visual_hull.find_child("Main_Rotor", true, false)
		if not main_rotor:
			main_rotor = visual_hull.get_node_or_null("MainRotor")
		tail_rotor = visual_hull.find_child("Tail_Rotor", true, false)
		if not tail_rotor:
			tail_rotor = visual_hull.get_node_or_null("TailRotor")

	if main_rotor:
		main_rotor_base_pos = main_rotor.position
		# Remove any old conflicting / cloudy CylinderMesh discs
		var old_disc = main_rotor.get_node_or_null("RotorDisc")
		if old_disc:
			old_disc.queue_free()

	if tail_rotor:
		tail_rotor_base_pos = tail_rotor.position
		var old_tail_disc = tail_rotor.get_node_or_null("TailRotorDisc")
		if old_tail_disc:
			old_tail_disc.queue_free()

	_setup_rotor_blur_discs()
	_polish_airframe_materials()

func _setup_rotor_blur_discs() -> void:
	# 1. Main Rotor Aerodynamic Motion Blur Disc (Sized to match Apache 11.4m rotor diameter)
	if main_rotor and not main_rotor.has_node("MainRotorBlurPlane"):
		main_rotor_blur_mesh = MeshInstance3D.new()
		main_rotor_blur_mesh.name = "MainRotorBlurPlane"
		main_rotor_blur_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		
		var p_mesh = PlaneMesh.new()
		p_mesh.size = Vector2(1.58, 1.58) # Sized to local rotor diameter
		main_rotor_blur_mesh.mesh = p_mesh
		
		main_rotor_blur_mat = StandardMaterial3D.new()
		main_rotor_blur_mat.resource_name = "MainRotorBlurMat"
		main_rotor_blur_mat.albedo_texture = _create_procedural_rotor_blur_texture(false)
		main_rotor_blur_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		main_rotor_blur_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		main_rotor_blur_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		main_rotor_blur_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		main_rotor_blur_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.42)
		main_rotor_blur_mesh.material_override = main_rotor_blur_mat
		main_rotor_blur_mesh.position = Vector3(0.0, 0.012, 0.0)
		main_rotor.add_child(main_rotor_blur_mesh)

	# 2. Tail Rotor High-Speed Motion Blur Disc
	if tail_rotor and not tail_rotor.has_node("TailRotorBlurPlane"):
		tail_rotor_blur_mesh = MeshInstance3D.new()
		tail_rotor_blur_mesh.name = "TailRotorBlurPlane"
		tail_rotor_blur_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		
		var q_mesh = QuadMesh.new()
		q_mesh.size = Vector2(0.32, 0.32)
		tail_rotor_blur_mesh.mesh = q_mesh
		
		tail_rotor_blur_mat = StandardMaterial3D.new()
		tail_rotor_blur_mat.resource_name = "TailRotorBlurMat"
		tail_rotor_blur_mat.albedo_texture = _create_procedural_rotor_blur_texture(true)
		tail_rotor_blur_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tail_rotor_blur_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		tail_rotor_blur_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		tail_rotor_blur_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		tail_rotor_blur_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.35)
		tail_rotor_blur_mesh.material_override = tail_rotor_blur_mat
		tail_rotor_blur_mesh.position = Vector3(0.0, 0.0, 0.008)
		tail_rotor.add_child(tail_rotor_blur_mesh)

func _create_procedural_rotor_blur_texture(is_tail: bool = false) -> GradientTexture2D:
	var grad = Gradient.new()
	if not is_tail:
		# Main rotor: hub cutout, carbon blade disc density, soft turbulent tip fade
		grad.colors = PackedColorArray([
			Color(0.18, 0.20, 0.22, 0.0),
			Color(0.20, 0.22, 0.24, 0.15),
			Color(0.22, 0.24, 0.27, 0.45),
			Color(0.25, 0.28, 0.30, 0.40),
			Color(0.18, 0.20, 0.22, 0.18),
			Color(0.15, 0.16, 0.18, 0.0)
		])
		grad.offsets = PackedFloat32Array([0.0, 0.16, 0.45, 0.78, 0.94, 1.0])
	else:
		grad.colors = PackedColorArray([
			Color(0.18, 0.20, 0.22, 0.0),
			Color(0.22, 0.24, 0.26, 0.42),
			Color(0.25, 0.28, 0.30, 0.35),
			Color(0.15, 0.16, 0.18, 0.0)
		])
		grad.offsets = PackedFloat32Array([0.0, 0.25, 0.85, 1.0])

	var tex = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 256
	tex.height = 256
	return tex


func _polish_airframe_materials() -> void:
	if not visual_hull:
		return
	var base_tex: Texture2D = null
	if ResourceLoader.exists("res://assets/player/player_apache_basecolor.png"):
		base_tex = load("res://assets/player/player_apache_basecolor.png")
	var norm_tex: Texture2D = null
	if ResourceLoader.exists("res://assets/player/player_apache_normal.png"):
		norm_tex = load("res://assets/player/player_apache_normal.png")
	var orm_tex: Texture2D = null
	if ResourceLoader.exists("res://assets/player/player_apache_orm.png"):
		orm_tex = load("res://assets/player/player_apache_orm.png")

	var mat = StandardMaterial3D.new()
	mat.resource_name = "Pristine_Apache_Material"
	if base_tex:
		mat.albedo_texture = base_tex
	if norm_tex:
		mat.normal_enabled = true
		mat.normal_texture = norm_tex
		mat.normal_scale = 1.0
	if orm_tex:
		mat.orm_texture = orm_tex
	mat.metallic = 0.12 # Non-metallic CARC military coating
	mat.roughness = 0.65 # Authentic satin matte finish
	var atype := aircraft_type.to_lower()
	if atype == "nighthawk":
		mat.albedo_color = Color(0.40, 0.42, 0.46, 1.0) # Sleek matte carbon
	elif atype == "warlock":
		mat.albedo_color = Color(0.60, 0.62, 0.65, 1.0) # Titanium armored slate
	else:
		mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0) # Authentic military baseline
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.rim_enabled = false

	# Dedicated aerodynamic carbon-composite material for main and tail rotors
	var rotor_mat = StandardMaterial3D.new()
	rotor_mat.resource_name = "Rotor_Carbon_Material"
	rotor_mat.albedo_color = Color(0.16, 0.18, 0.20, 1.0)
	rotor_mat.metallic = 0.10
	rotor_mat.roughness = 0.40
	rotor_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	rotor_mat.rim_enabled = false

	var meshes = visual_hull.find_children("", "MeshInstance3D", true, false)
	for m in meshes:
		# Blur planes keep their transparent disc material, never the opaque body atlas.
		if m.name in ["RotorDisc", "TailRotorDisc", "MainRotorBlurPlane", "TailRotorBlurPlane"]:
			continue
		elif m.name == "Main_Rotor" or m.name == "Tail_Rotor" or m.name == "MainRotor" or m.name == "TailRotor":
			m.material_override = rotor_mat
		else:
			m.material_override = mat

func _apply_aircraft_baseline() -> void:
	var specs: Dictionary = preload("res://data/aircraft_specs.gd").get_specs(aircraft_type)
	max_hull = specs.hull
	max_fuel = specs.fuel
	cruise_speed = specs.speed
	current_hull = max_hull
	current_fuel = max_fuel
	var visuals = get_node_or_null("Visuals")
	if visuals:
		preload("res://data/aircraft_specs.gd").configure_airframe_visuals(visuals, aircraft_type, false)

func _process(delta: float) -> void:
	if not is_instance_valid(self):
		return
	if is_dying:
		return
	if current_hull <= 0.0:
		return
	flight_time += delta
	if camera and camera.has_method("update_camera"):
		camera.update_camera(delta)
	if turret and camera:
		var mouse_pos: Vector2 = get_node("/root/InputManager").get_aim_screen_position()
		turret.update_aim(camera, mouse_pos, self, delta)

	# Fluid visual animations & rotor spinning executed at full render framerate
	_animate_rotors(delta)
	_update_helicopter_visuals(last_thrust_input, last_strafe_input, delta)
	_update_helicopter_audio(delta)
	_update_damage_effects(delta)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(self):
		return
	if is_dying:
		_process_death_sequence(delta)
		return
	if current_hull <= 0.0:
		return

	impact_damage_cooldown = maxf(0.0, impact_damage_cooldown - delta)
	_process_buff_timers(delta)
	_process_fuel(delta)
	_process_flight_physics(delta)

func _process_buff_timers(delta: float) -> void:
	mortal_protection.advance(delta, current_hull, max_hull)
	mortal_alarm_timer = maxf(0.0, mortal_alarm_timer - delta)
	if spawn_grace_timer > 0.0:
		spawn_grace_timer = maxf(0.0, spawn_grace_timer - delta)

	if shield_timer > 0.0:
		shield_timer = maxf(0.0, shield_timer - delta)
		if shield_timer <= 0.0:
			shield_capacity = 0.0

	update_invulnerability_state()

	if speed_boost_timer > 0.0:
		speed_boost_timer -= delta
		if speed_boost_timer <= 0.0:
			speed_boost_multiplier = 1.0

# ------------------------------------------------------------------------------
# 1. PHYSICS-BASED FLIGHT DYNAMICS
# ------------------------------------------------------------------------------
func _process_flight_physics(delta: float) -> void:
	# Read normalized inputs from InputManager (or test/bot override)
	var input_data: Dictionary = {}
	if override_flight_input.size() > 0:
		input_data = override_flight_input
	elif has_node("/root/InputManager"):
		input_data = get_node("/root/InputManager").get_flight_input()
	else:
		input_data = {"yaw": 0.0, "thrust": 0.0, "strafe": 0.0, "lift": 0.0, "dash": false}

	# Subsystem efficiency factors (Page 8)
	var engine_factor = 0.5 + 0.5 * (engine_condition / 100.0)
	var rotor_factor = 0.4 + 0.6 * (rotor_condition / 100.0)

	var thrust_input = input_data.get("thrust", 0.0)
	var strafe_input = input_data.get("strafe", 0.0)
	var yaw_input = input_data.get("yaw", 0.0)
	var lift_input = input_data.get("lift", 0.0)
	last_thrust_input = thrust_input
	last_strafe_input = strafe_input

	# 1. Evasive Dash
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta
		
	if input_data.get("dash", false) and dash_cooldown_timer <= 0.0 and not is_dashing:
		_trigger_dash(input_data)

	if is_dashing:
		lateral_acceleration = 0.0
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
			update_invulnerability_state()
		else:
			velocity.x = dash_direction.x * (GameConstants.DASH_BURST_SPEED * dash_speed_multiplier)
			velocity.z = dash_direction.z * (GameConstants.DASH_BURST_SPEED * dash_speed_multiplier)
			move_and_slide()
			_clamp_to_battlefield()
			return

	# Aircraft Performance Multipliers
	var max_speed = cruise_speed * speed_boost_multiplier
	var yaw_mult = 1.0
	var atype := aircraft_type.to_lower()
	if atype == "nighthawk":
		yaw_mult = 1.20
	elif atype == "warlock":
		yaw_mult = 0.85
	max_speed = minf(max_speed, GameConstants.HORIZONTAL_CRUISE_CAP)

	# 2. Smooth Yaw Turning Dynamics with Tail-Rotor Momentum
	var planar_speed = Vector2(velocity.x, velocity.z).length()
	var flight_speed_ratio = clampf(planar_speed / maxf(max_speed, 0.1), 0.0, 1.0)
	var yaw_authority = lerpf(0.92, 0.78, flight_speed_ratio)
	var target_yaw_rate = -yaw_input * GameConstants.MAX_YAW_RATE * yaw_authority * rotor_factor * yaw_mult * handling_multiplier
	var yaw_braking = absf(yaw_input) < 0.001 or angular_velocity * target_yaw_rate < 0.0
	var yaw_accel = deg_to_rad(yaw_braking_deg if yaw_braking else yaw_acceleration_deg)
	yaw_accel *= maxf(0.35, rotor_factor * handling_multiplier * cargo_mass_multiplier)
	angular_velocity = move_toward(angular_velocity, target_yaw_rate, yaw_accel * delta)
	rotate_y(angular_velocity * delta)

	# 3. Attitude Physics: Damped Spring-Mass Attitude System
	var forward_dir = -global_transform.basis.z.normalized()
	var right_dir = global_transform.basis.x.normalized()
	
	# Compute current local velocity components
	var v_fwd = velocity.dot(forward_dir)
	var v_lat = velocity.dot(right_dir)
	var direct_move: bool = input_data.get("direct_move", false)
	var strafe_speed = max_speed if direct_move else max_speed * 0.72
	fwd_speed_ratio = clampf(v_fwd / max_speed, -1.0, 1.0)
	lat_speed_ratio = clampf(v_lat / strafe_speed, -1.0, 1.0)
	
	# Pitch targets (In Godot 3D, negative rotation.x tilts nose DOWN = LEAN FORWARD)
	var max_pitch_rad = deg_to_rad(GameConstants.VISUAL_PITCH_LIMIT_DEG) # 18.0°
	var target_pitch = 0.0

	# Subtle arcade forward cyclic tilt during high-speed flight
	if thrust_input > 0.0:
		# Active forward cyclic (W): dips nose forward into flight path (-18°)
		var forward_demand = clampf(thrust_input + fwd_speed_ratio * 0.25, 0.0, 1.0)
		target_pitch = -forward_demand * max_pitch_rad
	elif thrust_input < 0.0:
		if v_fwd > 0.5:
			# Reverse cyclic / Air Braking Flare (S): nose flares UP (+22.5°)
			target_pitch = 1.25 * max_pitch_rad
		else:
			# Backing up / reverse flight: nose points up naturally (+13.5°)
			target_pitch = -thrust_input * max_pitch_rad * 0.75
	else:
		# Coasting: sustains slight forward lean with airspeed
		if v_fwd > 1.0:
			target_pitch = -fwd_speed_ratio * (max_pitch_rad * 0.50)
		elif v_fwd < -1.0:
			target_pitch = -fwd_speed_ratio * (max_pitch_rad * 0.35)

	# Bank / Roll targets (Z-axis airframe lean):
	var max_bank_rad = deg_to_rad(GameConstants.VISUAL_BANK_LIMIT_DEG) # 28.0°
	
	# Turn banking: turning left (angular_velocity > 0) leans airframe left (+Z roll); turning right (angular_velocity < 0) leans right (-Z roll)
	var turn_bank = (angular_velocity / GameConstants.MAX_YAW_RATE) * max_bank_rad * lerpf(0.12, 0.75, flight_speed_ratio)
	
	# Strafe banking: strafing left (strafe_input < 0) leans left (+Z roll); strafing right (strafe_input > 0) leans right (-Z roll)
	# Lean into acceleration and counter-bank while arresting sideways motion.
	# A small cruise lean remains once the requested lateral speed is reached.
	var lateral_speed_error = (strafe_input * strafe_speed - v_lat) / maxf(strafe_speed * 0.65, 0.1)
	var strafe_effort = strafe_input * 0.25 + clampf(lateral_speed_error, -1.0, 1.0) * 0.45
	var strafe_bank = -strafe_effort * max_bank_rad
	
	# Total target bank angle
	var target_bank = clampf(turn_bank + strafe_bank, -max_bank_rad, max_bank_rad)

	# Snappy and weighty Second-order Spring-Mass-Damper Attitude Integration
	var spring_k = 42.0
	var damp_c = 11.5
	pitch_velocity += ((target_pitch - pitch_angle) * spring_k - pitch_velocity * damp_c) * delta
	pitch_angle += pitch_velocity * delta
	pitch_angle = clampf(pitch_angle, -max_pitch_rad * 1.25, max_pitch_rad * 1.25)

	# Silky smooth second-order roll spring on Z-axis (fluid, natural roll inertia)
	var roll_spring_k = 60.0
	var roll_damp_c = 15.0
	bank_velocity += ((target_bank - bank_angle) * roll_spring_k - bank_velocity * roll_damp_c) * delta
	bank_angle += bank_velocity * delta
	bank_angle = clampf(bank_angle, -max_bank_rad, max_bank_rad)

	# Heading stays cleanly aligned with gameplay CharacterBody3D (no fishtailing or yaw slip offset)
	yaw_slip_angle = 0.0

	# Exported state for camera/HUD (positive visual pitch means leaning forward)
	visual_pitch = -pitch_angle
	visual_bank = bank_angle

	# 4. Physical Rotor Thrust Vectoring & Momentum
	var target_fwd_vel = 0.0
	if thrust_input > 0.0:
		target_fwd_vel = thrust_input * max_speed
	elif thrust_input < 0.0:
		# One continuous brake-to-reverse command; no zero-speed threshold latch.
		target_fwd_vel = thrust_input * max_speed * (1.0 if direct_move else 0.65)

	# Decoupled Strafe: cleanly driven by strafe input without injecting unwanted drift during yaw turning
	var target_str_vel = strafe_input * strafe_speed

	var target_horiz_vel = (forward_dir * target_fwd_vel) + (right_dir * target_str_vel)
	if target_horiz_vel.length() > max_speed:
		target_horiz_vel = target_horiz_vel.normalized() * max_speed

	# Independent local-axis control keeps lateral braking identical whether W/S
	# is held or released. Bounded acceleration also prevents reversal spikes.
	target_fwd_vel = target_horiz_vel.dot(forward_dir)
	target_str_vel = target_horiz_vel.dot(right_dir)
	var control_authority = engine_factor * cargo_mass_multiplier * thrust_multiplier
	var drag_rate = (6.2 + planar_speed / maxf(max_speed, 0.1) * 4.8) * drag_multiplier
	var forward_rate = 4.2 * control_authority if absf(thrust_input) > 0.001 else drag_rate
	if thrust_input < 0.0 and v_fwd > 1.8:
		forward_rate = 7.8 * control_authority
	v_fwd = lerpf(v_fwd, target_fwd_vel, 1.0 - exp(-forward_rate * delta))
	if absf(thrust_input) < 0.001 and absf(v_fwd) < 0.05:
		v_fwd = 0.0
	var lateral_error = target_str_vel - v_lat
	var braking_sideways = absf(strafe_input) < 0.001 or v_lat * strafe_input < 0.0
	var lateral_limit = (strafe_braking if braking_sideways else strafe_acceleration) * control_authority
	if direct_move:
		# Match forward response, with a bounded quick stop/reversal for dodging.
		lateral_limit = maxf(lateral_limit, max_speed * (6.0 if braking_sideways else 4.2) * control_authority)
	if absf(strafe_input) < 0.001:
		lateral_limit *= maxf(0.35, drag_multiplier)
	# Ease into small corrections instead of alternating full-strength thrust
	# around the requested speed while the helicopter is turning.
	var desired_accel = clampf(lateral_error * 12.0, -lateral_limit, lateral_limit)
	lateral_acceleration = lerpf(lateral_acceleration, desired_accel, 1.0 - exp(-strafe_response * delta))
	if lateral_acceleration * lateral_error <= 0.0:
		lateral_acceleration = 0.0
	var lateral_step = lateral_acceleration * delta
	if absf(lateral_step) >= absf(lateral_error):
		v_lat = target_str_vel
		lateral_acceleration = 0.0
	else:
		v_lat += lateral_step
	var horizontal_velocity = forward_dir * v_fwd + right_dir * v_lat
	horizontal_velocity = horizontal_velocity.limit_length(max_speed)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	# 5. Vertical Dynamics (Collective Lift, Buoyancy & In-Ground Effect)
	var target_vert_speed = 0.0
	if lift_input > 0.0:
		target_vert_speed = GameConstants.CLIMB_SPEED * engine_factor * handling_multiplier
	elif lift_input < 0.0:
		target_vert_speed = -GameConstants.SINK_SPEED
		
	# In-Ground Effect (IGE) Cushion calculation
	if ray_ground and ray_ground.is_colliding():
		current_agl = global_position.y - ray_ground.get_collision_point().y
	else:
		current_agl = global_position.y

	if current_agl < 9.0:
		var ige_ratio = clampf(1.0 - ((current_agl - 2.0) / 7.0), 0.0, 1.0)
		in_ground_effect_factor = 1.0 + (ige_ratio * 0.35)
		# Low altitude hover buoyancy: gentle ground effect float when hands off collective
		if lift_input == 0.0 and current_agl < 3.2:
			target_vert_speed += (3.2 - current_agl) * 1.5
	else:
		in_ground_effect_factor = 1.0

	# Smooth vertical buoyancy (no abrupt vertical snapping)
	var vert_rate = (3.6 * engine_factor) if lift_input != 0.0 else 3.8
	velocity.y = lerpf(velocity.y, target_vert_speed, 1.0 - exp(-vert_rate * delta))

	# Playable Area Boundary Steering Resistance (Slice A)
	var pos_2d = Vector2(global_position.x, global_position.z)
	var horiz_dist = maxf(absf(pos_2d.x), absf(pos_2d.y))
	if horiz_dist > GameConstants.BOUNDARY_SAFE_RADIUS:
		var warning_factor = clampf((horiz_dist - GameConstants.BOUNDARY_SAFE_RADIUS) / (GameConstants.BOUNDARY_HARD_RADIUS - GameConstants.BOUNDARY_SAFE_RADIUS), 0.0, 1.0)
		var return_dir_2d = -pos_2d.normalized()
		velocity.x += return_dir_2d.x * (GameConstants.BOUNDARY_STEERING_FORCE * warning_factor) * delta
		velocity.z += return_dir_2d.y * (GameConstants.BOUNDARY_STEERING_FORCE * warning_factor) * delta

	# Execute Physics Slide with Pre-Collision Velocity Tracking
	var pre_slide_velocity = velocity
	move_and_slide()

	# Collision Damage Handling: Ground contact & Building crashes deal damage
	_process_collision_damage(delta, pre_slide_velocity)

	# Hard Boundary Clamp Safety
	_clamp_to_battlefield()

	# 6. Enforce Flight Ceiling
	if global_position.y > GameConstants.FLIGHT_CEILING:
		global_position.y = GameConstants.FLIGHT_CEILING
		if velocity.y > 0.0:
			velocity.y = 0.0

	# Fail-safe void breach check (under world terrain)
	if global_position.y < -35.0:
		_die("Terrain Void Impact", true)

	# 7. Rotor Wash Ground Dust & Touchdown State Detection
	_update_rotor_wash_and_landing(delta)

func _process_collision_damage(delta: float, pre_velocity: Vector3) -> void:
	if is_dying or current_hull <= 0.0 or is_invulnerable:
		return

	if is_landed and pre_velocity.length() < 0.8:
		return

	var col_count = get_slide_collision_count()
	if col_count == 0:
		collision_scrape_timer = 0.0
		return

	var hardest_impact: float = 0.0
	var hardest_normal: Vector3 = Vector3.UP
	var hardest_collider: Object = null
	var hardest_pos: Vector3 = global_position
	var is_ground_contact: bool = false
	var is_wall_contact: bool = false

	for i in range(col_count):
		var col = get_slide_collision(i)
		var norm = col.get_normal()
		var collider = col.get_collider()
		var pt = col.get_position()

		# Ground or Flat Rooftop contact (upward pointing normal)
		if norm.y > 0.55:
			is_ground_contact = true
			var impact_speed = -pre_velocity.dot(norm)
			if impact_speed > hardest_impact:
				hardest_impact = impact_speed
				hardest_normal = norm
				hardest_collider = collider
				hardest_pos = pt
		else:
			# Building Wall or Vertical Obstacle contact
			is_wall_contact = true
			var horiz_pre = Vector3(pre_velocity.x, 0.0, pre_velocity.z)
			var horiz_norm = Vector3(norm.x, 0.0, norm.z).normalized()
			var impact_speed = -horiz_pre.dot(horiz_norm)
			if impact_speed > hardest_impact:
				hardest_impact = impact_speed
				hardest_normal = norm
				hardest_collider = collider
				hardest_pos = pt

	# 1. HARD IMPACT PROCESSING
	if is_ground_contact and not is_wall_contact:
		# Ground / Rooftop Impact (only on hard downward sink, soft touchdown takes 0 dmg)
		if hardest_impact > 1.8 and impact_damage_cooldown <= 0.0:
			impact_damage_cooldown = 1.0
			var impact_dmg = clampf(3.0 + (hardest_impact - 1.8) * 0.75, 3.0, 15.0)
			take_damage(impact_dmg, "Ground Impact")
			velocity.y = maxf(velocity.y, 4.5) + hardest_normal.y * 2.0
			if camera and camera.has_method("add_trauma"):
				camera.add_trauma(clampf(impact_dmg / 30.0 + 0.15, 0.20, 0.55))
			if has_node("/root/AudioManager"):
				get_node("/root/AudioManager").play_sfx("explosion", 1.6, 0.4)
			var fx = get_node_or_null("/root/FXManager")
			if fx and fx.has_method("spawn_impact_sparks"):
				fx.spawn_impact_sparks(hardest_pos, hardest_normal)
	elif is_wall_contact:
		# Building Wall Crash (forgiving collision: 5-18 damage, 1.0s i-frame cooldown, elastic bounce clear)
		if hardest_impact > 3.0 and impact_damage_cooldown <= 0.0:
			impact_damage_cooldown = 1.0
			var crash_dmg = clampf(5.0 + (hardest_impact - 3.0) * 0.65, 5.0, 18.0)
			take_damage(crash_dmg, "Building Crash")
			velocity = pre_velocity.bounce(hardest_normal) * 0.50 + hardest_normal * 10.0 + Vector3(0, 2.5, 0)
			if camera and camera.has_method("add_trauma"):
				camera.add_trauma(clampf(crash_dmg / 35.0 + 0.20, 0.30, 0.70))
			if has_node("/root/AudioManager"):
				get_node("/root/AudioManager").play_sfx("explosion", 1.2, 0.6)
			var fx = get_node_or_null("/root/FXManager")
			if fx and fx.has_method("spawn_impact_sparks"):
				fx.spawn_impact_sparks(hardest_pos, hardest_normal)
			engine_condition = maxf(0.0, engine_condition - randf_range(4.0, 10.0))
			
			# Deliver damage to destructible building
			if hardest_collider and is_instance_valid(hardest_collider):
				if hardest_collider.has_node("DamageReceiver"):
					var rec = hardest_collider.get_node("DamageReceiver")
					if rec.has_method("take_damage"):
						rec.take_damage(DamageDataClass.new(crash_dmg * 1.5, GameConstants.WeaponType.MACHINE_GUN, self))
				elif hardest_collider.has_method("take_damage"):
					hardest_collider.take_damage(crash_dmg * 1.5)

	# 2. CONTINUOUS TOUCHING / SCRAPING DAMAGE
	if not is_dying and current_hull > 0.0:
		var scrape_rate = 0.0
		if is_wall_contact:
			scrape_rate = 4.0 # Gentle 4 HP/s while scraping walls
		elif is_ground_contact and not is_landed:
			var horiz_speed = Vector2(velocity.x, velocity.z).length()
			if horiz_speed > 3.0:
				scrape_rate = 3.0 # Gentle 3 HP/s while skidding across ground at high speed

		if scrape_rate > 0.0:
			var scrape_raw = scrape_rate * delta
			take_damage(scrape_raw, "Building Crash" if is_wall_contact else "Ground Impact", hardest_pos)

			# Scraping sparks & camera shudder
			collision_scrape_timer += delta
			if collision_scrape_timer >= 0.14:
				collision_scrape_timer = 0.0
				var fx = get_node_or_null("/root/FXManager")
				if fx and fx.has_method("spawn_impact_sparks"):
					fx.spawn_impact_sparks(hardest_pos, hardest_normal)
				if camera and camera.has_method("add_trauma"):
					camera.add_trauma(0.04)

		# Deflection / clearance nudges to push player away from collider
		if is_ground_contact:
			velocity.y += 6.0 * delta
		if is_wall_contact:
			velocity += hardest_normal * 12.0 * delta + Vector3(0, 2.0 * delta, 0)

func _update_rotor_wash_and_landing(_delta: float) -> void:
	if ground_dust_particles and is_instance_valid(ground_dust_particles):
		if ray_ground and ray_ground.is_colliding() and current_agl < 8.5 and rotor_rpm_ratio > 0.35 and not is_dying:
			var ground_hit = ray_ground.get_collision_point()
			ground_dust_particles.global_position = ground_hit + Vector3(0, 0.12, 0)
			ground_dust_particles.emitting = true
			var dust_factor = clampf((8.5 - current_agl) / 6.5, 0.15, 1.0)
			ground_dust_particles.amount = int(20 + 32 * dust_factor)
		else:
			ground_dust_particles.emitting = false

	# Landing State & Touchdown Audio
	var horiz_vel = Vector2(velocity.x, velocity.z).length()
	var near_ground = current_agl <= (GameConstants.SURFACE_CLEARANCE + 0.35)
	var should_be_landed = near_ground and horiz_vel < 3.2 and absf(velocity.y) < 0.8 and not is_dying

	if should_be_landed:
		if not is_landed:
			is_landed = true
			if has_node("/root/AudioManager"):
				get_node("/root/AudioManager").play_sfx("touchdown", randf_range(0.96, 1.04), 1.5)
	else:
		is_landed = false

func _clamp_to_battlefield() -> void:
	# The road grid and four collision walls define a square battlefield.
	var limit := GameConstants.BOUNDARY_HARD_RADIUS - 8.0
	if absf(global_position.x) > limit:
		global_position.x = clampf(global_position.x, -limit, limit)
		if velocity.x * global_position.x > 0:
			velocity.x = 0
	if absf(global_position.z) > limit:
		global_position.z = clampf(global_position.z, -limit, limit)
		if velocity.z * global_position.z > 0:
			velocity.z = 0

func _update_helicopter_visuals(_thrust: float, _strafe: float, _delta: float) -> void:
	if not visual_hull or is_dying:
		return

	# Speed and idle factor calculations (1.0 = full idle hover, 0.0 = high-speed flight)
	var horiz_speed = Vector2(velocity.x, velocity.z).length()
	var idle_factor = clampf(1.0 - (horiz_speed / 10.0), 0.0, 1.0)
	idle_factor *= 1.0 - clampf(absf(last_strafe_input) + absf(last_thrust_input) + absf(angular_velocity) / GameConstants.MAX_YAW_RATE, 0.0, 1.0)
	var active_speed_ratio = clampf(horiz_speed / max(1.0, cruise_speed), 0.0, 1.5)

	# 1. PROMINENT IDLE POSITION HOVER BUOYANCY (Air Cushion Floating)
	# Dual-harmonic vertical air cushion bobbing (~0.50m amplitude at idle)
	var hover_bob = (sin(flight_time * 2.4) * 0.42 + sin(flight_time * 4.8) * 0.12) * (0.6 + 0.4 * idle_factor)
	
	# Micro-attitude idle cyclic adjustments (organic nodding & rolling)
	var idle_pitch = cos(flight_time * 1.8) * deg_to_rad(3.0) * idle_factor
	var idle_roll = sin(flight_time * 1.4) * deg_to_rad(3.5) * idle_factor
	var idle_yaw = sin(flight_time * 0.8) * deg_to_rad(2.0) * idle_factor
	
	# High-frequency mechanical turbine hum vibration
	var turbine_hum = sin(flight_time * 36.0) * 0.005

	# G-load airframe suspension compression during hard turns, swoops and dives
	var g_load_dip = (abs(bank_angle) * 0.45 + abs(pitch_angle) * 0.30) * -0.38

	# Apply translation offsets to visual hull (model stays centered over collider)
	visual_hull.position.x = 0.0
	visual_hull.position.y = hover_bob + g_load_dip + turbine_hum
	visual_hull.position.z = 0.0

	# Apply 3-axis attitude angles to visual hull with organic idle breathing
	visual_hull.rotation.x = pitch_angle + idle_pitch
	visual_hull.rotation.y = idle_yaw
	visual_hull.rotation.z = bank_angle + idle_roll

	# 2. SUBTLE MOVEMENT ANIMATIONS (DURING ACTIVE FLIGHT)
	# Blade coning lift on main rotor (smooth aerodynamic flex without high-frequency jitter)
	if main_rotor:
		var coning_lift = clampf(abs(fwd_speed_ratio) * 0.03 + (0.015 if abs(last_thrust_input) > 0.1 else 0.0), 0.0, 0.04)
		main_rotor.position = main_rotor_base_pos + Vector3(0.0, coning_lift, 0.0)

	# Dynamic secondary aero-elastic flex and speed flutter on weapon stub wings
	if side_wings:
		var wing_flex_z = -bank_velocity * 0.05
		var speed_flutter = sin(flight_time * 18.0) * 0.012 * active_speed_ratio
		side_wings.rotation.z = wing_flex_z + speed_flutter
		side_wings.position.y = -0.05 + (g_load_dip * 0.20)

	# Tail rotor anchor
	if tail_rotor:
		tail_rotor.position = tail_rotor_base_pos

	# Landing skid suspension compliance (skids sway slightly with inertia)
	if skid_left and skid_right:
		var skid_drag_z = clampf(fwd_speed_ratio * 0.08, -0.10, 0.10)
		var skid_sway_x = clampf(lat_speed_ratio * 0.06, -0.08, 0.08)
		skid_left.position.z = -skid_drag_z
		skid_right.position.z = -skid_drag_z
		skid_left.position.x = -1.15 - skid_sway_x
		skid_right.position.x = 1.15 - skid_sway_x

	# Aviation anti-collision beacon strobe (crisp realistic double flash)
	if tail_strobe:
		var strobe_phase = fmod(flight_time, 1.25)
		var is_flash = (strobe_phase < 0.08) or (strobe_phase > 0.18 and strobe_phase < 0.26)
		tail_strobe.light_energy = 0.3 if get_node("/root/AudioManager").reduce_flashes else (3.6 if is_flash else 0.3)

func _animate_rotors(delta: float) -> void:
	var engine_factor = 0.5 + 0.5 * (engine_condition / 100.0)
	
	# Physical RPM Spool Model:
	# Nominal target is 1.0; boosts up to 1.30 under heavy forward flight / dash
	var target_rpm = 1.0
	if is_dying or current_hull <= 0.0:
		target_rpm = 0.0
	elif is_landed:
		target_rpm = 0.45 # Gentle grounded idle rotor spin
	else:
		var speed_ratio = clampf(velocity.length() / cruise_speed, 0.0, 1.0)
		var active_load = 0.15 * speed_ratio + (0.25 if is_dashing else 0.0) + (0.08 if abs(last_thrust_input) > 0.1 else 0.0)
		target_rpm = (1.0 + active_load) * engine_factor

	var spool_rate = 3.5 if target_rpm >= rotor_rpm_ratio else 1.8
	rotor_rpm_ratio = lerpf(rotor_rpm_ratio, target_rpm, 1.0 - exp(-spool_rate * delta))

	# Calibrated anti-aliasing rotation speed for 4-blade rotor (54.0 rad/s ~ 51.5 deg/frame @ 60 FPS)
	# Breaks the 90-degree 4-blade wagon wheel harmonic trap, creating high-speed forward whir
	var main_rpm_speed = delta * 54.0 * rotor_rpm_ratio
	var tail_rpm_speed = delta * 108.0 * rotor_rpm_ratio

	if main_rotor:
		main_rotor.rotate_y(main_rpm_speed)
	if tail_rotor:
		# player.glb tail rotor rotates around its local Z axis
		tail_rotor.rotate_z(tail_rpm_speed)

	# Dynamic Motion Blur Disc Opacity Response:
	# Smoothly blends in as rotor spools up into high-speed operation
	if main_rotor_blur_mat:
		main_rotor_blur_mat.albedo_color.a = clampf((rotor_rpm_ratio - 0.20) * 0.52, 0.0, 0.45)
	if tail_rotor_blur_mat:
		tail_rotor_blur_mat.albedo_color.a = clampf((rotor_rpm_ratio - 0.20) * 0.44, 0.0, 0.38)

func _update_helicopter_audio(delta: float) -> void:
	if not rotor_audio or not is_instance_valid(rotor_audio):
		return

	if is_dying:
		# Rapid spool-down and pitch decay on fatal damage
		rotor_audio.pitch_scale = maxf(0.25, rotor_audio.pitch_scale - delta * 0.55)
		rotor_audio.volume_db = lerpf(rotor_audio.volume_db, -80.0, 1.0 - exp(-3.5 * delta))
		return

	if not rotor_audio.playing and rotor_audio.stream:
		rotor_audio.play()

	var am_master: float = 1.0
	var am_sfx: float = 1.0
	if has_node("/root/AudioManager"):
		var am = get_node("/root/AudioManager")
		am_master = am.master_volume
		am_sfx = am.sfx_volume

	if am_master <= 0.001 or am_sfx <= 0.001:
		rotor_audio.volume_db = -80.0
		return

	var speed_ratio: float = clampf(velocity.length() / cruise_speed, 0.0, 1.0)
	var engine_factor: float = 0.5 + 0.5 * (engine_condition / 100.0)

	# Dynamic Pitch Modulation:
	# Hover/idle baseline: 1.0; Grounded idle: 0.72; High-speed flight: up to 1.20x
	var target_pitch: float = 1.0 + (speed_ratio * 0.18)
	if is_landed:
		target_pitch = 0.72 # Grounded turbine idle hum
	elif abs(last_thrust_input) > 0.1:
		target_pitch += 0.06
	if is_dashing:
		target_pitch += 0.24
	target_pitch *= engine_factor

	rotor_audio.pitch_scale = lerpf(rotor_audio.pitch_scale, target_pitch, 1.0 - exp(-6.0 * delta))

	# Dynamic Volume Modulation:
	var g_load_audio_boost: float = (abs(bank_angle) + abs(pitch_angle)) * 2.2
	var load_boost_db: float = (speed_ratio * 2.8) + (2.0 if is_dashing else 0.0) + g_load_audio_boost
	if is_landed:
		load_boost_db = -4.5 # Softer, peaceful turbine idle at rest
	var base_db: float = linear_to_db(am_master * am_sfx) - 0.5 + load_boost_db
	rotor_audio.volume_db = lerpf(rotor_audio.volume_db, clampf(base_db, -80.0, 4.0), 1.0 - exp(-8.0 * delta))

func _trigger_dash(input_data: Dictionary) -> void:
	is_dashing = true
	dash_timer = GameConstants.DASH_DURATION
	dash_cooldown_timer = maxf(0.8, GameConstants.DASH_BASE_COOLDOWN - dash_cooldown_reduction)
	update_invulnerability_state()
	
	var thrust = input_data.get("thrust", 0.0)
	var strafe = input_data.get("strafe", 0.0)
	var dir = (-global_transform.basis.z.normalized() * thrust + global_transform.basis.x.normalized() * strafe)
	if dir.length_squared() < 0.1:
		dir = -global_transform.basis.z.normalized()
	dash_direction = dir.normalized()

# ------------------------------------------------------------------------------
# 2. FUEL & STARVATION (Page 8)
# ------------------------------------------------------------------------------
var _low_fuel_warned: bool = false

func _process_fuel(delta: float) -> void:
	if current_fuel > 0.0:
		current_fuel = maxf(0.0, current_fuel - fuel_drain_rate * delta)
		_emit_event_bus_player_fuel_changed(current_fuel, max_fuel)
		var fuel_ratio := current_fuel / maxf(max_fuel, 1.0)
		if fuel_ratio <= 0.20 and not _low_fuel_warned:
			_low_fuel_warned = true
			if has_node("/root/AudioManager"):
				get_node("/root/AudioManager").trigger_alarm("low_fuel")
		elif fuel_ratio > 0.25:
			_low_fuel_warned = false
	else:
		# Fuel Starvation repeated damage
		fuel_starvation_timer += delta
		if fuel_starvation_timer >= GameConstants.FUEL_STARVATION_DAMAGE_INTERVAL:
			fuel_starvation_timer = 0.0
			take_damage(GameConstants.FUEL_STARVATION_DAMAGE_AMOUNT, "Fuel Starvation")

# ------------------------------------------------------------------------------
# 3. DAMAGE, REPAIR & SUBSYSTEMS (Page 8)
# ------------------------------------------------------------------------------
func take_damage(amount_or_data: Variant, source: String = "Enemy", hit_origin: Variant = null) -> void:
	if has_protection():
		return
	if is_dying or current_hull <= 0.0:
		return

	var amount: float = 0.0
	if amount_or_data is float or amount_or_data is int:
		amount = float(amount_or_data)
	elif amount_or_data != null and ("raw_damage" in amount_or_data or amount_or_data.get("raw_damage") != null):
		amount = float(amount_or_data.raw_damage)
		if "attacker" in amount_or_data and is_instance_valid(amount_or_data.attacker):
			source = str(amount_or_data.attacker.name)
			if amount_or_data.attacker is Node3D and amount_or_data.attacker.is_inside_tree():
				hit_origin = amount_or_data.attacker.global_position
		else:
			source = "Enemy Projectile"
		if hit_origin == null and "has_source_position" in amount_or_data and amount_or_data.has_source_position:
			hit_origin = amount_or_data.source_position
	elif amount_or_data != null and "damage" in amount_or_data:
		amount = float(amount_or_data.damage)
		source = "Enemy Projectile"
	else:
		amount = 15.0

	if amount <= 0.0:
		return
	if source in ["Building Crash", "Ground Impact", "Ground Crash"]:
		amount *= 1.0 - collision_resistance
	elif evasion_chance > 0.0 and randf() < evasion_chance:
		return
	# Apply capped mitigation
	var effective_damage = amount * (1.0 - clampf(armor_mitigation, 0.0, GameConstants.MAX_ARMOR_MITIGATION))
	var absorbed_damage := 0.0
	if shield_timer > 0.0 and shield_capacity > 0.0:
		var absorbed := minf(shield_capacity, effective_damage)
		absorbed_damage = absorbed
		shield_capacity -= absorbed
		effective_damage -= absorbed
		if shield_capacity <= 0.0:
			shield_timer = 0.0
		update_invulnerability_state()
	if effective_damage <= 0.0:
		if absorbed_damage > 0.0 and has_node("/root/InputManager"):
			get_node("/root/InputManager").play_damage_rumble(absorbed_damage * 0.5)
		return
	# Flat plating applies only to identified non-explosive enemy small arms.
	if amount_or_data is RefCounted and "blast_radius" in amount_or_data and "weapon_type" in amount_or_data:
		if amount <= 18.0 and amount_or_data.blast_radius <= 0.0 and amount_or_data.weapon_type == GameConstants.WeaponType.MACHINE_GUN:
			effective_damage = maxf(effective_damage * 0.10, effective_damage - small_arms_armor)

	var prev_hull: float = current_hull
	if source not in ["Building Crash", "Ground Impact", "Ground Crash", "Fuel Starvation"]:
		var was_armed: bool = mortal_protection.armed
		effective_damage = mortal_protection.limit_damage(effective_damage, current_hull, max_hull)
		if was_armed and not mortal_protection.armed:
			mortal_alarm_timer = 2.0
			update_invulnerability_state()
			if has_node("/root/AudioManager"):
				get_node("/root/AudioManager").play_sfx("alarm")
	if effective_damage <= 0.0:
		return
	current_hull = maxf(0.0, current_hull - effective_damage)
	var accepted_damage: float = prev_hull - current_hull
	if source != "Fuel Starvation" and has_node("/root/InputManager"):
		get_node("/root/InputManager").play_damage_rumble(accepted_damage + absorbed_damage * 0.5)
	
	# Subsystem Damage roll (40% chance to hit engine or rotor) if alive
	if current_hull > 0.0 and randf() < GameConstants.SUBSYSTEM_DAMAGE_CHANCE:
		var hit_engine = randf() < 0.5
		if hit_engine:
			engine_condition = maxf(0.0, engine_condition - randf_range(8.0, 18.0))
		else:
			rotor_condition = maxf(0.0, rotor_condition - randf_range(8.0, 18.0))

	# Record bounded telemetry
	if damage_history.size() >= MAX_DAMAGE_HISTORY:
		damage_history.pop_front()
	damage_history.append({
		"time": flight_time,
		"source": source,
		"incoming": amount,
		"accepted": accepted_damage,
		"hull_before": prev_hull,
		"hull_after": current_hull,
		"armor": armor_mitigation,
		"mitigated": effective_damage < amount
	})

	_emit_event_bus_player_damaged(current_hull, max_hull, accepted_damage, hit_origin, source)

	if current_hull <= 0.0:
		_die(source)

func repair(amount: float) -> void:
	if is_dying or current_hull <= 0.0:
		return # Cannot repair dead airframe
	current_hull = minf(max_hull, current_hull + amount)
	engine_condition = minf(100.0, engine_condition + amount * 0.5)
	rotor_condition = minf(100.0, rotor_condition + amount * 0.5)
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").player_healed.emit(current_hull, max_hull)

func refill_fuel(amount: float) -> void:
	current_fuel = minf(max_fuel, current_fuel + amount)
	_emit_event_bus_player_fuel_changed(current_fuel, max_fuel)

func activate_spawn_grace(duration: float = 2.0) -> void:
	spawn_grace_timer = maxf(spawn_grace_timer, duration)
	update_invulnerability_state()

func activate_shield(duration: float = 8.0) -> void:
	shield_timer = maxf(shield_timer, duration + shield_duration_bonus)
	shield_capacity = shield_capacity_bonus
	update_invulnerability_state()
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("super_activate")

func activate_speed_boost(duration: float = 6.0, multiplier: float = 1.45) -> void:
	speed_boost_timer = maxf(speed_boost_timer, duration)
	speed_boost_multiplier = multiplier
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("ui_click")

func activate_overdrive(duration: float = 8.0) -> void:
	if has_node("Weapons"):
		get_node("Weapons").activate_overdrive(duration)
	if has_node("Super"):
		get_node("Super").add_charge(100.0)
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("super_activate")

func _die(cause: String, immediate: bool = false) -> void:
	if is_dying:
		return # Idempotent - death settlement once
	current_hull = 0.0
	death_cause = cause
	if immediate:
		is_dying = true
		update_invulnerability_state()
		if has_node("/root/EventBus"):
			get_node("/root/EventBus").player_died.emit(cause)
	else:
		_start_death_sequence(cause)

func _start_death_sequence(cause: String) -> void:
	is_dying = true
	update_invulnerability_state()
	death_cause = cause
	death_timer = 0.0
	death_smoke_timer = 0.0
	death_impact_occurred = false

	# Initial randomized death spin & attitude limits
	death_spiral_yaw_speed = randf_range(11.0, 16.0) * (1.0 if randf() > 0.5 else -1.0)
	death_spiral_pitch_target = deg_to_rad(randf_range(-35.0, -55.0))
	death_spiral_roll_target = deg_to_rad(randf_range(40.0, 70.0) * (1.0 if randf() > 0.5 else -1.0))

	# Audio alarms & initial fireball from fuselage
	if has_node("/root/AudioManager"):
		var am = get_node("/root/AudioManager")
		am.play_sfx("alarm")

	var fx = get_node_or_null("/root/FXManager")
	if fx and fx.has_method("play_destruction"):
		fx.play_destruction(self, global_position + Vector3(0.0, 0.5, 0.0), Vector3.UP, false, "drone")
	elif fx and fx.has_method("spawn_explosion"):
		fx.spawn_explosion(global_position + Vector3(0.0, 0.5, 0.0), 1.0)

	# Initial camera shudder
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(0.65)

func _process_death_sequence(delta: float) -> void:
	death_timer += delta
	death_smoke_timer += delta

	if death_impact_occurred:
		# Brief dramatic beat post-impact to view crash site
		if death_timer >= 0.85:
			is_dying = false
			if has_node("/root/EventBus"):
				get_node("/root/EventBus").player_died.emit(death_cause)
		return

	# Trail dark segmented smoke puffs
	if death_smoke_timer >= 0.12:
		death_smoke_timer = 0.0
		var fx = get_node_or_null("/root/FXManager")
		if fx and "fragment_trail_emitter" in fx and fx.fragment_trail_emitter:
			var jitter = Vector3(randf_range(-0.3, 0.3), randf_range(-0.1, 0.2), randf_range(-0.3, 0.3))
			fx.fragment_trail_emitter.spawn_smoke_puff(global_position + jitter, 0.65, 1.2)

	# Rotor sputtering slowdown
	if main_rotor:
		var sputter_rpm = maxf(2.0, 24.0 * (1.0 - death_timer / 1.5))
		main_rotor.rotate_y(delta * sputter_rpm)
	_update_helicopter_audio(delta)

	# Uncontrolled yaw death spin
	rotate_y(death_spiral_yaw_speed * delta)

	# Severe attitude pitch/roll tumbling
	if visual_hull:
		visual_hull.rotation.x = lerp_angle(visual_hull.rotation.x, death_spiral_pitch_target, 4.0 * delta)
		visual_hull.rotation.z = lerp_angle(visual_hull.rotation.z, death_spiral_roll_target, 4.0 * delta)

	# Downward gravity pulling out of sky
	velocity.y -= 25.0 * delta
	velocity.x *= 0.97
	velocity.z *= 0.97

	move_and_slide()

	# Impact triggers if hitting ground, buildings, or after 1.6s
	var has_collided: bool = is_on_floor() or get_slide_collision_count() > 0
	var at_ground: bool = global_position.y <= 1.2
	var max_time: bool = death_timer >= 1.6

	if has_collided or at_ground or max_time:
		var contact_pos: Vector3 = global_position
		var normal: Vector3 = Vector3.UP
		var is_surface: bool = false

		if get_slide_collision_count() > 0:
			var col = get_slide_collision(0)
			contact_pos = col.get_position()
			normal = col.get_normal()
			is_surface = true
		elif at_ground or is_on_floor():
			contact_pos = Vector3(global_position.x, 0.0, global_position.z)
			normal = get_floor_normal() if is_on_floor() else Vector3.UP
			is_surface = true
		elif max_time:
			# Timeout: check bounded surface query below before claiming airborne breakup
			var space_state = get_world_3d().direct_space_state if is_inside_tree() and get_world_3d() else null
			if space_state:
				var ray_query = PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * 3.5, 2)
				var hit = space_state.intersect_ray(ray_query)
				if not hit.is_empty():
					contact_pos = hit.position
					normal = hit.normal
					is_surface = true
				else:
					is_surface = false # True mid-air disintegration
			else:
				is_surface = false

		_on_death_impact(contact_pos, normal, is_surface)

func _on_death_impact(contact_pos: Vector3, contact_normal: Vector3 = Vector3.UP, is_surface: bool = true) -> void:
	death_impact_occurred = true
	death_timer = 0.0
	velocity = Vector3.ZERO
	if rotor_audio and is_instance_valid(rotor_audio):
		rotor_audio.stop()

	# Hide intact airframe to represent disintegration into wreckage
	if visual_hull:
		visual_hull.visible = false

	# Signature catastrophic ground / airborne destruction
	var fx = get_node_or_null("/root/FXManager")
	if fx and fx.has_method("play_destruction"):
		fx.play_destruction(self, contact_pos, contact_normal, is_surface, "player")
		if is_surface and fx.has_method("spawn_airframe_wreckage"):
			fx.spawn_airframe_wreckage(contact_pos)
	elif fx and fx.has_method("spawn_explosion"):
		fx.spawn_explosion(contact_pos, 2.6)

	# Heavy audio detonation sting
	if has_node("/root/AudioManager"):
		var am = get_node("/root/AudioManager")
		am.play_sfx("defeat_sound")

	# Heavy camera impact trauma
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(1.0)

# ------------------------------------------------------------------------------
# EventBus Safe Emitters
# ------------------------------------------------------------------------------
func _emit_event_bus_player_damaged(p_curr: float, p_max: float, p_dmg: float, hit_origin: Variant = null, source_label: String = "") -> void:
	if p_dmg > 0.0 and is_inside_tree() and has_node("/root/EventBus"):
		var bus = get_node("/root/EventBus")
		bus.player_damaged.emit(p_curr, p_max, p_dmg)
		var has_direction: bool = hit_origin is Vector3 and hit_origin.is_finite()
		bus.player_hit.emit(p_dmg, hit_origin if has_direction else Vector3.ZERO, has_direction, source_label)

func _emit_event_bus_player_fuel_changed(p_curr: float, p_max: float) -> void:
	if is_inside_tree() and has_node("/root/EventBus"):
		get_node("/root/EventBus").player_fuel_changed.emit(p_curr, p_max)
