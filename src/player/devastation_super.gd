class_name DevastationSuper
extends Node

## DevastationSuper — High-impact super ability (Page 20).
## 100 charge -> 5s invulnerability, 2.2x fire rate, 240-unit radial pulse.
const DamageDataClass = preload("res://src/combat/damage_data.gd")

signal super_charged()
signal super_activated()
signal super_ended()

var damage_multiplier: float = 1.0
var charge_multiplier: float = 1.0
var current_charge: float = 0.0
var is_active: bool = false
var active_timer: float = 0.0
var cooldown_timer: float = 0.0

@export var player_helicopter: CharacterBody3D

func _ready() -> void:
	if is_inside_tree() and has_node("/root/EventBus"):
		get_node("/root/EventBus").entity_destroyed.connect(_on_entity_destroyed)

func _process(delta: float) -> void:
	if has_node("/root/UIFlow") and not get_node("/root/UIFlow").gameplay_input_allowed():
		return
	if is_active:
		active_timer -= delta
		if active_timer <= 0.0:
			_deactivate_super()

	if cooldown_timer > 0.0:
		cooldown_timer -= delta

	if Input.is_action_just_pressed("super_ability"):
		try_activate_super()

func add_charge(amount: float) -> void:
	if is_active or cooldown_timer > 0.0:
		return # Charging is locked during active super and 8s cooldown (Page 20)

	current_charge = minf(GameConstants.SUPER_MAX_CHARGE, current_charge + amount * charge_multiplier)
	if is_inside_tree() and has_node("/root/EventBus"):
		get_node("/root/EventBus").super_charge_changed.emit(current_charge, GameConstants.SUPER_MAX_CHARGE)

	if current_charge >= GameConstants.SUPER_MAX_CHARGE:
		super_charged.emit()

func try_activate_super() -> bool:
	if current_charge < GameConstants.SUPER_MAX_CHARGE or is_active:
		return false

	is_active = true
	current_charge = 0.0
	active_timer = GameConstants.SUPER_DURATION
	cooldown_timer = GameConstants.SUPER_COOLDOWN

	if player_helicopter:
		player_helicopter.update_invulnerability_state()

	# Radial 240-unit damage pulse (Page 20)
	_trigger_devastation_pulse()

	super_activated.emit()
	if is_inside_tree() and has_node("/root/EventBus"):
		get_node("/root/EventBus").super_activated.emit()
		get_node("/root/EventBus").super_charge_changed.emit(0.0, GameConstants.SUPER_MAX_CHARGE)

	return true

func _deactivate_super() -> void:
	is_active = false
	if player_helicopter:
		player_helicopter.update_invulnerability_state()
	super_ended.emit()

func _trigger_devastation_pulse() -> void:
	if not player_helicopter:
		return
	var enemies = get_tree().get_nodes_in_group("enemies")
	var pulse_data = DamageDataClass.new(
		GameConstants.SUPER_PULSE_DAMAGE * damage_multiplier,
		GameConstants.WeaponType.ROCKET,
		player_helicopter,
		false,
		GameConstants.SUPER_PULSE_RADIUS
	)
	pulse_data.is_crit = true
	for e in enemies:
		if is_instance_valid(e) and e is Node3D:
			var d = player_helicopter.global_position.distance_to(e.global_position)
			if d <= GameConstants.SUPER_PULSE_RADIUS:
				var rec = e.get_node_or_null("DamageReceiver")
				if rec and rec.has_method("take_damage"):
					rec.take_damage(pulse_data)

func _on_entity_destroyed(_entity: Node, _weapon: String, _score: int, _xp: int) -> void:
	# Add charge on kill (+4 normal kill)
	add_charge(GameConstants.SUPER_KILL_CHARGE_NORMAL)
