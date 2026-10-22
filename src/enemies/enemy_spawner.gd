class_name EnemySpawner
extends Node

## EnemySpawner — Spawns hostiles according to wave gates, population targets,
## and variant caps (Page 9 & 11).
## Builds authentically styled, properly scaled Nuclear Strike military 3D models.

const EnemyDataClass = preload("res://src/enemies/enemy_data.gd")
const AttackGunshipScript = preload("res://src/enemies/air/attack_gunship.gd")
const ScoutDroneScript = preload("res://src/enemies/air/scout_drone.gd")
const KamikazeDroneScript = preload("res://src/enemies/air/kamikaze_drone.gd")
const RocketGunshipScript = preload("res://src/enemies/air/rocket_gunship.gd")
const InterceptorScript = preload("res://src/enemies/air/interceptor.gd")
const MinelayerScript = preload("res://src/enemies/air/minelayer.gd")
const FlakTankScript = preload("res://src/enemies/ground/flak_tank.gd")
const MissileCarrierScript = preload("res://src/enemies/ground/missile_carrier.gd")
const SiegeTankScript = preload("res://src/enemies/ground/siege_tank.gd")
const DesertIroncladScene: PackedScene = preload("res://scenes/enemies/desert_ironclad_visuals.tscn")
const GatlingHeavyScript = preload("res://src/enemies/ground/gatling_heavy.gd")
const InfantrySquadScript = preload("res://src/enemies/ground/infantry_squad.gd")
const ShieldDroneScript = preload("res://src/enemies/support/shield_drone.gd")
const RepairDroneScript = preload("res://src/enemies/support/repair_drone.gd")
const DamageReceiverScript = preload("res://src/combat/damage_receiver.gd")
const ProceduralRaider = preload("res://src/enemies/procedural_raider.gd")
const RaiderVisuals = preload("res://src/enemies/raider_visuals.gd")
const FieldRaiderVisuals = preload("res://src/enemies/field_raider_visuals.gd")
const FIELD_ROLES = ["rocket_buggy", "flame_tank", "rail_crawler", "hunter_drone", "torpedo_vtol", "escort_fighter"]
const SpawnCardClass = preload("res://src/resources/spawn_card.gd")

var encounter_rng := RandomNumberGenerator.new()
var encounter_angle := 0.0
var encounter_remaining := 0
var _cached_shape_query: PhysicsShapeQueryParameters3D = null
var _cached_box_shape: BoxShape3D = null

var spawn_timer: float = 0.0
var base_spawn_interval: float = 1.0
var last_handled_wave: int = -1
var opening_grace_timer: float = 0.0
var opening_burst_spawned: bool = false
var retirement_timer: float = 0.0
var retirement_candidates: Dictionary = {}
const RETIREMENT_DWELL_SECONDS: float = 8.0

func reset_encounter(seed_value: int) -> void:
	encounter_rng.seed = seed_value
	encounter_remaining = 0
	encounter_angle = 0.0
	retirement_candidates.clear()
	retirement_timer = 0.0

func _ready() -> void:
	add_to_group("enemy_spawners")
	var cd = get_node_or_null("/root/CombatDirector")
	reset_encounter(cd.encounter_seed if cd else 1337)
	_cached_shape_query = PhysicsShapeQueryParameters3D.new()
	_cached_box_shape = BoxShape3D.new()
	_cached_shape_query.shape = _cached_box_shape
	_cached_shape_query.collision_mask = 6

func _process(delta: float) -> void:
	if not has_node("/root/CombatDirector"):
		return
	var cd = get_node("/root/CombatDirector")
	if not cd.is_active_combat_eligible():
		return

	# Periodic administrative retirement check (Section 5)
	retirement_timer -= delta
	if retirement_timer <= 0.0:
		retirement_timer = 0.5
		_check_administrative_retirements(cd)

	# If credit director is active with catalog, credit engine handles purchases/opening cohorts.
	if "use_credit_director" in cd and cd.use_credit_director:
		return

	# Fallback legacy replenishment (when catalog is absent/testing)
	_process_legacy_replenishment(cd, delta)

func _process_legacy_replenishment(cd: Node, delta: float) -> void:
	# Wave transition tracking & opening grace (Page 11)
	if cd.current_wave != last_handled_wave:
		last_handled_wave = cd.current_wave
		opening_grace_timer = cd.opening_grace_duration if "opening_grace_duration" in cd else 2.0
		opening_burst_spawned = false
		spawn_timer = 0.0

	if opening_grace_timer > 0.0:
		opening_grace_timer -= delta
		if opening_grace_timer <= 0.0:
			_spawn_opening_wave_cohort(cd)
		return

	# Dynamic replenishment cadence
	var current_interval = _get_current_spawn_interval(cd)
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = current_interval
		_check_and_spawn(cd)


func _get_current_spawn_interval(cd: Node) -> float:
	var interval = base_spawn_interval
	var theme = cd.active_theme if "active_theme" in cd else "Normal"
	match theme:
		"Swarm Tide":
			interval = 0.55
		"Armored Column":
			interval = 1.15
		"Storm Surge":
			interval = 0.85
		"Night Surge":
			interval = 0.75
		_:
			interval = base_spawn_interval
	var scaling := EnemyDataClass.get_wave_scaling(cd.current_wave)
	return interval * float(scaling.spawn_interval)

