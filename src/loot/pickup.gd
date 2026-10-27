class_name Pickup
extends Area3D

## Pickup — Collectible ground/air items with magnetic attraction, dynamic acceleration,
## and smooth low-to-high speed fade collection animation (Page 17).

enum PickupType {
	FIELD_REPAIR = 0,
	AMMO_PACK = 1,
	FUEL = 2,
	SHIELD = 3,
	OVERDRIVE = 4,
	SPEED_BOOST = 5,
	BOMB = 6,
	XP_GEM = 7,
	SALVAGE = 8,
	COUNTERMEASURE = 9,
	SALVAGE_CACHE = 10,
	COIN = 11
}

@export var pickup_type: PickupType = PickupType.XP_GEM
@export var pickup_value: float = 5.0

# Dynamic Magnetic Attraction & Acceleration parameters
# Default base parameters: Generous baseline with fast, snappy pursuit
@export var magnet_radius: float = 48.0       # Calibrated: generous collection bubble so flight altitude doesn't strand loot
@export var min_magnet_speed: float = 18.0    # Responsive initial launch velocity
@export var max_magnet_speed: float = 85.0    # Rapid pursuit speed out-pacing player cruise & turbo
@export var magnet_acceleration: float = 140.0 # Snappy ramp-up curve

var is_attracting: bool = false
var is_collected: bool = false
var current_speed: float = 0.0
var initial_attract_dist: float = 1.0
var bob_offset: float = 0.0
var initial_base_y: float = 0.0
var target_player: Node3D = null
var mesh_instance: MeshInstance3D = null
var base_mat: StandardMaterial3D = null
var original_scale: Vector3 = Vector3.ONE
var run_generation: int = -1

func get_effective_magnet_radius() -> float:
	match pickup_type:
		PickupType.XP_GEM, PickupType.COIN:
			return maxf(magnet_radius, 85.0)
		_:
			return maxf(magnet_radius, 48.0)

func get_effective_min_speed() -> float:
	match pickup_type:
		PickupType.XP_GEM, PickupType.COIN:
			return maxf(min_magnet_speed, 24.0)
		_:
			return min_magnet_speed

func get_effective_max_speed() -> float:
	match pickup_type:
		PickupType.XP_GEM, PickupType.COIN:
			return maxf(max_magnet_speed, 88.0)
		_:
			return maxf(max_magnet_speed, 72.0)

func get_effective_acceleration() -> float:
	match pickup_type:
		PickupType.XP_GEM, PickupType.COIN:
			return maxf(magnet_acceleration, 160.0)
		_:
			return magnet_acceleration

func set_spawn_position(pos: Vector3) -> void:
	position = pos
	initial_base_y = pos.y

func start_immediate_attraction(p_player: Node3D) -> void:
	if is_collected or is_attracting or not is_instance_valid(p_player):
		return
	var dist = (p_player.global_position - global_position).length()
	_start_attraction(p_player, dist)

func _ready() -> void:
	var xp = get_node_or_null("/root/XpManager")
	if xp:
		run_generation = xp.run_generation
	add_to_group("pickups")
	collision_layer = 8
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	if is_zero_approx(initial_base_y) and not is_zero_approx(position.y):
		initial_base_y = position.y
	elif is_zero_approx(initial_base_y):
		initial_base_y = position.y
	bob_offset = randf() * TAU
	original_scale = scale
	_setup_mesh_and_material()

func _setup_mesh_and_material() -> void:
	for c in get_children():
		if c is MeshInstance3D:
			mesh_instance = c
			break
	if mesh_instance:
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mesh_instance.material_override is StandardMaterial3D:
			base_mat = mesh_instance.material_override.duplicate() as StandardMaterial3D
		elif mesh_instance.mesh and mesh_instance.mesh.material is StandardMaterial3D:
			base_mat = mesh_instance.mesh.material.duplicate() as StandardMaterial3D
		if base_mat:
			base_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mesh_instance.material_override = base_mat

