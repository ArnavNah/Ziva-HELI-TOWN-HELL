class_name MissionManager
extends Node

const MissionSpecsClass = preload("res://src/missions/mission_specs.gd")
const Site = preload("res://src/missions/mission_site.gd")
signal mission_started(mission_id: String, details: Dictionary)
signal mission_progressed(current_val: float, target_val: float)
signal mission_completed(details: Dictionary, bonus_won: bool)
signal mission_failed(details: Dictionary)

var active_mission_id := ""
var active_mission_data: Dictionary = {}
var is_mission_active := false
var mission_timer := 0.0
var hold_progress := 0.0
var current_kills := 0
var sam_damage_taken := false
var inter_mission_cooldown := 20.0
var cooldown_timer := 5.0
var phase := ""
var status_text := "Awaiting tasking"
var progress_goal := 1.0
var mission_serial := 0
var pickup_site: Node3D
var delivery_site: Node3D
var objective_site: Node3D
var borrowed_target: Node3D
var owned_sites: Array[Node3D] = []
var route := PackedVector3Array()
var route_index := 0
var passengers_aboard := 0
var recent_missions: Array[String] = []
var rng := RandomNumberGenerator.new()
var result_text := ""
var result_timer := 0.0
var cargo_completed := false
var escort_attackers: Array[WeakRef] = []
var escort_scan_timer := 0.0
var counted_enemy_ids: Dictionary = {}
var placement_diagnostics: Dictionary = {}
var roof_anchor: WeakRef
var hazard_timer := 6.0
var hazard_warning := 0.0
var hazard_aim := Vector3.ZERO

func _ready() -> void:
	add_to_group("mission_manager")
	var cd = get_node_or_null("/root/CombatDirector")
	rng.seed = (cd.encounter_seed if cd else 1337) + 9001
	var tracker = preload("res://src/ui/mission_tracker.gd").new()
	tracker.manager = self
	add_child(tracker)
	var bus = get_node_or_null("/root/EventBus")
	if bus:
		bus.run_state_changed.connect(_on_state_changed)
		bus.cargo_delivered.connect(_on_cargo_delivered)
		bus.player_hit.connect(_on_player_hit)

func _on_player_hit(_damage: float, _position: Vector3, _directional: bool, source: String) -> void:
	if is_mission_active and "sam" in source.to_lower(): sam_damage_taken = true

func _on_state_changed(state: int, _old: int) -> void:
	if state in [GameManager.RunState.RESULTS, GameManager.RunState.LOADING, GameManager.RunState.MENU]:
		cancel_mission("Sortie ended", false)

func _combat_eligible() -> bool:
	var gm = get_node_or_null("/root/GameManager")
	return not get_tree().paused and gm != null and gm.current_state == gm.RunState.ACTIVE

func _process(delta: float) -> void:
	if not _combat_eligible(): return
	var player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player) or ("is_dying" in player and player.is_dying):
		if is_mission_active: cancel_mission("Aircraft lost")
		return
	result_timer = maxf(0, result_timer - delta)
	if not is_mission_active:
		cooldown_timer -= delta
		if cooldown_timer <= 0: _generate_next_mission()
		return
	mission_timer += delta
	if mission_timer >= float(active_mission_data.get("time_limit", 240.0)):
		cancel_mission("Objective window expired")
		return
	_process_active_mission(delta)

func _generate_next_mission() -> void:
	var pool: Array[String] = []
	var cd = get_node_or_null("/root/CombatDirector")
	var wave: int = cd.current_wave if cd else 1
	for key in MissionSpecsClass.MISSIONS:
		var data: Dictionary = MissionSpecsClass.MISSIONS[key]
		if not data.get("manual_only", false) and int(data.get("gate_wave", 1)) <= wave and key not in recent_missions:
			pool.append(key)
	if pool.is_empty():
		recent_missions.clear()
		cooldown_timer = 1
		return
	var key: String = "rescue_crew" if active_mission_id.is_empty() else pool[rng.randi_range(0, pool.size() - 1)]
	if not start_mission(key): cooldown_timer = 5