func _spawn_opening_wave_cohort(cd: Node) -> void:
	if opening_burst_spawned:
		return
	opening_burst_spawned = true

	var target = cd.target_population
	var desired_opening = mini(target, maxi(4, int(float(target) * 0.8)))
	var active_count = _get_active_enemy_count()
	var needed = desired_opening - active_count
	for i in range(needed):
		spawn_wave_enemy(cd.current_wave)

func _check_and_spawn(cd: Node) -> void:
	var active_count = _get_active_enemy_count()
	var deficit = cd.target_population - active_count
	if deficit <= 0:
		return

	var batch = 1
	if deficit >= 5:
		batch = 3
	elif deficit >= 3:
		batch = 2

	for i in range(batch):
		if _get_active_enemy_count() < cd.target_population:
			spawn_wave_enemy(cd.current_wave)

func _get_active_enemy_count() -> int:
	var current_enemies = get_tree().get_nodes_in_group("enemies")
	var count = 0
	for e in current_enemies:
		if is_instance_valid(e) and not (e.has_node("DamageReceiver") and e.get_node("DamageReceiver").is_dead):
			count += 1
	return count

func spawn_wave_enemy(wave_num: int) -> Node3D:
	if not is_inside_tree() or get_tree() == null:
		return null

	var theme = "Normal"
	if has_node("/root/CombatDirector"):
		theme = get_node("/root/CombatDirector").active_theme

	var chosen_variant = _choose_wave_variant(wave_num, theme)
	if chosen_variant.is_empty():
		return null
	return spawn_enemy_type(chosen_variant)

func _choose_wave_variant(wave_num: int, theme: String) -> String:
	var active_counts: Dictionary = {}
	var current_enemies = get_tree().get_nodes_in_group("enemies")
	for e in current_enemies:
		if is_instance_valid(e) and not (e.has_node("DamageReceiver") and e.get_node("DamageReceiver").is_dead):
			var v_id = e.variant_id if "variant_id" in e else ""
			if v_id != "":
				active_counts[v_id] = active_counts.get(v_id, 0) + 1

	var ground_count := 0
	var air_count := 0
	for key in active_counts:
		if EnemyDataClass.VARIANTS.has(key):
			if EnemyDataClass.VARIANTS[key].family == "ground":
				ground_count += int(active_counts[key])
			else:
				air_count += int(active_counts[key])
	var ground_share := 0.70 if theme == "Armored Column" else 0.55
	var favor_ground := float(ground_count) < float(ground_count + air_count + 1) * ground_share
	var candidate_pool: Array[String] = []
	for k in EnemyDataClass.VARIANTS:
		if not EnemyDataClass.is_variant_enabled(k):
			continue
		var v = EnemyDataClass.VARIANTS[k]
		if wave_num < v.get("gate_wave", 1):
			continue
		var max_cap = v.get("max_cap", 8)
		if active_counts.get(k, 0) >= max_cap:
			continue
		if v.get("is_rare", false) and randf() > 0.18:
			continue

		# Underrepresented roles become more likely without breaking gates or caps.
		var weight = maxi(1, 4 - int(active_counts.get(k, 0)))
		if (v.family == "ground") == favor_ground:
			weight += 3
		if theme == "Swarm Tide" and k in ["scout_drone", "kamikaze_drone", "scout_buggy"]:
			weight = 4
		elif theme == "Armored Column" and k in ["assault_apc", "rail_crawler", "siege_tank", "gatling_heavy", "raptor_raider", "desert_barrage_rover"]:
			weight = 4
		elif theme == "Storm Surge" and k in ["attack_gunship", "rocket_gunship", "assault_apc"]:
			weight = 3
		elif theme == "Night Surge" and k in ["attack_gunship", "interceptor", "gatling_heavy"]:
			weight = 3

		for w in range(weight):
			candidate_pool.append(k)

	if candidate_pool.is_empty():
		return ""

	return candidate_pool[encounter_rng.randi_range(0, candidate_pool.size() - 1)]

func _get_variant_counts() -> Dictionary:
	var counts: Dictionary = {}
	var current_enemies = get_tree().get_nodes_in_group("enemies")
	for e in current_enemies:
		if is_instance_valid(e) and not e.is_queued_for_deletion() and not (e.has_node("DamageReceiver") and e.get_node("DamageReceiver").is_dead):
			var v_id = e.variant_id if "variant_id" in e else ""
			if not v_id.is_empty():
				counts[v_id] = counts.get(v_id, 0) + 1
	return counts

func spawn_director_card(card: SpawnCard, stream: String) -> Array[Node3D]:
	var spawned: Array[Node3D] = []
	if not is_inside_tree() or get_tree() == null:
		return spawned

	var player = get_tree().get_first_node_in_group("player")
	var center_pos = player.global_position if player else Vector3.ZERO
	var family = "air" if card.is_air else "ground"
	var cd = get_node_or_null("/root/CombatDirector")
	if cd == null:
		return spawned
	var token: int = cd.reserve_spawn_card(card, stream)
	if token == 0:
		return spawned
	# A purchase owns one sector for all of its members.
	encounter_remaining = card.group_size
	encounter_angle = encounter_rng.randf() * TAU

	for i in range(card.group_size):
		var spawn_pos = find_valid_spawn_position(family, center_pos, card.variant_id)
		if spawn_pos == Vector3.INF:
			# Failed placement: refund remaining unspawned units in group
			var remaining = card.group_size - spawned.size()
			for unused in range(i, i + remaining):
				cd.settle_spawn_member(token, false, unused)
			break

		var enemy_node = _create_enemy_node(card.variant_id)
		# BaseEnemy initializes shield, stats, rewards and collider exactly once in ready.
		enemy_node.modifier = card.modifier_type

		if get_parent() is Node3D:
			enemy_node.position = get_parent().to_local(spawn_pos)
		else:
			enemy_node.position = spawn_pos

		if get_parent():
			get_parent().add_child(enemy_node)
		elif get_tree() and get_tree().root:
			get_tree().root.add_child(enemy_node)

		enemy_node.global_position = spawn_pos

		if has_node("/root/ShaderManager"):
			get_node("/root/ShaderManager").apply_selective_outline(enemy_node, 0.009)

		spawned.append(enemy_node)

		if cd:
			cd.settle_spawn_member(token, true, i)
			cd.telemetry_last_sector = encounter_angle
			cd.telemetry_last_distance = spawn_pos.distance_to(center_pos)

	return spawned

