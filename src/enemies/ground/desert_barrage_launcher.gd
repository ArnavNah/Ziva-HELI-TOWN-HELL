class_name DesertBarrageLauncher
extends Node3D

## Articulated Missile Barrage Launcher Controller for Desert Barrage Rover.
## - Features 8 distinct tube outlets (2 pods x 4 tubes) with deterministic alternating-pod sequencing.
## - Preserves supplied angled launcher rest pose.
## - Independent yaw tracking and elevation hinge clamping.
## - Mechanical elevation reachability check preventing shots at impossible angles.
## - Pure query methods (get_muzzle_position, get_muzzle_transform) do NOT advance the tube index.
## - Tube index advances strictly when a shot is actually emitted (via play_recoil).
## - Synchronizes telegraphs, LOS checks, muzzle flash, and projectile spawns to the same active tube.

@export var min_elevation_deg: float = -5.0   # Depression limit
@export var max_elevation_deg: float = 60.0   # Upward elevation limit
@export var rest_elevation_deg: float = 14.0  # Angled rest pose

@onready var mount_model: Node3D = get_node_or_null("MountModel")
@onready var launcher_pitch: Node3D = get_node_or_null("LauncherPitch")
@onready var pod_model: Node3D = get_node_or_null("LauncherPitch/PodModel")
@onready var tubes_parent: Node3D = get_node_or_null("LauncherPitch/Tubes")

var _tubes: Array[Marker3D] = []
var _current_tube_index: int = 0
var _parent_body: Node3D

func _ready() -> void:
	_collect_tubes()
	_find_parent()
	if launcher_pitch:
		launcher_pitch.rotation.x = deg_to_rad(rest_elevation_deg)

func _collect_tubes() -> void:
	_tubes.clear()
	var tp = tubes_parent if tubes_parent else get_node_or_null("LauncherPitch/Tubes")
	if tp:
		for child in tp.get_children():
			if child is Marker3D:
				_tubes.append(child)
	_current_tube_index = 0

func _find_parent() -> void:
	var p = get_parent()
	while p:
		if p is CharacterBody3D:
			_parent_body = p
			break
		p = p.get_parent()

func reset_pose_or_teleport_sampling() -> void:
	_current_tube_index = 0
	if launcher_pitch:
		launcher_pitch.rotation.x = deg_to_rad(rest_elevation_deg)

func get_active_tube() -> Marker3D:
	if _tubes.is_empty():
		_collect_tubes()
	if _tubes.is_empty():
		return null
	var idx := wrapi(_current_tube_index, 0, _tubes.size())
	return _tubes[idx]

func get_muzzle_position() -> Vector3:
	var tube := get_active_tube()
	if tube and is_instance_valid(tube) and is_inside_tree():
		return tube.global_position
	var lp = launcher_pitch if launcher_pitch else get_node_or_null("LauncherPitch")
	if lp and is_instance_valid(lp) and is_inside_tree():
		return lp.global_position
	return (global_position + Vector3.UP * 0.8) if is_inside_tree() else Vector3.UP * 0.8

func get_muzzle_transform() -> Transform3D:
	var tube := get_active_tube()
	if tube and is_instance_valid(tube) and is_inside_tree():
		return tube.global_transform
	return global_transform if is_inside_tree() else Transform3D.IDENTITY

func play_recoil() -> void:
	# Advance tube strictly on actual fire emission
	if not _tubes.is_empty():
		_current_tube_index = (_current_tube_index + 1) % _tubes.size()

func track_aim(target_point: Vector3, delta: float, turn_speed_deg: float = 120.0, tolerance_deg: float = 24.0) -> bool:
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

	# 2. PITCH ELEVATION
	var raw_pitch: float = 0.0
	var min_pitch_rad := deg_to_rad(min_elevation_deg)
	var max_pitch_rad := deg_to_rad(max_elevation_deg)

	if launcher_pitch:
		var target_in_launcher := to_local(target_point)
		var to_target_pitch := target_in_launcher - launcher_pitch.position
		var horiz_dist := Vector2(to_target_pitch.x, to_target_pitch.z).length()
		raw_pitch = atan2(to_target_pitch.y, maxf(horiz_dist, 0.01))

		var clamped_pitch := clampf(raw_pitch, min_pitch_rad, max_pitch_rad)
		var pitch_diff := clamped_pitch - launcher_pitch.rotation.x
		if absf(pitch_diff) <= max_step:
			launcher_pitch.rotation.x = clamped_pitch
		else:
			launcher_pitch.rotation.x += signf(pitch_diff) * max_step

	# 3. MECHANICAL REACHABILITY & ALIGNMENT
	if raw_pitch < min_pitch_rad or raw_pitch > max_pitch_rad:
		return false

	var muzzle_fwd := -get_muzzle_transform().basis.z.normalized()
	var to_target_dir := (target_point - get_muzzle_position()).normalized()
	var angle_err_deg := rad_to_deg(muzzle_fwd.angle_to(to_target_dir))
	return angle_err_deg <= tolerance_deg
