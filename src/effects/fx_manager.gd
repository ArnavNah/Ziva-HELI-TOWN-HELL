extends Node

## FXManager — Procedural visual effects engine for Heli-Town Hell.
## Spawns explosions, bullet sparks, flare bursts, building dust, smoke trails,
## and manages the high-performance pooled shooting presentation pass (muzzle flashes,
## surface fake-light patches, projectile exhaust trails, and real flash lights).
## Unshaded additive fake-light geometry keeps Megabonk chunky readability.
## Zero external textures, pause-safe execution, and strictly bounded memory pools.

static var instance: Node

const FloatingTextClass = preload("res://src/effects/floating_text.gd")
const WeaponFXProfileClass = preload("res://src/effects/weapon_fx_profile.gd")
const DestructionFXProfileClass = preload("res://src/effects/destruction_fx_profile.gd")
const BurningFragmentTrailClass = preload("res://src/effects/burning_fragment_trail.gd")
const FakeLightShader = preload("res://src/shaders/weapon_fake_light.gdshader")
const MuzzleFlashFXClass = preload("res://src/effects/muzzle_flash_fx.gd")
const ImpactFlashFXClass = preload("res://src/effects/impact_flash_fx.gd")
const SurfaceLightPatchClass = preload("res://src/effects/surface_light_patch.gd")
const ProjectileTrailClass = preload("res://src/effects/projectile_trail.gd")

class DestructionFlashMaterial extends ShaderMaterial:
	var albedo_texture: Texture2D = null

const KILL_COMPLIMENTS: Array[String] = [
	"NICE!",
	"SAVAGE!",
	"BRUTAL!",
	"HEADSHOT!",
	"OVERKILL!",
	"SICK!",
	"SMOKED!",
	"DESTROYED!",
	"BOOM!",
	"GODLIKE!",
	"PERFECT!",
	"ANNIHILATED!",
	"WRECKED!",
	"BULLSEYE!",
	"EXCELLENT!",
	"CLEAN KILL!",
	"MONSTER!"
]

var kill_streak_count: int = 0
var last_kill_time: float = 0.0
const KILL_STREAK_WINDOW: float = 2.4

# ------------------------------------------------------------------------------
# POOLED COMBAT PRESENTATION PASS (Budgets: 48 Muzzle, 32 Impact, 16 Patch, 32 Trail, 4 Light)
# ------------------------------------------------------------------------------
const MAX_MUZZLE_BURSTS: int = 48
const MAX_IMPACT_BURSTS: int = 32
const MAX_SURFACE_PATCHES: int = 16
const MAX_PROJECTILE_TRAILS: int = 32
const MAX_FLASH_LIGHTS: int = 4
const MAX_ORDINARY_EXPLOSIONS: int = 12
const MAX_SPARK_EMITTERS: int = 16

var muzzle_pool: Array = []
var impact_pool: Array = []
var patch_pool: Array = []
var trail_pool: Array = []
var flash_light_pool: Array[OmniLight3D] = []
var spark_pool: Array = []
var _spark_cursor: int = 0
var active_flash_lights: Array[Dictionary] = [] # { light, timer, duration, initial_energy, base_energy, priority, pos }
var active_composed_explosions: Array = []

var gameplay_fx_root: Node3D = null
var fragment_trail_emitter: BurningFragmentTrail = null

func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_gameplay_fx_pools()
	_connect_event_bus()

func _setup_gameplay_fx_pools() -> void:
	# Pausable root ensures gameplay visual effects freeze during pause
	gameplay_fx_root = Node3D.new()
	gameplay_fx_root.name = "GameplayFXRoot"
	gameplay_fx_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(gameplay_fx_root)

	# 1. Muzzle flashes (48 slots)
	for i in range(MAX_MUZZLE_BURSTS):
		var flash = MuzzleFlashFXClass.new()
		flash.name = "MuzzleFlash_%d" % i
		gameplay_fx_root.add_child(flash)
		muzzle_pool.append(flash)

	# 2. Impact flashes (32 slots)
	for i in range(MAX_IMPACT_BURSTS):
		var impact = ImpactFlashFXClass.new()
		impact.name = "ImpactFlash_%d" % i
		gameplay_fx_root.add_child(impact)
		impact_pool.append(impact)

	# 3. Surface fake-light patches (16 slots)
	for i in range(MAX_SURFACE_PATCHES):
		var patch = SurfaceLightPatchClass.new()
		patch.name = "SurfacePatch_%d" % i
		gameplay_fx_root.add_child(patch)
		patch_pool.append(patch)

	# 4. Projectile exhaust trails (32 slots)
	for i in range(MAX_PROJECTILE_TRAILS):
		var trail = ProjectileTrailClass.new()
		trail.name = "ProjectileTrail_%d" % i
		gameplay_fx_root.add_child(trail)
		trail_pool.append(trail)

	# 5. Shared real flash lights (4 bounded slots)
	for i in range(MAX_FLASH_LIGHTS):
		var light = OmniLight3D.new()
		light.name = "PooledFlashLight_%d" % i
		light.shadow_enabled = false
		light.omni_attenuation = 1.4
		light.visible = false
		light.light_energy = 0.0
		gameplay_fx_root.add_child(light)
		flash_light_pool.append(light)

	# 6. Burning fragment trajectories & segmented smoke trail pool
	fragment_trail_emitter = BurningFragmentTrailClass.new()
	fragment_trail_emitter.name = "BurningFragmentTrailEmitter"
	gameplay_fx_root.add_child(fragment_trail_emitter)

	# 7. Pooled impact spark particles (16 bounded slots, zero runtime node allocation)
	var spark_mesh = BoxMesh.new()
	spark_mesh.size = Vector3(0.12, 0.12, 0.3)
	var spark_mat = StandardMaterial3D.new()
	spark_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.albedo_color = Color(1.0, 0.9, 0.4, 1.0)
	spark_mesh.material = spark_mat

	for i in range(MAX_SPARK_EMITTERS):
		var sparks = CPUParticles3D.new()
		sparks.name = "ImpactSparks_%d" % i
		sparks.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		sparks.one_shot = true
		sparks.explosiveness = 0.98
		sparks.amount = 8
		sparks.lifetime = 0.25
		sparks.spread = 70.0
		sparks.initial_velocity_min = 14.0
		sparks.initial_velocity_max = 26.0
		sparks.gravity = Vector3(0, -25.0, 0)
		sparks.mesh = spark_mesh
		sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sparks.emitting = false
		gameplay_fx_root.add_child(sparks)
		spark_pool.append(sparks)

