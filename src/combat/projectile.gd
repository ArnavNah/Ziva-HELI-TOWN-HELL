class_name Projectile
extends Node3D

## Projectile — Handles high-speed bullets, homing missiles, ballistic rockets,
## explosive blast radiuses, and collision sweeps.

const DamageDataClass = preload("res://src/combat/damage_data.gd")

@export var speed: float = 300.0
@export var lifetime: float = 3.5
@export var is_homing: bool = false
@export var homing_turn_rate: float = 6.0
@export var blast_radius: float = 0.0
@export var profile_id: String = ""
@export var collision_mask: int = 6:
	set(val):
		collision_mask = val
		if raycast:
			raycast.collision_mask = val

var damage_data: RefCounted = null
var target_node: Node3D = null
var velocity: Vector3 = Vector3.ZERO
var elapsed: float = 0.0
var _fx_initialized: bool = false

var homing: bool:
	get: return is_homing
	set(v): is_homing = v

var homing_turn_speed: float:
	get: return homing_turn_rate
	set(v): homing_turn_rate = v

var homing_target: Node3D:
	get: return target_node
	set(v): target_node = v

@onready var raycast: RayCast3D = get_node_or_null("RayCast3D")

func _ready() -> void:
	add_to_group("combat_projectiles")
	if raycast:
		raycast.collision_mask = collision_mask
	if velocity.is_zero_approx():
		velocity = -global_transform.basis.z * speed
	_orient_to_velocity()
	if not _fx_initialized and not profile_id.is_empty():
		_fx_initialized = true
		_apply_visual_profile()

func setup(p_data: RefCounted, p_target: Node3D = null, p_profile_id: String = "") -> void:
	damage_data = p_data
	target_node = p_target
	if "speed" in p_data and p_data.speed > 0:
		speed = p_data.speed
	if "blast_radius" in p_data:
		blast_radius = p_data.blast_radius
	
	if p_profile_id != "":
		profile_id = p_profile_id
	elif profile_id.is_empty():
		profile_id = _infer_profile_id()

	_orient_to_velocity()

	# Idempotent setup guard to handle multi-setup calls (e.g. player salvo)
	if not _fx_initialized:
		_fx_initialized = true
		_apply_visual_profile()
		if damage_data and is_instance_valid(damage_data.attacker) and damage_data.attacker.is_in_group("enemies"):
			if has_node("/root/CombatDirector"):
				get_node("/root/CombatDirector").record_shot()

func _infer_profile_id() -> String:
	var is_player: bool = false
	if damage_data and "attacker" in damage_data and damage_data.attacker != null:
		var att = damage_data.attacker
		if att is Node and (att.is_in_group("player") or att.name == "PlayerHelicopter"):
			is_player = true
	
	if is_player:
		if damage_data and "is_salvo" in damage_data and damage_data.is_salvo:
			return "player_salvo"
		var w_type: int = damage_data.weapon_type if damage_data and "weapon_type" in damage_data else 0
		match w_type:
			GameConstants.WeaponType.MACHINE_GUN:
				return "player_mg"
			GameConstants.WeaponType.SHOTGUN:
				return "player_shotgun"
			GameConstants.WeaponType.MISSILE:
				return "player_missile"
			GameConstants.WeaponType.ROCKET:
				return "player_rocket"
		return "player_mg"
	else:
		if is_homing:
			return "enemy_sam"
		if blast_radius >= 6.0:
			return "enemy_heavy"
		elif blast_radius > 0.0:
			return "enemy_rocket"
		return "enemy_bullet"

func _apply_visual_profile() -> void:
	if not has_node("/root/FXManager"):
		return
	var fx = get_node("/root/FXManager")
	var profile = fx.get_profile(profile_id)
	if not profile:
		return

	# Apply tracer coloration if MeshInstance3D exists
	var mesh_inst = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_inst:
		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = profile.tracer_color
		mat.emission_enabled = true
		mat.emission = profile.tracer_color
		mat.emission_energy_multiplier = 3.5
		mesh_inst.material_override = mat

	if profile.has_trail:
		fx.attach_projectile_trail(self, profile_id)

func _orient_to_velocity() -> void:
	if velocity.length_squared() > 0.01:
		var dir = velocity.normalized()
		if absf(dir.dot(Vector3.UP)) < 0.99:
			look_at(global_position + dir, Vector3.UP)
		else:
			look_at(global_position + dir, Vector3.FORWARD)

func _physics_process(delta: float) -> void:
	elapsed += delta
	if elapsed >= lifetime:
		_on_expire()
		return

	# Homing steering
	if is_homing and target_node != null and is_instance_valid(target_node):
		var target_dir = (target_node.global_position - global_position).normalized()
		var current_dir = velocity.normalized()
		var new_dir = current_dir.slerp(target_dir, homing_turn_rate * delta)
		velocity = new_dir * speed
		look_at(global_position + velocity, Vector3.UP)

	# Swept collision detection
	var step = velocity * delta
	if raycast:
		raycast.target_position = raycast.to_local(global_position + step)
		raycast.force_raycast_update()
		if raycast.is_colliding():
			var hit_collider = raycast.get_collider()
			var hit_point = raycast.get_collision_point()
			var hit_normal = raycast.get_collision_normal()
			_on_impact(hit_collider, hit_point, hit_normal)
			return

	global_position += step

