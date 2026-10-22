class_name ScoutBuggyTurret
extends Node3D

## Controller for the articulated Scout Buggy turret.
## Implements yaw at the mount center and independent pitch elevation at the gun trunnion.
## Provides muzzle-origin resolution and barrel recoil.

@export var min_elevation_deg: float = -15.0
@export var max_elevation_deg: float = 60.0
@export var recoil_distance: float = 0.06
@export var recoil_recovery_speed: float = 18.0

var gun_pitch: Node3D
var recoil_node: Node3D
var muzzle: Marker3D

var _current_recoil: float = 0.0
var _recoil_target: float = 0.0

func _ready() -> void:
	gun_pitch = get_node_or_null("GunPitch")
	if gun_pitch:
		recoil_node = gun_pitch.get_node_or_null("Recoil")
	if recoil_node:
		muzzle = recoil_node.get_node_or_null("Muzzle")

func _process(delta: float) -> void:
	if _current_recoil > 0.001 or _recoil_target > 0.001:
		_current_recoil = move_toward(_current_recoil, _recoil_target, delta * recoil_recovery_speed)
		if _recoil_target > 0.0 and _current_recoil >= _recoil_target:
			_recoil_target = 0.0
		if recoil_node:
			# Gun recoils along local +Z (backward relative to barrel facing -Z)
			recoil_node.position.z = _current_recoil

func play_recoil(dist: float = -1.0) -> void:
	var kick = dist if dist > 0.0 else recoil_distance
	_current_recoil = kick
	_recoil_target = 0.0
	if recoil_node:
		recoil_node.position.z = _current_recoil

func get_muzzle_position() -> Vector3:
	if muzzle and is_instance_valid(muzzle):
		return muzzle.global_position
	if gun_pitch and is_instance_valid(gun_pitch):
		return gun_pitch.global_position
	return global_position

func get_muzzle_transform() -> Transform3D:
	if muzzle and is_instance_valid(muzzle):
		return muzzle.global_transform
	return global_transform

## Tracks target position with independent yaw and gun elevation.
## Returns true when aligned within tolerance_deg.
func track_aim(target_pos: Vector3, delta: float, turn_speed_deg: float = 140.0, tolerance_deg: float = 24.0) -> bool:
	if not is_inside_tree():
		return false

	var mount_pos := global_position
	var to_target_world := target_pos - mount_pos
	if to_target_world.length_squared() < 0.01:
		return true

	var max_step_rad := deg_to_rad(turn_speed_deg) * delta

	# --- 1. YAW TRACKING (in vehicle parent space) ---
	var parent_basis := Transform3D.IDENTITY.basis
	if get_parent() is Node3D:
		parent_basis = (get_parent() as Node3D).global_transform.basis.orthonormalized()

	# Convert direction into parent local coordinates
	var local_target_dir := (parent_basis.inverse() * to_target_world).normalized()
	# In vehicle space: -Z is forward, +X is right -> yaw angle
	var target_yaw := atan2(-local_target_dir.x, -local_target_dir.z)

	var yaw_diff := wrapf(target_yaw - rotation.y, -PI, PI)
	rotation.y += clampf(yaw_diff, -max_step_rad, max_step_rad)

	# --- 2. PITCH ELEVATION TRACKING (in Turret local space) ---
	if gun_pitch:
		var trunnion_pos := gun_pitch.global_position
		var to_target_gun := target_pos - trunnion_pos
		# Convert to turret local coordinate frame (after current yaw)
		var turret_basis := global_transform.basis.orthonormalized()
		var dir_in_turret := (turret_basis.inverse() * to_target_gun).normalized()

		var dist_h := sqrt(dir_in_turret.x * dir_in_turret.x + dir_in_turret.z * dir_in_turret.z)
		# Positive elevation angles tilt up towards +Y
		var raw_pitch := atan2(dir_in_turret.y, maxf(dist_h, 0.001))

		var min_elev_rad := deg_to_rad(min_elevation_deg)
		var max_elev_rad := deg_to_rad(max_elevation_deg)
		var clamped_target_pitch := clampf(raw_pitch, min_elev_rad, max_elev_rad)

		var pitch_diff := clamped_target_pitch - gun_pitch.rotation.x
		gun_pitch.rotation.x += clampf(pitch_diff, -max_step_rad, max_step_rad)

	# --- 3. ALIGNMENT VALIDATION ---
	var barrel_facing := -global_transform.basis.z
	if gun_pitch:
		barrel_facing = -gun_pitch.global_transform.basis.z

	var aim_origin := get_muzzle_position()
	var direct_to_target := (target_pos - aim_origin).normalized()
	var angle_err_deg := rad_to_deg(barrel_facing.angle_to(direct_to_target))

	return angle_err_deg <= tolerance_deg