func _connect_event_bus() -> void:
	if has_node("/root/EventBus"):
		var bus = get_node("/root/EventBus")
		bus.entity_destroyed.connect(_on_entity_destroyed)
		bus.flares_deployed.connect(_on_flares_deployed)
		bus.damage_dealt.connect(_on_damage_dealt)
		if bus.has_signal("run_state_changed"):
			bus.run_state_changed.connect(_on_run_state_changed)

func _on_run_state_changed(new_state: int, _prev_state: int) -> void:
	# Clean combat effects when leaving active gameplay
	if new_state in [GameManager.RunState.MENU, GameManager.RunState.LOADING, GameManager.RunState.RESULTS]:
		clear_combat_effects()

func _process(delta: float) -> void:
	if get_tree().paused:
		return

	var reduce_flashes: bool = false
	if has_node("/root/AudioManager"):
		reduce_flashes = get_node("/root/AudioManager").reduce_flashes

	# Update active real flash lights
	var i = active_flash_lights.size() - 1
	while i >= 0:
		var entry = active_flash_lights[i]
		entry.timer += delta
		if entry.timer >= entry.duration:
			var light: OmniLight3D = entry.light
			if is_instance_valid(light):
				light.visible = false
				light.light_energy = 0.0
				flash_light_pool.append(light)
			active_flash_lights.remove_at(i)
		else:
			var light: OmniLight3D = entry.light
			if is_instance_valid(light):
				var cur_max_energy: float = entry.get("base_energy", entry.initial_energy) * (0.35 if reduce_flashes else 1.0)
				var life_rem = clampf(1.0 - (entry.timer / maxf(entry.duration, 0.001)), 0.0, 1.0)
				light.light_energy = cur_max_energy * pow(life_rem, 1.6)
		i -= 1

func get_profile(profile_id: String) -> RefCounted:
	return WeaponFXProfileClass.get_profile(profile_id)

# ------------------------------------------------------------------------------
# 1. MUZZLE FLASH BURST API
# ------------------------------------------------------------------------------
func play_muzzle(
	profile_id: String,
	muzzle_transform: Transform3D,
	source_node: Node = null,
	shot_direction: Vector3 = Vector3.ZERO
) -> void:
	var profile = WeaponFXProfileClass.get_profile(profile_id)
	var flash = _acquire_muzzle_flash()
	if flash:
		flash.activate(profile, muzzle_transform, source_node, shot_direction)

	# High-priority real flash light (launcher flare / heavy shell)
	if profile.muzzle_light_energy > 0.0:
		request_flash_light(
			muzzle_transform.origin,
			profile.muzzle_core_color,
			profile.muzzle_light_energy,
			profile.muzzle_light_radius,
			profile.muzzle_light_duration,
			1
		)

	# Optional nearby ground splash for shotgun or heavy ground tanks
	if profile.family in ["shotgun", "heavy"] and is_inside_tree() and get_viewport():
		var space = get_viewport().find_world_3d().direct_space_state if get_viewport().find_world_3d() else null
		if space:
			var patch = _acquire_surface_patch()
			if patch:
				var placed = patch.project_from_point(
					space,
					muzzle_transform.origin,
					Vector3.DOWN,
					profile.muzzle_edge_color,
					profile.muzzle_width * 1.8,
					profile.muzzle_duration * 1.5,
					3.5
				)
				if not placed:
					patch.deactivate()

func _acquire_muzzle_flash() -> Node3D:
	for f in muzzle_pool:
		if not f.active:
			return f
	# Pool exhausted: reuse oldest active flash
	if muzzle_pool.size() > 0:
		var oldest = muzzle_pool[0]
		oldest.deactivate()
		return oldest
	return null

