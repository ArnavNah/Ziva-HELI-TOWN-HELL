class_name PlayerTurret
extends Node3D

## PlayerTurret — Controls chin-gun 3D gimbal, aiming independently of helicopter heading.
## Unified aiming solution:
## - Direct mouse raycasting against world/roof/enemy geometry
## - Screen-space proximity aim-assist with line-of-sight verification
## - Instant release to free aim on cursor exit or target invalidation
## - Out-of-arc reachable clamp detection and actual barrel impact calculation
## - Alternating muzzle state isolated from HUD readouts

@export var max_yaw_angle_deg: float = 110.0
@export var min_pitch_deg: float = -75.0  # Aiming down
@export var max_pitch_deg: float = 25.0   # Aiming up
@export var tracking_speed: float = 26.0   # Rad/s tracking smoothing
@export var auto_aim_cursor_radius: float = 18.0

const SCREEN_ASSIST_RADIUS_PX: float = 65.0
const SCREEN_RETENTION_RADIUS_PX: float = 90.0

@onready var yaw_pivot: Node3D = $YawPivot
@onready var pitch_pivot: Node3D = $YawPivot/PitchPivot
@onready var muzzle_left: Marker3D = $YawPivot/PitchPivot/MuzzleLeft
@onready var muzzle_right: Marker3D = $YawPivot/PitchPivot/MuzzleRight

# Unified Aiming Solution State
var requested_world_point: Vector3 = Vector3.ZERO
var target_world_pos: Vector3 = Vector3.ZERO
var current_target_node: Node3D = null
var current_target_score: float = 0.0
var is_aim_in_arc: bool = true
var actual_aim_direction: Vector3 = Vector3.FORWARD
var actual_impact_point: Vector3 = Vector3.ZERO

var current_muzzle_toggle: bool = false
var enemy_query_timer: float = 0.0
var cached_enemies: Array = []
var settle_timer: float = 0.0

func _ready() -> void:
	pass

func update_aim(camera: Camera3D, mouse_pos: Vector2, parent_heli: Node3D, delta: float) -> void:
	if not camera or not yaw_pivot or not pitch_pivot:
		return

	# 1. Direct Mouse Raycast: test physics colliders (Buildings, Ground, Enemy hulls)
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)
	var ground_target = Vector3.ZERO
	var has_hit = false
	var direct_hit_enemy: Node3D = null

	var space: PhysicsDirectSpaceState3D = null
	if camera.is_inside_tree() and camera.get_world_3d() != null:
		space = camera.get_world_3d().direct_space_state

	if space:
		# Layer 2 (World/Buildings = 2) + Layer 3 (Enemies = 4) -> mask = 6
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_dir * 300.0, 6)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		if parent_heli:
			query.exclude = [parent_heli.get_rid()]
		var phys_hit = space.intersect_ray(query)
		if not phys_hit.is_empty():
			ground_target = phys_hit.get("position", Vector3.ZERO)
			has_hit = true
			var hit_collider = phys_hit.get("collider", null)
			if hit_collider:
				direct_hit_enemy = _resolve_enemy_node(hit_collider)

	if not has_hit:
		var ground_plane = Plane(Vector3.UP, 0.0)
		var hit = ground_plane.intersects_ray(ray_origin, ray_dir)
		if hit != null:
			ground_target = hit
		else:
			var forward = -parent_heli.global_transform.basis.z.normalized() if parent_heli else Vector3.FORWARD
			ground_target = (parent_heli.global_position if parent_heli else Vector3.ZERO) + (forward * 50.0)
			ground_target.y = 0.0

	requested_world_point = ground_target

	# 2. Update enemy cache periodically
	enemy_query_timer -= delta
	settle_timer = maxf(0.0, settle_timer - delta)
	if enemy_query_timer <= 0.0:
		enemy_query_timer = 0.08
		cached_enemies = get_tree().get_nodes_in_group("enemies")

	# 3. Direct Mouse Intent Priority & Screen-Space Proximity Selection
	var heli_pos = parent_heli.global_position if parent_heli else Vector3.ZERO
	var heli_forward = -parent_heli.global_transform.basis.z.normalized() if parent_heli else Vector3.FORWARD

	var best_candidate: Node3D = null
	var best_score: float = 0.0

	# If direct raycast clicked an enemy collider, it receives maximum direct-hit score
	if is_instance_valid(direct_hit_enemy) and _is_enemy_valid(direct_hit_enemy, heli_pos):
		best_candidate = direct_hit_enemy
		best_score = 100.0
	else:
		# Evaluate screen-space proximity for visible enemies
		for e in cached_enemies:
			if not is_instance_valid(e) or not _is_enemy_valid(e, heli_pos):
				continue

			var e_pos = e.global_position
			# Ensure enemy is in front of the camera
			if camera.is_position_behind(e_pos):
				continue

			var e_screen = camera.unproject_position(e_pos)
			var screen_dist = mouse_pos.distance_to(e_screen)

			var max_dist_px = SCREEN_RETENTION_RADIUS_PX if (e == current_target_node) else SCREEN_ASSIST_RADIUS_PX
			if screen_dist > max_dist_px:
				# Also check world-space proximity as fallback for top-down views
				var world_d = Vector2(e_pos.x - ground_target.x, e_pos.z - ground_target.z).length()
				if world_d > auto_aim_cursor_radius:
					continue

			# Line-of-sight check against world buildings (layer 2)
			if space and not _has_line_of_sight(space, camera.global_position, e_pos, parent_heli):
				continue

			# Score formula: Proximity (up to 50) + Forward Alignment (up to 20) + Hysteresis (15)
			var dist_factor = clampf(1.0 - (screen_dist / max_dist_px), 0.0, 1.0)
			var to_enemy_dir = (e_pos - heli_pos).normalized()
			var angle_factor = maxf(0.0, heli_forward.dot(to_enemy_dir))
			var score = (dist_factor * 50.0) + (angle_factor * 20.0)
			if e == current_target_node:
				score += 15.0 # Hysteresis retention bonus prevents fluttering

			if score > best_score:
				best_score = score
				best_candidate = e

	# 4. Target Assignment or Instant Free-Aim Release
	if best_candidate != null:
		current_target_node = best_candidate
		current_target_score = best_score
		target_world_pos = _get_target_aim_point(best_candidate)
		settle_timer = 0.20
	else:
		# Free aim: mouse moved away or target died/escaped
		current_target_node = null
		current_target_score = 0.0
		target_world_pos = requested_world_point

	# 5. Compute Gimbal Angles in Chin-Gun Local Space
	var local_target_dir = global_transform.affine_inverse() * target_world_pos
	
	# Yaw calculation (horizontal angle in local XZ plane)
	var raw_yaw = atan2(-local_target_dir.x, -local_target_dir.z)
	var max_yaw_rad = deg_to_rad(max_yaw_angle_deg)
	var desired_yaw = clampf(raw_yaw, -max_yaw_rad, max_yaw_rad)
	
	# Pitch calculation (vertical angle)
	var horizontal_dist = Vector2(local_target_dir.x, local_target_dir.z).length()
	var raw_pitch = atan2(local_target_dir.y, horizontal_dist)
	var min_pitch_rad = deg_to_rad(min_pitch_deg)
	var max_pitch_rad = deg_to_rad(max_pitch_deg)
	var desired_pitch = clampf(raw_pitch, min_pitch_rad, max_pitch_rad)
	
	# Verify reachable gimbal arc with small threshold
	is_aim_in_arc = (absf(raw_yaw) <= max_yaw_rad + 0.04) and (raw_pitch >= min_pitch_rad - 0.04 and raw_pitch <= max_pitch_rad + 0.04)

	# Frame-rate independent exponential interpolation
	var lerp_factor = 1.0 - exp(-tracking_speed * delta)
	yaw_pivot.rotation.y = lerp_angle(yaw_pivot.rotation.y, desired_yaw, lerp_factor)
	pitch_pivot.rotation.x = lerp_angle(pitch_pivot.rotation.x, desired_pitch, lerp_factor)

	# 6. Actual Aim Direction & Real Impact Point along Barrel Trajectory
	actual_aim_direction = get_aim_direction()
	_update_actual_impact_point(space, parent_heli)

