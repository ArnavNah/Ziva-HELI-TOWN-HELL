class_name HeavyGunshipBoss
extends CharacterBody3D

## HeavyGunshipBoss — Wave 10 Heavy Gunship encounter with 3 distinct hull phases,
## telegraphs, escorts, core deterioration, and continuation choices (Page 12).

const GameConstants = preload("res://data/game_constants.gd")
const DamageReceiverScript = preload("res://src/combat/damage_receiver.gd")
const ProjectileScene = preload("res://scenes/combat/projectile.tscn")
const DamageDataClass = preload("res://src/combat/damage_data.gd")

enum BossStage {
	OPENING = 3,    # >66% hull: 5-projectile spread volley
	ESCALATION = 2, # 33%-66% hull: 7-projectile telegraphed volley (speed 115) + radial rings
	FINAL = 1       # <=33% hull: 9-projectile telegraphed volley (speed 135) + denser pressure
}

var current_stage: BossStage = BossStage.OPENING
var is_boss: bool = true
var defeat_settled: bool = false
var target_player: Node3D = null

var volley_timer: float = 0.0
var telegraph_timer: float = 0.0
var is_telegraphing: bool = false
var pending_volley_count: int = 5
var pending_volley_speed: float = 95.0

@onready var damage_receiver: Node = get_node_or_null("DamageReceiver")
@onready var turret_pivot: Node3D = get_node_or_null("TurretPivot")
@onready var core_mesh: MeshInstance3D = get_node_or_null("CoreMesh")
@onready var telegraph_label: Label3D = get_node_or_null("TelegraphLabel")

func _ready() -> void:
	# The director constructs this controller directly; provide its complete physical rig.
	if not has_node("Visuals"):
		preload("res://src/enemies/raider_visuals.gd").build(self, "heavy_gunship_boss")
	if get_node("Visuals").has_method("get_weapon_origin") and not telegraph_label:
		telegraph_label = Label3D.new()
		telegraph_label.name = "TelegraphLabel"
		# Above-hull text overlaps the boss HUD in the real chase camera. Place
		# warnings below the hull and keep rooftops from occluding preparation.
		telegraph_label.position.y = -2.8
		telegraph_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		telegraph_label.font_size = 44
		telegraph_label.pixel_size = 0.035
		telegraph_label.outline_size = 8
		telegraph_label.no_depth_test = true
		telegraph_label.modulate = Color("ffad48")
		add_child(telegraph_label)
	if not has_node("CollisionShape3D"):
		var shape := BoxShape3D.new()
		shape.size = Vector3(5, 3.5, 11)
		var collision := CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		collision.shape = shape
		collision.position.y = 1.8
		add_child(collision)
	collision_layer = 4
	collision_mask = 7
	volley_timer = 2.0
	add_to_group("enemies")
	add_to_group("bosses")
	_setup_boss_stats()
	_find_player()

func _weapon_origin() -> Vector3:
	var rig := get_node_or_null("Visuals")
	if rig and rig.has_method("get_weapon_origin"): return rig.get_weapon_origin()
	# Modular fortress bosses retain their own articulated battery.
	return turret_pivot.global_position if turret_pivot else global_position + Vector3.UP * 2.0

func _setup_boss_stats() -> void:
	if not damage_receiver:
		damage_receiver = get_node_or_null("DamageReceiver")
	if not damage_receiver:
		damage_receiver = DamageReceiverScript.new()
		damage_receiver.name = "DamageReceiver"
		add_child(damage_receiver)

	if damage_receiver:
		damage_receiver.max_health = 260.0 # Base hull 260 (Page 12)
		damage_receiver.current_health = 260.0
		damage_receiver.target_affinity = GameConstants.TargetAffinity.BOSS_CORE
		if not damage_receiver.damaged.is_connected(_on_damaged):
			damage_receiver.damaged.connect(_on_damaged)
		if not damage_receiver.destroyed.is_connected(_on_destroyed):
			damage_receiver.destroyed.connect(_on_destroyed)

func _find_player() -> void:
	target_player = get_tree().get_first_node_in_group("player") as Node3D

var boss_phase_timer: float = 0.0
var move_speed: float = 24.0