# ------------------------------------------------------------------------------
# 2. IMPACT FLASH & SURFACE LIGHT PATCH API
# ------------------------------------------------------------------------------
func play_impact(
	profile_id: String,
	hit_position: Vector3,
	hit_normal: Vector3,
	_surface_context: Dictionary = {}
) -> void:
	var profile = WeaponFXProfileClass.get_profile(profile_id)

	# 1. Normal-oriented multi-plane impact burst
	var impact = _acquire_impact_flash()
	if impact:
		impact.activate(hit_position, hit_normal, profile.impact_color, profile.impact_size, profile.impact_duration)

	# 2. Directional sparks
	spawn_impact_sparks(hit_position, hit_normal)

	# 3. Conforming ground/wall fake-light patch
	if profile.impact_patch_size > 0.0:
		var patch = _acquire_surface_patch()
		if patch:
			patch.activate_at_surface(
				hit_position,
				hit_normal,
				profile.impact_color,
				profile.impact_patch_size * 0.5,
				profile.impact_patch_duration
			)

	# 4. Optional real flash light for heavy impacts
	if profile.impact_real_light_radius > 0.0:
		request_flash_light(
			hit_position + hit_normal.normalized() * 0.4,
			profile.impact_color,
			profile.impact_real_light_energy,
			profile.impact_real_light_radius,
			profile.impact_real_light_duration,
			profile.impact_real_light_priority
		)

func _acquire_impact_flash() -> Node3D:
	for imp in impact_pool:
		if not imp.active:
			return imp
	if impact_pool.size() > 0:
		var oldest = impact_pool[0]
		oldest.deactivate()
		return oldest
	return null

func _acquire_surface_patch() -> Node3D:
	for p in patch_pool:
		if not p.active:
			return p
	if patch_pool.size() > 0:
		var oldest = patch_pool[0]
		oldest.deactivate()
		return oldest
	return null

# ------------------------------------------------------------------------------
# 3. PROJECTILE TRAIL API
# ------------------------------------------------------------------------------
func attach_projectile_trail(proj: Node3D, profile_id: String) -> Node:
	var profile = WeaponFXProfileClass.get_profile(profile_id)
	if not profile.has_trail:
		return null

	for trail in trail_pool:
		if not trail.active:
			trail.attach_to_projectile(proj, profile)
			return trail
	return null

func detach_projectile_trail(trail: Node) -> void:
	if is_instance_valid(trail) and trail.has_method("detach_cleanly"):
		trail.detach_cleanly()

# ------------------------------------------------------------------------------
# 4. SHARED REAL FLASH LIGHT POOL (Max 4 active OmniLight3D, shadows disabled)
# ------------------------------------------------------------------------------
func request_flash_light(
	position: Vector3,
	color: Color,
	energy: float,
	radius: float,
	duration: float,
	priority: int = 0
) -> void:
	if not is_inside_tree() or get_tree() == null:
		return

	# Respect Reduce Flashes
	var reduce_flashes: bool = false
	if has_node("/root/AudioManager"):
		reduce_flashes = get_node("/root/AudioManager").reduce_flashes

	var adj_energy = energy * (0.35 if reduce_flashes else 1.0)
	var adj_duration = duration * (0.80 if reduce_flashes else 1.0)
	var adj_radius = minf(radius, 14.0)

	# 1. Nearby merge (< 4.0m): Boost duration and energy rather than popping second light
	for entry in active_flash_lights:
		if entry.pos.distance_to(position) < 4.0:
			var light: OmniLight3D = entry.light
			if is_instance_valid(light):
				light.light_color = color
				entry.duration = maxf(entry.duration, adj_duration)
				entry.initial_energy = maxf(entry.initial_energy, adj_energy)
				entry.base_energy = maxf(entry.get("base_energy", entry.initial_energy), energy)
				light.omni_range = maxf(light.omni_range, adj_radius)
				entry.timer = 0.0
			return

	# 2. Allocate free light from pool
	if flash_light_pool.size() > 0:
		var light = flash_light_pool.pop_back()
		if is_instance_valid(light):
			light.global_position = position
			light.light_color = color
			light.omni_range = adj_radius
			light.light_energy = adj_energy
			light.visible = true
			active_flash_lights.append({
				"light": light,
				"timer": 0.0,
				"duration": adj_duration,
				"initial_energy": adj_energy,
				"base_energy": energy,
				"priority": priority,
				"pos": position
			})
			return

	# 3. All 4 active: Preempt lowest priority with hysteresis
	var lowest_idx = -1
	var lowest_prio = 999
	for k in range(active_flash_lights.size()):
		var e = active_flash_lights[k]
		if e.priority < lowest_prio:
			lowest_prio = e.priority
			lowest_idx = k

	if lowest_idx >= 0 and priority > lowest_prio:
		var target_entry = active_flash_lights[lowest_idx]
		if target_entry.timer >= 0.04: # Hysteresis threshold
			var light: OmniLight3D = target_entry.light
			if is_instance_valid(light):
				light.global_position = position
				light.light_color = color
				light.omni_range = adj_radius
				light.light_energy = adj_energy
				light.visible = true
				target_entry.timer = 0.0
				target_entry.duration = adj_duration
				target_entry.initial_energy = adj_energy
				target_entry.base_energy = energy
				target_entry.priority = priority
				target_entry.pos = position