func _is_enemy_valid(e: Variant, heli_pos: Vector3) -> bool:
	if not is_instance_valid(e) or not (e is Node3D) or not (e as Node).is_inside_tree():
		return false
	if e.has_node("DamageReceiver"):
		var rec = e.get_node("DamageReceiver")
		if rec.is_dead:
			return false
	if (e.global_position - heli_pos).length() > 140.0:
		return false
	return true

func _resolve_enemy_node(collider: Object) -> Node3D:
	if not is_instance_valid(collider):
		return null
	var n: Node = collider as Node
	while n and n != get_tree().root:
		if n.is_in_group("enemies"):
			return n as Node3D
		n = n.get_parent()
	return null

func _has_line_of_sight(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, exclude_node: Node) -> bool:
	var q = PhysicsRayQueryParameters3D.create(from, to, 2) # Layer 2: World / Buildings
	if exclude_node:
		q.exclude = [(exclude_node as CollisionObject3D).get_rid()] if exclude_node is CollisionObject3D else []
	var hit = space.intersect_ray(q)
	return hit.is_empty()

func _get_target_aim_point(e: Node3D) -> Vector3:
	if not is_instance_valid(e):
		return Vector3.ZERO
	var col = e.get_node_or_null("CollisionShape3D")
	if col and col is CollisionShape3D:
		return col.global_position
	return e.global_position + Vector3(0.0, 0.75, 0.0)

func _update_actual_impact_point(space: PhysicsDirectSpaceState3D, parent_heli: Node3D) -> void:
	var muzzle_pos = pitch_pivot.global_position if pitch_pivot else global_position
	var aim_dist = (target_world_pos - muzzle_pos).length()
	aim_dist = clampf(aim_dist, 10.0, 160.0)

	if space:
		var q = PhysicsRayQueryParameters3D.create(muzzle_pos, muzzle_pos + actual_aim_direction * aim_dist, 6)
		if parent_heli and parent_heli is CollisionObject3D:
			q.exclude = [parent_heli.get_rid()]
		var hit = space.intersect_ray(q)
		if not hit.is_empty():
			actual_impact_point = hit.get("position", muzzle_pos + actual_aim_direction * aim_dist)
			return

	actual_impact_point = muzzle_pos + actual_aim_direction * aim_dist

## Non-mutating getter for HUD and FX placement (does NOT alternate barrels)
func get_current_muzzle_transform() -> Transform3D:
	if current_muzzle_toggle and muzzle_left:
		return muzzle_left.global_transform
	elif muzzle_right:
		return muzzle_right.global_transform
	return pitch_pivot.global_transform if pitch_pivot else global_transform

## Authoritative shot getter: alternates barrels for actual projectile firing
func get_active_muzzle_transform() -> Transform3D:
	current_muzzle_toggle = !current_muzzle_toggle
	return get_current_muzzle_transform()

func get_aim_direction() -> Vector3:
	if pitch_pivot:
		return -pitch_pivot.global_transform.basis.z.normalized()
	return -global_transform.basis.z.normalized()

func get_current_target() -> Node3D:
	if is_instance_valid(current_target_node) and current_target_node is Node3D:
		return current_target_node
	current_target_node = null
	return null
