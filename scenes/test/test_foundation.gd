extends Node3D

@onready var label: Label = $UI/Label

func _ready() -> void:
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").start_new_run("apache")
	_update_ui()

func _process(_delta: float) -> void:
	_update_ui()

func _update_ui() -> void:
	if not label:
		return
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		label.text = "PHASE 1 FOUNDATION TEST\n"
		label.text += "State: %s | Wave: %d | Time: %.1fs\n" % [gm.RunState.keys()[gm.current_state], gm.current_wave, gm.run_time]
		label.text += "Kills: %d | Score: %d | Combo: x%.1f\n" % [gm.kills_count, gm.score, gm.combo_multiplier]
		label.text += "Banked: %d CR | At-Risk: %d CR | Salvage: %d" % [gm.banked_credits, gm.at_risk_credits, gm.carried_salvage]