# ------------------------------------------------------------------------------
# 5. CLEANUP TRANSITION API
# ------------------------------------------------------------------------------
func clear_combat_effects() -> void:
	if is_instance_valid(fragment_trail_emitter):
		fragment_trail_emitter.clear_all()

	for f in muzzle_pool:
		if is_instance_valid(f):
			f.deactivate()

	for imp in impact_pool:
		if is_instance_valid(imp):
			imp.deactivate()

	for p in patch_pool:
		if is_instance_valid(p):
			p.deactivate()

	for t in trail_pool:
		if is_instance_valid(t):
			t.deactivate()

	for spk in spark_pool:
		if is_instance_valid(spk):
			spk.emitting = false

	for entry in active_flash_lights:
		var light: OmniLight3D = entry.get("light")
		if is_instance_valid(light):
			light.visible = false
			light.light_energy = 0.0
			flash_light_pool.append(light)
	active_flash_lights.clear()
	active_composed_explosions.clear()

	# Clear all non-pooled dynamic nodes in gameplay_fx_root (flashes, fireballs, dust, wreckage)
	if is_instance_valid(gameplay_fx_root):
		for child in gameplay_fx_root.get_children():
			if not _is_pooled_child(child):
				child.queue_free()

	# Also free any debris, flashes, dust or explosions in scene tree
	if is_inside_tree():
		for grp in ["combat_explosions", "combat_flashes", "combat_debris", "combat_dust"]:
			for n in get_tree().get_nodes_in_group(grp):
				if is_instance_valid(n):
					n.queue_free()

func _is_pooled_child(child: Node) -> bool:
	if child == fragment_trail_emitter:
		return true
	if child in muzzle_pool or child in impact_pool or child in patch_pool or child in trail_pool or child in spark_pool:
		return true
	if child is OmniLight3D and child in flash_light_pool:
		return true
	for entry in active_flash_lights:
		if entry.get("light") == child:
			return true
	return false

# ------------------------------------------------------------------------------
# 6. ACTIVE COUNT TELEMETRY
# ------------------------------------------------------------------------------
func get_active_muzzle_count() -> int:
	var count = 0
	for m in muzzle_pool:
		if is_instance_valid(m) and m.active:
			count += 1
	return count

func get_active_impact_count() -> int:
	var count = 0
	for i in impact_pool:
		if is_instance_valid(i) and i.active:
			count += 1
	return count

func get_active_patch_count() -> int:
	var count = 0
	for p in patch_pool:
		if is_instance_valid(p) and p.active:
			count += 1
	return count

func get_active_trail_count() -> int:
	var count = 0
	for t in trail_pool:
		if is_instance_valid(t) and t.active:
			count += 1
	return count

func get_active_flash_light_count() -> int:
	return active_flash_lights.size()