func _kind() -> String:
	return active_mission_data.get("kind", "")

func start_mission(key: String) -> bool:
	if not MissionSpecsClass.MISSIONS.has(key) or not _combat_eligible(): return false
	var cd = get_node_or_null("/root/CombatDirector")
	if cd and cd.current_wave < int(MissionSpecsClass.MISSIONS[key].get("gate_wave", 1)): return false
	if is_mission_active: cancel_mission("Task replaced", false)
	_clear_sites()
	mission_serial += 1
	active_mission_id = key
	active_mission_data = MissionSpecsClass.MISSIONS[key].duplicate(true)
	var kinds := {"rescue_crew": "extract", "destroy_sam": "destroy", "destroy_radar": "destroy", "cargo_run": "cargo", "high_value_target": "hunt", "bounty_leader": "hunt", "clear_airspace": "airspace", "defend_beacon": "defend", "escort_convoy": "escort"}
	active_mission_data["kind"] = active_mission_data.get("kind", kinds.get(key, "defend"))
	mission_timer = 0
	hold_progress = 0
	progress_goal = 1
	current_kills = 0
	counted_enemy_ids.clear()
	passengers_aboard = 0
	sam_damage_taken = false
	cargo_completed = false
	phase = "TRAVEL"
	var player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player): return false
	var location := _find_site(player.global_position)
	if location == Vector3.INF: return false
	is_mission_active = true
	var kind := _kind()
	hazard_timer = 6.0
	hazard_warning = 0.0
	roof_anchor = null
	if kind in ["extract", "sortie"]:
		pickup_site = _create_site(location, active_mission_data.get("visual", "crew"), "EXFIL LZ" if kind == "sortie" else "PICKUP", Color("f5bd63"))
		objective_site = pickup_site
		if kind == "extract":
			var destination := _find_site(location, 100.0)
			if destination == Vector3.INF: return _placement_failed()
			delivery_site = _create_site(destination, "evac", "DELIVERY LZ", Color("62d6c2"))
			delivery_site.set_active_marker(false)
		status_text = "Reach the pickup marker" if kind == "extract" else "Reach exfil LZ; confirm before ending sortie"
	elif kind == "supply":
		var roof := _find_rooftop(player.global_position)
		if roof == Vector3.INF: return _placement_failed()
		objective_site = _create_site(roof, "cargo", "SECURE ROOFTOP CACHE", Color("be8fff"))
		status_text = "Clear hostiles, then stabilize above the rooftop LZ"
	elif kind == "destroy":
		objective_site = _create_site(location, "sam" if key == "destroy_sam" else "radar", "DESTROY INSTALLATION", Color("f17662"), true)
		objective_site.objective_destroyed.connect(_on_target_destroyed.bind(mission_serial))
		status_text = "Destroy the marked installation"
	elif kind == "hunt":
		var candidates: Array[Node3D] = []
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy is Node3D and not enemy.is_in_group("bosses") and enemy.has_node("DamageReceiver") and not enemy.get_node("DamageReceiver").is_dead: candidates.append(enemy)
		if candidates.is_empty(): return _placement_failed()
		borrowed_target = candidates[rng.randi_range(0, candidates.size() - 1)]
		borrowed_target.add_to_group("mission_targets")
		objective_site = _create_site(borrowed_target.global_position, "marker", "PRIORITY TARGET", Color("f17662"))
		var serial := mission_serial
		borrowed_target.get_node("DamageReceiver").destroyed.connect(func(_data): _on_target_destroyed(serial), CONNECT_ONE_SHOT)
		status_text = "Eliminate the marked hostile"
	elif kind == "cargo":
		var cargo = get_parent().get_node_or_null("CargoManager")
		if cargo == null: return _placement_failed()
		if cargo.current_state < 4:
			cargo.pickup_pos = location
			cargo.dropoff_pos = _find_site(location, 100)
			if cargo.dropoff_pos == Vector3.INF: return _placement_failed()
			cargo.offer_contract("medical", location.distance_to(cargo.dropoff_pos))
		pickup_site = _create_site(cargo.pickup_pos, "cargo", "CARGO PICKUP", Color("f5bd63"))
		delivery_site = _create_site(cargo.dropoff_pos, "evac", "CARGO DELIVERY", Color("62d6c2"))
		objective_site = pickup_site
		status_text = "Follow cargo pickup and delivery markers"
	else:
		objective_site = _create_site(location, "convoy" if kind == "escort" else "evac", "ESCORT TRANSPORT" if kind == "escort" else "PATROL ZONE", Color("62d6c2"), kind == "escort", true)
		if kind == "escort":
			var endpoint := _find_site(location, 110)
			if endpoint == Vector3.INF: return _placement_failed()
			route = UrbanPathfinder.find_street_path(location, endpoint)
			route.append(endpoint)
			route_index = 0
			objective_site.objective_destroyed.connect(_on_transport_destroyed.bind(mission_serial))
		status_text = "Protect and accompany the transport" if kind == "escort" else "Clear aircraft in the marked sector" if kind == "airspace" else "Hold near the marked beacon"
	recent_missions.append(key)
	if recent_missions.size() > 3: recent_missions.pop_front()
	mission_started.emit(key, active_mission_data)
	get_node("/root/EventBus").tactical_mission_started.emit(active_mission_data)
	return true

