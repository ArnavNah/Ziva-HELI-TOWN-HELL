extends Node3D

@onready var player: CharacterBody3D = $PlayerHelicopter
@onready var telemetry_label: Label = $UI/TelemetryLabel

func _ready() -> void:
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").start_new_run("apache")

func _process(_delta: float) -> void:
	if not player or not telemetry_label:
		return
	var speed = Vector2(player.velocity.x, player.velocity.z).length()
	telemetry_label.text = "=== HELI FLIGHT TELEMETRY ===\n"
	telemetry_label.text += "Speed: %5.1f / 72.0 u/s | Vert Speed: %+5.1f u/s\n" % [speed, player.velocity.y]
	telemetry_label.text += "Altitude: %5.1f / 60.0 (Ceiling)\n" % [player.global_position.y]
	telemetry_label.text += "Heading: %5.1f° | Visual Pitch: %4.1f° | Bank: %4.1f°\n" % [
		rad_to_deg(player.rotation.y),
		rad_to_deg(player.visual_pitch),
		rad_to_deg(player.visual_bank)
	]
	telemetry_label.text += "Hull: %3.0f / %3.0f | Fuel: %3.0f / %3.0f\n" % [
		player.current_hull, player.max_hull, player.current_fuel, player.max_fuel
	]
	telemetry_label.text += "Subsystems -> Engine: %3.0f%% | Rotor: %3.0f%%\n" % [
		player.engine_condition, player.rotor_condition
	]
	telemetry_label.text += "Controls: W/S Thrust | A/D Yaw | Q/E Strafe | Space/Shift Climb | Ctrl/C Descend | Alt/X Dash"
