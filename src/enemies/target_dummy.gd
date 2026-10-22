class_name TargetDummy
extends CharacterBody3D

## TargetDummy — Reusable target dummy for combat verification and weapon testing.

const GameConstants = preload("res://data/game_constants.gd")
const DamageReceiverClass = preload("res://src/combat/damage_receiver.gd")

@export var enemy_name: String = "Test Dummy"
@export var affinity_category: int = GameConstants.TargetAffinity.LIGHT
@export var base_health: float = 50.0

@onready var damage_receiver: Node = $DamageReceiver
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var label_hp: Label3D = $Label3D

func _ready() -> void:
	add_to_group("enemies")
	if damage_receiver:
		damage_receiver.max_health = base_health
		damage_receiver.current_health = base_health
		damage_receiver.target_affinity = affinity_category
		damage_receiver.damaged.connect(_on_damaged)
		damage_receiver.destroyed.connect(_on_destroyed)
	_update_hp_display()

func _on_damaged(amount: float, remaining: float, _data: RefCounted) -> void:
	_update_hp_display()

func _on_destroyed(data: RefCounted) -> void:
	var killer_w = "Unknown"
	if data != null and "weapon_type" in data:
		killer_w = GameConstants.WEAPONS.get(data.weapon_type, {}).get("name", "Weapon")
	print("TargetDummy destroyed by: ", killer_w)
	# Fade/hide and respawn after 2 seconds for continuous combat testing
	visible = false
	collision_layer = 0
	await get_tree().create_timer(2.0).timeout
	_respawn()

func _respawn() -> void:
	if not is_instance_valid(self):
		return
	if damage_receiver:
		damage_receiver.current_health = base_health
		damage_receiver.is_dead = false
	visible = true
	collision_layer = 4
	_update_hp_display()

func _update_hp_display() -> void:
	if label_hp and damage_receiver:
		label_hp.text = "%s\nHP: %.0f / %.0f" % [enemy_name, damage_receiver.current_health, damage_receiver.max_health]