func _check_administrative_retirements(cd: Node) -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	var player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		return
	var player_pos = player.global_position
	var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() else null
	var enemies = get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if enemy.is_in_group("bosses") or enemy.is_in_group("mission_targets"):
			continue

		var v_id = enemy.variant_id if "variant_id" in enemy else ""
		var family = "ground"
		if EnemyDataClass.VARIANTS.has(v_id):
			family = EnemyDataClass.VARIANTS[v_id].get("family", "ground")

		# Family-specific retirement thresholds (Section 5)
		var threshold = 140.0
		if v_id == "rail_crawler":
			threshold = 165.0 # Azure rail crawler has 130m weapon reach!
		elif v_id in ["siege_tank", "gatling_heavy", "desert_barrage_rover"]:
			threshold = 150.0
		elif v_id in ["scout_buggy", "assault_apc", "raptor_raider"]:
			threshold = 130.0
		elif v_id in ["interceptor", "heavy_bomber"]:
			threshold = 185.0
		elif family == "air":
			threshold = 150.0

		var offset = enemy.global_position - player_pos
		var dist_h = Vector2(offset.x, offset.z).length()

		var beyond_threshold = (dist_h > threshold)
		var visible_bounds := cam != null and is_spawn_visible(cam, enemy.global_position, v_id)
		var engaged := false
		if "behavior_state" in enemy:
			engaged = enemy.behavior_state in [BaseEnemy.BehaviorState.WINDUP, BaseEnemy.BehaviorState.FIRE]
		if "weapon_reach_3d" in enemy:
			engaged = engaged or dist_h <= enemy.weapon_reach_3d + 15.0
		var key := enemy.get_instance_id()
		if not beyond_threshold or visible_bounds or engaged:
			retirement_candidates.erase(key)
			continue
		if not retirement_candidates.has(key):
			retirement_candidates[key] = cd.active_combat_time
		elif cd.active_combat_time - float(retirement_candidates[key]) >= RETIREMENT_DWELL_SECONDS:
			_retire_enemy(enemy, cd)
	# Bound metadata even when enemies die through the ordinary combat path.
	for key in retirement_candidates.keys():
		if not is_instance_id_valid(key):
			retirement_candidates.erase(key)

func _retire_enemy(enemy: Node, cd: Node) -> void:
	retirement_candidates.erase(enemy.get_instance_id())
	if cd:
		if cd.has_method("release_air_attack_slot"):
			cd.release_air_attack_slot(enemy)
		if cd.has_method("release_heavy_attack_slot"):
			cd.release_heavy_attack_slot(enemy)
		if "telemetry_retirements" in cd:
			cd.telemetry_retirements += 1

	if enemy.has_method("clear_telegraph"):
		enemy.clear_telegraph()

	# Administrative retirement gives NO XP, NO score, NO credits, NO explosion
	enemy.queue_free()

func spawn_enemy_type(variant_key: String, custom_pos: Vector3 = Vector3.INF, allow_test_bypass: bool = false) -> Node3D:
	if not is_inside_tree() or get_tree() == null:
		return null

	# Fixture bypass never enables disabled/unknown assets.
	if not EnemyDataClass.is_variant_enabled(variant_key):
		return null
	var cd = get_node_or_null("/root/CombatDirector")
	if not allow_test_bypass and (cd == null or not cd.is_active_combat_eligible() or not cd.can_spawn_variant(variant_key)):
		return null

	var player = get_tree().get_first_node_in_group("player")
	var center_pos = player.global_position if player else Vector3.ZERO
	var family = "air"
	if EnemyDataClass.VARIANTS.has(variant_key):
		family = EnemyDataClass.VARIANTS[variant_key].get("family", "air")

	var spawn_pos: Vector3
	if custom_pos != Vector3.INF:
		spawn_pos = custom_pos
		if not allow_test_bypass:
			var planar_distance := Vector2(spawn_pos.x - center_pos.x, spawn_pos.z - center_pos.z).length()
			var camera := get_viewport().get_camera_3d()
			if planar_distance < 40.0 or (camera and is_spawn_visible(camera, spawn_pos, variant_key)):
				return null
	else:
		spawn_pos = find_valid_spawn_position(family, center_pos, variant_key)
	if spawn_pos == Vector3.INF:
		return null

	var enemy_node = _create_enemy_node(variant_key)

	# Set the transform before ready() so AI never initializes at the origin.
	if get_parent() is Node3D:
		enemy_node.position = get_parent().to_local(spawn_pos)
	else:
		enemy_node.position = spawn_pos
	if get_parent():
		get_parent().add_child(enemy_node)
	elif get_tree() and get_tree().root:
		get_tree().root.add_child(enemy_node)

	enemy_node.global_position = spawn_pos
	if has_node("/root/ShaderManager"):
		get_node("/root/ShaderManager").apply_selective_outline(enemy_node, 0.009)
	if has_node("/root/CombatDirector"):
		get_node("/root/CombatDirector").record_spawn()
	return enemy_node

