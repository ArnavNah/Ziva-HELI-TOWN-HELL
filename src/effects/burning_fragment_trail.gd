class_name BurningFragmentTrail
extends Node3D

## BurningFragmentTrail — Pooled kinematic fragment trajectories and world-space segmented smoke trails.
## Strictly matches the primary destruction reference (YouTube: @Smitty_Games, "RTS Nav Routes", 29-31s):
## - Bright pale-hot glowing tips traveling on ballistic downward-bending arcs.
## - Dark irregular segmented smoke puffs emitted by world-distance intervals (not frame rate).
## - Puffs stay fixed in world space, gently expand, drift, and fade out.
## - MultiMesh renders all 256 world puffs in a single batched draw call.
## - Zero garbage collection, clamped delta protection against hitches, pause-safe.

const MAX_FRAGMENT_HEADS: int = 48
const MAX_SMOKE_PUFFS: int = 144

var fragment_heads: Array[Dictionary] = []
var smoke_puffs: Array[Dictionary] = []

var multimesh_inst: MultiMeshInstance3D
var multimesh: MultiMesh
var head_parent: Node3D

var _puff_cursor: int = 0
var _tip_material: StandardMaterial3D
var _puff_material: StandardMaterial3D
var cosmetic_rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	cosmetic_rng.randomize()
	_setup_materials()
	_setup_multimesh()
	_setup_heads()

func _setup_materials() -> void:
	# 1. Hot tip material: Bright pale-yellow core with orange emission
	_tip_material = StandardMaterial3D.new()
	_tip_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tip_material.albedo_color = Color(1.0, 0.92, 0.65) # #FFE6A3
	_tip_material.emission_enabled = true
	_tip_material.emission = Color(1.0, 0.55, 0.15)
	_tip_material.emission_energy_multiplier = 2.5
	_tip_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	# 2. Segmented smoke material: Dark charcoal with vertex color alpha fade
	_puff_material = StandardMaterial3D.new()
	_puff_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_puff_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_puff_material.vertex_color_use_as_albedo = true
	_puff_material.albedo_color = Color(0.14, 0.15, 0.17, 1.0)
	_puff_material.cull_mode = BaseMaterial3D.CULL_BACK

func _setup_multimesh() -> void:
	multimesh_inst = MultiMeshInstance3D.new()
	multimesh_inst.name = "SegmentedSmokeMultiMesh"
	multimesh_inst.top_level = true # Renders in world coordinates
	multimesh_inst.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	multimesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(multimesh_inst)

	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.instance_count = MAX_SMOKE_PUFFS

	# Chunky low-poly puff mesh
	var sphere = SphereMesh.new()
	sphere.radial_segments = 5
	sphere.rings = 3
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.material = _puff_material
	multimesh.mesh = sphere
	multimesh_inst.multimesh = multimesh

	# Initialize puff slots
	smoke_puffs.clear()
	for i in range(MAX_SMOKE_PUFFS):
		multimesh.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0, -9999, 0)))
		multimesh.set_instance_color(i, Color(0, 0, 0, 0))
		smoke_puffs.append({
			"active": false,
			"pos": Vector3.ZERO,
			"vel": Vector3.ZERO,
			"age": 0.0,
			"lifetime": 1.0,
			"init_size": 0.4,
			"max_size": 0.8,
			"rot_axis": Vector3.UP,
			"rot_angle": 0.0
		})

func _setup_heads() -> void:
	head_parent = Node3D.new()
	head_parent.name = "FragmentHeadPool"
	head_parent.top_level = true
	head_parent.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(head_parent)

	fragment_heads.clear()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(0.16, 0.16, 0.26)
	box_mesh.material = _tip_material

	for i in range(MAX_FRAGMENT_HEADS):
		var mesh_inst = MeshInstance3D.new()
		mesh_inst.name = "HeadMesh_%d" % i
		mesh_inst.mesh = box_mesh
		mesh_inst.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh_inst.visible = false
		head_parent.add_child(mesh_inst)

		fragment_heads.append({
			"active": false,
			"pos": Vector3.ZERO,
			"vel": Vector3.ZERO,
			"gravity": 18.0,
			"age": 0.0,
			"lifetime": 0.6,
			"dist_since_puff": 0.0,
			"puff_spacing": 0.28,
			"puff_size": 0.5,
			"puff_lifetime": 1.1,
			"mesh": mesh_inst
		})

func launch_fragments(
	origin: Vector3,
	base_vel: Vector3,
	count: int,
	speed_min: float,
	speed_max: float,
	gravity: float,
	lifetime: float,
	puff_spacing: float,
	puff_size: float,
	puff_lifetime: float
) -> void:
	var spawned: int = 0
	# Seeded irregular angular scatter (not a flat circle or symmetric wheel)
	var angle_step = TAU / float(maxi(count, 1))

	for i in range(count):
		var head = _acquire_free_head()
		if not head:
			break

		var phi = float(i) * angle_step + cosmetic_rng.randf_range(-0.35, 0.35)
		var elevation = cosmetic_rng.randf_range(deg_to_rad(20.0), deg_to_rad(75.0))
		var dir = Vector3(
			cos(phi) * cos(elevation),
			sin(elevation),
			sin(phi) * cos(elevation)
		).normalized()

		var spd = cosmetic_rng.randf_range(speed_min, speed_max)
		# Inherit fraction of source vehicle velocity
		var launch_vel = dir * spd + base_vel * 0.25

		head.active = true
		head.pos = origin + dir * cosmetic_rng.randf_range(0.1, 0.4)
		head.vel = launch_vel
		head.gravity = gravity
		head.age = 0.0
		head.lifetime = lifetime * cosmetic_rng.randf_range(0.85, 1.15)
		head.dist_since_puff = 0.0
		head.puff_spacing = puff_spacing
		head.puff_size = puff_size
		head.puff_lifetime = puff_lifetime

		var m: MeshInstance3D = head.mesh
		m.global_position = head.pos
		m.visible = true
		spawned += 1

