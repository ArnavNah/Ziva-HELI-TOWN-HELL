class_name SurfaceLightPatch
extends Node3D

## SurfaceLightPatch — Flat, conforming additive fake-light patch projected onto
## nearby ground, roads, or building walls via raycast normal alignment.
## Does NOT billboard away from the surface; uses a small 0.03m normal offset to avoid z-fighting.
## Inspired by @Smitty_Games "Game Dev Hack about Lights".

const ShaderRes = preload("res://src/shaders/weapon_fake_light.gdshader")

var active: bool = false
var elapsed: float = 0.0
var duration: float = 0.10
var initial_intensity: float = 1.8

var patch_mesh: MeshInstance3D
var patch_mat: ShaderMaterial

func _init() -> void:
	_build_patch()

func _ready() -> void:
	set_process(active)

func _build_patch() -> void:
	var q_mesh = QuadMesh.new()
	q_mesh.size = Vector2(1.0, 1.0)

	patch_mesh = MeshInstance3D.new()
	patch_mesh.mesh = q_mesh
	patch_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	patch_mesh.rotation_degrees = Vector3(-90.0, 0.0, 0.0) # Flat on local XZ plane

	patch_mat = ShaderMaterial.new()
	patch_mat.shader = ShaderRes
	patch_mat.set_shader_parameter("shape_type", 3) # Surface patch disc
	patch_mat.set_shader_parameter("falloff_exponent", 2.2)
	patch_mesh.material_override = patch_mat
	add_child(patch_mesh)

	visible = false

## Attempts to project a patch onto a nearby surface within max_dist. Returns true if placed.
func project_from_point(
	space_state: PhysicsDirectSpaceState3D,
	origin_point: Vector3,
	cast_direction: Vector3,
	color: Color,
	radius: float,
	patch_duration: float,
	max_dist: float = 5.0
) -> bool:
	if not space_state:
		return false

	var ray_query = PhysicsRayQueryParameters3D.create(origin_point, origin_point + cast_direction.normalized() * max_dist, 2)
	var hit = space_state.intersect_ray(ray_query)
	if hit.is_empty():
		return false

	var hit_pos: Vector3 = hit.get("position", origin_point)
	var hit_norm: Vector3 = hit.get("normal", Vector3.UP)

	activate_at_surface(hit_pos, hit_norm, color, radius, patch_duration)
	return true

func activate_at_surface(
	surface_pos: Vector3,
	surface_normal: Vector3,
	color: Color,
	radius: float,
	patch_duration: float
) -> void:
	active = true
	set_process(true)
	elapsed = 0.0
	visible = true

	# Respect Reduce Flashes
	var reduce_flashes: bool = false
	if has_node("/root/AudioManager"):
		reduce_flashes = get_node("/root/AudioManager").reduce_flashes

	var intensity_mult: float = 0.45 if reduce_flashes else 1.0
	duration = patch_duration * (0.85 if reduce_flashes else 1.0)
	initial_intensity = 1.6 * intensity_mult

	# Offset slightly along normal to prevent z-fighting with asphalt / brick
	var normal = surface_normal.normalized()
	global_position = surface_pos + normal * 0.03

	# Orient flat against surface normal (local +Y aligned with normal)
	var up_ref = Vector3.FORWARD if absf(normal.dot(Vector3.UP)) > 0.95 else Vector3.UP
	var tangent = normal.cross(up_ref).normalized()
	var bitangent = normal.cross(tangent).normalized()
	global_transform.basis = Basis(tangent, normal, bitangent)

	# Scale quad radius
	var d = radius * 2.0 * (0.85 if reduce_flashes else 1.0)
	patch_mesh.scale = Vector3(d, d, 1.0)

	patch_mat.set_shader_parameter("tint_color", color)
	patch_mat.set_shader_parameter("intensity", initial_intensity)
	patch_mat.set_shader_parameter("shape_type", 3)
	patch_mat.set_shader_parameter("falloff_exponent", 2.0)

func _process(delta: float) -> void:
	if not active:
		return

	elapsed += delta
	if elapsed >= duration:
		deactivate()
		return

	var life_rem: float = clampf(1.0 - (elapsed / maxf(duration, 0.001)), 0.0, 1.0)
	var fade_alpha = pow(life_rem, 1.4)
	patch_mat.set_shader_parameter("intensity", initial_intensity * fade_alpha)

func deactivate() -> void:
	active = false
	set_process(false)
	visible = false
