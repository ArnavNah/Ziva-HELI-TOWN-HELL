extends "res://src/combat/damage_receiver.gd"

var friendly: bool = false

func take_damage(data: RefCounted) -> float:
	if friendly and data != null and "attacker" in data and is_instance_valid(data.attacker) and data.attacker.is_in_group("player"):
		return 0.0
	return super.take_damage(data)

func _notify_event_bus(data: RefCounted) -> void:
	# Friendly assets do not count as enemy kills or produce combat rewards.
	if not friendly:
		super._notify_event_bus(data)
