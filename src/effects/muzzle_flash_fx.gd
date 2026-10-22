class_name MuzzleFlashFX
extends Node3D

## MuzzleFlashFX — Pooled crossed-quad fake-light muzzle burst.
## Aligns with shot direction and barrel orientation without bloom dependency.
## Automatically pauses with the game tree when placed under a pausable root.

const ShaderRes = preload("res://src/shaders/weapon_fake_light.gdshader")

var active: bool = false
var elapsed: float = 0.0
var duration: float = 0.05
var source_node: Node = null
var initial_transform: Transform3D = Transform3D.IDENTITY
var local_to_source: Transform3D = Transform3D.IDENTITY
var has_source: bool = false

var quad_h: MeshInstance3D
var quad_v: MeshInstance3D
var quad_front: MeshInstance3D

var mat_h: ShaderMaterial
var mat_v: ShaderMaterial
var mat_front: ShaderMaterial

func _init() -> void:
	_build_geometry()

func _build_geometry() -> void:
	# Shared QuadMesh: 1.0m x 1.0m
	var q_mesh = QuadMesh.new()
	q_mesh.size = Vector2(1.0, 1.0)

	# 1. Horizontal axial quad (XZ plane)
	quad_h = MeshInstance3D.new()
	quad_h.mesh = q_mesh
	quad_h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	quad_h.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	mat_h = ShaderMaterial.new()
	mat_h.shader = ShaderRes
	quad_h.material_override = mat_h
	add_child(quad_h)

	# 2. Vertical axial quad (YZ plane)
	quad_v = MeshInstance3D.new()
	quad_v.mesh = q_mesh
	quad_v.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	quad_v.rotation_degrees = Vector3(90.0, 90.0, 0.0)
	mat_v = ShaderMaterial.new()
	mat_v.shader = ShaderRes
	quad_v.material_override = mat_v
	add_child(quad_v)

	# 3. Transverse frontal flare quad (XY plane)
	quad_front = MeshInstance3D.new()
	quad_front.mesh = q_mesh
	quad_front.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mat_front = ShaderMaterial.new()
	mat_front.shader = ShaderRes
	quad_front.material_override = mat_front
	add_child(quad_front)

	visible = false

func activate(
	profile: RefCounted,
	muzzle_tf: Transform3D,
	p_source: Node = null,
	shot_direction: Vector3 = Vector3.ZERO,
	scale_mult: float = 1.0
) -> void:
	active = true
	elapsed = 0.0
	visible = true

	# Respect Reduce Flashes preference
	var reduce_flashes: bool = false
	if has_node("/root/AudioManager"):
		reduce_flashes = get_node("/root/AudioManager").reduce_flashes

	var intensity_mult: float = 0.40 if reduce_flashes else 1.0
	duration = profile.muzzle_duration * (0.80 if reduce_flashes else 1.0)

	# Orient to muzzle transform and shot direction
	global_transform = muzzle_tf
	if shot_direction.length_squared() > 0.01:
		var dir = shot_direction.normalized()
		if absf(dir.dot(Vector3.UP)) < 0.98:
			look_at(global_position + dir, Vector3.UP)
		else:
			look_at(global_position + dir, Vector3.FORWARD)

	# Handle source tracking (e.g. helicopter chin turret moving during frame)
	source_node = p_source
	has_source = is_instance_valid(source_node) and source_node is Node3D
	if has_source:
		local_to_source = (source_node as Node3D).global_transform.affine_inverse() * global_transform
	initial_transform = global_transform

	# Dimensions
	var w: float = profile.muzzle_width * scale_mult * (0.85 if reduce_flashes else 1.0)
	var l: float = profile.muzzle_length * scale_mult

	# Scale axial quads (forward is -Z in Godot, length extends along Z)
	quad_h.scale = Vector3(w, l, 1.0)
	quad_h.position = Vector3(0.0, 0.0, -l * 0.45)

	quad_v.scale = Vector3(w, l, 1.0)
	quad_v.position = Vector3(0.0, 0.0, -l * 0.45)

	# Transverse front flare quad
	quad_front.scale = Vector3(w * 1.15, w * 1.15, 1.0)
	quad_front.position = Vector3(0.0, 0.0, -0.05)

	# Apply shader parameters
	var core_col: Color = profile.muzzle_core_color
	var edge_col: Color = profile.muzzle_edge_color

	mat_h.set_shader_parameter("tint_color", edge_col)
	mat_h.set_shader_parameter("intensity", profile.muzzle_intensity * intensity_mult)
	mat_h.set_shader_parameter("shape_type", profile.muzzle_shape)
	mat_h.set_shader_parameter("falloff_exponent", 2.2)

	mat_v.set_shader_parameter("tint_color", edge_col)
	mat_v.set_shader_parameter("intensity", profile.muzzle_intensity * intensity_mult)
	mat_v.set_shader_parameter("shape_type", profile.muzzle_shape)
	mat_v.set_shader_parameter("falloff_exponent", 2.2)

	mat_front.set_shader_parameter("tint_color", core_col)
	mat_front.set_shader_parameter("intensity", (profile.muzzle_intensity * 1.3) * intensity_mult)
	mat_front.set_shader_parameter("shape_type", 0) # Front star core
	mat_front.set_shader_parameter("core_radius", 0.32)
	mat_front.set_shader_parameter("falloff_exponent", 2.5)

func _process(delta: float) -> void:
	if not active:
		return

	elapsed += delta
	if elapsed >= duration:
		deactivate()
		return

	# Follow moving muzzle source if still alive
	if has_source:
		if is_instance_valid(source_node) and source_node is Node3D:
			global_transform = (source_node as Node3D).global_transform * local_to_source
		else:
			has_source = false

	# Linear decay over lifetime
	var life_rem: float = clampf(1.0 - (elapsed / maxf(duration, 0.001)), 0.0, 1.0)
	var fade_alpha = pow(life_rem, 1.5)

	mat_h.set_shader_parameter("intensity", 2.4 * fade_alpha)
	mat_v.set_shader_parameter("intensity", 2.4 * fade_alpha)
	mat_front.set_shader_parameter("intensity", 3.0 * fade_alpha)

func deactivate() -> void:
	active = false
	visible = false
	has_source = false
	source_node = null
