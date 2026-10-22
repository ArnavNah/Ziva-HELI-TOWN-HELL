class_name PlayerCountermeasures
extends Node

## PlayerCountermeasures — Manages flare deployment, decoy heat signature window,
## and homing missile diversion (Page 13 & 33).

signal flares_deployed(charges_left: int)
signal charges_replenished(current_charges: int, max_charges: int)

@export var max_charges: int = GameConstants.FLARE_BASE_CHARGES
@export var cooldown_duration: float = GameConstants.FLARE_BASE_COOLDOWN
@export var decoy_window_duration: float = GameConstants.FLARE_BASE_DECOY_WINDOW

var current_charges: int = GameConstants.FLARE_BASE_CHARGES
var cooldown_timer: float = 0.0
var decoy_window_timer: float = 0.0
var is_decoy_active: bool = false

@export var player_helicopter: CharacterBody3D

func _ready() -> void:
	current_charges = max_charges

func _process(delta: float) -> void:
	if has_node("/root/UIFlow") and not get_node("/root/UIFlow").gameplay_input_allowed():
		return
	if cooldown_timer > 0.0:
		cooldown_timer -= delta

	if is_decoy_active:
		decoy_window_timer -= delta
		if decoy_window_timer <= 0.0:
			is_decoy_active = false

	if Input.is_action_just_pressed("deploy_flares"):
		try_deploy_flares()

func deploy_flares() -> bool:
	return try_deploy_flares()

func try_deploy_flares() -> bool:
	if current_charges <= 0 or cooldown_timer > 0.0:
		return false

	current_charges -= 1
	cooldown_timer = cooldown_duration
	is_decoy_active = true
	decoy_window_timer = decoy_window_duration

	_divert_incoming_missiles()

	flares_deployed.emit(current_charges)
	if is_inside_tree() and has_node("/root/EventBus"):
		get_node("/root/EventBus").flares_deployed.emit(current_charges)

	return true

func _divert_incoming_missiles() -> void:
	if not player_helicopter:
		return

	var my_pos = player_helicopter.global_position
	# Find all active projectiles in group or tree
	var projectiles = get_tree().get_nodes_in_group("homing_missiles")
	for m in projectiles:
		if m is Node3D and is_instance_valid(m) and m.get("is_homing"):
			var d = my_pos.distance_to(m.global_position)
			# Page 13: Within 135 units diverted; 135-190 probabilistic; >190 unaffected
			if d <= GameConstants.FLARE_DIVERSION_CLOSE_RADIUS:
				_divert_missile(m)
			elif d <= GameConstants.FLARE_DIVERSION_OUTER_RADIUS:
				if randf() < 0.60:
					_divert_missile(m)

func _divert_missile(missile: Node3D) -> void:
	# Retarget missile away into empty decoy vector
	if missile.has_method("divert"):
		missile.divert()
	else:
		missile.set("is_homing", false)
		if "velocity" in missile:
			var rand_deflect = Vector3(randf_range(-1, 1), randf_range(0.5, 1.5), randf_range(-1, 1)).normalized()
			missile.set("velocity", rand_deflect * (missile.get("velocity") as Vector3).length())

func replenish_charges(amount: int = 1) -> void:
	current_charges = mini(max_charges, current_charges + amount)
	charges_replenished.emit(current_charges, max_charges)
