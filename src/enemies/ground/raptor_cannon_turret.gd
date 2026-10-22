class_name RaptorCannonTurret
extends Node3D

## Articulated Cannon Turret Controller for Raptor Raider.
## - Independent yaw tracking around local Y in vehicle parent coordinate space.
## - Elevation around trunnion hinge clamped between min_elevation_deg and max_elevation_deg.
## - Translational gun recoil with drift-free recovery to bind pose.
## - Mechanical elevation reachability check preventing shots at impossible angles.
## - Synchronizes muzzle marker for telegraphs, LOS checks, and projectile spawning.

@export var min_elevation_deg: float = -10.0 # Depression limit
@export var max_elevation_deg: float = 55.0  # Elevation limit
@export var recoil_distance: float = 0.08    # Backward kick in meters
@export var recoil_recovery_time: float = 0.12 # Recovery duration in seconds

@onready var mount_model: Node3D = get_node_or_null("MountModel")
@onready var gun_pitch: Node3D = get_node_or_null("GunPitch")
@onready var recoil: Node3D = get_node_or_null("GunPitch/Recoil")
@onready var gun_model: Node3D = get_node_or_null("GunPitch/Recoil/GunModel")
@onready var muzzle: Marker3D = get_node_or_null("GunPitch/Recoil/Muzzle")

var _current_recoil: float = 0.0
var _recoil_timer: float = 0.0
var _recoil_bind_pos: Vector3 = Vector3.ZERO
var _parent_body: Node3D

func _ready() -> void:
	if recoil:
		_recoil_bind_pos = recoil.position
	_find_parent()

func _find_parent() -> void:
	var p = get_parent()
	while p:
		if p is CharacterBody3D:
			_parent_body = p
			break
		p = p.get_parent()

func reset_pose_or_teleport_sampling() -> void:
	if recoil:
		recoil.position = _recoil_bind_pos
	_current_recoil = 0.0
	_recoil_timer = 0.0

func get_muzzle_position() -> Vector3:
	var m = muzzle if muzzle else get_node_or_null("GunPitch/Recoil/Muzzle")
	if m and is_instance_valid(m) and is_inside_tree():
		return m.global_position
	var gp = gun_pitch if gun_pitch else get_node_or_null("GunPitch")
	if gp and is_instance_valid(gp) and is_inside_tree():
		return gp.global_position
	return (global_position + Vector3.UP * 0.4) if is_inside_tree() else Vector3.UP * 0.4

func get_muzzle_transform() -> Transform3D:
	var m = muzzle if muzzle else get_node_or_null("GunPitch/Recoil/Muzzle")
	if m and is_instance_valid(m) and is_inside_tree():
		return m.global_transform
	return global_transform if is_inside_tree() else Transform3D.IDENTITY

func play_recoil() -> void:
	_current_recoil = recoil_distance
	_recoil_timer = recoil_recovery_time
	if recoil:
		recoil.position = _recoil_bind_pos + Vector3(0.0, 0.0, _current_recoil)

func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	if _recoil_timer > 0.0:
		_recoil_timer -= delta
		if _recoil_timer <= 0.0:
			_current_recoil = 0.0
			if recoil:
				recoil.position = _recoil_bind_pos
		else:
			var t := clampf(1.0 - (_recoil_timer / recoil_recovery_time), 0.0, 1.0)
			_current_recoil = lerpf(recoil_distance, 0.0, t)
			if recoil:
				recoil.position = _recoil_bind_pos + Vector3(0.0, 0.0, _current_recoil)

func track_aim(target_point: Vector3, delta: float, turn_speed_deg: float = 150.0, tolerance_deg: float = 24.0) -> bool:
	if not _parent_body or not is_instance_valid(_parent_body):
		_find_parent()
		if not _parent_body:
			return false

	var max_step := deg_to_rad(turn_speed_deg) * delta

	# 1. YAW ROTATION (Vehicle parent coordinate space)
	var target_in_parent := _parent_body.to_local(target_point)
	var to_target_parent := target_in_parent - position
	var target_yaw := atan2(-to_target_parent.x, -to_target_parent.z)
	var yaw_diff := wrapf(target_yaw - rotation.y, -PI, PI)

	if absf(yaw_diff) <= max_step:
		rotation.y = target_yaw
	else:
		rotation.y += signf(yaw_diff) * max_step

	rotation.x = 0.0
	rotation.z = 0.0

	# 2. PITCH ELEVATION (Gun trunnion space)
	var raw_pitch: float = 0.0
	var min_pitch_rad := deg_to_rad(min_elevation_deg)
	var max_pitch_rad := deg_to_rad(max_elevation_deg)

	if gun_pitch:
		var target_in_turret := to_local(target_point)
		var to_target_gun := target_in_turret - gun_pitch.position
		var horiz_dist := Vector2(to_target_gun.x, to_target_gun.z).length()
		raw_pitch = atan2(to_target_gun.y, maxf(horiz_dist, 0.01))

		var clamped_pitch := clampf(raw_pitch, min_pitch_rad, max_pitch_rad)
		var pitch_diff := clamped_pitch - gun_pitch.rotation.x
		if absf(pitch_diff) <= max_step:
			gun_pitch.rotation.x = clamped_pitch
		else:
			gun_pitch.rotation.x += signf(pitch_diff) * max_step

	# 3. MECHANICAL REACHABILITY & ALIGNMENT
	if raw_pitch < min_pitch_rad or raw_pitch > max_pitch_rad:
		return false

	var muzzle_fwd := -get_muzzle_transform().basis.z.normalized()
	var to_target_dir := (target_point - get_muzzle_position()).normalized()
	var angle_err_deg := rad_to_deg(muzzle_fwd.angle_to(to_target_dir))
	return angle_err_deg <= tolerance_deg
