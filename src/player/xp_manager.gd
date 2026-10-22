class_name XpManagerClass
extends Node

## XpManager — Authoritative XP collection and level-up scaling manager.
## Manages total XP, current level, dynamic exponential curve threshold scaling,
## and queued level-up events for the roguelite level-up card draft system.

signal xp_changed(current_xp: int, max_xp: int)
signal level_up(new_level: int)
signal run_reset

@export var current_level: int = 1
@export var current_xp: int = 0
@export var target_xp: int = 25
@export var base_xp_requirement: int = 25
@export var xp_exponent: float = 1.35

var total_xp_collected: int = 0
var queued_level_ups: int = 0
var xp_multiplier: float = 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_recalculate_target_xp()

func _recalculate_target_xp() -> void:
	# Level Scaling Curve Formula:
	# target_xp = int(base_xp_requirement * pow(current_level, xp_exponent))
	target_xp = maxi(10, int(base_xp_requirement * pow(float(current_level), xp_exponent)))

func reset_run() -> void:
	current_level = 1
	current_xp = 0
	total_xp_collected = 0
	queued_level_ups = 0
	xp_multiplier = 1.0
	_recalculate_target_xp()
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").run_xp = 0
	run_reset.emit()
	xp_changed.emit(current_xp, target_xp)

func add_xp(amount: int) -> void:
	if amount <= 0:
		return

	var effective_amount: int = int(round(float(amount) * xp_multiplier))
	current_xp += effective_amount
	total_xp_collected += effective_amount

	# Synchronize with GameManager if available
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		gm.run_xp = total_xp_collected

	# Emit continuous progress signal
	xp_changed.emit(current_xp, target_xp)

	# Handle potential multi-level-up bursts without skipping levels
	while current_xp >= target_xp:
		current_xp -= target_xp
		current_level += 1
		queued_level_ups += 1
		_recalculate_target_xp()
		
		# Emit level up signal for listeners/UI
		level_up.emit(current_level)
		xp_changed.emit(current_xp, target_xp)

func has_pending_level_ups() -> bool:
	return queued_level_ups > 0

func consume_pending_level_up() -> int:
	if queued_level_ups > 0:
		queued_level_ups -= 1
	xp_changed.emit(current_xp, target_xp)
	return queued_level_ups

func get_progress_ratio() -> float:
	if target_xp <= 0:
		return 0.0
	return clampf(float(current_xp) / float(target_xp), 0.0, 1.0)
