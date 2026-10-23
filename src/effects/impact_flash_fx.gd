class_name ImpactFlashFX
extends Node3D

## ImpactFlashFX — Pooled surface-normal oriented impact burst.
## Combines an outward-pointing directional flash core with a surface contact disc.
## Bounded pool of 32 instances.

const ShaderRes = preload("res://src/shaders/weapon_fake_light.gdshader")

var active: bool = false
var elapsed: float = 0.0
var duration: float = 0.08
var initial_intensity: float = 2.6

var quad_surface: MeshInstance3D
var quad_axial1: MeshInstance3D
var quad_axial2: MeshInstance3D

var mat_surface: ShaderMaterial
var mat_axial1: ShaderMaterial
var mat_axial2: ShaderMaterial

func _init() -> void:
	_build_geometry()

func _ready() -> void:
	set_process(active)

func _build_geometry() -> void:
	var q_mesh = QuadMesh.new()
	q_mesh.size = Vector2(1.0, 1.0)

	# 1. Surface contact disc (flat along XY in local space, normal is +Z)
	quad_surface = MeshInstance3D.new()
	quad_surface.mesh = q_mesh
	quad_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mat_surface = ShaderMaterial.new()
	mat_surface.shader = ShaderRes
	mat_surface.set_shader_parameter("shape_type", 0)
	mat_surface.set_shader_parameter("core_radius", 0.28)
	quad_surface.material_override = mat_surface
	add_child(quad_surface)

	# 2. Outward axial crossed quad 1
	quad_axial1 = MeshInstance3D.new()
	quad_axial1.mesh = q_mesh
	quad_axial1.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	quad_axial1.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	mat_axial1 = ShaderMaterial.new()
	mat_axial1.shader = ShaderRes
	mat_axial1.set_shader_parameter("shape_type", 2) # Directional fan
	quad_axial1.material_override = mat_axial1
	add_child(quad_axial1)

	# 3. Outward axial crossed quad 2
	quad_axial2 = MeshInstance3D.new()
	quad_axial2.mesh = q_mesh
	quad_axial2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	quad_axial2.rotation_degrees = Vector3(90.0, 90.0, 0.0)
	mat_axial2 = ShaderMaterial.new()
	mat_axial2.shader = ShaderRes
	mat_axial2.set_shader_parameter("shape_type", 2)
	quad_axial2.material_override = mat_axial2
	add_child(quad_axial2)

	visible = false

func activate(
	hit_pos: Vector3,
	hit_normal: Vector3,
	color: Color,
	size_scale: float = 1.2,
	p_duration: float = 0.08
) -> void:
	active = true
	set_process(true)
	elapsed = 0.0
	visible = true

	# Respect Reduce Flashes
	var reduce_flashes: bool = false
	if has_node("/root/AudioManager"):
		reduce_flashes = get_node("/root/AudioManager").reduce_flashes

	var intensity_mult: float = 0.40 if reduce_flashes else 1.0
	duration = p_duration * (0.80 if reduce_flashes else 1.0)
	initial_intensity = 2.8 * intensity_mult

	# Position with slight normal offset
	var norm = hit_normal.normalized()
	if norm.length_squared() < 0.01:
		norm = Vector3.UP
	global_position = hit_pos + norm * 0.04

	# Orient +Z outward along hit normal
	var up_ref = Vector3.FORWARD if absf(norm.dot(Vector3.UP)) > 0.95 else Vector3.UP
	var tangent = norm.cross(up_ref).normalized()
	var bitangent = norm.cross(tangent).normalized()
	global_transform.basis = Basis(tangent, bitangent, norm)

	var s = size_scale * (0.85 if reduce_flashes else 1.0)

	# Surface disc scale
	quad_surface.scale = Vector3(s, s, 1.0)
	quad_surface.position = Vector3(0.0, 0.0, 0.01)

	# Outward axial burst extending away from surface along +Z
	var burst_len = s * 1.3
	quad_axial1.scale = Vector3(s * 0.8, burst_len, 1.0)
	quad_axial1.position = Vector3(0.0, 0.0, burst_len * 0.45)

	quad_axial2.scale = Vector3(s * 0.8, burst_len, 1.0)
	quad_axial2.position = Vector3(0.0, 0.0, burst_len * 0.45)

	mat_surface.set_shader_parameter("tint_color", color)
	mat_surface.set_shader_parameter("intensity", initial_intensity)
	mat_surface.set_shader_parameter("shape_type", 0)

	mat_axial1.set_shader_parameter("tint_color", color)
	mat_axial1.set_shader_parameter("intensity", initial_intensity * 0.9)
	mat_axial1.set_shader_parameter("shape_type", 2)

	mat_axial2.set_shader_parameter("tint_color", color)
	mat_axial2.set_shader_parameter("intensity", initial_intensity * 0.9)
	mat_axial2.set_shader_parameter("shape_type", 2)

func _process(delta: float) -> void:
	if not active:
		return

	elapsed += delta
	if elapsed >= duration:
		deactivate()
		return

	var life_rem: float = clampf(1.0 - (elapsed / maxf(duration, 0.001)), 0.0, 1.0)
	var fade_alpha = pow(life_rem, 1.6)

	mat_surface.set_shader_parameter("intensity", initial_intensity * fade_alpha)
	mat_axial1.set_shader_parameter("intensity", (initial_intensity * 0.9) * fade_alpha)
	mat_axial2.set_shader_parameter("intensity", (initial_intensity * 0.9) * fade_alpha)

func deactivate() -> void:
	active = false
	set_process(false)
	visible = false
