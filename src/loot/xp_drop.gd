class_name XpDrop
extends Area3D

## XpDrop — World entity dropped by destroyed enemies with planar magnet attraction
## toward the player helicopter, dynamic anti-orbit acceleration, and authoritative XP delivery.

@export var xp_amount: int = 10
@export var attract_speed: float = 0.0
@export var max_attract_speed: float = 25.0
@export var attraction_acceleration: float = 40.0
@export var is_being_attracted: bool = false
@export var target_player: Node3D = null

var is_collected: bool = false
var bob_offset: float = 0.0
var initial_y: float = 0.0
var run_generation: int = -1

@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")
@onready var mesh_instance: MeshInstance3D = get_node_or_null("MeshInstance3D")

static var _shared_gem_material: StandardMaterial3D = null

static func _get_shared_gem_material() -> StandardMaterial3D:
	if _shared_gem_material == null:
		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		mat.albedo_color = Color(0.25, 0.95, 0.55, 1.0) # Emerald XP Gem
		mat.roughness = 0.25
		mat.metallic = 0.20
		mat.emission_enabled = true
		mat.emission = Color(0.20, 0.85, 0.45)
		mat.emission_energy_multiplier = 2.2
		_shared_gem_material = mat
	return _shared_gem_material

func _ready() -> void:
	add_to_group("xp_drops")
	collision_layer = 16 # Pickups / drops layer
	collision_mask = 1   # Player layer
	initial_y = position.y
	var xp = get_node_or_null("/root/XpManager")
	if xp:
		run_generation = xp.run_generation
	bob_offset = randf() * TAU

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	_setup_visual_materials()

func _setup_visual_materials() -> void:
	if not mesh_instance:
		return
	mesh_instance.material_override = _get_shared_gem_material()
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func start_attraction(player: Node3D) -> void:
	if is_collected or not _can_collect(player):
		return
	target_player = player
	is_being_attracted = true

func _physics_process(delta: float) -> void:
	if is_collected:
		return
	if not _belongs_to_current_run():
		queue_free()
		return
	if is_being_attracted and not _can_collect(target_player):
		is_being_attracted = false
		target_player = null
		attract_speed = 0.0
		initial_y = position.y

	if not is_being_attracted or not target_player or not is_instance_valid(target_player):
		# Idle visual floating bob & rotation when not actively pulled
		bob_offset += delta * 3.5
		position.y = initial_y + sin(bob_offset) * 0.18
		rotation.y += delta * 2.8
		return

	# Magnet Physics Logic
	var target_pos = target_player.global_position + Vector3(0.0, 0.4, 0.0)
	var to_player = target_pos - global_position
	var dist_3d = to_player.length()

	# Planar distance (XZ plane ignore height variations)
	var planar_dist = Vector2(to_player.x, to_player.z).length()

	# Anti-Overshoot / Anti-Orbit Defensive Safeguard:
	# 1. Scale max speed if player is dashing/flying at top speed
	var effective_max_speed = max_attract_speed
	if target_player is CharacterBody3D:
		var p_speed = (target_player as CharacterBody3D).velocity.length()
		effective_max_speed = maxf(effective_max_speed, p_speed * 1.30 + 15.0)

	# 2. Scale acceleration linearly with distance to snap cleanly into player
	var dist_multiplier = maxf(1.0, dist_3d * 0.15)
	var effective_accel = attraction_acceleration * dist_multiplier

	# 3. Accelerate attract_speed toward effective_max_speed
	attract_speed = move_toward(attract_speed, effective_max_speed, effective_accel * delta)

	# 4. Collection threshold check: planar distance < 1.5m or 3D step reaches/exceeds target
	var step_distance = attract_speed * delta
	if planar_dist < 1.5 or dist_3d < 1.5 or step_distance >= dist_3d:
		global_position = target_pos
		_trigger_collection()
		return

	# Move position along 3D normalized direction vector toward player gunship
	var dir = to_player.normalized()
	global_position += dir * step_distance

	# Visual spin accelerating proportionally with flight speed
	var speed_ratio = clampf(attract_speed / maxf(effective_max_speed, 1.0), 0.0, 1.0)
	rotation.y += lerpf(4.0, 24.0, speed_ratio) * delta
	rotation.x += lerpf(1.0, 8.0, speed_ratio) * delta

func _trigger_collection() -> void:
	if is_collected or not _can_collect(target_player):
		return
	is_collected = true

	# Authoritative XP Delivery to XpManager
	var xp_mgr = get_node_or_null("/root/XpManager")
	if xp_mgr and xp_mgr.has_method("add_xp"):
		xp_mgr.add_xp(xp_amount)

	# Visual floating text / FX feedback
	if has_node("/root/FXManager"):
		var fx = get_node("/root/FXManager")
		if fx.has_method("spawn_pickup_sparkle"):
			fx.spawn_pickup_sparkle(global_position, Color(0.25, 1.0, 0.55))

	# EventBus notification
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").pickup_collected.emit("XP_GEM", float(xp_amount))

	queue_free()

func _on_body_entered(body: Node3D) -> void:
	if is_collected:
		return
	if body.is_in_group("player"):
		target_player = body
		_trigger_collection()

func _belongs_to_current_run() -> bool:
	if not is_inside_tree() or is_queued_for_deletion():
		return false
	var xp = get_node_or_null("/root/XpManager")
	return xp != null and run_generation == xp.run_generation

func _can_collect(player: Node3D) -> bool:
	if not _belongs_to_current_run() or not is_instance_valid(player) or not player.is_inside_tree() or player.is_queued_for_deletion():
		return false
	if "is_dying" in player and player.is_dying:
		return false
	var gm = get_node_or_null("/root/GameManager")
	return gm != null and gm.current_state in [gm.RunState.ACTIVE, gm.RunState.EXTRACTION, gm.RunState.TUTORIAL] and not get_tree().paused

func _on_area_entered(area: Area3D) -> void:
	if is_collected:
		return
	if area.name == "MagnetSensor" or area.is_in_group("player_magnet"):
		var p = area.get_parent()
		if p is Node3D:
			start_attraction(p)
