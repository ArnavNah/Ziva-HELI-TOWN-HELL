class_name RadarTower
extends StaticBody3D

## RadarTower — Empowers nearby SAM lock speed by 1.2x.
## On destruction releases a 30-damage shockwave to active enemies (Page 13).

const GameConstants = preload("res://data/game_constants.gd")
const DamageReceiverScript = preload("res://src/combat/damage_receiver.gd")
const DamageDataClass = preload("res://src/combat/damage_data.gd")

@onready var damage_receiver: Node = $DamageReceiver
@onready var dish_mesh: Node3D = $DishPivot

var is_destroyed: bool = false

func _ready() -> void:
	collision_layer = 2
	collision_mask = 5
	add_to_group("radar_towers")
	add_to_group("installations")
	_setup_receiver()

func _setup_receiver() -> void:
	if not damage_receiver:
		damage_receiver = get_node_or_null("DamageReceiver")
	if damage_receiver:
		damage_receiver.max_health = 220.0 # Base hull 220 (Page 13)
		damage_receiver.current_health = 220.0
		damage_receiver.target_affinity = GameConstants.TargetAffinity.STRUCTURE
		damage_receiver.destroyed.connect(_on_destroyed)

func _process(delta: float) -> void:
	if not is_destroyed and dish_mesh:
		dish_mesh.rotate_y(delta * 2.5)

func _on_destroyed(_data: RefCounted) -> void:
	if is_destroyed:
		return
	is_destroyed = true
	remove_from_group("radar_towers")

	# Payout: 45 secured credits, 4 salvage, threat +7 (Page 13)
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		gm.add_banked_credits(45)
		gm.add_salvage(4)
		gm.add_threat(7.0)
		gm.counted_objectives += 1

	# Shockwave: 30 damage to active enemies
	_trigger_radar_shockwave()

func _trigger_radar_shockwave() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var blast_data = DamageDataClass.new(30.0, GameConstants.WeaponType.ROCKET, self, false, 0.0)
	for e in enemies:
		if is_instance_valid(e) and e.has_node("DamageReceiver"):
			e.get_node("DamageReceiver").take_damage(blast_data)
