class_name WeatherSystem
extends Node3D

## WeatherSystem — Manages sun, fill-light, environment, storm/night modes,
## and smooth weather transitions with lightning strikes (Page 23).

@onready var dir_light: DirectionalLight3D = $DirectionalLight3D
@onready var fill_light: DirectionalLight3D = get_node_or_null("DirectionalLight3D_Fill")
@onready var world_env: WorldEnvironment = $WorldEnvironment

var is_storming: bool = false
var is_night: bool = false
var lightning_timer: float = 0.0
var _transition_tween: Tween
var grade_material: ShaderMaterial
const GRADE_SHADER = preload("res://src/shaders/battlefield_grade.gdshader")

# --- Presets for each weather state ----------------------------------------

const PRESET_DAY := {
	"sun_energy": 0.95,
	"sun_color": Color(1.0, 0.97, 0.88),
	"fill_energy": 0.22,
	"fill_color": Color(0.70, 0.82, 0.93),
	"ambient_energy": 0.48,
	"ambient_color": Color(0.72, 0.82, 0.90),
	"fog_density": 0.0004,
	"fog_depth_begin": 150.0,
	"fog_depth_end": 330.0,
	"fog_color": Color(0.68, 0.84, 0.98),
	"fog_light_energy": 0.25,
	"fog_height_density": 0.001,
	"glow_intensity": 0.10,
	"sky_top": Color(0.18, 0.52, 0.92),
	"sky_horizon": Color(0.68, 0.84, 0.98),
	"exposure": 1.0,
	"saturation": 0.96,
	"grade_lift": 0.018,
	"grade_warmth": 0.008,
}

const PRESET_STORM := {
	"sun_energy": 0.60,
	"sun_color": Color(0.70, 0.77, 0.83),
	"fill_energy": 0.08,
	"fill_color": Color(0.55, 0.62, 0.70),
	"ambient_energy": 0.48,
	"ambient_color": Color(0.60, 0.66, 0.73),
	"fog_density": 0.007,
	"fog_depth_begin": 65.0,
	"fog_depth_end": 175.0,
	"fog_color": Color(0.28, 0.32, 0.38),
	"fog_light_energy": 0.15,
	"fog_height_density": 0.04,
	"glow_intensity": 0.45,
	"sky_top": Color(0.12, 0.16, 0.22),
	"sky_horizon": Color(0.28, 0.32, 0.38),
	"exposure": 0.92,
	"saturation": 0.78,
	"grade_lift": 0.025,
	"grade_warmth": -0.006,
}

const PRESET_NIGHT := {
	"sun_energy": 0.48,
	"sun_color": Color(0.58, 0.66, 0.84), # Cold lunar key light
	"fill_energy": 0.12,
	"fill_color": Color(0.52, 0.60, 0.75),
	"ambient_energy": 0.55,
	"ambient_color": Color(0.58, 0.65, 0.82),
	"fog_density": 0.004,
	"fog_depth_begin": 85.0,
	"fog_depth_end": 210.0,
	"fog_color": Color(0.05, 0.08, 0.14),
	"fog_light_energy": 0.08,
	"fog_height_density": 0.02,
	"glow_intensity": 0.65,
	"sky_top": Color(0.02, 0.04, 0.08),
	"sky_horizon": Color(0.06, 0.09, 0.15),
	"exposure": 0.90,
	"saturation": 0.78,
	"grade_lift": 0.055,
	"grade_warmth": -0.015,
}

var rain_particles: CPUParticles3D

func _ready() -> void:
	_build_color_grade()
	_setup_rain_particles()
	_apply_preset(PRESET_DAY, 0.0)
	if is_inside_tree() and has_node("/root/EventBus"):
		get_node("/root/EventBus").wave_started.connect(_on_wave_started)

func _setup_rain_particles() -> void:
	rain_particles = CPUParticles3D.new()
	rain_particles.name = "RainParticles"
	rain_particles.emitting = false
	rain_particles.amount = 750
	rain_particles.lifetime = 1.0
	rain_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain_particles.emission_box_extents = Vector3(55.0, 18.0, 55.0)
	rain_particles.direction = Vector3(-0.35, -1.0, 0.15).normalized()
	rain_particles.spread = 4.0
	rain_particles.initial_velocity_min = 45.0
	rain_particles.initial_velocity_max = 55.0

	var r_mesh = BoxMesh.new()
	r_mesh.size = Vector3(0.035, 1.1, 0.035)
	var r_mat = StandardMaterial3D.new()
	r_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	r_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	r_mat.albedo_color = Color(0.72, 0.82, 0.95, 0.38)
	r_mesh.material = r_mat
	rain_particles.mesh = r_mesh
	add_child(rain_particles)

func _on_wave_started(_wave: int, theme: String, _duration: float) -> void:
	match theme:
		"Storm Surge":
			set_storm_mode(true)
			set_night_mode(false)
		"Night Surge":
			set_night_mode(true)
			set_storm_mode(false)
		_:
			set_storm_mode(false)
			set_night_mode(false)

func set_storm_mode(enabled: bool) -> void:
	is_storming = enabled
	if rain_particles:
		rain_particles.emitting = enabled
	if enabled:
		_apply_preset(PRESET_STORM, 2.0)
	elif not is_night:
		_apply_preset(PRESET_DAY, 2.5)

func set_night_mode(enabled: bool) -> void:
	is_night = enabled
	if enabled:
		_apply_preset(PRESET_NIGHT, 3.0)
	elif not is_storming:
		_apply_preset(PRESET_DAY, 2.5)

