class_name MultiAxleWheelController
extends Node3D

## General Multi-Axle Wheel Controller for Wheeled Ground Enemies.
## Supports arbitrary axle/wheel counts (e.g. 4 wheels for Raptor Raider, 6 wheels for Desert Barrage Rover).
## - Automatically discovers steer and spin pivots under $Wheels.
## - Drives wheel spin from actual planar traveled distance projected onto vehicle heading.
## - Blocks spin when vehicle is wall-blocked or stationary.
## - Inverts spin on reverse motion.
## - Steers front wheels up to max_steer_angle_deg, leaving middle and rear axles fixed.
## - Handles ELITE scale modifier, teleports, death, and pause.

@export var wheel_radius: float = 0.58
@export var max_steer_angle_deg: float = 24.0
@export var steer_speed: float = 8.0

var _parent_body: CharacterBody3D
var _prev_pos: Vector3 = Vector3.INF
var _prev_yaw: float = 0.0
var _current_steer: float = 0.0

var _steer_pivots: Array[Node3D] = []
var _spin_pivots: Array[Node3D] = []

func _ready() -> void:
	_discover_wheel_nodes()
	_find_parent_body()

func _discover_wheel_nodes() -> void:
	_steer_pivots.clear()
	_spin_pivots.clear()
	var wheels_node = get_node_or_null("Wheels")
	if not wheels_node:
		wheels_node = self
	_find_pivots_recursive(wheels_node)

func _find_pivots_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is Node3D:
			var n_name := child.name.to_lower()
			if "steer" in n_name and child not in _steer_pivots:
				_steer_pivots.append(child)
			if "spin" in n_name and child not in _spin_pivots:
				_spin_pivots.append(child)
			_find_pivots_recursive(child)

func _find_parent_body() -> void:
	var p = get_parent()
	while p:
		if p is CharacterBody3D:
			_parent_body = p
			break
		p = p.get_parent()

func reset_teleport() -> void:
	_prev_pos = Vector3.INF
	_current_steer = 0.0
	for steer_node in _steer_pivots:
		if is_instance_valid(steer_node):
			steer_node.rotation.y = 0.0
	if _parent_body and is_instance_valid(_parent_body):
		var fwd = -_parent_body.global_transform.basis.z
		_prev_yaw = atan2(fwd.x, -fwd.z)

func reset_pose_or_teleport_sampling() -> void:
	reset_teleport()

func _physics_process(delta: float) -> void:
	if delta <= 0.0:
		return
	if not _parent_body or not is_instance_valid(_parent_body):
		_find_parent_body()
		if not _parent_body:
			return

	# Stop animating if dead or paused
	if _parent_body.has_node("DamageReceiver"):
		var dr = _parent_body.get_node("DamageReceiver")
		if dr and dr.is_dead:
			return
	if "behavior_state" in _parent_body and _parent_body.behavior_state == BaseEnemy.BehaviorState.DEAD:
		return

	var curr_pos := _parent_body.global_position
	if _prev_pos == Vector3.INF:
		_prev_pos = curr_pos
		var fwd = -_parent_body.global_transform.basis.z
		_prev_yaw = atan2(fwd.x, -fwd.z)
		return

	var disp := curr_pos - _prev_pos
	_prev_pos = curr_pos

	# Teleport / leap guard
	if disp.length_squared() > 16.0:
		var fwd = -_parent_body.global_transform.basis.z
		_prev_yaw = atan2(fwd.x, -fwd.z)
		return

	# 1. WHEEL SPIN
	var forward := -_parent_body.global_transform.basis.z
	var planar_forward := Vector3(forward.x, 0.0, forward.z)
	if planar_forward.length_squared() > 0.0001:
		planar_forward = planar_forward.normalized()
		var planar_disp := Vector3(disp.x, 0.0, disp.z)
		var signed_dist := planar_disp.dot(planar_forward)

		var eff_radius := wheel_radius * _parent_body.scale.x
		if eff_radius > 0.01 and absf(signed_dist) > 0.0001:
			var angle_delta := signed_dist / eff_radius
			for spin_node in _spin_pivots:
				if is_instance_valid(spin_node):
					spin_node.rotate_x(-angle_delta)

	# 2. FRONT WHEEL STEERING
	var current_forward := -_parent_body.global_transform.basis.z
	var current_yaw := atan2(current_forward.x, -current_forward.z)
	var yaw_delta := wrapf(current_yaw - _prev_yaw, -PI, PI)
	_prev_yaw = current_yaw

	var target_steer := 0.0
	if absf(yaw_delta) > 0.0005:
		var yaw_rate := yaw_delta / delta
		var max_steer_rad := deg_to_rad(max_steer_angle_deg)
		target_steer = -clampf(yaw_rate * 0.35, -max_steer_rad, max_steer_rad)

	_current_steer = lerpf(_current_steer, target_steer, clampf(delta * steer_speed, 0.0, 1.0))
	for steer_node in _steer_pivots:
		if is_instance_valid(steer_node):
			steer_node.rotation.y = _current_steer