func _placement_failed() -> bool:
	cancel_mission("No safe objective site", false)
	return false

func _create_site(location: Vector3, kind: String, title: String, color: Color, damageable: bool = false, friendly: bool = false) -> Node3D:
	var site = Site.new()
	site.configure(kind, title, color, damageable, friendly)
	get_parent().add_child(site)
	site.global_position = location
	owned_sites.append(site)
	return site

func _find_site(center: Vector3, separation: float = 65.0) -> Vector3:
	placement_diagnostics = {"bounds": 0, "distance": 0, "surface": 0, "overlap": 0}
	var parent = get_parent() as Node3D
	if parent == null: return Vector3.INF
	var space = parent.get_world_3d().direct_space_state
	for attempt in range(48):
		var angle := rng.randf() * TAU
		var candidate := UrbanPathfinder.get_nearest_road_point(center + Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(separation, separation + 70))
		# A 12m landing pad needs a wide avenue/intersection, not an 8m side street.
		if attempt % 3 == 0:
			candidate.x = 0
		elif attempt % 3 == 1:
			candidate.z = 0
		else:
			candidate.x = roundf(candidate.x / 38.0) * 38.0
			candidate.z = roundf(candidate.z / 38.0) * 38.0
		if maxf(absf(candidate.x), absf(candidate.z)) > 235:
			placement_diagnostics.bounds += 1
			continue
		if Vector2(candidate.x - center.x, candidate.z - center.z).length() < separation * 0.8:
			placement_diagnostics.distance += 1
			continue
		# Query below the arena's 64m ceiling collider, not from outside the enclosure.
		var hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(candidate + Vector3.UP * 55, candidate - Vector3.UP * 20, 2))
		if hit.is_empty() or hit.normal.y < 0.9 or hit.position.y > 2:
			placement_diagnostics.surface += 1
			placement_diagnostics["last_surface"] = "empty" if hit.is_empty() else str(hit.position) + " / " + str(hit.normal) + " / " + str(hit.collider.get_path())
			continue
		candidate.y = hit.position.y + 0.12
		var query := PhysicsShapeQueryParameters3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(13, 4, 13)
		query.shape = box_shape
		query.collision_mask = 6
		query.transform = Transform3D(Basis.IDENTITY, candidate + Vector3.UP * 2.4)
		var overlaps = space.intersect_shape(query, 1)
		if not overlaps.is_empty():
			placement_diagnostics.overlap += 1
			placement_diagnostics["last_collider"] = str(overlaps[0].collider.get_path())
			continue
		return candidate
	return Vector3.INF