# ------------------------------------------------------------------------------
# 6. STYLIZED VEHICLE & AIRFRAME DESTRUCTION API
# Matching primary reference (YouTube: @Smitty_Games, "RTS Nav Routes", 29-31s):
# - Layer A: 0.05-0.08s unshaded additive core flash
# - Layer B: Compact irregular multi-lobe low-poly fireball (amber -> orange -> brown -> charcoal fade)
# - Layer C & D: Burning fragments on ballistic downward arcs with curved segmented dark smoke trails
# - Layer E: Low surface contact dust burst and conforming scorch patch (if is_surface_contact)
# - Real light from 4-light pool, camera trauma, single audio boom
# ------------------------------------------------------------------------------
func play_destruction(
	entity: Node,
	hit_pos: Vector3,
	contact_normal: Vector3 = Vector3.UP,
	is_surface_contact: bool = true,
	custom_profile_id: String = ""
) -> void:
	if not is_inside_tree() or get_tree() == null:
		return

	var profile: Dictionary = {}
	if not custom_profile_id.is_empty():
		profile = DestructionFXProfileClass.get_profile(custom_profile_id)
	elif is_instance_valid(entity):
		profile = DestructionFXProfileClass.get_profile_for_entity(entity)
	else:
		profile = DestructionFXProfileClass.get_profile("light_ground")

	# Respect Reduce Flashes
	var reduce_flashes: bool = false
	if has_node("/root/AudioManager"):
		reduce_flashes = get_node("/root/AudioManager").reduce_flashes

	var is_hero: bool = (custom_profile_id in ["boss", "hero", "player"] or (is_instance_valid(entity) and (entity.is_in_group("bosses") or entity.is_in_group("player"))))

	# Clean up inactive explosions from tracker
	var idx = active_composed_explosions.size() - 1
	while idx >= 0:
		var item = active_composed_explosions[idx]
		if not is_instance_valid(item.get("container")):
			active_composed_explosions.remove_at(idx)
		idx -= 1

	# Enforce MAX_ORDINARY_EXPLOSIONS (12) budget, reserving capacity for hero/boss
	if not is_hero:
		while active_composed_explosions.size() >= MAX_ORDINARY_EXPLOSIONS:
			var oldest = active_composed_explosions.pop_front()
			if oldest:
				if is_instance_valid(oldest.get("container")):
					oldest.container.remove_from_group("combat_explosions")
					oldest.container.queue_free()
				if is_instance_valid(oldest.get("flash")):
					oldest.flash.remove_from_group("combat_flashes")
					oldest.flash.queue_free()
				if is_instance_valid(oldest.get("dust")):
					oldest.dust.remove_from_group("combat_dust")
					oldest.dust.queue_free()

	# Degrade distant smoke/dust if active ordinary explosions > 8
	var degrade_fx: bool = not is_hero and active_composed_explosions.size() > 8

	# Layer A: Core Flash Quad
	var flash_mesh = _spawn_destruction_flash(hit_pos, profile, reduce_flashes)

	# Layer B: Compact Irregular Multi-Lobe Fireball
	var fireball_container = _spawn_destruction_fireball(hit_pos, profile, reduce_flashes)

	# Layer C & D: Burning Fragments with Curved Segmented Smoke Trails
	if is_instance_valid(fragment_trail_emitter):
		var base_vel = Vector3.ZERO
		if is_instance_valid(entity) and "velocity" in entity:
			base_vel = entity.velocity
		var frag_count: int = profile.get("fragment_count", 4)
		if degrade_fx:
			frag_count = maxi(1, frag_count / 2)
		fragment_trail_emitter.launch_fragments(
			hit_pos,
			base_vel,
			frag_count,
			profile.get("fragment_speed_min", 13.0),
			profile.get("fragment_speed_max", 20.0),
			profile.get("fragment_gravity", 18.0),
			profile.get("fragment_lifetime", 0.6),
			profile.get("smoke_puff_spacing", 0.28),
			profile.get("smoke_puff_size", 0.5),
			profile.get("smoke_puff_lifetime", 1.1)
		)

	# Layer E: Surface Contact Dust & Scorch Patch
	var dust_node: Node = null
	if is_surface_contact and profile.get("contact_dust_enabled", false) and not degrade_fx:
		dust_node = _spawn_surface_contact_dust(hit_pos, contact_normal, profile)
		var patch = _acquire_surface_patch()
		if patch:
			patch.activate_at_surface(
				hit_pos,
				contact_normal,
				Color(0.12, 0.11, 0.10, 0.70),
				profile.get("fireball_size", 1.5) * 1.5,
				1.8
			)

	# Register composed explosion tracking entry
	var explosion_entry = {
		"container": fireball_container,
		"flash": flash_mesh,
		"dust": dust_node,
		"is_hero": is_hero
	}
	active_composed_explosions.append(explosion_entry)

	# Shared Real Flash Light
	var light_energy: float = profile.get("real_light_energy", 3.0)
	if light_energy > 0.0:
		request_flash_light(
			hit_pos + contact_normal.normalized() * 0.35,
			profile.get("flash_core_color", Color(1.0, 0.9, 0.6)),
			light_energy,
			profile.get("real_light_radius", 9.0),
			profile.get("real_light_duration", 0.12),
			profile.get("real_light_priority", 2)
		)

	# Camera Trauma
	var trauma: float = profile.get("camera_trauma", 0.3)
	if trauma > 0.0 and get_viewport():
		var cam = get_viewport().get_camera_3d()
		if cam and cam.has_method("add_trauma"):
			cam.add_trauma(trauma)

	# Audio Detonation
	var snd_name: String = profile.get("sound_name", "explosion")
	if has_node("/root/AudioManager"):
		var am = get_node("/root/AudioManager")
		am.play_sfx(snd_name, randf_range(0.92, 1.08), 2.0)

func spawn_explosion(pos: Vector3, scale_mult: float = 1.0) -> void:
	var prof_id = "light_ground"
	if scale_mult >= 2.4:
		prof_id = "boss"
	elif scale_mult >= 1.6:
		prof_id = "heavy_ground"
	play_destruction(null, pos, Vector3.UP, true, prof_id)

