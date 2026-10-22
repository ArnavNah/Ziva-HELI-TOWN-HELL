class_name VolatileHazard
extends StaticBody3D

## VolatileHazard — Fuel tanks, generators, and explosive containers that trigger
## chain-reaction detonations damaging nearby enemies and structures (Page 23).

const DamageReceiverScript = preload("res://src/combat/damage_receiver.gd")
const DamageDataClass = preload("res://src/combat/damage_data.gd")

@export var blast_radius: float = 22.0
@export var blast_damage: float = 45.0
@export var hazard_name: String = "Fuel Tank"

var has_exploded: bool = false

@onready var damage_receiver: Node = get_node_or_null("DamageReceiver")
@onready var mesh_instance: MeshInstance3D = get_node_or_null("MeshInstance3D")

func _ready() -> void:
	collision_layer = 2
	collision_mask = 5
	if not damage_receiver:
		damage_receiver = get_node_or_null("DamageReceiver")
	if damage_receiver:
		damage_receiver.max_health = 35.0
		damage_receiver.current_health = 35.0
		damage_receiver.target_affinity = GameConstants.TargetAffinity.STRUCTURE
		damage_receiver.destroyed.connect(_on_destroyed)
	if has_node("/root/ShaderManager"):
		get_node("/root/ShaderManager").apply_selective_outline(self, 0.012, Color(0.15, 0.08, 0.08, 0.75))

func _on_destroyed(_data: RefCounted) -> void:
	if has_exploded:
		return
	has_exploded = true
	# Brief delay before explosion for chain-reaction cadence
	await get_tree().create_timer(0.2).timeout
	_detonate()

func _detonate() -> void:
	var space = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = blast_radius
	query.shape = sphere
	query.transform = global_transform
	query.collision_mask = 7 # Enemies (4) + Environment/Hazards (2) + Player (1)

	var results = space.intersect_shape(query, 32)
	var processed_colliders: Array = []
	for r in results:
		var c = r.get("collider")
		if c and c != self and is_instance_valid(c) and not processed_colliders.has(c):
			processed_colliders.append(c)
			var rec = c.get_node_or_null("DamageReceiver")
			if rec and rec.has_method("take_damage"):
				var chain_dmg = DamageDataClass.new(
					blast_damage,
					GameConstants.WeaponType.ROCKET,
					self,
					false,
					blast_radius
				)
				rec.take_damage(chain_dmg)
			elif c.has_method("take_damage"):
				c.take_damage(blast_damage, "Volatile Hazard Detonation")

	visible = false
	collision_layer = 0
	queue_free()
