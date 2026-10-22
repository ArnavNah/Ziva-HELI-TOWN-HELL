class_name EndlessOverdrive
extends Node

## EndlessOverdrive — Paces post-boss continuation beyond Wave 10 with 1.25x scaling (Page 12).

var is_endless_active: bool = false
var escalation_multiplier: float = 1.25

func activate_endless_overdrive() -> void:
	is_endless_active = true
	if has_node("/root/CombatDirector"):
		var cd = get_node("/root/CombatDirector")
		cd._setup_wave(11)
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		gm.change_state(gm.RunState.ACTIVE)
