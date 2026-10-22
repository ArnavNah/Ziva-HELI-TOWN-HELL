extends Node3D
## Napalm persists for three seconds and ticks only enemy damage receivers.
var radius: float = 5.0
var attacker: Node
var time_left: float = 3.0
var tick_time: float = 0.0

func _ready() -> void:
	add_to_group("combat_explosions")
	var mesh := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = 0.08
	shape.radial_segments = 12
	mesh.mesh = shape
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.6, 0.18, 0.03, 0.35)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material_override = material
	add_child(mesh)

func _physics_process(delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		queue_free()
		return
	tick_time += delta
	if tick_time < 0.5:
		return
	tick_time = 0.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy is Node3D:
			continue
		if absf(enemy.global_position.y - global_position.y) > 4.0 or enemy.global_position.distance_to(global_position) > radius:
			continue
		var receiver = enemy.get_node_or_null("DamageReceiver")
		if receiver:
			var data = preload("res://src/combat/damage_data.gd").new(7.0, GameConstants.WeaponType.ROCKET, attacker if is_instance_valid(attacker) else null)
			receiver.take_damage(data)