func _build_color_grade() -> void:
	# Layer 0 is above the 3D world and below the HUD's layer 1.
	var layer := CanvasLayer.new()
	layer.name = "BattlefieldGrade"
	layer.layer = 0
	add_child(layer)
	# The grade must read the preceding screen-resampling pass, not its old copy.
	var screen_copy := BackBufferCopy.new()
	screen_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	layer.add_child(screen_copy)
	var rect := ColorRect.new()
	rect.name = "GradeRect"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grade_material = ShaderMaterial.new()
	grade_material.shader = GRADE_SHADER
	grade_material.set_shader_parameter("saturation", PRESET_DAY["saturation"])
	grade_material.set_shader_parameter("shadow_lift", PRESET_DAY["grade_lift"])
	grade_material.set_shader_parameter("warmth", PRESET_DAY["grade_warmth"])
	rect.material = grade_material
	layer.add_child(rect)

# --- Smooth Preset Blending -----------------------------------------------

func _apply_preset(preset: Dictionary, duration: float) -> void:
	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)

	# Directional (sun) light
	if dir_light:
		_transition_tween.tween_property(dir_light, "light_energy", preset["sun_energy"], duration)
		_transition_tween.tween_property(dir_light, "light_color", preset["sun_color"], duration)

	# Fill light (sky bounce)
	if fill_light:
		_transition_tween.tween_property(fill_light, "light_energy", preset["fill_energy"], duration)
		_transition_tween.tween_property(fill_light, "light_color", preset["fill_color"], duration)

	# Environment
	var env := world_env.environment if world_env else null
	if env:
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_DEPTH
		if preset.has("fog_depth_begin"):
			_transition_tween.tween_property(env, "fog_depth_begin", preset["fog_depth_begin"], duration)
		if preset.has("fog_depth_end"):
			_transition_tween.tween_property(env, "fog_depth_end", preset["fog_depth_end"], duration)
		_transition_tween.tween_property(env, "ambient_light_energy", preset["ambient_energy"], duration)
		_transition_tween.tween_property(env, "ambient_light_color", preset["ambient_color"], duration)
		_transition_tween.tween_property(env, "fog_density", preset["fog_density"], duration)
		_transition_tween.tween_property(env, "fog_light_color", preset["fog_color"], duration)
		_transition_tween.tween_property(env, "fog_light_energy", preset["fog_light_energy"], duration)
		_transition_tween.tween_property(env, "fog_height_density", preset["fog_height_density"], duration)
		_transition_tween.tween_property(env, "glow_intensity", preset["glow_intensity"], duration)
		_transition_tween.tween_property(env, "tonemap_exposure", preset["exposure"], duration)
		# Built-in environment adjustments are unavailable in Compatibility.
		env.adjustment_enabled = false
	if grade_material:
		_transition_tween.tween_method(_set_grade_value.bind("saturation"), float(grade_material.get_shader_parameter("saturation")), float(preset["saturation"]), duration)
		_transition_tween.tween_method(_set_grade_value.bind("shadow_lift"), float(grade_material.get_shader_parameter("shadow_lift")), float(preset["grade_lift"]), duration)
		_transition_tween.tween_method(_set_grade_value.bind("warmth"), float(grade_material.get_shader_parameter("warmth")), float(preset["grade_warmth"]), duration)

	# Sky material
	var sky_mat = _get_sky_material()
	if sky_mat:
		_transition_tween.tween_property(sky_mat, "sky_top_color", preset["sky_top"], duration)
		_transition_tween.tween_property(sky_mat, "sky_horizon_color", preset["sky_horizon"], duration)

func _set_grade_value(value: float, parameter: String) -> void:
	grade_material.set_shader_parameter(parameter, value)

func _get_sky_material() -> ProceduralSkyMaterial:
	if not world_env or not world_env.environment:
		return null
	var sky = world_env.environment.sky
	if sky and sky.sky_material is ProceduralSkyMaterial:
		return sky.sky_material as ProceduralSkyMaterial
	return null

# --- Lightning Strikes During Storm ----------------------------------------

func _process(delta: float) -> void:
	if is_storming:
		if rain_particles and is_instance_valid(rain_particles):
			var cam = get_viewport().get_camera_3d() if get_viewport() else null
			if cam:
				rain_particles.global_position = cam.global_position + Vector3(10.0, 10.0, -4.0)
		if dir_light:
			lightning_timer -= delta
			if lightning_timer <= 0.0:
				lightning_timer = randf_range(4.0, 9.0)
				_flash_lightning()

func _flash_lightning() -> void:
	if not dir_light:
		return
	var env := world_env.environment if world_env else null

	# Store current values for restore
	var prev_sun_energy: float = dir_light.light_energy
	var prev_ambient: float = env.ambient_light_energy if env else 0.45
	var prev_glow: float = env.glow_intensity if env else 0.55

	# Flash peak
	dir_light.light_energy = 5.5
	dir_light.light_color = Color(0.85, 0.88, 1.0) # Cold blue-white flash
	if env:
		env.ambient_light_energy = 2.8
		env.glow_intensity = 1.8

	# Play rolling acoustic thunder with realistic propagation delay (0.12 - 0.35s)
	var delay = randf_range(0.12, 0.32)
	get_tree().create_timer(delay).timeout.connect(func():
		if is_inside_tree() and has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("thunder", randf_range(0.92, 1.08), 2.5)
	)

	# Rapid decay back to storm preset
	var flash_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	flash_tween.tween_property(dir_light, "light_energy", prev_sun_energy, 0.18)
	if env:
		flash_tween.tween_property(env, "ambient_light_energy", prev_ambient, 0.22)
		flash_tween.tween_property(env, "glow_intensity", prev_glow, 0.25)
	# Restore storm sun color after flash
	flash_tween.tween_property(dir_light, "light_color", PRESET_STORM["sun_color"], 0.12)
