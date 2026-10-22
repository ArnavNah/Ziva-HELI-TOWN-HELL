class_name PlayerCamera
extends Camera3D

## PlayerCamera — Tactical combat chase camera with cool lazy follow animation,
## dual-rate inertia damping, dynamic banking roll tilt, organic airborne float,
## speed-dependent pull-back & FOV breathing, and trauma shake response.

@export var target_node: Node3D
@export var base_distance: float = 35.0
@export var max_speed_distance: float = 39.0
@export var base_height: float = 33.5
@export var look_ahead_base: float = 7.0
@export var look_ahead_speed_factor: float = 2.0
@export var base_fov: float = 50.0

var current_cam_yaw: float = 0.0
var smoothed_target_pos: Vector3 = Vector3.ZERO
var current_look_target: Vector3 = Vector3.ZERO
var is_initialized: bool = false
var trauma: float = 0.0

# Lazy Follow & Banking Dynamics
var current_cam_roll: float = 0.0
var current_cam_dist: float = 35.0
var current_cam_height: float = 33.5
var organic_float_time: float = 0.0
var lazy_look_point: Vector3 = Vector3.ZERO
var current_occlusion_factor: float = 1.0
var last_update_process_frame: int = -1

func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)

func _ready() -> void:
	current = true
	top_level = true # Decouples camera transform from direct parent hierarchy
	fov = base_fov
	current_cam_dist = base_distance
	current_cam_height = base_height
	if target_node:
		init_camera(target_node)

func init_camera(target: Node3D) -> void:
	target_node = target
	smoothed_target_pos = target.global_position
	current_cam_dist = base_distance
	current_cam_height = base_height

	var forward: Vector3 = -target.global_transform.basis.z.normalized()
	current_cam_yaw = atan2(forward.x, forward.z)
	current_cam_roll = 0.0

	var cam_dir = Vector3(sin(current_cam_yaw), 0.0, cos(current_cam_yaw))
	global_position = smoothed_target_pos - (cam_dir * base_distance) + Vector3(0, base_height, 0)

	current_look_target = smoothed_target_pos + (cam_dir * look_ahead_base) + Vector3(0, -2.0, 0)
	lazy_look_point = current_look_target
	look_at(current_look_target, Vector3.UP)
	is_initialized = true

func _process(delta: float) -> void:
	update_camera(delta)