func spawn_smoke_puff(pos: Vector3, size: float, lifetime: float, drift: Vector3 = Vector3.ZERO) -> void:
	var idx = _puff_cursor
	_puff_cursor = (_puff_cursor + 1) % MAX_SMOKE_PUFFS

	var p = smoke_puffs[idx]
	p.active = true
	p.pos = pos
	p.vel = drift + Vector3(cosmetic_rng.randf_range(-0.4, 0.4), cosmetic_rng.randf_range(0.3, 0.9), cosmetic_rng.randf_range(-0.4, 0.4))
	p.age = 0.0
	p.lifetime = lifetime * cosmetic_rng.randf_range(0.85, 1.15)
	p.init_size = size * 0.70
	p.max_size = size * 1.55
	p.rot_axis = Vector3(cosmetic_rng.randf_range(-1, 1), cosmetic_rng.randf_range(-1, 1), cosmetic_rng.randf_range(-1, 1)).normalized()
	p.rot_angle = cosmetic_rng.randf_range(0, TAU)

	# Initial instance transform
	var b = Basis(p.rot_axis, p.rot_angle).scaled(Vector3.ONE * p.init_size)
	multimesh.set_instance_transform(idx, Transform3D(b, pos))
	multimesh.set_instance_color(idx, Color(0.14, 0.15, 0.17, 0.85))

func _acquire_free_head() -> Dictionary:
	for h in fragment_heads:
		if not h.active:
			return h
	return {}

func _process(delta: float) -> void:
	# Synchronize tip glow with Reduce Flashes setting
	if has_node("/root/AudioManager"):
		var reduce_flashes: bool = get_node("/root/AudioManager").reduce_flashes
		if _tip_material:
			_tip_material.emission_energy_multiplier = 0.875 if reduce_flashes else 2.5

	var dt = minf(delta, 0.2) # Hard cap against freeze/hitch spiral of death

	# 1. Update fragment heads
	var space = get_world_3d().direct_space_state if is_inside_tree() and get_world_3d() else null

	for h in fragment_heads:
		if not h.active:
			continue

		h.age += dt
		if h.age >= h.lifetime:
			h.active = false
			(h.mesh as MeshInstance3D).visible = false
			continue

		# Ballistic physics
		h.vel.y -= h.gravity * dt
		h.vel *= pow(0.985, dt * 60.0) # Air resistance

		var step = h.vel * dt
		var step_len = step.length()

		# Ground collision check for visual fragments (fast, zero physics lockup)
		if h.pos.y <= 0.40:
			h.pos.y = 0.40
			h.active = false
			(h.mesh as MeshInstance3D).visible = false
			spawn_smoke_puff(h.pos, h.puff_size * 0.8, h.puff_lifetime * 0.8)
			continue

		h.pos += step
		h.dist_since_puff += step_len

		var m: MeshInstance3D = h.mesh
		m.global_position = h.pos
		if step_len > 0.05:
			m.look_at_from_position(h.pos, h.pos + h.vel.normalized(), Vector3.UP)

		# Distance-based smoke emission in world space (max 4 per step to limit workload)
		var emitted: int = 0
		while h.dist_since_puff >= h.puff_spacing and emitted < 4:
			h.dist_since_puff -= h.puff_spacing
			emitted += 1
			var t = clampf(h.dist_since_puff / maxf(step_len, 0.001), 0.0, 1.0)
			var puff_pos = h.pos - step * t
			spawn_smoke_puff(puff_pos, h.puff_size, h.puff_lifetime)

		if h.dist_since_puff > h.puff_spacing:
			h.dist_since_puff = fmod(h.dist_since_puff, h.puff_spacing)

	# 2. Update MultiMesh smoke puffs
	for i in range(MAX_SMOKE_PUFFS):
		var p = smoke_puffs[i]
		if not p.active:
			continue

		p.age += dt
		var norm_age = p.age / maxf(p.lifetime, 0.001)
		if norm_age >= 1.0:
			p.active = false
			multimesh.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0, -9999, 0)))
			multimesh.set_instance_color(i, Color(0, 0, 0, 0))
			continue

		# Drift and expand
		p.pos += p.vel * dt
		p.vel *= pow(0.96, dt * 60.0)
		p.rot_angle += dt * 0.5

		var cur_size = lerpf(p.init_size, p.max_size, ease(norm_age, 0.35))
		var alpha = (1.0 - norm_age) * 0.82

		var b = Basis(p.rot_axis, p.rot_angle).scaled(Vector3.ONE * cur_size)
		multimesh.set_instance_transform(i, Transform3D(b, p.pos))
		multimesh.set_instance_color(i, Color(0.14, 0.15, 0.17, alpha))

func clear_all() -> void:
	_puff_cursor = 0
	for h in fragment_heads:
		h.active = false
		if is_instance_valid(h.mesh):
			(h.mesh as MeshInstance3D).visible = false

	for i in range(MAX_SMOKE_PUFFS):
		var p = smoke_puffs[i]
		p.active = false
		if multimesh:
			multimesh.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0, -9999, 0)))
			multimesh.set_instance_color(i, Color(0, 0, 0, 0))
