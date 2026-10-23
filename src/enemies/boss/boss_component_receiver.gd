extends "res://src/combat/damage_receiver.gd"

func _notify_event_bus(_data: RefCounted) -> void:
	# Components are weak points of one enemy, not additional kills or loot sources.
	pass
