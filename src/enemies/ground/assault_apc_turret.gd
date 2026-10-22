class_name AssaultAPCTurret
extends Node3D

## Articulated Turret Controller for Assault APC.
## - Yaws base ring around local Y in vehicle parent coordinate space.
## - Keeps pedestal/roof armor upright while pitching only the gun trunnion hinge.
## - Clamps gun pitch between -10 deg depression and +55 deg elevation.
## - Drives translational gun recoil along barrel axis without accumulating drift during rapid bursts.
## - Synchronizes muzzle marker for telegraph warnings, LOS checks, and projectile spawning.

@export var min_elevation_deg: float = -10.0 # Downward gun depression limit
@export var max_elevation_deg: float = 55.0  # Upward gun elevation limit
@export var recoil_distance: float = 0.05    # Local backward kick in meters
@export var recoil_recovery_time: float = 0.09 # Recovery duration (burst delay is 0.12s)

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

func get_muzzle_position() -> Vector3:
	if muzzle and is_instance_valid(muzzle):
		return muzzle.global_position
	if gun_pitch and is_instance_valid(gun_pitch):
		return gun_pitch.global_position
	return global_position + Vector3.UP * 0.4

func get_muzzle_transform() -> Transform3D:
	if muzzle and is_instance_valid(muzzle):
		return muzzle.global_transform
	return global_transform

func play_recoil() -> void:
	_current_recoil = recoil_distance
	_recoil_timer = recoil_recovery_time
	if recoil:
		# Recoil kicks along local +Z in the recoil node (barrel points along -Z)
		recoil.position = _recoil_bind_pos + Vector3(0, 0, _current_recoil)

func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	if _recoil_timer > 0.0:
		_recoil_timer -= delta
		var t = clampf(1.0 - (_recoil_timer / recoil_recovery_time), 0.0, 1.0)
		_current_recoil = lerpf(recoil_distance, 0.0, t)
		if recoil:
			recoil.position = _recoil_bind_pos + Vector3(0, 0, _current_recoil)
		if _recoil_timer <= 0.0 and recoil:
			recoil.position = _recoil_bind_pos

func track_aim(target_point: Vector3, delta: float, turn_speed: float = 3.0, tolerance: float = 0.08) -> bool:
	if not _parent_body or not is_instance_valid(_parent_body):
		_find_parent()
		if not _parent_body:
			return false

	# 1. YAW ROTATION (Vehicle parent coordinate space)
	var target_in_parent := _parent_body.to_local(target_point)
	var to_target_parent := target_in_parent - position
	var target_yaw := atan2(-to_target_parent.x, -to_target_parent.z)
	var yaw_diff := wrapf(target_yaw - rotation.y, -PI, PI)
	var max_step := turn_speed * delta

	if absf(yaw_diff) <= max_step:
		rotation.y = target_yaw
	else:
		rotation.y += signf(yaw_diff) * max_step

	# Keep pedestal base flat and upright (zero pitch/roll on turret root)
	rotation.x = 0.0
	rotation.z = 0.0

	# 2. PITCH ELEVATION (Gun trunnion space)
	if gun_pitch:
		var target_in_turret := to_local(target_point)
		var to_target_gun := target_in_turret - gun_pitch.position
		var horiz_dist := Vector2(to_target_gun.x, to_target_gun.z).length()
		var target_pitch := atan2(to_target_gun.y, horiz_dist)

		# Clamp elevation
		var min_pitch_rad := deg_to_rad(min_elevation_deg)
		var max_pitch_rad := deg_to_rad(max_elevation_deg)
		target_pitch = clampf(target_pitch, min_pitch_rad, max_pitch_rad)

		var pitch_diff := target_pitch - gun_pitch.rotation.x
		if absf(pitch_diff) <= max_step:
			gun_pitch.rotation.x = target_pitch
		else:
			gun_pitch.rotation.x += signf(pitch_diff) * max_step

	# 3. ALIGNMENT CHECK
	var muzzle_fwd := -get_muzzle_transform().basis.z.normalized()
	var to_target_dir := (target_point - get_muzzle_position()).normalized()
	var alignment := muzzle_fwd.dot(to_target_dir)
	return alignment >= (1.0 - tolerance)