func _in_hover(player: Node3D, site: Node3D) -> bool:
	var offset := player.global_position - site.global_position
	var speed: float = player.velocity.length() if player is CharacterBody3D else 0.0
	return Vector2(offset.x, offset.z).length() <= 12 and offset.y >= 4 and offset.y <= 24 and speed <= 7

func _find_rooftop(center: Vector3) -> Vector3:
	var city = get_parent().get_node_or_null("CityGenerator")
	if city == null: return Vector3.INF
	var space = get_parent().get_world_3d().direct_space_state
	var candidates: Array = city.building_footprints.keys()
	candidates.sort_custom(func(a, b): return a.distance_squared_to(center) < b.distance_squared_to(center))
	for point: Vector3 in candidates:
		if city.building_footprints[point].x < 13 or city.building_footprints[point].y < 13: continue
		var hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP * 55, point + Vector3.UP * 4, 2))
		if hit.is_empty() or hit.position.y > 34 or hit.normal.y < 0.95: continue
		var level: bool = true
		for offset in [Vector3(4, 0, 4), Vector3(-4, 0, 4), Vector3(4, 0, -4), Vector3(-4, 0, -4)]:
			var edge = space.intersect_ray(PhysicsRayQueryParameters3D.create(point + offset + Vector3.UP * 55, point + offset, 2))
			if edge.is_empty() or absf(edge.position.y - hit.position.y) > 0.5: level = false
		if level:
			roof_anchor = weakref(hit.collider)
			return hit.position + Vector3.UP * 0.12
	return Vector3.INF

func _supply_contested() -> bool:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.has_node("DamageReceiver") and not enemy.get_node("DamageReceiver").is_dead and enemy.global_position.distance_to(objective_site.global_position) < 30.0:
			return true
	return false

func _sam_hazard(delta: float, player: Node3D) -> void:
	# One reserved, telegraphed flak shot per cycle; destroy the site to stop it.
	if hazard_warning > 0.0:
		hazard_warning -= delta
		if hazard_warning <= 0.0:
			var projectile = preload("res://scenes/combat/projectile.tscn").instantiate()
			get_parent().add_child(projectile)
			projectile.global_position = objective_site.global_position + Vector3.UP * 4
			projectile.velocity = (hazard_aim - projectile.global_position).normalized() * 55.0
			projectile.collision_mask = 3
			projectile.setup(preload("res://src/combat/damage_data.gd").new(10.0, GameConstants.WeaponType.ROCKET, objective_site, false, 3.0), null, "enemy_heavy")
			get_node("/root/CombatDirector").release_heavy_attack_slot(objective_site)
		return
	hazard_timer -= delta
	if hazard_timer <= 0.0:
		if not get_node("/root/CombatDirector").request_heavy_attack_slot(objective_site): return
		hazard_timer = 6.0
		hazard_warning = 1.5
		hazard_aim = player.global_position
		get_node("/root/EventBus").threat_warning.emit(objective_site.global_position, "SAM FLAK / DESTROY BATTERY", 1.5)