func _spawn_destruction_flash(pos: Vector3, profile: Dictionary, reduce_flashes: bool) -> MeshInstance3D:
	var flash_mesh = MeshInstance3D.new()
	flash_mesh.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	flash_mesh.add_to_group("combat_flashes")
	var quad = QuadMesh.new()
	var size_m: float = profile.get("fireball_size", 1.5) * 2.4
	quad.size = Vector2(size_m, size_m)
	flash_mesh.mesh = quad

	var mat = DestructionFlashMaterial.new()
	mat.shader = FakeLightShader
	mat.set_shader_parameter("is_billboard", true)
	mat.set_shader_parameter("shape_type", 0) # Radial star / soft core falloff
	mat.set_shader_parameter("falloff_exponent", 2.2)
	mat.set_shader_parameter("core_radius", 0.35)
	mat.set_shader_parameter("core_brightness", 3.0)
	var core_col: Color = profile.get("flash_core_color", Color(1.0, 0.92, 0.65))
	var alpha_mult: float = 0.4 if reduce_flashes else 0.95
	mat.set_shader_parameter("tint_color", Color(core_col.r, core_col.g, core_col.b, alpha_mult))
	mat.set_shader_parameter("intensity", 2.5)
	flash_mesh.material_override = mat
	flash_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var target_parent = gameplay_fx_root if is_instance_valid(gameplay_fx_root) else self
	target_parent.add_child(flash_mesh)
	flash_mesh.global_position = pos

	var dur: float = profile.get("flash_duration", 0.06)
	var tw = flash_mesh.create_tween()
	tw.tween_property(flash_mesh, "scale", Vector3.ONE * 1.35, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(func(val: float):
		if is_instance_valid(mat):
			mat.set_shader_parameter("tint_color", Color(core_col.r, core_col.g, core_col.b, val))
	, alpha_mult, 0.0, dur)
	tw.tween_callback(flash_mesh.queue_free)
	return flash_mesh

func _spawn_destruction_fireball(pos: Vector3, profile: Dictionary, reduce_flashes: bool) -> Node3D:
	var container = Node3D.new()
	container.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	container.add_to_group("combat_explosions")
	var target_parent = gameplay_fx_root if is_instance_valid(gameplay_fx_root) else self
	target_parent.add_child(container)
	container.global_position = pos

	var fb_size: float = profile.get("fireball_size", 1.5)
	var edge_col: Color = profile.get("flash_edge_color", Color(1.0, 0.55, 0.18))
	var core_col: Color = profile.get("flash_core_color", Color(1.0, 0.92, 0.65))

	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radial_segments = 6
	sphere_mesh.rings = 4
	sphere_mesh.radius = fb_size * 0.42
	sphere_mesh.height = fb_size * 0.84

	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(core_col.r, core_col.g, core_col.b, 0.4 if reduce_flashes else 0.95)
	sphere_mesh.material = mat

	# Cluster 4 irregular low-poly lobes
	var lobe_offsets: Array[Vector3] = [
		Vector3.ZERO,
		Vector3(0.28, 0.20, -0.16) * fb_size,
		Vector3(-0.22, -0.14, 0.20) * fb_size,
		Vector3(0.12, 0.30, 0.18) * fb_size
	]

	for offset in lobe_offsets:
		var lobe = MeshInstance3D.new()
		lobe.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		lobe.mesh = sphere_mesh
		lobe.position = offset
		lobe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		container.add_child(lobe)

	container.scale = Vector3.ONE * 0.25

	# Two-phase rapid burst: 0.08s sharp pop -> 0.20s charcoal transition & fade
	var tw = container.create_tween()
	var target_fade_col = Color(edge_col.r, edge_col.g, edge_col.b, 0.4 if reduce_flashes else 1.0)
	tw.tween_property(container, "scale", Vector3.ONE, 0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mat, "albedo_color", target_fade_col, 0.08)
	tw.tween_property(container, "scale", Vector3.ONE * 1.25, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mat, "albedo_color", Color(0.15, 0.14, 0.13, 0.0), 0.20)
	tw.tween_callback(container.queue_free)
	return container

func _spawn_surface_contact_dust(pos: Vector3, normal: Vector3, profile: Dictionary) -> CPUParticles3D:
	var dust = CPUParticles3D.new()
	dust.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	dust.add_to_group("combat_dust")
	var target_parent = gameplay_fx_root if is_instance_valid(gameplay_fx_root) else self
	target_parent.add_child(dust)
	dust.global_position = pos
	dust.emitting = true
	dust.one_shot = true
	dust.explosiveness = 0.92
	dust.amount = 12
	dust.lifetime = 0.65
	dust.direction = normal
	dust.spread = 85.0
	var fb_size: float = profile.get("fireball_size", 1.5)
	dust.initial_velocity_min = 4.0 * fb_size
	dust.initial_velocity_max = 8.5 * fb_size
	dust.damping_min = 12.0
	dust.damping_max = 18.0
	dust.gravity = Vector3(0, -6.0, 0)

	var d_mesh = SphereMesh.new()
	d_mesh.radial_segments = 6
	d_mesh.rings = 4
	d_mesh.radius = 0.35 * fb_size
	d_mesh.height = 0.70 * fb_size

	var d_mat = StandardMaterial3D.new()
	d_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	d_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	d_mat.albedo_color = Color(0.40, 0.38, 0.35, 0.60)
	d_mesh.material = d_mat
	dust.mesh = d_mesh
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var tw = dust.create_tween()
	tw.tween_interval(0.70)
	tw.tween_callback(dust.queue_free)
	return dust

# ------------------------------------------------------------------------------
# 7. BULLET IMPACT SPARKS (High-speed zero-alloc pooled particles)
# ------------------------------------------------------------------------------
func spawn_impact_sparks(pos: Vector3, normal: Vector3 = Vector3.UP) -> void:
	if spark_pool.is_empty():
		return
	var sparks = spark_pool[_spark_cursor]
	_spark_cursor = (_spark_cursor + 1) % MAX_SPARK_EMITTERS
	sparks.global_position = pos
	sparks.direction = normal
	sparks.restart()

# ------------------------------------------------------------------------------
# 8. FLARE DECOY EMBER CLOUD
# ------------------------------------------------------------------------------
func spawn_flare_burst(pos: Vector3) -> void:
	var flares = CPUParticles3D.new()
	get_tree().root.add_child(flares)
	flares.global_position = pos
	flares.emitting = true
	flares.one_shot = true
	flares.explosiveness = 0.85
	flares.amount = 28
	flares.lifetime = 1.1
	flares.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flares.emission_sphere_radius = 2.0
	flares.direction = Vector3.DOWN
	flares.spread = 120.0
	flares.initial_velocity_min = 10.0
	flares.initial_velocity_max = 22.0
	flares.gravity = Vector3(0, -6.0, 0)
	
	var flare_mesh = SphereMesh.new()
	flare_mesh.radial_segments = 8
	flare_mesh.rings = 4
	flare_mesh.radius = 0.35
	flare_mesh.height = 0.7
	var flare_mat = StandardMaterial3D.new()
	flare_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	flare_mat.albedo_color = Color(1.0, 1.0, 0.7, 1.0)
	flare_mesh.material = flare_mat
	flares.mesh = flare_mesh
	flares.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var timer = flares.get_tree().create_timer(1.3)
	timer.timeout.connect(flares.queue_free)

# ------------------------------------------------------------------------------
# 9. FLOATING COMBAT TEXT & COMPLIMENTS
# ------------------------------------------------------------------------------
func spawn_damage_number(pos: Vector3, damage_amount: float, is_crit: bool = false) -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	
	var spawn_pos = pos + Vector3(randf_range(-0.4, 0.4), randf_range(0.2, 0.8), randf_range(-0.4, 0.4))
	
	if is_crit:
		var crit_label = FloatingTextClass.new()
		get_tree().root.add_child.call_deferred(crit_label)
		var crit_text = "CRIT!\n%d" % int(round(damage_amount))
		crit_label.setup(crit_text, spawn_pos + Vector3(0, 0.4, 0), FloatingTextClass.TextType.DAMAGE_CRIT, Color(1.0, 0.90, 0.0, 1.0))
		
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_sfx("crit_hit", randf_range(0.96, 1.05), 1.0)
	else:
		var dmg_label = FloatingTextClass.new()
		get_tree().root.add_child.call_deferred(dmg_label)
		var dmg_str = str(int(round(damage_amount)))
		dmg_label.setup(dmg_str, spawn_pos, FloatingTextClass.TextType.DAMAGE_NORMAL, Color(1.0, 0.90, 0.10, 1.0))

func spawn_compliment(pos: Vector3, entity: Node = null) -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	
	var now = Time.get_ticks_msec() / 1000.0
	if (now - last_kill_time) <= KILL_STREAK_WINDOW:
		kill_streak_count += 1
	else:
		kill_streak_count = 1
	last_kill_time = now
	
	var compliment_text = ""
	var text_col = Color(1.0, 0.92, 0.15, 1.0)
	
	if entity and is_instance_valid(entity):
		if entity.is_in_group("bosses"):
			compliment_text = "BOSS DESTROYED!"
			text_col = Color(1.0, 0.45, 0.1, 1.0)
		elif entity.get("modifier") == 1:
			compliment_text = "ELITE SMOKED!"
			text_col = Color(1.0, 0.65, 0.1, 1.0)
	
	if compliment_text == "":
		match kill_streak_count:
			2:
				compliment_text = "DOUBLE KILL!"
				text_col = Color(1.0, 0.92, 0.2, 1.0)
			3:
				compliment_text = "TRIPLE KILL!"
				text_col = Color(1.0, 0.82, 0.1, 1.0)
			4:
				compliment_text = "MULTI KILL!"
				text_col = Color(1.0, 0.65, 0.1, 1.0)
			5:
				compliment_text = "RAMPAGE!"
				text_col = Color(1.0, 0.35, 0.1, 1.0)
			_:
				if kill_streak_count >= 6:
					compliment_text = "UNSTOPPABLE!"
					text_col = Color(1.0, 0.2, 0.1, 1.0)
				else:
					compliment_text = KILL_COMPLIMENTS[randi() % KILL_COMPLIMENTS.size()]
	
	var comp_label = FloatingTextClass.new()
	get_tree().root.add_child(comp_label)
	comp_label.setup(compliment_text, pos + Vector3(0, 2.5, 0), FloatingTextClass.TextType.COMPLIMENT, text_col)
	
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("compliment", randf_range(0.96, 1.04), 1.5)

func spawn_bounty_popup(pos: Vector3, score_amount: int) -> void:
	if not is_inside_tree() or get_tree() == null or score_amount <= 0:
		return
	
	var bounty_label = FloatingTextClass.new()
	get_tree().root.add_child(bounty_label)
	var bounty_pos = pos + Vector3(0.0, 1.2, 0.0)
	bounty_label.setup("$%d" % score_amount, bounty_pos, FloatingTextClass.TextType.BOUNTY, Color(1.0, 0.88, 0.15, 1.0))

# ------------------------------------------------------------------------------
# 10. PICKUP COLLECTION SPARKS
# ------------------------------------------------------------------------------
func spawn_pickup_sparkle(pos: Vector3, sparkle_color: Color = Color(1.0, 0.9, 0.3)) -> void:
	if not is_inside_tree() or get_tree() == null or get_tree().get_nodes_in_group("combat_sparks").size() >= 32:
		return
	var sparks = CPUParticles3D.new()
	get_tree().root.add_child(sparks)
	sparks.add_to_group("combat_sparks")
	sparks.global_position = pos
	sparks.emitting = true
	sparks.one_shot = true
	sparks.explosiveness = 0.95
	sparks.amount = 6
	sparks.lifetime = 0.22
	sparks.spread = 180.0
	sparks.initial_velocity_min = 2.5
	sparks.initial_velocity_max = 6.0
	sparks.gravity = Vector3.ZERO
	
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.08, 0.08, 0.08)
	var mat = StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = sparkle_color
	mesh.material = mat
	sparks.mesh = mesh
	
	var tw = sparks.create_tween()
	tw.tween_interval(0.25)
	tw.tween_callback(sparks.queue_free)

