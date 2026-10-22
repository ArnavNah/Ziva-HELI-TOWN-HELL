class_name TankModelConfig
extends Resource

## Configuration resource defining geometry, scale, bind transforms, pitch limits,
## recoil parameters, and chassis dynamics for an articulated enemy tank.

@export var model_name: String = ""
@export var assigned_role: String = ""

# Visual Scaling and Ground Alignment
@export var visual_scale: float = 1.0
@export var ground_contact_lift: float = 0.0
@export var hull_center_offset_z: float = 0.0

# Mount Positions in Godot World-Scale Coordinates (relative to vehicle root at Y=0)
@export var turret_mount_offset: Vector3 = Vector3.ZERO
@export var gun_hinge_offset: Vector3 = Vector3.ZERO
@export var muzzle_offset: Vector3 = Vector3.ZERO

# Elevation and Traverse Limits (in degrees)
@export var min_pitch_deg: float = -8.0   # Depression limit (downward)
@export var max_pitch_deg: float = 50.0   # Elevation limit (upward)
@export var turn_speed_deg: float = 120.0 # Turret traverse rate in deg/s
@export var pitch_speed_deg: float = 90.0 # Gun elevation rate in deg/s
@export var default_aim_tolerance_deg: float = 15.0

# Recoil Parameters
@export var recoil_distance: float = 0.12 # Backward kick in meters along local +Z
@export var recoil_recovery_time: float = 0.20 # Recovery duration in seconds

# Rotary Barrels (Sentinel specific)
@export var has_rotary_barrels: bool = false
@export var barrel_bore_offset: Vector3 = Vector3.ZERO
@export var windup_spin_speed: float = 28.0 # rad/s
@export var fire_spin_speed: float = 42.0   # rad/s

# Chassis Motion Dynamics
@export var max_pitch_settle_deg: float = 2.2
@export var max_roll_settle_deg: float = 1.8
@export var chassis_pitch_speed: float = 6.0
@export var chassis_roll_speed: float = 7.0
@export var chassis_return_speed: float = 8.0