func spawn_bounds_radius(variant_key: String) -> float:
	# Includes hull, gun overhang and rotor/wing span, rather than only the root point.
	if variant_key in ["scout_drone", "kamikaze_drone", "shield_drone", "repair_drone"]:
		return 3.0
	if variant_key == "rail_crawler":
		return 12.0
	if variant_key == "desert_barrage_rover":
		return 7.0
	if variant_key == "raptor_raider":
		return 6.0
	return 8.0 if EnemyDataClass.get_spec(variant_key).get("family", "ground") == "air" else 7.0

func is_spawn_visible(cam: Camera3D, position: Vector3, variant_key: String) -> bool:
	var radius := spawn_bounds_radius(variant_key)
	var viewport_center := cam.get_viewport().get_visible_rect().size * 0.5
	var inside := cam.project_position(viewport_center, maxf(cam.near * 2.0, 1.0))
	# Determine each plane's outside sign from a known interior point.
	for plane in cam.get_frustum():
		var sign_out := -1.0 if plane.distance_to(inside) > 0.0 else 1.0
		if plane.distance_to(position + Vector3.UP * 1.5) * sign_out > radius:
			return false
	return true

func find_valid_spawn_position(family: String, center_pos: Vector3, variant_key: String = "") -> Vector3:
	var space: PhysicsDirectSpaceState3D = null
	if is_inside_tree() and get_tree() != null and get_tree().root != null and get_tree().root.get_world_3d() != null:
		space = get_tree().root.get_world_3d().direct_space_state

	var block_size = 38.0
	const MIN_PLANAR_EXCLUSION: float = 40.0

	var city := get_parent().get_node_or_null("CityGenerator")
	if city:
		block_size = city.block_size

	var player_node = get_tree().get_first_node_in_group("player") if get_tree() else null
	var player_vel = Vector3.ZERO
	if is_instance_valid(player_node) and "velocity" in player_node and player_node.velocity is Vector3:
		player_vel = player_node.velocity

	var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() else null

	# Successive units enter from a seeded approach sector; failed candidates fan out.
	if encounter_remaining <= 0:
		if player_vel.length_squared() > 16.0:
			# Prioritize intercept approach sectors ahead of the flight path (+-60 deg)
			var flight_yaw = atan2(player_vel.z, player_vel.x)
			encounter_angle = flight_yaw + encounter_rng.randf_range(-PI / 3.0, PI / 3.0)
		else:
			encounter_angle = encounter_rng.randf() * TAU
		encounter_remaining = encounter_rng.randi_range(2, 4)

	for attempt in range(40):
		var spread := 0.30 if attempt < 12 else PI
		var angle = encounter_angle + encounter_rng.randf_range(-spread, spread)
		var dist = encounter_rng.randf_range(62.0, 95.0)

		# Intercept sectors: route candidates ahead of a moving player (Section 3)
		var gen_center = center_pos
		if player_vel.length_squared() > 16.0:
			gen_center = center_pos + Vector3(player_vel.x, 0.0, player_vel.z).normalized() * 25.0

		var cand_x = gen_center.x + cos(angle) * dist
		var cand_z = gen_center.z + sin(angle) * dist
		var limit := GameConstants.BOUNDARY_HARD_RADIUS - 12.0
		if absf(cand_x) > limit or absf(cand_z) > limit:
			continue

		if family == "ground":
			# Snap to nearest street (along X) or avenue (along Z) corridor
			var nearest_ave_x = roundf(cand_x / block_size) * block_size
			var nearest_str_z = roundf(cand_z / block_size) * block_size
			var dist_to_ave = absf(cand_x - nearest_ave_x)
			var dist_to_str = absf(cand_z - nearest_str_z)
			if dist_to_ave < dist_to_str:
				cand_x = nearest_ave_x + encounter_rng.randf_range(-1.8, 1.8)
			else:
				cand_z = nearest_str_z + encounter_rng.randf_range(-1.2, 1.2)

			# Ensure candidate is strictly on road corridor
			if UrbanPathfinder.distance_to_nearest_road(Vector3(cand_x, 0.5, cand_z)) > 2.5:
				continue

			# Post-snap planar safe distance check (Section 1 & 3): verify >= 40m from player
			var post_snap_dist = Vector2(cand_x - center_pos.x, cand_z - center_pos.z).length()
			if post_snap_dist < MIN_PLANAR_EXCLUSION:
				continue

			var surface_y := 0.0
			if space != null:
				var surface_query = PhysicsRayQueryParameters3D.create(Vector3(cand_x, 60.0, cand_z), Vector3(cand_x, -100.0, cand_z), 2)
				var surface = space.intersect_ray(surface_query)
				if surface.is_empty() or surface.normal.y < 0.85:
					continue
				surface_y = surface.position.y
				# Roads are generated at street level; reject building tops over a road candidate.
				var road_level := UrbanPathfinder.get_nearest_road_point(Vector3(cand_x, surface_y, cand_z)).y
				if absf(surface_y - road_level) > 1.8:
					continue
			if cam and is_spawn_visible(cam, Vector3(cand_x, surface_y, cand_z), variant_key):
				continue

			# Test clearance against buildings & obstacles (Mask 6)
			if space != null and _cached_shape_query != null and _cached_box_shape != null:
				var box_size = Vector3(3.2, 2.2, 5.2)
				if variant_key in ["flak_tank", "missile_carrier", "siege_tank", "gatling_heavy"]:
					box_size = Vector3(3.6, 2.4, 7.2)
				elif variant_key in ["sam_launcher", "assault_apc", "desert_barrage_rover"]:
					box_size = Vector3(3.4, 2.4, 6.4)
				elif variant_key == "raptor_raider":
					box_size = Vector3(3.8, 2.2, 5.8)
				_cached_box_shape.size = box_size
				_cached_shape_query.transform = Transform3D(Basis.IDENTITY, Vector3(cand_x, surface_y + 1.5, cand_z))
				var hits = space.intersect_shape(_cached_shape_query, 1)
				if not hits.is_empty():
					continue

			if absf(cand_x) <= limit and absf(cand_z) <= limit:
				if is_instance_valid(player_node) and UrbanPathfinder.find_street_path(Vector3(cand_x, surface_y, cand_z), center_pos).is_empty():
					continue
				encounter_remaining -= 1
				return Vector3(cand_x, surface_y + 0.1, cand_z)

		else:
			# Air & Support units: check downward rooftop height
			var cand_y = encounter_rng.randf_range(22.0, 36.0)
			if space != null:
				var ray_down = PhysicsRayQueryParameters3D.create(Vector3(cand_x, 60.0, cand_z), Vector3(cand_x, 0.0, cand_z), 2)
				var hit = space.intersect_ray(ray_down)
				if hit.is_empty():
					continue
				if not hit.is_empty():
					var roof_h: float = hit.get("position", Vector3.ZERO).y
					cand_y = maxf(cand_y, roof_h + 8.0)
				if cand_y > 52.0:
					continue

				var shape_query = PhysicsShapeQueryParameters3D.new()
				var sphere = SphereShape3D.new()
				sphere.radius = 3.8
				shape_query.shape = sphere
				shape_query.transform = Transform3D(Basis.IDENTITY, Vector3(cand_x, cand_y, cand_z))
				shape_query.collision_mask = 6
				var air_hits = space.intersect_shape(shape_query, 1)
				if not air_hits.is_empty():
					continue

			# Post-snap planar safe distance check for air
			var post_dist = Vector2(cand_x - center_pos.x, cand_z - center_pos.z).length()
			if post_dist < MIN_PLANAR_EXCLUSION:
				continue

			# Frustum check preference
			if cam:
				if is_spawn_visible(cam, Vector3(cand_x, cand_y, cand_z), variant_key):
					continue

			encounter_remaining -= 1
			return Vector3(cand_x, cand_y, cand_z)

	# Retry on the next replenishment tick instead of placing an unchecked unit.
	return Vector3.INF