func update_camera(delta: float) -> void:
	if not is_inside_tree():
		return
	if Engine.get_process_frames() == last_update_process_frame:
		return
	last_update_process_frame = Engine.get_process_frames()
	if not target_node or not is_instance_valid(target_node) or not target_node.is_inside_tree():
		return
	if not is_initialized:
		init_camera(target_node)

	var target_transform := target_node.global_transform
	var target_pos: Vector3 = target_transform.origin
	var target_forward: Vector3 = -target_transform.basis.z.normalized()

	var speed: float = 0.0
	var vel_x: float = 0.0
	var vel_z: float = 0.0
	if "velocity" in target_node:
		var v: Vector3 = target_node.velocity
		speed = Vector2(v.x, v.z).length()
		vel_x = v.x
		vel_z = v.z

	var ref_speed: float = 34.0
	if "cruise_speed" in target_node:
		ref_speed = target_node.cruise_speed
	var speed_ratio: float = clampf(speed / maxf(ref_speed, 1.0), 0.0, 1.0)

	# 1. Dynamic Speed Pull-Back & Lazy Distance / Height Interpolation
	var target_dist: float = base_distance + (speed_ratio * (max_speed_distance - base_distance))
	var target_height: float = base_height + speed_ratio * 1.5
	var target_lookahead: float = look_ahead_base + (speed_ratio * look_ahead_speed_factor)

	# Smooth lazy damping for distance and height
	current_cam_dist = lerpf(current_cam_dist, target_dist, 1.0 - exp(-6.5 * delta))
	current_cam_height = lerpf(current_cam_height, target_height, 1.0 - exp(-6.5 * delta))

	# 2. Responsive Angular Follow (Maintains sustained-turn yaw lag below 5.0 degrees)
	var desired_yaw: float = atan2(target_forward.x, target_forward.z)
	var yaw_damping: float = 1.0 - exp(-30.0 * delta)
	current_cam_yaw = lerp_angle(current_cam_yaw, desired_yaw, yaw_damping)

	# 3. Dual-Rate Responsive Position Tracking (Tight street-canyon tracking + cushioned vertical spring)
	var horiz_damping: float = 1.0 - exp(-13.0 * delta)
	var vert_damping: float = 1.0 - exp(-13.0 * delta)
	smoothed_target_pos.x = lerpf(smoothed_target_pos.x, target_pos.x, horiz_damping)
	smoothed_target_pos.z = lerpf(smoothed_target_pos.z, target_pos.z, horiz_damping)
	smoothed_target_pos.y = lerpf(smoothed_target_pos.y, target_pos.y, vert_damping)

	# 4. Restrained Airborne Float (Subtle atmospheric micro-currents without idle wandering)
	organic_float_time += delta
	var float_offset := Vector3.ZERO
	var is_dying: bool = "is_dying" in target_node and target_node.is_dying
	if not is_dying:
		var float_y = (sin(organic_float_time * 1.6) * 0.05 + sin(organic_float_time * 3.2) * 0.02) * (1.0 - speed_ratio * 0.5)
		var float_x = cos(organic_float_time * 1.2) * 0.03 * (1.0 - speed_ratio * 0.5)
		float_offset = Vector3(float_x, float_y, 0.0)

	# 5. Compute World Position with Guaranteed Orbital Radius & Lazy Cushion
	var cam_dir: Vector3 = Vector3(sin(current_cam_yaw), 0.0, cos(current_cam_yaw))
	var focus_point: Vector3 = smoothed_target_pos + Vector3(0.0, 1.4, 0.0)
	var desired_cam_pos: Vector3 = focus_point - (cam_dir * current_cam_dist) + Vector3(0, current_cam_height - 1.4, 0) + float_offset
	var ray_dist: float = (desired_cam_pos - focus_point).length()
	var target_occ_factor: float = 1.0

	# Urban Canyon Camera Occlusion Check: Prevents skyscraper geometry from blocking line-of-sight
	if is_inside_tree():
		var direct_space = get_world_3d().direct_space_state
		if direct_space:
			var ray_query = PhysicsRayQueryParameters3D.create(focus_point, desired_cam_pos, 2) # Layer 2: World / Buildings
			var hit = direct_space.intersect_ray(ray_query)
			if not hit.is_empty():
				var hit_dist: float = (hit.position - focus_point).length()
				var safe_dist: float = maxf(8.0, hit_dist - 1.5)
				target_occ_factor = clampf(safe_dist / maxf(ray_dist, 1.0), 0.22, 1.0)

	var occ_speed: float = 14.0 if target_occ_factor < current_occlusion_factor else 4.5
	current_occlusion_factor = lerpf(current_occlusion_factor, target_occ_factor, 1.0 - exp(-occ_speed * delta))
	var target_cam_pos: Vector3 = focus_point + (desired_cam_pos - focus_point) * current_occlusion_factor
	global_position = target_cam_pos

	# Camera Shake / Trauma from impacts and explosions
	if trauma > 0.0:
		trauma = maxf(0.0, trauma - delta * 1.5)
		var shake = trauma * trauma
		if has_node("/root/AudioManager"):
			shake *= [0.0, 0.3, 1.0][clampi(get_node("/root/AudioManager").screen_shake_level, 0, 2)]
		var shake_offset = Vector3(
			randf_range(-1.0, 1.0) * 1.8 * shake,
			randf_range(-1.0, 1.0) * 1.4 * shake,
			randf_range(-1.0, 1.0) * 1.8 * shake
		)
		global_position += shake_offset

	# 6. Lazy Dynamic Look-Ahead Tracking
	var forward_look: Vector3 = cam_dir * target_lookahead + Vector3(vel_x * 0.035, 0.0, vel_z * 0.035)
	var raw_look_target: Vector3 = smoothed_target_pos + forward_look + Vector3(0, -2.0, 0)
	lazy_look_point = lazy_look_point.lerp(raw_look_target, 1.0 - exp(-9.0 * delta))
	current_look_target = lazy_look_point

	# 7. Cool Dynamic Banking / Roll Tilt Follow
	var target_bank_angle: float = 0.0
	if "bank_angle" in target_node:
		target_bank_angle = target_node.bank_angle
	elif "visual_bank" in target_node:
		target_bank_angle = target_node.visual_bank

	# Subtle roll tilt (10% of aircraft bank, restrained to +/- 2.5 degrees for stable combat crosshairs)
	var desired_cam_roll = clampf(target_bank_angle * 0.10, -deg_to_rad(2.5), deg_to_rad(2.5))
	current_cam_roll = lerpf(current_cam_roll, desired_cam_roll, 1.0 - exp(-7.0 * delta))

	# Compute orientation with dynamic roll tilt
	var cam_fwd = (current_look_target - global_position).normalized()
	var cam_up = Vector3.UP
	if abs(current_cam_roll) > 0.001:
		cam_up = cam_up.rotated(cam_fwd, current_cam_roll)

	look_at(current_look_target, cam_up)

	# 8. Dynamic Speed FOV
	fov = lerpf(base_fov, base_fov + 2.0, speed_ratio)
