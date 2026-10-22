class_name LandingZone
extends Node3D

## LandingZone — Manages extraction opportunity, hold envelope, progress decay,
## and successful run settlement (Page 22 & 36).

const GameConstants = preload("res://data/game_constants.gd")

signal extraction_progress_changed(current_sec: float, total_sec: float)
signal extraction_completed()

@export var required_hold_time: float = 12.0 # Normal 12s (Page 22)
@export var zone_radius: float = 22.0
@export var max_vertical_offset: float = 48.0 # Within 48 vertical units

var current_hold_time: float = 0.0
var is_player_inside: bool = false
var is_completed: bool = false

@onready var indicator_mesh: MeshInstance3D = $MeshInstance3D
@onready var progress_label: Label3D = $ProgressLabel

func _ready() -> void:
	# Ensure altitude is safely below 60.0 ceiling (Page 25)
	global_position.y = clampf(global_position.y, 2.0, 45.0)

func _process(delta: float) -> void:
	if is_completed:
		return

	var player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if not player or not is_instance_valid(player):
		return

	# Evaluate horizontal distance and vertical tolerance
	var p_horiz = Vector2(player.global_position.x, player.global_position.z)
	var my_horiz = Vector2(global_position.x, global_position.z)
	var vert_diff = absf(player.global_position.y - global_position.y)

	if p_horiz.distance_to(my_horiz) <= zone_radius and vert_diff <= max_vertical_offset:
		is_player_inside = true
		current_hold_time += delta
		if current_hold_time >= required_hold_time:
			_complete_extraction()
	else:
		is_player_inside = false
		# Leaving reduces progress at 0.18 per second (Page 22)
		current_hold_time = maxf(0.0, current_hold_time - delta * 0.18)

	_update_feedback()

func _update_feedback() -> void:
	extraction_progress_changed.emit(current_hold_time, required_hold_time)
	if progress_label:
		if is_player_inside:
			progress_label.text = "EXTRACTING: %.1f / %.1fs" % [current_hold_time, required_hold_time]
		else:
			progress_label.text = "LZ READY: HOLD TO EXTRACT"

func _complete_extraction() -> void:
	is_completed = true
	extraction_completed.emit()
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").settle_extraction(true)