func _process(delta: float) -> void:
	if not damage_receiver or damage_receiver.is_dead:
		return

	if not target_player or not is_instance_valid(target_player):
		_find_player()
		return

	boss_phase_timer += delta
	var rotor = get_node_or_null("Visuals/AnimatedRotor")
	if rotor: rotor.rotation.y += delta * 24.0

	# Heavy Boss Flight Maneuvering (Drifts & Standoff)
	var to_player = (target_player.global_position - global_position).normalized()
	var dist = global_position.distance_to(target_player.global_position)
	var perp = Vector3(-to_player.z, 0.0, to_player.x).normalized()

	var speed_multiplier = 1.0 if current_stage == BossStage.OPENING else (1.25 if current_stage == BossStage.ESCALATION else 1.5)
	var strafe_offset = perp * (sin(boss_phase_timer * 0.9) * 22.0)
	var desired_pos = target_player.global_position - to_player * 55.0 + strafe_offset
	desired_pos.y = clampf(target_player.global_position.y + 7.0, 24.0, 46.0)

	var move_dir = (desired_pos - global_position).normalized()
	velocity = velocity.lerp(move_dir * (move_speed * speed_multiplier), delta * 3.0)
	move_and_slide()

	# Chassis smooth yaw rotation toward player
	var horiz_p = Vector3(to_player.x, 0.0, to_player.z).normalized()
	if horiz_p.length_squared() > 0.01:
		var target_yaw = atan2(-horiz_p.x, -horiz_p.z)
		rotation.y = rotate_toward(rotation.y, target_yaw, delta * 3.5)

	# Predictive turret tracking
	var muzzle_pos := _weapon_origin()
	var proj_speed := pending_volley_speed if is_telegraphing else (95.0 if current_stage == BossStage.OPENING else (115.0 if current_stage == BossStage.ESCALATION else 135.0))
	var aim_lead := _predict_lead_point(muzzle_pos, target_player, proj_speed)

	if turret_pivot:
		turret_pivot.look_at(aim_lead, Vector3.UP)

	# Telegraph countdown
	if is_telegraphing:
		telegraph_timer -= delta
		if telegraph_label:
			telegraph_label.text = "INCOMING BARRAGE"
		if telegraph_timer <= 0.0:
			is_telegraphing = false
			if telegraph_label:
				telegraph_label.text = ""
			_launch_telegraphed_volley(aim_lead)
		return

	# Normal volley cycle
	volley_timer -= delta
	if volley_timer <= 0.0:
		_start_next_attack(aim_lead)

func _start_next_attack(aim_lead: Vector3) -> void:
	var director = get_node_or_null("/root/CombatDirector")
	if director and not director.request_combined_attack_slots(self, true, true):
		volley_timer = 0.3
		return
	match current_stage:
		BossStage.OPENING:
			volley_timer = 3.5
			_begin_telegraph(5, 95.0)
		BossStage.ESCALATION:
			volley_timer = 4.0
			_begin_telegraph(7, 115.0) # Page 12: 0.8s warning, speed 115
		BossStage.FINAL:
			volley_timer = 2.8
			_begin_telegraph(9, 135.0) # Page 12: 0.8s warning, speed 135

func _begin_telegraph(count: int, speed: float) -> void:
	is_telegraphing = true
	telegraph_timer = 0.8 # 0.8s warning (Page 12)
	var camera = get_viewport().get_camera_3d()
	if camera and not camera.is_position_in_frustum(global_position):
		telegraph_timer = 1.5
		var bus = get_node_or_null("/root/EventBus")
		if bus: bus.threat_warning.emit(global_position, "heavy_gunship_boss", telegraph_timer)
	pending_volley_count = count
	pending_volley_speed = speed

func _launch_telegraphed_volley(aim_lead: Vector3) -> void:
	_fire_spread_volley(pending_volley_count, pending_volley_speed, aim_lead)
	_release_attack_slots()

func _release_attack_slots() -> void:
	var director = get_node_or_null("/root/CombatDirector")
	if director:
		director.release_air_attack_slot(self)
		director.release_heavy_attack_slot(self)

func on_attack_slot_expired(_kind: String) -> void:
	is_telegraphing = false
	if telegraph_label: telegraph_label.text = ""
	volley_timer = 0.3
	_release_attack_slots()

