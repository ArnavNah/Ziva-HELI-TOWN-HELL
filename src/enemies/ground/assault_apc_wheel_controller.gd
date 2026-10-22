class_name AssaultAPCWheelController
extends Node3D

## Drives wheel spin and front-wheel steering from actual physical movement of Assault APC.
## - Spins wheels based on planar traveled distance projected onto vehicle forward.
## - Stops spinning when wall-blocked or stationary.
## - Smoothly steers front wheels up to max_steer_angle_deg, leaving rear wheels fixed.
## - Reverses spin on reverse motion.
## - Ignores vertical displacement and teleports.

@export var wheel_radius: float = 0.58 # Calibrated game wheel radius in meters
@export var max_steer_angle_deg: float = 22.0 # Cosmetic steering limit
@export var steer_speed: float = 8.0 # Steering lerp response rate

@onready var fl_steer: Node3D = get_node_or_null("Wheels/FrontLeftSteer")
@onready var fr_steer: Node3D = get_node_or_null("Wheels/FrontRightSteer")
@onready var fl_spin: Node3D = get_node_or_null("Wheels/FrontLeftSteer/FrontLeftSpin")
@onready var fr_spin: Node3D = get_node_or_null("Wheels/FrontRightSteer/FrontRightSpin")
@onready var rl_spin: Node3D = get_node_or_null("Wheels/RearLeftSpin")
@onready var rr_spin: Node3D = get_node_or_null("Wheels/RearRightSpin")

var _parent_body: CharacterBody3D
var _prev_pos: Vector3 = Vector3.INF
var _prev_yaw: float = 0.0
var _current_steer: float = 0.0

func _ready() -> void:
	_find_parent_body()

func _find_parent_body() -> void:
	var p = get_parent()
	while p:
		if p is CharacterBody3D:
			_parent_body = p
			break
		p = p.get_parent()

func reset_teleport() -> void:
	_prev_pos = Vector3.INF
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

	# Stop animating if enemy is dead or game is paused
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

	# Teleport/respawn guard: ignore leaps > 4.0m in a single frame
	if disp.length_squared() > 16.0:
		var fwd = -_parent_body.global_transform.basis.z
		_prev_yaw = atan2(fwd.x, -fwd.z)
		return

	# 1. WHEEL SPIN
	# Projected onto vehicle planar forward heading (ignores vertical displacement)
	var forward := -_parent_body.global_transform.basis.z
	var planar_forward := Vector3(forward.x, 0.0, forward.z)
	if planar_forward.length_squared() > 0.0001:
		planar_forward = planar_forward.normalized()
		var planar_disp := Vector3(disp.x, 0.0, disp.z)
		var signed_dist := planar_disp.dot(planar_forward)

		# Scale effective radius by root scale (handles ELITE modifier scaling)
		var eff_radius := wheel_radius * _parent_body.scale.x
		if eff_radius > 0.01 and absf(signed_dist) > 0.0001:
			var angle_delta := signed_dist / eff_radius
			if fl_spin:
				fl_spin.rotate_x(-angle_delta)
			if fr_spin:
				fr_spin.rotate_x(-angle_delta)
			if rl_spin:
				rl_spin.rotate_x(-angle_delta)
			if rr_spin:
				rr_spin.rotate_x(-angle_delta)

	# 2. FRONT WHEEL STEERING
	# Driven by vehicle turning / yaw rate around vehicle forward (-Z)
	var current_forward := -_parent_body.global_transform.basis.z
	var current_yaw := atan2(current_forward.x, -current_forward.z)
	var yaw_delta := wrapf(current_yaw - _prev_yaw, -PI, PI)
	_prev_yaw = current_yaw

	var target_steer := 0.0
	if absf(yaw_delta) > 0.0005:
		var yaw_rate := yaw_delta / delta
		var max_steer_rad := deg_to_rad(max_steer_angle_deg)
		# In Godot (-Z forward, +X right), a rightward heading yaw (toward +X, yaw_rate > 0)
		# requires a negative local Y steer rotation on the wheel pivot to point toward +X.
		target_steer = -clampf(yaw_rate * 0.35, -max_steer_rad, max_steer_rad)

	_current_steer = lerpf(_current_steer, target_steer, clampf(delta * steer_speed, 0.0, 1.0))
	if fl_steer:
		fl_steer.rotation.y = _current_steer
	if fr_steer:
		fr_steer.rotation.y = _current_steer
