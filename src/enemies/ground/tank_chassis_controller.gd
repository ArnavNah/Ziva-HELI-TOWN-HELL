class_name TankChassisController
extends Node3D

var _damage_receiver: Node = null

## Tank Chassis Motion Controller for Modular Tanks.
## Simulates restrained cosmetic chassis acceleration/braking pitch and turning roll,
## driven by actual planar movement and velocity changes.
## Stops animating when wall-blocked or stationary, ignores vertical displacement/teleports,
## and carries the turret mounting frame without opening gaps.

const TankModelConfigClass = preload("res://src/enemies/ground/tank_model_config.gd")

@export var config: Resource

@onready var chassis_motion: Node3D = get_node_or_null("ChassisMotion")
@onready var hull_model: Node3D = get_node_or_null("ChassisMotion/HullModel")

var _parent_body: CharacterBody3D
var _turret_node: Node3D
var _turret_bind_pos: Vector3 = Vector3.ZERO
var _prev_pos: Vector3 = Vector3.INF
var _prev_speed: float = 0.0
var _prev_yaw: float = 0.0
var _current_pitch: float = 0.0
var _current_roll: float = 0.0

func _ready() -> void:
	_find_parent_body()
	_resolve_turret()

func _find_parent_body() -> void:
	var p = get_parent()
	while p:
		if p is CharacterBody3D:
			_parent_body = p
			_damage_receiver = _parent_body.get_node_or_null("DamageReceiver")
			break
		p = p.get_parent()

func _resolve_turret() -> void:
	if not _parent_body:
		_find_parent_body()
	if _parent_body:
		_turret_node = _parent_body.get_node_or_null("Turret")
		if _turret_node:
			var s := _turret_node.scale.y
			if config and config.turret_mount_offset != Vector3.ZERO:
				_turret_bind_pos = config.turret_mount_offset * s
			else:
				_turret_bind_pos = _turret_node.position

func reset_teleport() -> void:
	_prev_pos = Vector3.INF
	_prev_speed = 0.0
	_current_pitch = 0.0
	_current_roll = 0.0
	if chassis_motion:
		chassis_motion.rotation = Vector3.ZERO
	if _turret_node:
		_turret_node.rotation.x = 0.0
		_turret_node.rotation.z = 0.0
		_turret_node.position = _turret_bind_pos
	if _parent_body and is_instance_valid(_parent_body):
		var fwd = -_parent_body.global_transform.basis.z
		_prev_yaw = atan2(fwd.x, -fwd.z)

func _physics_process(delta: float) -> void:
	if delta <= 0.0:
		return
	if not _parent_body or not is_instance_valid(_parent_body):
		_find_parent_body()
		if not _parent_body:
			return

	if not _turret_node or not is_instance_valid(_turret_node):
		_resolve_turret()
	elif config and config.turret_mount_offset != Vector3.ZERO:
		_turret_bind_pos = config.turret_mount_offset * _turret_node.scale.y

	# Stop animating if enemy is dead or game is paused
	if _damage_receiver and is_instance_valid(_damage_receiver):
		if _damage_receiver.is_dead:
			_settle_to_rest(delta)
			return
	if "behavior_state" in _parent_body and _parent_body.behavior_state == BaseEnemy.BehaviorState.DEAD:
		_settle_to_rest(delta)
		return

	var curr_pos := _parent_body.global_position
	if _prev_pos == Vector3.INF:
		_prev_pos = curr_pos
		var fwd = -_parent_body.global_transform.basis.z
		_prev_yaw = atan2(fwd.x, -fwd.z)
		return

	var disp := curr_pos - _prev_pos
	_prev_pos = curr_pos

	# Teleport/respawn guard: ignore leaps > 4.0m in a single frame
	if disp.length_squared() > 16.0:
		reset_teleport()
		return

	# Planar forward heading (ignores vertical displacement)
	var forward := -_parent_body.global_transform.basis.z
	var planar_forward := Vector3(forward.x, 0.0, forward.z)
	if planar_forward.length_squared() < 0.0001:
		_settle_to_rest(delta)
		return

	planar_forward = planar_forward.normalized()
	var planar_disp := Vector3(disp.x, 0.0, disp.z)
	var signed_dist := planar_disp.dot(planar_forward)
	var current_speed := signed_dist / delta

	# Acceleration / Braking
	var accel := (current_speed - _prev_speed) / delta
	_prev_speed = current_speed

	# Yaw turning rate
	var current_yaw := atan2(forward.x, -forward.z)
	var yaw_diff := wrapf(current_yaw - _prev_yaw, -PI, PI)
	var yaw_rate := yaw_diff / delta
	_prev_yaw = current_yaw

	# 1. PITCH (Acceleration / Braking)
	# Braking (accel < 0) dips nose down (negative rotation around local X).
	# Accelerating (accel > 0) lifts nose up (positive rotation around local X).
	var max_pitch_rad := deg_to_rad(config.max_pitch_settle_deg if config else 2.2)
	var target_pitch := clampf(-accel * 0.0035, -max_pitch_rad, max_pitch_rad)

	# 2. ROLL (Turn inertia)
	# Turning right (yaw_rate > 0) rolls chassis outward to the left (negative roll around Z).
	var max_roll_rad := deg_to_rad(config.max_roll_settle_deg if config else 1.8)
	var target_roll := clampf(-yaw_rate * 0.015, -max_roll_rad, max_roll_rad)

	# Stop animating if stationary or wall-blocked
	if absf(current_speed) < 0.05 and absf(yaw_rate) < 0.05:
		target_pitch = 0.0
		target_roll = 0.0

	var p_speed: float = config.chassis_pitch_speed if config else 6.0
	var r_speed: float = config.chassis_roll_speed if config else 7.0
	var ret_speed: float = config.chassis_return_speed if config else 8.0

	var effective_p_speed := p_speed if absf(target_pitch) > absf(_current_pitch) else ret_speed
	var effective_r_speed := r_speed if absf(target_roll) > absf(_current_roll) else ret_speed

	_current_pitch = move_toward(_current_pitch, target_pitch, delta * effective_p_speed * max_pitch_rad)
	_current_roll = move_toward(_current_roll, target_roll, delta * effective_r_speed * max_roll_rad)

	# Apply chassis pitch and roll to ChassisMotion
	if chassis_motion:
		chassis_motion.rotation.x = _current_pitch
		chassis_motion.rotation.z = _current_roll

	# Synchronize Turret so it tilts with the chassis roof without opening any gap
	if _turret_node and is_instance_valid(_turret_node):
		var tilt_basis := Basis.from_euler(Vector3(_current_pitch, 0.0, _current_roll))
		_turret_node.position = tilt_basis * _turret_bind_pos
		_turret_node.rotation.x = _current_pitch
		_turret_node.rotation.z = _current_roll

func _settle_to_rest(delta: float) -> void:
	var ret_speed: float = config.chassis_return_speed if config else 8.0
	_current_pitch = move_toward(_current_pitch, 0.0, delta * ret_speed * 0.05)
	_current_roll = move_toward(_current_roll, 0.0, delta * ret_speed * 0.05)
	if chassis_motion:
		chassis_motion.rotation.x = _current_pitch
		chassis_motion.rotation.z = _current_roll
	if _turret_node and is_instance_valid(_turret_node):
		var tilt_basis := Basis.from_euler(Vector3(_current_pitch, 0.0, _current_roll))
		_turret_node.position = tilt_basis * _turret_bind_pos
		_turret_node.rotation.x = _current_pitch
		_turret_node.rotation.z = _current_roll
