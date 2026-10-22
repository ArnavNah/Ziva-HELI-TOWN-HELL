class_name SAMSite
extends StaticBody3D

## SAMSite — Surface-to-Air Missile battery with search, track, lock, and launch lifecycle (Page 13).

const GameConstants = preload("res://data/game_constants.gd")
const DamageReceiverScript = preload("res://src/combat/damage_receiver.gd")
const ProjectileScene = preload("res://scenes/combat/projectile.tscn")
const DamageDataClass = preload("res://src/combat/damage_data.gd")

enum SAMState {
	SEARCH = 0,
	TRACK = 1,
	LOCKING = 2,
	RELOAD = 3,
	DESTROYED = 4
}

var current_state: SAMState = SAMState.SEARCH
var lock_timer: float = 0.0
var reload_timer: float = 0.0
var target_player: CharacterBody3D = null

@onready var damage_receiver: Node = $DamageReceiver
@onready var launcher_turret: Node3D = $Turret
@onready var lock_indicator: Label3D = $LockLabel

func _ready() -> void:
	collision_layer = 2
	collision_mask = 5
	add_to_group("sam_sites")
	add_to_group("installations")
	_setup_receiver()

func _setup_receiver() -> void:
	if not damage_receiver:
		damage_receiver = get_node_or_null("DamageReceiver")
	if damage_receiver:
		damage_receiver.max_health = 170.0 # Base hull 170 (Page 13)
		damage_receiver.current_health = 170.0
		damage_receiver.target_affinity = GameConstants.TargetAffinity.STRUCTURE
		damage_receiver.destroyed.connect(_on_destroyed)

func _process(delta: float) -> void:
	if current_state == SAMState.DESTROYED:
		return

	_find_player()
	if not target_player or not is_instance_valid(target_player):
		current_state = SAMState.SEARCH
		return

	var dist = global_position.distance_to(target_player.global_position)

	match current_state:
		SAMState.SEARCH:
			if dist <= GameConstants.SAM_SEARCH_RANGE:
				current_state = SAMState.TRACK

		SAMState.TRACK:
			if launcher_turret:
				launcher_turret.look_at(target_player.global_position, Vector3.UP)
			if dist >= GameConstants.SAM_FIRE_MIN_RANGE and dist <= GameConstants.SAM_FIRE_MAX_RANGE:
				current_state = SAMState.LOCKING
				lock_timer = 0.0
			elif dist > GameConstants.SAM_SEARCH_RANGE:
				current_state = SAMState.SEARCH

		SAMState.LOCKING:
			if launcher_turret:
				launcher_turret.look_at(target_player.global_position, Vector3.UP)
			if dist < GameConstants.SAM_FIRE_MIN_RANGE or dist > GameConstants.SAM_FIRE_MAX_RANGE:
				current_state = SAMState.TRACK
				lock_timer = 0.0
				return

			# Check Radar acceleration multiplier (1.2x if active radar present)
			var lock_speed = 1.0
			if _has_active_radar_support():
				lock_speed = GameConstants.SAM_RADAR_ACCELERATION_MULT

			lock_timer += delta * lock_speed
			if lock_indicator:
				lock_indicator.text = "LOCKING: %.0f%%" % [(lock_timer / GameConstants.SAM_BASE_LOCK_TIME) * 100.0]

			if lock_timer >= GameConstants.SAM_BASE_LOCK_TIME:
				_fire_sam_missile()
				current_state = SAMState.RELOAD
				reload_timer = GameConstants.SAM_BASE_RELOAD_TIME

		SAMState.RELOAD:
			reload_timer -= delta
			if lock_indicator:
				lock_indicator.text = "RELOAD: %.1fs" % [reload_timer]
			if reload_timer <= 0.0:
				current_state = SAMState.TRACK

func _has_active_radar_support() -> bool:
	var radars = get_tree().get_nodes_in_group("radar_towers")
	for r in radars:
		if is_instance_valid(r) and not (r.has_node("DamageReceiver") and r.get_node("DamageReceiver").is_dead):
			return true
	return false

func _fire_sam_missile() -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	if not target_player or not is_instance_valid(target_player):
		return

	var p = ProjectileScene.instantiate()
	var p_data = DamageDataClass.new(45.0, GameConstants.WeaponType.MISSILE, self, false, 14.0)
	get_tree().root.add_child(p)
	p.add_to_group("homing_missiles")
	p.global_position = launcher_turret.global_position if launcher_turret else global_position + Vector3.UP * 2.0
	p.speed = GameConstants.SAM_MISSILE_SPEED
	p.is_homing = true
	p.homing_turn_rate = 5.0
	p.lifetime = GameConstants.SAM_MISSILE_LIFETIME
	p.collision_mask = 3 # Player + environment
	p.setup(p_data, target_player)

func _find_player() -> void:
	if not target_player or not is_instance_valid(target_player):
		target_player = get_tree().get_first_node_in_group("player") as CharacterBody3D

func _on_destroyed(_data: RefCounted) -> void:
	current_state = SAMState.DESTROYED
	if lock_indicator:
		lock_indicator.text = "DESTROYED"

	# Payout: 55 secured credits, 5 salvage, threat +8 (Page 13)
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		gm.add_banked_credits(55)
		gm.add_salvage(5)
		gm.add_threat(8.0)
		gm.counted_objectives += 1