func _create_enemy_node(variant_key: String) -> CharacterBody3D:
	var enemy: CharacterBody3D
	match variant_key:
		"rocket_buggy", "flame_tank", "rail_crawler", "hunter_drone", "torpedo_vtol", "escort_fighter":
			enemy = ProceduralRaider.new()
		"scout_buggy", "mortar_crawler", "attack_wing", "assault_apc", "sam_launcher", "technical_truck", "stealth_vtol", "heavy_bomber", "raptor_raider", "desert_barrage_rover":
			enemy = ProceduralRaider.new()
		"attack_gunship":
			enemy = AttackGunshipScript.new()
		"scout_drone":
			enemy = ScoutDroneScript.new()
		"kamikaze_drone":
			enemy = KamikazeDroneScript.new()
		"rocket_gunship":
			enemy = RocketGunshipScript.new()
		"interceptor":
			enemy = InterceptorScript.new()
		"minelayer":
			enemy = MinelayerScript.new()
		"flak_tank":
			enemy = FlakTankScript.new()
		"missile_carrier":
			enemy = MissileCarrierScript.new()
		"siege_tank":
			enemy = SiegeTankScript.new()
		"gatling_heavy":
			enemy = GatlingHeavyScript.new()
		"infantry_squad":
			enemy = InfantrySquadScript.new()
		"shield_drone":
			enemy = ShieldDroneScript.new()
		"repair_drone":
			enemy = RepairDroneScript.new()
		_:
			enemy = AttackGunshipScript.new()

	enemy.variant_id = variant_key

	# Calibrated scale based on unit class (Tanks: 7m long, Gunships: 9m, Drones: 2.8m, Infantry: 1.8m)
	var col_size = Vector3(2.5, 2.0, 3.5)

	if variant_key in ["flak_tank", "missile_carrier", "siege_tank", "gatling_heavy"]:
		col_size = Vector3(3.6, 2.2, 7.0)
	elif variant_key == "sam_launcher":
		col_size = Vector3(3.4, 2.4, 6.4)
	elif variant_key == "assault_apc":
		col_size = Vector3(3.2, 2.2, 6.2)
	elif variant_key == "desert_barrage_rover":
		col_size = Vector3(3.2, 2.4, 6.2)
	elif variant_key == "raptor_raider":
		col_size = Vector3(3.8, 2.2, 5.8)
	elif variant_key == "technical_truck":
		col_size = Vector3(2.2, 1.8, 4.4)
	elif variant_key in ["scout_drone", "kamikaze_drone", "shield_drone", "repair_drone"]:
		col_size = Vector3(2.4, 1.4, 2.8)
	elif variant_key in ["attack_gunship", "rocket_gunship", "minelayer"]:
		col_size = Vector3(3.2, 2.2, 9.0)
	elif variant_key == "heavy_bomber":
		col_size = Vector3(8.0, 2.2, 8.0)
	elif variant_key == "stealth_vtol":
		col_size = Vector3(5.5, 1.8, 5.0)
	elif variant_key == "infantry_squad":
		col_size = Vector3(2.0, 1.8, 2.0)
	elif variant_key in ["attack_wing", "interceptor"]:
		col_size = Vector3(6.0, 1.5, 4.0)
	elif variant_key == "mortar_crawler":
		col_size = Vector3(3.6, 2.5, 5.0)

	if variant_key == "rocket_buggy":
		col_size = Vector3(2.8, 2.4, 4.6)
	elif variant_key in ["flame_tank", "rail_crawler"]:
		col_size = Vector3(3.9, 2.5, 6.2)
	elif variant_key == "hunter_drone":
		col_size = Vector3(3.6, 1.5, 3.6)
	elif variant_key in ["torpedo_vtol", "escort_fighter"]:
		col_size = Vector3(7.0, 2.0, 5.5)

	# Add CollisionShape3D
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = col_size
	col.shape = shape
	col.position = Vector3(0, col_size.y * 0.5, 0)
	enemy.add_child(col)

	# Add DamageReceiver
	var receiver = DamageReceiverScript.new()
	receiver.name = "DamageReceiver"
	enemy.add_child(receiver)

	# Build authentic Nuclear Strike 3D visual geometry
	_build_enemy_visuals(enemy, variant_key, col_size)
	_reduce_visual_detail(enemy)

	# Modifiers are set explicitly by director cards (Section 6) rather than random unbudgeted rolls.
	enemy.modifier = EnemyDataClass.ModifierType.NONE

	return enemy