func _fire_spread_volley(count: int, speed: float, aim_lead: Vector3) -> void:
	if not is_inside_tree() or get_tree() == null or defeat_settled or (damage_receiver and damage_receiver.is_dead):
		return
	if not target_player or not is_instance_valid(target_player):
		return
	var muzzle_pos := _weapon_origin()
	var base_dir = (aim_lead - muzzle_pos).normalized()
	var perp = Vector3(-base_dir.z, 0.0, base_dir.x).normalized()

	for i in range(count):
		muzzle_pos = _weapon_origin()
		var rig := get_node_or_null("Visuals")
		var muzzle_socket: Node3D = rig.get_weapon_socket() if rig and rig.has_method("get_weapon_socket") else self
		if rig and rig.has_method("get_weapon_origin"):
			var query := PhysicsRayQueryParameters3D.create(muzzle_pos, aim_lead, 2)
			if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
		var p = ProjectileScene.instantiate()
		var p_data = DamageDataClass.new(12.0, GameConstants.WeaponType.ROCKET, self, false, 6.0)
		get_tree().root.add_child(p)
		p.global_position = muzzle_pos
		var spread_fraction = float(i - int(count / 2)) * 0.14
		var fire_dir = (base_dir + perp * spread_fraction).normalized()
		p.velocity = fire_dir * speed
		p.blast_radius = 6.0
		p.collision_mask = 3 # Player + environment
		p.setup(p_data, null, "enemy_boss")
		if rig and rig.has_method("commit_shot"): rig.commit_shot()
		if has_node("/root/FXManager"):
			var up_vec = Vector3.UP if absf(fire_dir.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
			get_node("/root/FXManager").play_muzzle("enemy_boss", Transform3D(Basis.looking_at(fire_dir, up_vec), muzzle_pos), muzzle_socket, fire_dir)

func _predict_lead_point(origin: Vector3, target: Node3D, proj_speed: float) -> Vector3:
	if not is_instance_valid(target):
		return origin + Vector3.FORWARD * 20.0
	var target_pos = target.global_position
	var target_vel = Vector3.ZERO
	if "velocity" in target and target.velocity is Vector3:
		target_vel = target.velocity

	if target_vel.length_squared() < 0.25:
		return target_pos

	var dist = origin.distance_to(target_pos)
	var t = clampf(dist / maxf(proj_speed, 10.0), 0.0, 2.5)
	var predicted = target_pos + target_vel * (t * 0.90)
	predicted.y = maxf(predicted.y, 1.5)
	return predicted

func _on_damaged(_amount: float, remaining_hp: float, _data: RefCounted) -> void:
	var ratio = remaining_hp / damage_receiver.max_health
	if ratio <= 0.33 and current_stage != BossStage.FINAL:
		current_stage = BossStage.FINAL
		_update_core_visual(Color(1.0, 0.1, 0.1)) # Critical red core
	elif ratio <= 0.66 and current_stage == BossStage.OPENING:
		current_stage = BossStage.ESCALATION
		_update_core_visual(Color(1.0, 0.6, 0.1)) # Orange unstable core

func _update_core_visual(color: Color) -> void:
	var rig := get_node_or_null("Visuals")
	if rig and rig.has_method("get_weapon_origin"):
		var cue := rig.get_node("CosmeticOffset/StateCue") as MeshInstance3D
		var cue_mat: StandardMaterial3D = cue.get_active_material(0).duplicate()
		cue_mat.albedo_color = color
		cue_mat.emission = color
		cue.material_override = cue_mat
	if core_mesh and core_mesh.mesh:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		core_mesh.material_override = mat

func _on_destroyed(_data: RefCounted) -> void:
	if defeat_settled:
		return
	defeat_settled = true
	_release_attack_slots()
	if has_node("/root/FXManager"):
		get_node("/root/FXManager").play_destruction(self, global_position, Vector3.UP, false, "boss")

	# Defeat rewards: 320 bounty + 1,000 boss reward + 10 salvage + 40 hull repair (Page 12)
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		gm.add_banked_credits(320 + 1000)
		gm.add_salvage(10)
		gm.add_score(2000)

	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("repair"):
		player.repair(40.0)

	if is_inside_tree() and has_node("/root/EventBus"):
		get_node("/root/EventBus").boss_defeated.emit()

	# Trigger Boss Decision State (Extract vs Overdrive)
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").change_state(get_node("/root/GameManager").RunState.BOSS_DECISION)

	visible = false
	collision_layer = 0
	queue_free()