func _on_impact(collider: Object, hit_pos: Vector3, hit_normal: Vector3 = Vector3.UP) -> void:
	if hit_normal.is_zero_approx():
		hit_normal = Vector3.UP

	if has_node("/root/FXManager"):
		get_node("/root/FXManager").detach_projectile_trail(self)

	# Mark damage data so downstream generic center sparks are suppressed
	if damage_data != null:
		damage_data.impact_fx_handled = true

	if blast_radius > 0.0:
		_explode(hit_pos)
	else:
		_apply_direct_hit(collider)
	
	_spawn_mod_effects(hit_pos)
	_spawn_impact_fx(hit_pos, hit_normal)
	queue_free()

func _apply_direct_hit(collider: Object) -> void:
	if collider != null and is_instance_valid(collider):
		var receiver = _find_damage_receiver(collider)
		if receiver != null and damage_data != null:
			receiver.take_damage(damage_data)
			if has_node("/root/CombatDirector") and collider is Node and (collider as Node).is_in_group("player"):
				get_node("/root/CombatDirector").record_damage_landed(damage_data.raw_damage)

func _explode(center: Vector3) -> void:
	# Area blast damage query
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = blast_radius
	query.shape = sphere
	query.transform = Transform3D(Basis(), center)
	query.collision_mask = 5 # Enemies (4) + Player (1)
	
	var results = space_state.intersect_shape(query, 32)
	var processed_receivers: Array = []
	var processed_colliders: Array = []
	for res in results:
		var col = res.get("collider")
		if col != null and not processed_colliders.has(col):
			processed_colliders.append(col)
			var col_pos: Vector3 = col.global_position if "global_position" in col else center
			# Vertical reach limit: ground / area blast should not automatically reach an aircraft far above (max 12.0m vertical delta)
			if absf(col_pos.y - center.y) > 12.0:
				continue
			# Cover occlusion check: raycast from blast center to target collider on Mask 2 (terrain / buildings)
			var occ_query = PhysicsRayQueryParameters3D.create(center + Vector3(0, 0.2, 0), col_pos + Vector3(0, 0.5, 0), 2)
			var occ_hit = space_state.intersect_ray(occ_query)
			if occ_hit.size() > 0:
				var hit_collider = occ_hit.get("collider")
				if hit_collider != col and not (col is Node and (col as Node).is_ancestor_of(hit_collider)):
					# Ray hit a building/obstacle between blast center and target! Occluded!
					continue

			var receiver = _find_damage_receiver(col)
			if receiver != null and not processed_receivers.has(receiver):
				processed_receivers.append(receiver)
				# Proximity falloff
				var dist = center.distance_to(col.global_position)
				var factor = clampf(1.0 - (dist / blast_radius), 0.35, 1.0)
				var blast_data: DamageData = null
				if damage_data != null:
					blast_data = damage_data.clone_scaled(factor)
					blast_data.blast_radius = blast_radius
				else:
					blast_data = DamageDataClass.new(
						50.0 * factor,
						GameConstants.WeaponType.ROCKET,
						null,
						false,
						blast_radius,
						false
					)
				receiver.take_damage(blast_data)
				if has_node("/root/CombatDirector") and col is Node and (col as Node).is_in_group("player"):
					get_node("/root/CombatDirector").record_damage_landed(blast_data.raw_damage)

func _find_damage_receiver(node: Object) -> Node:
	if not node is Node:
		return null
	var n = node as Node
	if n.has_node("DamageReceiver"):
		return n.get_node("DamageReceiver")
	if n.has_method("take_damage"):
		return n
	for child in n.get_children():
		if child.has_method("take_damage"):
			return child
	return null

func _on_expire() -> void:
	if has_node("/root/FXManager"):
		get_node("/root/FXManager").detach_projectile_trail(self)
	if blast_radius > 0.0:
		_explode(global_position)
		_spawn_mod_effects(global_position)
		_spawn_impact_fx(global_position, Vector3.UP)
	queue_free()

func _spawn_impact_fx(pos: Vector3, normal: Vector3 = Vector3.UP) -> void:
	if has_node("/root/FXManager"):
		get_node("/root/FXManager").play_impact(profile_id, pos, normal)

func _spawn_mod_effects(center: Vector3) -> void:
	if not damage_data:
		return
	if "cluster_count" in damage_data and damage_data.cluster_count > 0:
		for i in damage_data.cluster_count:
			var projectile = load("res://scenes/combat/projectile.tscn").instantiate()
			projectile.position = center + Vector3.UP * 1.0
			var angle := float(i) * TAU / float(damage_data.cluster_count)
			projectile.velocity = Vector3(cos(angle), 0.6, sin(angle)) * 16.0
			projectile.lifetime = 0.22
			get_tree().root.add_child(projectile)
			var cluster_damage: DamageData = null
			if damage_data != null:
				cluster_damage = damage_data.clone_scaled(0.30)
				# Bomblets terminate the cluster chain instead of recursively multiplying.
				cluster_damage.cluster_count = 0
				cluster_damage.lingering_fire = false
				cluster_damage.blast_radius = maxf(2.0, blast_radius * 0.55)
				cluster_damage.is_salvo = false
			else:
				cluster_damage = DamageDataClass.new(
					15.0,
					damage_data.weapon_type if damage_data else GameConstants.WeaponType.ROCKET,
					null,
					false,
					maxf(2.0, blast_radius * 0.55),
					false
				)
			projectile.setup(cluster_damage)
	if "lingering_fire" in damage_data and damage_data.lingering_fire:
		var field = load("res://src/combat/lingering_fire.gd").new()
		field.position = center
		field.radius = minf(12.0, blast_radius * 0.6)
		field.attacker = damage_data.attacker if is_instance_valid(damage_data.attacker) else null
		get_tree().root.add_child(field)
