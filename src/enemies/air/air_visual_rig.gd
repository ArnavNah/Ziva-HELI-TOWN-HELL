class_name AirVisualRig
extends Node3D
## Selection is a pure query. Commit only after creating a shot.
@export var weapon_sockets: Array[NodePath] = []
@export var fixed_gun_half_arc_degrees := 70.0
var outlet_index := 0
var _recoil := 0.0
var _cue := 0.0
var role := ""
static var _variant_materials: Dictionary = {}
@onready var offset: Node3D = $CosmeticOffset

func _ready() -> void:
	var aircraft := get_parent()
	role = str(aircraft.get("variant_id")) if "variant_id" in aircraft else "heavy_gunship_boss"
	if role in ["stealth_vtol", "minelayer"]:
		for mesh in $CosmeticOffset/Model.find_children("*", "MeshInstance3D", true, false):
			for surface in mesh.mesh.get_surface_count():
				var original: Material = mesh.get_active_material(surface)
				if not original is StandardMaterial3D: continue
				var key := "%s:%s" % [original.get_instance_id(), role]
				if not _variant_materials.has(key):
					var mat: StandardMaterial3D = original.duplicate()
					mat.albedo_color *= Color(0.72, 0.82, 1.0) if role == "stealth_vtol" else Color(1.0, 0.88, 0.70)
					_variant_materials[key] = mat
				mesh.set_surface_override_material(surface, _variant_materials[key])
	var mine_cue := get_node_or_null("CosmeticOffset/MineCue") as Node3D
	if mine_cue: mine_cue.visible = role == "minelayer"
	var missile_cue := get_node_or_null("CosmeticOffset/MissileCue") as Node3D
	if missile_cue: missile_cue.visible = role == "torpedo_vtol"

func get_weapon_socket() -> Marker3D:
	if weapon_sockets.is_empty(): return null
	return get_node_or_null(weapon_sockets[outlet_index % weapon_sockets.size()]) as Marker3D

func get_weapon_origin() -> Vector3:
	var socket := get_weapon_socket()
	return socket.global_position if socket else global_position

func is_in_firing_arc(aim: Vector3) -> bool:
	var socket := get_weapon_socket()
	if not socket: return false
	return (-socket.global_basis.z).normalized().dot((aim - socket.global_position).normalized()) >= cos(deg_to_rad(fixed_gun_half_arc_degrees))

func commit_shot() -> void:
	outlet_index += 1
	_recoil = minf(_recoil + 0.035, 0.09)
	_cue = 0.18

func get_drop_origin(kind: String) -> Vector3:
	var socket := get_node_or_null("CosmeticOffset/Sockets/" + kind) as Marker3D
	return socket.global_position if socket else global_position

func reset_for_spawn() -> void:
	outlet_index = 0
	_recoil = 0.0
	_cue = 0.0
	if offset: offset.position = Vector3.ZERO
	var rotor := get_node_or_null("RotorController")
	if rotor: rotor.reset_for_spawn()

func _process(delta: float) -> void:
	_recoil *= exp(-18.0 * delta)
	_cue = maxf(_cue - delta, 0.0)
	offset.position = Vector3(0, 0, _recoil)
	var aircraft := get_parent()
	var warning := false
	if "behavior_state" in aircraft:
		warning = aircraft.behavior_state in [BaseEnemy.BehaviorState.WINDUP, BaseEnemy.BehaviorState.FIRE]
	elif "is_telegraphing" in aircraft:
		warning = aircraft.is_telegraphing
	var cue := get_node_or_null("CosmeticOffset/StateCue") as Node3D
	if cue: cue.visible = warning or _cue > 0.0
