extends Node3D

@onready var label: Label = $UI/Label
@onready var mission_mgr: Node = $MissionManager
@onready var cargo_mgr: Node = $CargoManager

func _ready() -> void:
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").start_new_run("apache")
	if mission_mgr:
		mission_mgr.start_mission("defend_beacon")
	if cargo_mgr:
		cargo_mgr.offer_contract("ammunition", 600.0)

func _process(_delta: float) -> void:
	if not label or not mission_mgr or not cargo_mgr:
		return
	var text = "=== PHASE 7: MISSIONS & CARGO TEST ===\n"
	text += "ACTIVE MISSION: %s (Time: %.1fs)\n" % [
		mission_mgr.active_mission_data.get("title", "None"), mission_mgr.mission_timer
	]
	text += "Mission Progress: %.1fs / %.1fs\n\n" % [
		mission_mgr.hold_progress, mission_mgr.active_mission_data.get("hold_time", 25.0)
	]
	text += "CARGO CONTRACT: %s (Base: %d CR | Speed: %d CR)\n" % [
		cargo_mgr.current_contract.get("commodity", "None"),
		cargo_mgr.current_contract.get("base_price", 0),
		cargo_mgr.current_contract.get("speed_bonus", 0)
	]
	text += "Cargo State: %s | Load Hold: %.2fs / 1.0s\n" % [
		cargo_mgr.CargoState.keys()[cargo_mgr.current_state], cargo_mgr.load_hold_timer
	]
	label.text = text
