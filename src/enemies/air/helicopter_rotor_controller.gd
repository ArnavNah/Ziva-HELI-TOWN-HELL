class_name HelicopterRotorController
extends Node
## Rest-basis animation; integrate speed response analytically at any frame rate.
@export var main_rotor: Node3D
@export var tail_rotor: Node3D
@export var upper_rotor: Node3D
@export var lower_rotor: Node3D
@export var main_rotor_axis := Vector3.UP
@export var tail_rotor_axis := Vector3.RIGHT
@export var main_rotor_speed := 1440.0
@export var tail_rotor_speed := 2160.0
@export var response_rate := 5.0
@export var is_spinning := true
@export var extra_rotor_paths: Array[NodePath] = []
@export var extra_rotor_axis := Vector3.FORWARD
@export var extra_rotor_speed := 1440.0
var _speed_multiplier := 1.0
var _target_speed := 1.0
var _parts: Array[Dictionary] = []

func _ready() -> void:
	if not _parts.is_empty(): return
	var model := get_parent().get_node_or_null("CosmeticOffset/Model")
	if not model: model = get_parent().get_node_or_null("Model")
	if model:
		if not main_rotor: main_rotor = model.find_child("Main_Rotor", true, false)
		if not tail_rotor: tail_rotor = model.find_child("Tail_Rotor", true, false)
		if not upper_rotor: upper_rotor = model.find_child("Upper_Rotor", true, false)
		if not lower_rotor: lower_rotor = model.find_child("Lower_Rotor", true, false)
	_bind(main_rotor, main_rotor_axis, -main_rotor_speed)
	_bind(tail_rotor, tail_rotor_axis, tail_rotor_speed)
	_bind(upper_rotor, main_rotor_axis, -main_rotor_speed)
	_bind(lower_rotor, main_rotor_axis, main_rotor_speed)
	for i in extra_rotor_paths.size():
		_bind(get_parent().get_node_or_null(extra_rotor_paths[i]), extra_rotor_axis, extra_rotor_speed * (-1.0 if i % 2 else 1.0))

func _bind(part: Node3D, axis: Vector3, speed: float) -> void:
	if part:
		_parts.append({"node":part, "rest":part.transform, "axis":axis.normalized(), "speed":deg_to_rad(speed), "angle":0.0})

func _process(delta: float) -> void:
	if not is_spinning or not can_process(): return
	var aircraft := get_parent().get_parent()
	var receiver := aircraft.get_node_or_null("DamageReceiver")
	var target := 0.0 if receiver and receiver.is_dead else _target_speed
	var rate := maxf(response_rate, 0.001)
	var decay := exp(-rate * delta)
	var elapsed_speed := target * delta + (_speed_multiplier - target) * (1.0 - decay) / rate
	_speed_multiplier = target + (_speed_multiplier - target) * decay
	for part in _parts:
		part.angle = fposmod(part.angle + part.speed * elapsed_speed, TAU)
		var rest: Transform3D = part.rest
		part.node.transform = Transform3D(rest.basis * Basis(part.axis, part.angle), rest.origin)

func reset_for_spawn() -> void:
	is_spinning = true
	_speed_multiplier = 1.0
	_target_speed = 1.0
	for part in _parts:
		part.angle = 0.0
		part.node.transform = part.rest

func start_spin() -> void:
	is_spinning = true
	_target_speed = 1.0

func stop_spin() -> void:
	is_spinning = false

func set_speed_multiplier(mult: float) -> void:
	_target_speed = maxf(0.0, mult)