func _process(delta: float) -> void:
	if is_collected:
		return
	var xp = get_node_or_null("/root/XpManager")
	if xp and run_generation != xp.run_generation:
		queue_free()
		return
	if is_attracting and not _can_collect(target_player):
		is_attracting = false
		target_player = null
		initial_base_y = position.y

	if not is_attracting:
		# 1. Idle animation: Floating bob & rotation
		bob_offset += delta * 3.5
		position.y = initial_base_y + sin(bob_offset) * 0.16

		match pickup_type:
			PickupType.COIN:
				# High-gloss arcade coin spin on vertical Y axis
				rotation.y += delta * 3.8
			PickupType.XP_GEM:
				# Glowing crystalline spin on Y axis with subtle precession
				rotation.y += delta * 3.0
				rotation.z = sin(bob_offset * 0.75) * 0.10
			_:
				rotation.y += delta * 2.2

		# 2. Check magnet proximity with helicopter altitude tolerance
		if not target_player or not is_instance_valid(target_player):
			target_player = get_tree().get_first_node_in_group("player") as Node3D

		if target_player and is_instance_valid(target_player):
			var to_p = target_player.global_position - global_position
			var horiz_dist = Vector2(to_p.x, to_p.z).length()
			var vert_dist = absf(to_p.y)
			var radius_mult: float = target_player.pickup_radius_multiplier if "pickup_radius_multiplier" in target_player else 1.0
			var effective_radius = get_effective_magnet_radius() * radius_mult

			# Altitude-aware combat envelope: allow full horizontal radius up to 50m vertical flight altitude
			if horiz_dist <= effective_radius and vert_dist <= 50.0:
				_start_attraction(target_player, to_p.length())
	else:
		# 3. Attracting: Rapidly closing in on player with speed that outpaces helicopter flight
		if not target_player or not is_instance_valid(target_player):
			target_player = get_tree().get_first_node_in_group("player") as Node3D
			if not target_player or not is_instance_valid(target_player):
				is_attracting = false
				return

		var target_pos = target_player.global_position + Vector3(0.0, 0.4, 0.0)
		var to_target = target_pos - global_position
		var current_dist = to_target.length()

		# Smoothly accelerate current speed to high pursuit speed
		var max_speed = get_effective_max_speed()
		if target_player is CharacterBody3D:
			max_speed = maxf(max_speed, target_player.velocity.length() * 1.30 + 25.0)

		current_speed = move_toward(current_speed, max_speed, get_effective_acceleration() * delta)

		# Distance suction boost: pulls extra fast as it approaches the airframe
		var suction_factor = clampf(1.0 + (8.0 / maxf(current_dist, 1.0)), 1.0, 2.8)
		var step_dist = current_speed * suction_factor * delta

		if current_dist <= 2.8 or step_dist >= current_dist:
			# Arrived at collection point
			global_position = target_pos
			_collect(target_player)
			return

		# Move directly toward target position
		global_position = global_position.move_toward(target_pos, step_dist)

		# Spin rate accelerates in sync with rapid flight
		var min_spd = get_effective_min_speed()
		var speed_ratio = clampf((current_speed - min_spd) / maxf(max_speed - min_spd, 1.0), 0.0, 1.0)
		var spin_rate = lerpf(4.0, 28.0, speed_ratio)
		rotation.y += spin_rate * delta
		if pickup_type == PickupType.XP_GEM:
			rotation.x += spin_rate * 0.4 * delta

		# FADE ANIMATION:
		# As distance closes, smoothly fade alpha and scale
		var dist_ratio = clampf(current_dist / maxf(initial_attract_dist, 3.5), 0.0, 1.0)
		var fade_alpha = clampf(dist_ratio * (1.10 - 0.45 * speed_ratio), 0.10, 1.0)
		if base_mat:
			base_mat.albedo_color.a = fade_alpha

		# Subtle stretch/squash scale toward collection center
		var scale_factor = lerpf(0.35, 1.0, clampf(dist_ratio, 0.0, 1.0))
		scale = original_scale * scale_factor

func _start_attraction(player: Node3D, dist: float) -> void:
	if not _can_collect(player):
		return
	is_attracting = true
	target_player = player
	initial_attract_dist = maxf(dist, 4.0)

	var p_vel_len: float = 0.0
	if player is CharacterBody3D:
		p_vel_len = player.velocity.length()

	# Instantly begin moving with fast snap velocity that outpaces player forward speed
	var base_start_speed = get_effective_min_speed()
	current_speed = maxf(base_start_speed, p_vel_len * 1.15 + 10.0)

	# Cleanly remove any inverted-hull outline pass so the fading energy orb glows cleanly
	if mesh_instance and mesh_instance.material_override:
		mesh_instance.material_override.next_pass = null
	if base_mat:
		base_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

func _on_body_entered(body: Node3D) -> void:
	if is_collected or not body.is_in_group("player"):
		return
	_collect(body)

