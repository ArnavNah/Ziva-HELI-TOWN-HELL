extends Node3D

@onready var label: Label = $UI/Label
@onready var sam: Node3D = $SAMSite
@onready var radar: Node3D = $RadarTower
@onready var player: CharacterBody3D = $PlayerHelicopter

func _ready() -> void:
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").start_new_run("apache")

func _process(_delta: float) -> void:
	if not label or not sam or not player:
		return
	var text = "=== PHASE 6: DEFENSES & SAMS TEST ===\n"
	text += "SAM State: %s | Lock Progress: %.2fs / 1.15s\n" % [
		sam.SAMState.keys()[sam.current_state], sam.lock_timer
	]
	var dist = player.global_position.distance_to(sam.global_position)
	text += "Distance to SAM: %.1f u (Envelope: 38 - 255 u)\n" % [dist]
	
	var cm = player.get_node_or_null("Countermeasures")
	if cm:
		text += "Flares: %d / %d | Cooldown: %.1fs | Decoy Active: %s\n" % [
			cm.current_charges, cm.max_charges, cm.cooldown_timer, str(cm.is_decoy_active)
		]
	
	text += "Press C to Deploy Flares | Destroy Radar to disable 1.2x lock acceleration"
	label.text = text
