class_name ProjectileTrail
extends Node3D

## ProjectileTrail — Pooled rocket/missile motor exhaust and particle trail.
## Emits discrete exhaust puffs in world space (local_coords = false) behind the projectile.
## Bends smoothly during homing maneuvers and leaves no orphan beams on impact.
## Bounded pool of 32 instances.

const ShaderRes = preload("res://src/shaders/weapon_fake_light.gdshader")

var active: bool = false
var target_projectile: Node3D = null
var is_detaching: bool = false
var detach_timer: float = 0.0

var exhaust_flare: MeshInstance3D
var exhaust_mat: ShaderMaterial
var trail_particles: CPUParticles3D
var particle_mat: StandardMaterial3D

func _init() -> void:
	_build_trail_system()

func _ready() -> void:
	set_process(active)

func _build_trail_system() -> void:
	# 1. Rocket Motor Exhaust Flare (attached directly behind projectile)
	var q_mesh = QuadMesh.new()
	q_mesh.size = Vector2(0.35, 0.35)

	exhaust_flare = MeshInstance3D.new()
	exhaust_flare.mesh = q_mesh
	exhaust_flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	exhaust_mat = ShaderMaterial.new()
	exhaust_mat.shader = ShaderRes
	exhaust_mat.set_shader_parameter("shape_type", 0) # Radial star core
	exhaust_mat.set_shader_parameter("core_radius", 0.40)
	exhaust_mat.set_shader_parameter("falloff_exponent", 2.2)
	exhaust_flare.material_override = exhaust_mat
	add_child(exhaust_flare)

	# 2. World-Space Curving Exhaust Trail Particles
	trail_particles = CPUParticles3D.new()
	trail_particles.emitting = false
	trail_particles.one_shot = false
	trail_particles.local_coords = false # Particles remain stationary in world space as missile curves
	trail_particles.amount = 18
	trail_particles.lifetime = 0.28
	trail_particles.explosiveness = 0.0
	trail_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINT
	trail_particles.direction = Vector3.ZERO
	trail_particles.spread = 15.0
	trail_particles.initial_velocity_min = 0.0
	trail_particles.initial_velocity_max = 1.5
	trail_particles.gravity = Vector3.ZERO
	trail_particles.scale_amount_min = 0.14
	trail_particles.scale_amount_max = 0.42

	var p_mesh = BoxMesh.new()
	p_mesh.size = Vector3(0.12, 0.12, 0.12)
	particle_mat = StandardMaterial3D.new()
	particle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	particle_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particle_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	particle_mat.albedo_color = Color(1.0, 0.60, 0.18, 0.75)
	p_mesh.material = particle_mat
	trail_particles.mesh = p_mesh
	trail_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trail_particles)

	visible = false

func attach_to_projectile(proj: Node3D, profile: RefCounted) -> void:
	target_projectile = proj
	active = true
	set_process(true)
	is_detaching = false
	detach_timer = 0.0
	exhaust_flare.visible = true
	visible = true

	# Respect Reduce Flashes
	var reduce_flashes: bool = false
	if has_node("/root/AudioManager"):
		reduce_flashes = get_node("/root/AudioManager").reduce_flashes

	var col = profile.trail_color
	if reduce_flashes:
		col.a *= 0.5

	exhaust_mat.set_shader_parameter("tint_color", col)
	exhaust_mat.set_shader_parameter("intensity", 1.8 if reduce_flashes else 3.2)
	particle_mat.albedo_color = col

	trail_particles.lifetime = profile.trail_lifetime
	trail_particles.emitting = true
	trail_particles.restart()

	global_transform = proj.global_transform

func _process(delta: float) -> void:
	if not active:
		return

	if is_detaching:
		detach_timer -= delta
		if detach_timer <= 0.0:
			deactivate()
		return

	# Track moving projectile
	if is_instance_valid(target_projectile) and target_projectile.is_inside_tree():
		global_transform = target_projectile.global_transform
		# Position exhaust flare at missile nozzle (slightly behind center)
		exhaust_flare.position = Vector3(0, 0, 0.25)
	else:
		# Projectile was destroyed / impacted! Begin clean detachment fade
		detach_cleanly()

func detach_cleanly() -> void:
	if not active or is_detaching:
		return
	is_detaching = true
	detach_timer = 0.30
	target_projectile = null
	exhaust_flare.visible = false
	trail_particles.emitting = false

func deactivate() -> void:
	active = false
	set_process(false)
	is_detaching = false
	visible = false
	target_projectile = null
	trail_particles.emitting = false
	exhaust_flare.visible = true
