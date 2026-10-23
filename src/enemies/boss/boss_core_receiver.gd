extends "res://src/combat/damage_receiver.gd"
var component_transfer := false

func take_damage(data: RefCounted) -> float:
	var boss := get_parent()
	if not component_transfer and boss.has_method("core_exposed") and not boss.core_exposed():
		return 0.0
	return super.take_damage(data)