func _process_active_mission(delta: float) -> void:
	if not is_mission_active: return
	var player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player): return
	var kind := _kind()
	if kind in ["extract", "sortie"]:
		if not is_instance_valid(objective_site):
			cancel_mission("Extraction site lost")
			return
		progress_goal = float(active_mission_data.get("delivery_hold", 3.0) if phase == "DELIVER" else active_mission_data.get("hold_time", 4.0))
		if _in_hover(player, objective_site):
			if phase == "TRAVEL": phase = "BOARDING" if kind == "extract" else "SECURING"
			hold_progress = minf(progress_goal, hold_progress + delta)
			status_text = "Unloading / keep hover steady" if phase == "DELIVER" else "Boarding / keep hover steady" if kind == "extract" else "Securing extraction / keep hover steady"
		else:
			hold_progress = maxf(0, hold_progress - delta)
			status_text = "Hover 4–24m above marker, below 7m/s"
			if phase in ["READY", "BOARDING", "SECURING"]: phase = "TRAVEL"
		objective_site.set_progress(hold_progress / progress_goal)
		if hold_progress >= progress_goal:
			if kind == "sortie":
				phase = "READY"
				status_text = "LZ SECURE / Confirm END SORTIE to bank and leave"
			elif phase == "DELIVER": complete_active_mission()
			else:
				phase = "DELIVER"
				passengers_aboard = int(active_mission_data.get("passengers", 0))
				pickup_site.set_active_marker(false)
				pickup_site.set_collected()
				delivery_site.set_active_marker(true)
				objective_site = delivery_site
				hold_progress = 0
				status_text = "Payload aboard / return to delivery LZ"
	elif kind == "supply":
		var anchor = roof_anchor.get_ref() if roof_anchor else null
		if not is_instance_valid(anchor) or anchor.is_queued_for_deletion() or (anchor.has_node("DamageReceiver") and anchor.get_node("DamageReceiver").is_dead):
			cancel_mission("Rooftop destroyed")
			return
		progress_goal = float(active_mission_data.get("hold_time", 8.0))
		if _in_hover(player, objective_site) and not _supply_contested():
			hold_progress += delta
			status_text = "Securing rare supply cache"
		else:
			hold_progress = maxf(0.0, hold_progress - delta)
			status_text = "Clear hostiles within 30m; hover 4–24m above roof below 7m/s"
		objective_site.set_progress(hold_progress / progress_goal)
		if hold_progress >= progress_goal: complete_active_mission()
	elif kind == "defend":
		progress_goal = float(active_mission_data.get("hold_time", 25.0))
		if player.global_position.distance_to(objective_site.global_position) <= float(active_mission_data.get("radius", 34)): hold_progress += delta
		objective_site.set_progress(hold_progress / progress_goal)
		if hold_progress >= progress_goal: complete_active_mission()
	elif kind == "escort":
		escort_scan_timer -= delta
		if escort_scan_timer <= 0:
			escort_scan_timer = 0.6
			_redirect_escort_threats()
		if route_index < route.size():
			var destination := route[route_index]
			destination.y = objective_site.global_position.y
			var offset := destination - objective_site.global_position
			if player.global_position.distance_to(objective_site.global_position) <= 65:
				objective_site.velocity = offset.normalized() * 4.5
				objective_site.move_and_collide(offset.limit_length(delta * 4.5))
				if offset.length() > 0.2: objective_site.rotation.y = atan2(-offset.x, -offset.z)
				status_text = "Convoy moving / remain within 65m"
			else:
				objective_site.velocity = Vector3.ZERO
				status_text = "Convoy waiting / return within 65m"
			if objective_site.global_position.distance_to(destination) <= 0.5: route_index += 1
		progress_goal = maxi(1, route.size())
		hold_progress = route_index
		if route_index >= route.size(): complete_active_mission()
	elif kind == "hunt":
		if not is_instance_valid(borrowed_target): cancel_mission("Target lost")
		else:
			objective_site.global_position = borrowed_target.global_position
			var receiver = borrowed_target.get_node("DamageReceiver")
			progress_goal = receiver.max_health
			hold_progress = receiver.max_health - receiver.current_health
	elif kind == "destroy":
		if active_mission_id == "destroy_sam": _sam_hazard(delta, player)
		var receiver = objective_site.get_node("DamageReceiver")
		progress_goal = receiver.max_health
		hold_progress = receiver.max_health - receiver.current_health
	elif kind == "airspace":
		progress_goal = float(active_mission_data.get("target_kills", 10))
		hold_progress = current_kills
	elif kind == "cargo":
		var cargo = get_parent().get_node_or_null("CargoManager")
		if cargo.current_state == 0:
			cancel_mission("Cargo delivery lost")
			return
		if cargo.current_state >= 4:
			objective_site = delivery_site
			phase = "DELIVER"
		pickup_site.set_active_marker(phase != "DELIVER")
		delivery_site.set_active_marker(phase == "DELIVER")
		progress_goal = 0.75 if phase == "DELIVER" else 1.0
		hold_progress = cargo.unload_hold_timer if phase == "DELIVER" else cargo.load_hold_timer
		status_text = "Deliver cargo to the teal LZ" if phase == "DELIVER" else "Collect cargo at the amber LZ"
	mission_progressed.emit(hold_progress, progress_goal)
	get_node("/root/EventBus").tactical_mission_updated.emit(hold_progress, progress_goal)