func _collect(player: Node3D) -> void:
	if is_collected or not _can_collect(player):
		return
	is_collected = true

	# 1. Apply economic & progression effect immediately
	_apply_pickup_effect(player)

	# 2. Emit EventBus signal (triggers audio chime & HUD update)
	if is_inside_tree() and has_node("/root/EventBus"):
		get_node("/root/EventBus").pickup_collected.emit(PickupType.keys()[pickup_type].to_lower(), pickup_value)

	# 3. Disable collision monitoring immediately
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)

	# 4. Spawn micro-sparkle effect at collection point
	var sparkle_col: Color
	match pickup_type:
		PickupType.COIN:
			sparkle_col = Color("ffd447")
		PickupType.XP_GEM:
			sparkle_col = Color(0.25, 0.85, 1.0)
		PickupType.SHIELD:
			sparkle_col = Color(0.3, 0.85, 1.0)
		PickupType.OVERDRIVE:
			sparkle_col = Color(1.0, 0.2, 0.85)
		PickupType.SPEED_BOOST:
			sparkle_col = Color(1.0, 0.85, 0.15)
		PickupType.BOMB:
			sparkle_col = Color(1.0, 0.3, 0.2)
		_:
			sparkle_col = Color(0.3, 0.9, 0.4)

	if is_inside_tree() and has_node("/root/FXManager"):
		get_node("/root/FXManager").spawn_pickup_sparkle(global_position, sparkle_col)

	# 5. Finish subtle fade & scale down tween into player
	if is_inside_tree():
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(self, "scale", Vector3(0.02, 0.02, 0.02), 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		if base_mat:
			tween.tween_property(base_mat, "albedo_color:a", 0.0, 0.10)
		tween.chain().tween_callback(queue_free)
	else:
		queue_free()

func _can_collect(player: Node3D) -> bool:
	if not is_inside_tree() or is_queued_for_deletion():
		return false
	if not is_instance_valid(player) or not player.is_inside_tree() or player.is_queued_for_deletion():
		return false
	if "is_dying" in player and player.is_dying:
		return false
	var xp = get_node_or_null("/root/XpManager")
	if xp and run_generation != xp.run_generation:
		return false
	var gm = get_node_or_null("/root/GameManager")
	return gm != null and gm.current_state in [gm.RunState.ACTIVE, gm.RunState.EXTRACTION, gm.RunState.TUTORIAL] and not get_tree().paused

func _apply_pickup_effect(player: Node3D) -> void:
	var bonus: float = player.loot_multiplier if "loot_multiplier" in player else 1.0
	match pickup_type:
		PickupType.COIN:
			if is_inside_tree() and has_node("/root/GameManager"):
				get_node("/root/GameManager").collect_coins(ceili(pickup_value * bonus))
		PickupType.FIELD_REPAIR:
			if player.has_method("repair"):
				player.repair(35.0) # Page 17: Restore 35 hull
		PickupType.FUEL:
			if player.has_method("refill_fuel"):
				player.refill_fuel(35.0) # Restore 35 fuel
		PickupType.AMMO_PACK:
			if player.has_node("Weapons"):
				var wp = player.get_node("Weapons")
				if wp.has_method("refill_all_ammo"):
					wp.refill_all_ammo()
				else:
					for k in wp.weapon_states:
						wp.weapon_states[k]["ammo"] = GameConstants.WEAPONS[k]["ammo_max"]
						wp.weapon_states[k]["is_reloading"] = false
		PickupType.COUNTERMEASURE:
			if player.has_node("Countermeasures"):
				player.get_node("Countermeasures").replenish_charges(1)
		PickupType.SALVAGE:
			if is_inside_tree() and has_node("/root/GameManager"):
				get_node("/root/GameManager").add_salvage(ceili(pickup_value * bonus))
		PickupType.SALVAGE_CACHE:
			if is_inside_tree() and has_node("/root/GameManager"):
				get_node("/root/GameManager").add_salvage(ceili(10 * bonus)) # Normalized to 10
				get_node("/root/GameManager").add_score(250)
		PickupType.XP_GEM:
			if has_node("/root/XpManager"):
				get_node("/root/XpManager").add_xp(int(pickup_value))
			elif player.has_node("RunProgression"):
				player.get_node("RunProgression").add_run_xp(int(pickup_value))
			elif is_inside_tree() and has_node("/root/GameManager"):
				get_node("/root/GameManager").run_xp += int(pickup_value)
		PickupType.SHIELD:
			var dur: float = pickup_value if pickup_value > 0.0 else 8.0
			if player.has_method("activate_shield"):
				player.activate_shield(dur)
			else:
				player.is_invulnerable = true
		PickupType.SPEED_BOOST:
			var dur: float = pickup_value if pickup_value > 0.0 else 6.0
			if player.has_method("activate_speed_boost"):
				player.activate_speed_boost(dur, 1.45)
			elif "speed_boost_multiplier" in player:
				player.speed_boost_multiplier = 1.45
		PickupType.OVERDRIVE:
			var dur: float = pickup_value if pickup_value > 0.0 else 8.0
			if player.has_method("activate_overdrive"):
				player.activate_overdrive(dur)
			else:
				if player.has_node("Weapons") and player.get_node("Weapons").has_method("activate_overdrive"):
					player.get_node("Weapons").activate_overdrive(dur)
				if player.has_node("Super"):
					player.get_node("Super").add_charge(100.0)
		PickupType.BOMB:
			_trigger_bomb_effect()

func _trigger_bomb_effect() -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if is_instance_valid(e) and e.has_node("DamageReceiver"):
			var rec = e.get_node("DamageReceiver")
			# Resolved design: capped chunk damage to boss, instant wipe for minions
			if e.get("is_boss") == true:
				var chunk_dmg = preload("res://src/combat/damage_data.gd").new(80.0, 2, null, false, 0.0)
				rec.take_damage(chunk_dmg)
			else:
				var lethal_dmg = preload("res://src/combat/damage_data.gd").new(999.0, 2, null, false, 0.0)
				rec.take_damage(lethal_dmg)
	if is_inside_tree() and has_node("/root/GameManager"):
		get_node("/root/GameManager").add_score(150)