func _reduce_visual_detail(root: Node) -> void:
	# Stock primitives default to dozens of rings; tactical silhouettes need far fewer.
	for child in root.get_children():
		if child is MeshInstance3D:
			if child.mesh is SphereMesh:
				child.mesh.radial_segments = 12
				child.mesh.rings = 6
			elif child.mesh is CylinderMesh:
				child.mesh.radial_segments = 12
			child.visibility_range_end = 230.0
		_reduce_visual_detail(child)

## Builds authentic, beautifully styled Nuclear Strike 3D military models
func _build_enemy_visuals(enemy: CharacterBody3D, variant_key: String, _col_size: Vector3) -> void:
	if variant_key in FIELD_ROLES:
		FieldRaiderVisuals.build(enemy, variant_key, encounter_rng.randi())
		return
	if variant_key in ["scout_buggy", "gatling_heavy", "mortar_crawler", "attack_wing", "interceptor", "assault_apc", "sam_launcher", "technical_truck", "stealth_vtol", "heavy_bomber", "attack_gunship", "rocket_gunship", "minelayer", "raptor_raider", "desert_barrage_rover"]:
		RaiderVisuals.build(enemy, variant_key)
		return
	if variant_key == "siege_tank":
		var rig = DesertIroncladScene.instantiate()
		var new_visuals = rig.get_node_or_null("Visuals")
		var turret = rig.get_node_or_null("Turret")
		if new_visuals and turret:
			rig.remove_child(new_visuals)
			rig.remove_child(turret)
			new_visuals.owner = null
			turret.owner = null
			enemy.add_child(new_visuals)
			enemy.add_child(turret)
			rig.queue_free()
			return
	var vis = Node3D.new()
	vis.name = "Visuals"
	enemy.add_child(vis)

	# Common Military Materials
	var mat_armor_green = StandardMaterial3D.new()
	var ground_palette := {"flak_tank": Color("65754a"), "siege_tank": Color("9a7751"), "gatling_heavy": Color("635d76"), "missile_carrier": Color("517875")}
	mat_armor_green.albedo_color = ground_palette.get(variant_key, Color("65754a"))
	mat_armor_green.metallic = 0.35
	mat_armor_green.roughness = 0.65

	var mat_armor_dark = StandardMaterial3D.new()
	mat_armor_dark.albedo_color = Color(0.20, 0.22, 0.24, 1.0) # Gunship charcoal
	mat_armor_dark.metallic = 0.5
	mat_armor_dark.roughness = 0.4

	var mat_treads = StandardMaterial3D.new()
	mat_treads.albedo_color = Color(0.12, 0.13, 0.14, 1.0) # Dark rubber/steel
	mat_treads.metallic = 0.7
	mat_treads.roughness = 0.8

	var mat_gun_metal = StandardMaterial3D.new()
	mat_gun_metal.albedo_color = Color(0.14, 0.15, 0.16, 1.0)
	mat_gun_metal.metallic = 0.85
	mat_gun_metal.roughness = 0.3

	if variant_key in ["flak_tank", "missile_carrier", "siege_tank", "gatling_heavy"]:
		# --- GROUND TANK VEHICLES ---
		# 1. Armored Lower Hull (3.4m x 1.2m x 6.6m)
		var hull_inst = MeshInstance3D.new()
		var hull_mesh = BoxMesh.new()
		hull_mesh.size = Vector3(3.4, 1.2, 6.6)
		hull_mesh.material = mat_armor_green
		hull_inst.mesh = hull_mesh
		hull_inst.position = Vector3(0, 0.6, 0)
		vis.add_child(hull_inst)

		# 2. Left & Right Track Skirts
		for side in [-1.0, 1.0]:
			var tread = MeshInstance3D.new()
			var tr_mesh = BoxMesh.new()
			tr_mesh.size = Vector3(0.42, 0.9, 6.8)
			tr_mesh.material = mat_treads
			tread.mesh = tr_mesh
			tread.position = Vector3(side * 1.62, 0.45, 0)
			vis.add_child(tread)

		# 3. Turret Assembly (attached to $Turret node for independent aiming tracking)
		var turret = Node3D.new()
		turret.name = "Turret"
		turret.position = Vector3(0, 1.25, -0.2)
		enemy.add_child(turret)

		var turret_mesh_inst = MeshInstance3D.new()
		var t_mesh = BoxMesh.new()
		t_mesh.size = Vector3(2.4, 0.8, 2.8)
		t_mesh.material = mat_armor_green
		turret_mesh_inst.mesh = t_mesh
		turret_mesh_inst.position = Vector3(0, 0.4, 0)
		turret.add_child(turret_mesh_inst)

		# Commander cupola hatch
		var hatch = MeshInstance3D.new()
		var h_mesh = CylinderMesh.new()
		h_mesh.top_radius = 0.32
		h_mesh.bottom_radius = 0.32
		h_mesh.height = 0.18
		h_mesh.material = mat_treads
		hatch.mesh = h_mesh
		hatch.position = Vector3(0.5, 0.85, 0.3)
		turret.add_child(hatch)

		# Armament based on tank class (extending along -Z)
		match variant_key:
			"flak_tank":
				# Dual AA autocannon barrels elevated at +18 deg
				for side in [-0.5, 0.5]:
					var barrel = MeshInstance3D.new()
					var b_mesh = CylinderMesh.new()
					b_mesh.top_radius = 0.1
					b_mesh.bottom_radius = 0.1
					b_mesh.height = 3.6
					b_mesh.material = mat_gun_metal
					barrel.mesh = b_mesh
					barrel.position = Vector3(side, 0.5, -2.1)
					barrel.rotation_degrees = Vector3(-72.0, 0, 0) # Tilted up toward sky
					turret.add_child(barrel)

			"siege_tank":
				# Massive 125mm heavy cannon barrel extending forward
				var cannon = MeshInstance3D.new()
				var c_mesh = CylinderMesh.new()
				c_mesh.top_radius = 0.16
				c_mesh.bottom_radius = 0.18
				c_mesh.height = 4.8
				c_mesh.material = mat_gun_metal
				cannon.mesh = c_mesh
				cannon.position = Vector3(0, 0.4, -2.6)
				cannon.rotation_degrees = Vector3(-90.0, 0, 0)
				turret.add_child(cannon)

				var brake = MeshInstance3D.new()
				var br_mesh = BoxMesh.new()
				br_mesh.size = Vector3(0.52, 0.38, 0.6)
				br_mesh.material = mat_gun_metal
				brake.mesh = br_mesh
				brake.position = Vector3(0, 0.4, -4.9)
				turret.add_child(brake)

			"gatling_heavy":
				# Rotary multi-barrel gatling gun
				var gatling = MeshInstance3D.new()
				var g_mesh = CylinderMesh.new()
				g_mesh.top_radius = 0.28
				g_mesh.bottom_radius = 0.28
				g_mesh.height = 3.4
				g_mesh.material = mat_gun_metal
				gatling.mesh = g_mesh
				gatling.position = Vector3(0, 0.4, -2.0)
				gatling.rotation_degrees = Vector3(-90.0, 0, 0)
				turret.add_child(gatling)

			"missile_carrier":
				# Elevated dual SAM missile launcher box
				var rack = MeshInstance3D.new()
				var r_mesh = BoxMesh.new()
				r_mesh.size = Vector3(2.0, 0.8, 2.6)
				r_mesh.material = mat_armor_green
				rack.mesh = r_mesh
				rack.position = Vector3(0, 0.65, -0.4)
				rack.rotation_degrees = Vector3(-32.0, 0, 0)
				turret.add_child(rack)

				# Missiles loaded in launcher
				var mat_missile = StandardMaterial3D.new()
				mat_missile.albedo_color = Color(0.92, 0.92, 0.95)
				for side in [-0.55, 0.55]:
					var m_tip = MeshInstance3D.new()
					var tip_mesh = CylinderMesh.new()
					tip_mesh.top_radius = 0.12
					tip_mesh.bottom_radius = 0.12
					tip_mesh.height = 2.2
					tip_mesh.material = mat_missile
					m_tip.mesh = tip_mesh
					m_tip.position = Vector3(side, 0.75, -1.2)
					m_tip.rotation_degrees = Vector3(-32.0, 0, 0)
					turret.add_child(m_tip)

	elif variant_key == "infantry_squad":
		# --- INFANTRY FIRETEAM SQUAD (3 Soldiers on Street) ---
		var offsets = [Vector3(0, 0, -0.6), Vector3(-0.7, 0, 0.6), Vector3(0.7, 0, 0.6)]
		for pos_off in offsets:
			var soldier = Node3D.new()
			soldier.position = pos_off
			vis.add_child(soldier)

			# Torso
			var torso = MeshInstance3D.new()
			var t_mesh = BoxMesh.new()
			t_mesh.size = Vector3(0.48, 0.75, 0.32)
			t_mesh.material = mat_armor_green
			torso.mesh = t_mesh
			torso.position = Vector3(0, 0.75, 0)
			soldier.add_child(torso)

			# Helmet
			var helmet = MeshInstance3D.new()
			var h_mesh = SphereMesh.new()
			h_mesh.radius = 0.22
			h_mesh.height = 0.38
			h_mesh.material = mat_armor_green
			helmet.mesh = h_mesh
			helmet.position = Vector3(0, 1.35, 0)
			soldier.add_child(helmet)

			# Rifle
			var rifle = MeshInstance3D.new()
			var r_mesh = BoxMesh.new()
			r_mesh.size = Vector3(0.1, 0.12, 0.75)
			r_mesh.material = mat_gun_metal
			rifle.mesh = r_mesh
			rifle.position = Vector3(0.22, 0.8, -0.35)
			soldier.add_child(rifle)

	else:
		# --- DRONES & SUPPORT UNITS ---
		# Drone central body
		var body = MeshInstance3D.new()
		var b_mesh = BoxMesh.new()
		b_mesh.size = Vector3(1.6, 0.55, 1.8)
		b_mesh.material = mat_armor_dark
		body.mesh = b_mesh
		body.position = Vector3(0, 0.7, 0)
		vis.add_child(body)

		# 4 Corner Quadrotor Arms & Discs
		var disc_mat = StandardMaterial3D.new()
		disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		disc_mat.albedo_color = Color(0.15, 0.18, 0.22, 0.32)

		for ox in [-1.2, 1.2]:
			for oz in [-1.2, 1.2]:
				var arm = MeshInstance3D.new()
				var arm_m = BoxMesh.new()
				arm_m.size = Vector3(0.12, 0.1, 1.2)
				arm_m.material = mat_gun_metal
				arm.mesh = arm_m
				arm.position = Vector3(ox * 0.5, 0.7, oz * 0.5)
				arm.rotation_degrees = Vector3(0, 45.0 if (ox * oz > 0) else -45.0, 0)
				vis.add_child(arm)

				var prop = MeshInstance3D.new()
				var p_mesh = CylinderMesh.new()
				p_mesh.top_radius = 0.65
				p_mesh.bottom_radius = 0.65
				p_mesh.height = 0.02
				prop.mesh = p_mesh
				prop.material_override = disc_mat
				prop.position = Vector3(ox, 0.8, oz)
				vis.add_child(prop)

		# Role-Specific Core Emitters
		match variant_key:
			"kamikaze_drone":
				var core = MeshInstance3D.new()
				var c_m = SphereMesh.new()
				c_m.radius = 0.45
				c_m.height = 0.9
				var c_mat = StandardMaterial3D.new()
				c_mat.albedo_color = Color(1.0, 0.15, 0.1) # Glowing red warhead
				c_mat.emission_enabled = true
				c_mat.emission = Color(1.0, 0.2, 0.1)
				c_mat.emission_energy_multiplier = 2.0
				core.mesh = c_m
				core.material_override = c_mat
				core.position = Vector3(0, 0.7, 0)
				vis.add_child(core)

			"shield_drone":
				# Luminous energy core + outer bubble shield
				var core = MeshInstance3D.new()
				var c_m = SphereMesh.new()
				c_m.radius = 0.5
				c_m.height = 1.0
				var c_mat = StandardMaterial3D.new()
				c_mat.albedo_color = Color(0.15, 0.75, 1.0)
				c_mat.emission_enabled = true
				c_mat.emission = Color(0.2, 0.8, 1.0)
				c_mat.emission_energy_multiplier = 2.5
				core.mesh = c_m
				core.material_override = c_mat
				core.position = Vector3(0, 0.7, 0)
				vis.add_child(core)

				# Translucent energy bubble shield
				var bubble = MeshInstance3D.new()
				var b_sph = SphereMesh.new()
				b_sph.radius = 7.0
				b_sph.height = 14.0
				var b_mat = StandardMaterial3D.new()
				b_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				b_mat.albedo_color = Color(0.2, 0.65, 1.0, 0.16)
				b_mat.roughness = 0.1
				b_mat.emission_enabled = true
				b_mat.emission = Color(0.1, 0.5, 0.9)
				b_mat.emission_energy_multiplier = 0.4
				bubble.mesh = b_sph
				bubble.material_override = b_mat
				bubble.position = Vector3(0, 0.7, 0)
				vis.add_child(bubble)

			"repair_drone":
				var core = MeshInstance3D.new()
				var c_m = SphereMesh.new()
				c_m.radius = 0.45
				c_m.height = 0.9
				var c_mat = StandardMaterial3D.new()
				c_mat.albedo_color = Color(0.2, 1.0, 0.3) # Bright medical green
				c_mat.emission_enabled = true
				c_mat.emission = Color(0.2, 1.0, 0.3)
				c_mat.emission_energy_multiplier = 2.0
				core.mesh = c_m
				core.material_override = c_mat
				core.position = Vector3(0, 0.7, 0)
				vis.add_child(core)

			_: # scout_drone
				var core = MeshInstance3D.new()
				var c_m = SphereMesh.new()
				c_m.radius = 0.35
				c_m.height = 0.7
				var c_mat = StandardMaterial3D.new()
				c_mat.albedo_color = Color(1.0, 0.85, 0.2) # Amber sensor eye
				c_mat.emission_enabled = true
				c_mat.emission = Color(1.0, 0.85, 0.2)
				c_mat.emission_energy_multiplier = 1.8
				core.mesh = c_m
				core.material_override = c_mat
				core.position = Vector3(0, 0.7, -0.6)
				vis.add_child(core)