func register_kill_for_mission(entity: Node = null) -> void:
	if not is_mission_active or _kind() != "airspace" or not is_instance_valid(entity) or not entity.is_in_group("enemies"): return
	if counted_enemy_ids.has(entity.get_instance_id()): return
	if not entity.has_node("DamageReceiver") or not entity.get_node("DamageReceiver").is_dead: return
	if not "variant_id" in entity or EnemyData.get_spec(entity.variant_id).get("family", "") != "air": return
	if entity.global_position.distance_to(objective_site.global_position) > float(active_mission_data.get("radius", 140)): return
	counted_enemy_ids[entity.get_instance_id()] = true
	current_kills += 1
	if current_kills >= int(active_mission_data.get("target_kills", 10)): complete_active_mission()

func _on_target_destroyed(serial: int) -> void:
	if is_mission_active and serial == mission_serial: complete_active_mission()

func _on_transport_destroyed(serial: int) -> void:
	if is_mission_active and serial == mission_serial: cancel_mission("Transport destroyed")

func _redirect_escort_threats() -> void:
	for index in range(escort_attackers.size() - 1, -1, -1):
		var actor = escort_attackers[index].get_ref()
		if not is_instance_valid(actor) or actor.is_queued_for_deletion() or (actor.has_node("DamageReceiver") and actor.get_node("DamageReceiver").is_dead):
			escort_attackers.remove_at(index)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if escort_attackers.size() >= 2: break
		if not "target" in enemy or not "variant_id" in enemy or EnemyData.get_spec(enemy.variant_id).get("family", "") != "ground": continue
		if enemy.global_position.distance_to(objective_site.global_position) > 120 or enemy.target == objective_site: continue
		if enemy.has_node("DamageReceiver") and enemy.get_node("DamageReceiver").is_dead: continue
		if enemy.has_method("on_attack_slot_expired"): enemy.on_attack_slot_expired("all")
		var cd = get_node_or_null("/root/CombatDirector")
		if cd:
			cd.release_air_attack_slot(enemy)
			cd.release_heavy_attack_slot(enemy)
		enemy.target = objective_site
		enemy.activity_player = objective_site
		escort_attackers.append(weakref(enemy))

func _on_cargo_delivered(_data: Dictionary, _speed: bool, _safe: bool) -> void:
	if is_mission_active and _kind() == "cargo":
		cargo_completed = true
		complete_active_mission()

func request_sortie_extraction() -> bool:
	if is_mission_active and _kind() == "sortie": return false
	return start_mission("sortie_extraction")

func confirm_sortie_extraction() -> bool:
	var player = get_tree().get_first_node_in_group("player")
	if not _combat_eligible() or not is_mission_active or _kind() != "sortie" or phase != "READY" or not is_instance_valid(player) or not _in_hover(player, objective_site): return false
	if "is_dying" in player and player.is_dying: return false
	is_mission_active = false
	_clear_sites()
	get_node("/root/GameManager").settle_extraction(true, "Tactical LZ extraction")
	return true