# ------------------------------------------------------------------------------
# 11. EventBus Callbacks
# ------------------------------------------------------------------------------
func _on_entity_destroyed(entity: Node, _killer: String, _score: int, _xp: int) -> void:
	if is_instance_valid(entity) and entity is Node3D:
		var handles_own: bool = entity.is_in_group("enemies") or entity.is_in_group("player") or entity.is_in_group("buildings")
		if not handles_own:
			play_destruction(entity, entity.global_position, Vector3.UP, true)
		
		if entity.is_in_group("enemies") or not entity.is_in_group("buildings"):
			var death_pos: Vector3 = entity.global_position
			spawn_compliment(death_pos, entity)
			
			var rec = entity.get_node_or_null("DamageReceiver")
			var lethal_dmg: float = rec.last_damage_taken if rec and "last_damage_taken" in rec and rec.last_damage_taken > 0.0 else 50.0
			var was_crit: bool = rec.last_hit_was_crit if rec and "last_hit_was_crit" in rec else false
			
			var dmg_timer = get_tree().create_timer(0.08)
			dmg_timer.timeout.connect(func():
				if is_inside_tree():
					spawn_damage_number(death_pos, lethal_dmg, was_crit)
			)
			
			if _score > 0:
				var bounty_timer = get_tree().create_timer(0.18)
				bounty_timer.timeout.connect(func():
					if is_inside_tree():
						spawn_bounty_popup(death_pos - Vector3(0.0, 0.6, 0.0), _score)
				)

