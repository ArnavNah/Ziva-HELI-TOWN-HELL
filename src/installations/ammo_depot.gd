class_name AmmoDepot
extends StaticBody3D

## AmmoDepot — Critical installation supplying 35 credits, 3 salvage, and ammo refill on destruction (Page 13).

const GameConstants = preload("res://data/game_constants.gd")
const DamageReceiverScript = preload("res://src/combat/damage_receiver.gd")

@onready var damage_receiver: Node = $DamageReceiver

var is_destroyed: bool = false

func _ready() -> void:
	collision_layer = 2
	collision_mask = 5
	add_to_group("ammo_depots")
	add_to_group("installations")
	_setup_receiver()

func _setup_receiver() -> void:
	if not damage_receiver:
		damage_receiver = get_node_or_null("DamageReceiver")
	if damage_receiver:
		damage_receiver.max_health = 190.0 # Base hull 190 (Page 13)
		damage_receiver.current_health = 190.0
		damage_receiver.target_affinity = GameConstants.TargetAffinity.STRUCTURE
		damage_receiver.destroyed.connect(_on_destroyed)

func _on_destroyed(_data: RefCounted) -> void:
	if is_destroyed:
		return
	is_destroyed = true

	# Payout: 35 secured credits, 3 salvage (Page 13)
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		gm.add_banked_credits(35)
		gm.add_salvage(3)

	# Refill player's current weapon ammo
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_node("Weapons"):
		var wp = player.get_node("Weapons")
		var st = wp.weapon_states[wp.current_weapon_idx]
		st["ammo"] = GameConstants.WEAPONS[wp.current_weapon_idx]["ammo_max"]