func complete_active_mission() -> void:
	if not is_mission_active or not _combat_eligible() or _kind() == "sortie": return
	var player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player) or ("is_dying" in player and player.is_dying): return
	match _kind():
		"supply":
			if hold_progress < float(active_mission_data.get("hold_time", 8.0)) or not _in_hover(player, objective_site) or _supply_contested(): return
		"extract":
			if phase != "DELIVER" or hold_progress < float(active_mission_data.get("delivery_hold", 3.0)) or not _in_hover(player, objective_site): return
		"destroy", "hunt":
			var target = borrowed_target if _kind() == "hunt" else objective_site
			if not is_instance_valid(target) or not target.get_node("DamageReceiver").is_dead: return
		"airspace":
			if current_kills < int(active_mission_data.get("target_kills", 10)): return
		"escort":
			if route_index < route.size(): return
		"defend":
			if hold_progress < float(active_mission_data.get("hold_time", 25.0)): return
		"cargo":
			if not cargo_completed: return
	is_mission_active = false
	cooldown_timer = inter_mission_cooldown
	var bonus_won: bool = not sam_damage_taken if _kind() == "destroy" else (mission_timer <= 65 if _kind() == "hunt" else (player.current_hull >= player.max_hull * 0.5 if "current_hull" in player else true))
	var data := active_mission_data.duplicate(true)
	data["rewards_settled"] = true
	var gm = get_node("/root/GameManager")
	gm.add_banked_credits(int(data.get("base_cr", 0)))
	gm.add_salvage(int(data.get("base_salvage", 0)))
	if _kind() == "supply":
		var loot = get_parent().get_node_or_null("LootManager")
		if loot:
			loot.spawn_pickup(3, player.global_position + Vector3(3, -2, 0), 8.0)
			loot.spawn_pickup(4, player.global_position + Vector3(-3, -2, 0), 8.0)
	if bonus_won:
		gm.add_at_risk_credits(int(data.get("bonus_cr", 0)))
		gm.add_salvage(int(data.get("bonus_salvage", 0)))
	if data.has("repair_reward") and player.has_method("repair"): player.repair(float(data.repair_reward))
	if data.has("flare_reward") and player.has_node("Countermeasures"): player.get_node("Countermeasures").replenish_charges(int(data.flare_reward))
	var reward = load("res://scenes/loot/xp_drop.tscn").instantiate()
	reward.xp_amount = int(data.get("base_xp", 0))
	get_parent().add_child(reward)
	reward.global_position = player.global_position + Vector3(0, -3, 3)
	result_text = "MISSION COMPLETE  +%d CR / %d XP cache" % [int(data.get("base_cr", 0)), int(data.get("base_xp", 0))]
	result_timer = 6
	passengers_aboard = 0
	_clear_sites()
	mission_completed.emit(data, bonus_won)
	get_node("/root/EventBus").tactical_mission_completed.emit(data, bonus_won)

func cancel_mission(reason: String, notify: bool = true) -> void:
	var was_active := is_mission_active
	if was_active and _kind() == "cargo":
		var cargo = get_parent().get_node_or_null("CargoManager")
		if cargo and cargo.current_state > 0 and cargo.current_state < 6:
			cargo.fail_delivery(reason)
	is_mission_active = false
	passengers_aboard = 0
	mission_serial += 1
	cooldown_timer = inter_mission_cooldown
	_clear_sites()
	if was_active and notify:
		result_text = "MISSION LOST / " + reason
		result_timer = 6
		var data := active_mission_data.duplicate(true)
		data["failure_reason"] = reason
		mission_failed.emit(data)
		get_node("/root/EventBus").tactical_mission_failed.emit(data)

func _clear_sites() -> void:
	var player = get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	for reference in escort_attackers:
		var enemy = reference.get_ref()
		if is_instance_valid(enemy) and enemy.target == objective_site:
			if enemy.has_method("on_attack_slot_expired"): enemy.on_attack_slot_expired("all")
			enemy.target = player
			enemy.activity_player = player
	escort_attackers.clear()
	if is_instance_valid(borrowed_target): borrowed_target.remove_from_group("mission_targets")
	borrowed_target = null
	for site in owned_sites:
		if is_instance_valid(site):
			var director = get_node_or_null("/root/CombatDirector")
			if director: director.release_heavy_attack_slot(site)
			site.remove_from_group("mission_objectives")
			site.remove_from_group("mission_targets")
			site.remove_from_group("hostile_mission_targets")
			site.queue_free()
	owned_sites.clear()
	objective_site = null
	pickup_site = null
	delivery_site = null
	route.clear()

func _exit_tree() -> void:
	_clear_sites()
