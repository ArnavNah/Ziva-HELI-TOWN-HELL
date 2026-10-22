class_name ArticulatedTankTurret
extends Node3D

## Universal Articulated Tank Turret Controller for Modular Tanks.
## Handles independent turret yaw, gun elevation around hinge trunnion,
## translational firing recoil with zero cumulative drift, and optional rotary barrel spin.

const TankModelConfigClass = preload("res://src/enemies/ground/tank_model_config.gd")

@export var config: Resource

@onready var mount_model: Node3D = get_node_or_null("MountModel")
@onready var gun_pitch: Node3D = get_node_or_null("GunPitch")
@onready var recoil: Node3D = get_node_or_null("GunPitch/Recoil")
@onready var gun_model: Node3D = get_node_or_null("GunPitch/Recoil/GunModel")
@onready var muzzle: Marker3D = get_node_or_null("GunPitch/Recoil/Muzzle")
@onready var barrel_spin: Node3D = get_node_or_null("GunPitch/Recoil/BarrelSpin")

var _parent_body: CharacterBody3D
var _recoil_bind_pos: Vector3 = Vector3.ZERO
var _current_recoil: float = 0.0
var _recoil_timer: float = 0.0
var _current_barrel_spin: float = 0.0
var _target_barrel_spin: float = 0.0

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
	_current_barrel_spin = 0.0
	_target_barrel_spin = 0.0

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
	var rec_dist: float = config.recoil_distance if config else 0.12
	var rec_time: float = config.recoil_recovery_time if config else 0.20
	_current_recoil = rec_dist
	_recoil_timer = rec_time
	if recoil:
		# Recoil kicks along local +Z in the recoil node (barrel points along local -Z)
		recoil.position = _recoil_bind_pos + Vector3(0.0, 0.0, _current_recoil)

func set_barrel_spin_speed(speed: float) -> void:
	_target_barrel_spin = speed

func _process(delta: float) -> void:
	if delta <= 0.0:
		return

	# 1. Smooth Recoil Recovery with zero cumulative drift
	if _recoil_timer > 0.0:
		_recoil_timer -= delta
		var rec_dist: float = config.recoil_distance if config else 0.12
		var rec_time: float = config.recoil_recovery_time if config else 0.20
		if _recoil_timer <= 0.0:
			_current_recoil = 0.0
			if recoil:
				recoil.position = _recoil_bind_pos
		else:
			var t := clampf(1.0 - (_recoil_timer / rec_time), 0.0, 1.0)
			_current_recoil = lerpf(rec_dist, 0.0, t)
			if recoil:
				recoil.position = _recoil_bind_pos + Vector3(0.0, 0.0, _current_recoil)

	# 2. Rotary Barrels Spin Animation (Sentinel)
	if barrel_spin:
		var spin_accel: float = 45.0 if _target_barrel_spin > _current_barrel_spin else 22.0
		_current_barrel_spin = move_toward(_current_barrel_spin, _target_barrel_spin, delta * spin_accel)
		if absf(_current_barrel_spin) > 0.01:
			# Rotate around local Z (bore axis pointing forward)
			barrel_spin.rotate_z(_current_barrel_spin * delta)

func track_aim(world_target: Vector3, delta: float, turn_speed_deg: float = -1.0, tolerance_deg: float = -1.0) -> bool:
	if not _parent_body or not is_instance_valid(_parent_body):
		_find_parent()
		if not _parent_body:
			return false

	var effective_turn_speed: float = turn_speed_deg if turn_speed_deg > 0.0 else (config.turn_speed_deg if config else 120.0)
	var effective_tolerance: float = tolerance_deg if tolerance_deg > 0.0 else (config.default_aim_tolerance_deg if config else 15.0)

	# 1. YAW ROTATION (Vehicle parent coordinate space)
	var target_in_parent := _parent_body.to_local(world_target)
	var to_target_parent := target_in_parent - position
	var target_yaw := atan2(-to_target_parent.x, -to_target_parent.z)
	var yaw_diff := wrapf(target_yaw - rotation.y, -PI, PI)
	var max_yaw_step := deg_to_rad(effective_turn_speed) * delta

	if absf(yaw_diff) <= max_yaw_step:
		rotation.y = target_yaw
	else:
		rotation.y += signf(yaw_diff) * max_yaw_step

	# 2. PITCH ELEVATION (Gun hinge trunnion space)
	var raw_pitch: float = 0.0
	var min_pitch_rad := deg_to_rad(config.min_pitch_deg if config else -8.0)
	var max_pitch_rad := deg_to_rad(config.max_pitch_deg if config else 50.0)

	if gun_pitch:
		var target_in_turret := to_local(world_target)
		var to_target_gun := target_in_turret - gun_pitch.position
		var horiz_dist := Vector2(to_target_gun.x, to_target_gun.z).length()
		raw_pitch = atan2(to_target_gun.y, maxf(horiz_dist, 0.01))

		var clamped_pitch := clampf(raw_pitch, min_pitch_rad, max_pitch_rad)
		var pitch_speed: float = config.pitch_speed_deg if config else 90.0
		var max_pitch_step := deg_to_rad(pitch_speed) * delta
		var pitch_diff := clamped_pitch - gun_pitch.rotation.x

		if absf(pitch_diff) <= max_pitch_step:
			gun_pitch.rotation.x = clamped_pitch
		else:
			gun_pitch.rotation.x += signf(pitch_diff) * max_pitch_step

	# 3. ALIGNMENT & ELEVATION REACHABILITY CHECK
	# If target is outside mechanical elevation limits, report NOT aligned so AI can reposition
	if raw_pitch < min_pitch_rad or raw_pitch > max_pitch_rad:
		return false

	var barrel_fwd := -get_muzzle_transform().basis.z.normalized()
	var to_target_dir := (world_target - get_muzzle_position()).normalized()
	var angle_err_deg := rad_to_deg(barrel_fwd.angle_to(to_target_dir))

	return angle_err_deg <= effective_tolerance