func _on_flares_deployed(_charges: int) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		spawn_flare_burst(player.global_position - player.global_transform.basis.z * 2.0)

func _on_damage_dealt(target: Node, _amount: float, _weapon: String, _is_lethal: bool) -> void:
	# Single ownership: If projectile impact burst already handled this hit, skip duplicate center sparks
	if is_instance_valid(target) and target is Node3D:
		var rec = target.get_node_or_null("DamageReceiver")
		if rec and "last_damage_data" in rec and rec.last_damage_data:
			if "impact_fx_handled" in rec.last_damage_data and rec.last_damage_data.impact_fx_handled:
				return
		spawn_impact_sparks(target.global_position + Vector3(randf_range(-0.5, 0.5), randf_range(0.2, 1.2), randf_range(-0.5, 0.5)))

# ------------------------------------------------------------------------------
# 12. AIRFRAME CRASH WRECKAGE
# ------------------------------------------------------------------------------
func spawn_airframe_wreckage(pos: Vector3) -> void:
	# Enforce debris cap (max 16 chunks active in tree)
	var existing_debris = get_tree().get_nodes_in_group("combat_debris") if is_inside_tree() else []
	if existing_debris.size() >= 16:
		for d in existing_debris.slice(0, existing_debris.size() - 15):
			if is_instance_valid(d):
				d.queue_free()

	var container = Node3D.new()
	container.add_to_group("combat_debris")
	container.add_to_group("combat_explosions")
	if is_instance_valid(gameplay_fx_root):
		gameplay_fx_root.add_child(container)
	else:
		get_tree().root.add_child(container)
	container.global_position = pos

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.14, 0.16)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.38, 0.08)
	mat.emission_energy_multiplier = 2.8

	for i in 6:
		var chunk = RigidBody3D.new()
		chunk.add_to_group("combat_debris")
		chunk.collision_layer = 0
		chunk.collision_mask = 2
		var mesh_inst = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(randf_range(0.35, 0.75), randf_range(0.2, 0.45), randf_range(0.35, 0.9))
		box.material = mat
		mesh_inst.mesh = box
		chunk.add_child(mesh_inst)

		var col = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = box.size
		col.shape = shape
		chunk.add_child(col)

		container.add_child(chunk)
		chunk.global_position = pos + Vector3(randf_range(-0.6, 0.6), randf_range(0.2, 0.8), randf_range(-0.6, 0.6))
		chunk.linear_velocity = Vector3(randf_range(-9.0, 9.0), randf_range(5.0, 13.0), randf_range(-9.0, 9.0))
		chunk.angular_velocity = Vector3(randf_range(-7.0, 7.0), randf_range(-7.0, 7.0), randf_range(-7.0, 7.0))

	var tw = container.create_tween()
	tw.tween_interval(3.5)
	tw.tween_callback(container.queue_free)

# ------------------------------------------------------------------------------
# 13. BUILDING COLLAPSE DUST BURST
# ------------------------------------------------------------------------------
func spawn_building_collapse_dust(pos: Vector3, size: Vector3) -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	var dust = CPUParticles3D.new()
	get_tree().root.add_child(dust)
	dust.global_position = pos
	dust.emitting = true
	dust.one_shot = true
	dust.explosiveness = 0.85
	dust.amount = 48
	dust.lifetime = 2.4
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(size.x * 0.5, 1.2, size.z * 0.5)
	dust.direction = Vector3.UP
	dust.spread = 75.0
	dust.initial_velocity_min = 6.0
	dust.initial_velocity_max = 14.0
	dust.gravity = Vector3(0.0, -2.5, 0.0)
	dust.scale_amount_min = 2.0
	dust.scale_amount_max = 5.5

	var d_mesh = SphereMesh.new()
	d_mesh.radius = 1.2
	d_mesh.height = 2.4
	var d_mat = StandardMaterial3D.new()
	d_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	d_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	d_mat.albedo_color = Color(0.68, 0.65, 0.60, 0.40)
	d_mesh.material = d_mat
	dust.mesh = d_mesh
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var tw = dust.create_tween()
	tw.tween_interval(2.6)
	tw.tween_callback(dust.queue_free)
