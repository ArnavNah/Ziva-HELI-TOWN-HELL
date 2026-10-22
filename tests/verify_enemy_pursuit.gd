extends SceneTree

const Specs = preload("res://src/enemies/enemy_data.gd")
const Spawner = preload("res://src/enemies/enemy_spawner.gd")
const Hit = preload("res://src/combat/damage_data.gd")
var failures: Array[String] = []
var checks := 0
var arena: Node3D
var player: CharacterBody3D
var spawner: EnemySpawner
var director: Node
var shot_sources: Dictionary = {}

func check(ok: bool, label: String) -> void:
	checks += 1
	print("[PASS] " if ok else "[FAIL] ", label)
	if not ok:
		failures.append(label)

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	seed(7119)
	Engine.time_scale = 8.0
	Engine.physics_ticks_per_second = 480
	Engine.max_fps = 0
	director = root.get_node("CombatDirector")
	director.stop_wave_director()
	director.set_process(false)
	director.current_wave = 1
	director.max_air_slots = 4
	director.max_heavy_slots = 3
	arena = Node3D.new()
	root.add_child(arena)
	current_scene = arena
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 2
	var floor_col := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(600, 1, 600)
	floor_col.shape = floor_shape
	floor_body.add_child(floor_col)
	floor_body.position.y = -0.5
	arena.add_child(floor_body)
	player = CharacterBody3D.new()
	player.add_to_group("player")
	player.position = Vector3(0, 14, 0)
	arena.add_child(player)
	spawner = Spawner.new()
	arena.add_child(spawner)
	spawner.set_process(false)
	node_added.connect(_track_projectile)
	await physics_frame
	_test_progression()
	await _test_all_shooters()
	await _test_chase_restart()
	await _test_cover()
	await _test_clear_street()
	await _test_pause()
	print("ENEMY PURSUIT: %d/%d checks passed" % [checks - failures.size(), checks])
	quit(0 if failures.is_empty() else 1)

func _track_projectile(node: Node) -> void:
	if node is Projectile:
		_record_shot.call_deferred(node)

func _record_shot(projectile: Projectile) -> void:
	if not is_instance_valid(projectile) or not projectile.damage_data:
		return
	var source = projectile.damage_data.attacker
	if not is_instance_valid(source) or not source is BaseEnemy:
		return
	if not shot_sources.has(source.get_instance_id()):
		var planar: Vector3 = source.global_position - player.global_position
		planar.y = 0
		shot_sources[source.get_instance_id()] = {
			"distance": planar.length(), "entry": source.entry_grace_timer,
			"closed": source.has_closed_to_attack_range
		}

func _unit(key: String, pos: Vector3) -> BaseEnemy:
	var unit := spawner._create_enemy_node(key) as BaseEnemy
	unit.modifier = Specs.ModifierType.NONE
	unit.position = pos
	arena.add_child(unit)
	return unit

func _test_progression() -> void:
	var previous := Specs.get_wave_scaling(1)
	for wave in [2, 5, 9, 11, 20, 100]:
		var scaling := Specs.get_wave_scaling(wave)
		check(scaling.health >= previous.health and scaling.damage >= previous.damage and scaling.speed >= previous.speed and scaling.cooldown <= previous.cooldown and scaling.spawn_interval <= previous.spawn_interval, "Wave %d grows progressively harder" % wave)
		previous = scaling
	check(previous.health <= 2.4 and previous.speed <= 1.24 and previous.damage <= 1.45 and previous.cooldown >= 0.68, "Endless progression stays bounded")
	var early := _unit("technical_truck", Vector3(0, 1, 95))
	early.set_physics_process(false)
	director.current_wave = 12
	var late := _unit("technical_truck", Vector3(0, 1, -95))
	late.set_physics_process(false)
	check(late.damage_receiver.max_health > early.damage_receiver.max_health and late.move_speed > early.move_speed and late.combat_cooldown < early.combat_cooldown, "Spawned units receive wave health, speed and firing cadence")
	var hit := Hit.new(10.0, 0, late)
	check(is_equal_approx(hit.raw_damage, 10.0 * late.combat_damage_multiplier), "Enemy damage strength applied once to hit data")
	check(is_equal_approx(Hit.new(10.0, 0, player).raw_damage, 10.0), "Player damage is unaffected")
	check(is_equal_approx(early.combat_windup_time, late.combat_windup_time), "Later waves retain full firing warnings")
	director._setup_wave(11)
	check(director.max_air_slots == 4 and director.max_heavy_slots == 3, "Endless waves restore pressure after boss wave")
	director._setup_wave(100)
	check(director.target_population <= 40, "Population cap survives endless progression")
	director.stop_wave_director()
	director.current_wave = 1
	early.queue_free()
	late.queue_free()

func _test_all_shooters() -> void:
	for key in Specs.VARIANTS:
		var data: Dictionary = Specs.VARIANTS[key]
		if data.role in [Specs.ROLE_SUPPORT, Specs.ROLE_SUICIDE, Specs.ROLE_AREA_HAZARD]:
			continue
		await physics_frame
		var unit := _unit(key, Vector3(0, 24 if data.family == "air" else 1, 95))
		var unit_id := unit.get_instance_id()
		var first_second_clean := true
		var moved_closer := false
		for tick in range(1080): # 18 simulated seconds at the game's normal 60 Hz step.
			await physics_frame
			if tick < 60 and shot_sources.has(unit_id):
				first_second_clean = false
			if tick == 59:
				moved_closer = Vector2(unit.position.x, unit.position.z).length() < 94.0
			if shot_sources.has(unit_id):
				break
		check(first_second_clean and moved_closer, "%s approaches during protected entry" % key)
		var shot: Dictionary = shot_sources.get(unit_id, {})
		check(not shot.is_empty() and shot.get("closed", false) and shot.get("entry", 1.0) <= 0.0 and shot.get("distance", 999.0) <= unit.get_approach_range() + 13.0, "%s closes before shooting (first shot %.1fm)" % [key, shot.get("distance", -1.0)])
		if shot.is_empty():
			print("  diagnostic: ", unit.position, " state=", unit.behavior_state, " reason=", unit.not_firing_reason)
		unit._release_all_slots()
		unit.queue_free()
		for projectile in get_nodes_in_group("combat_projectiles"):
			projectile.queue_free()

func _test_chase_restart() -> void:
	await physics_frame
	var unit := _unit("attack_gunship", Vector3(0, 24, 40))
	unit.entry_grace_period = 0
	var windup_ticks := 0
	var first_shot := false
	for tick in range(360):
		await physics_frame
		if unit.behavior_state == BaseEnemy.BehaviorState.WINDUP:
			windup_ticks += 1
		if shot_sources.has(unit.get_instance_id()):
			first_shot = true
			break
	check(first_shot and windup_ticks >= 20, "Gunship completes its warning before the attack run")
	unit.start_telegraph(0.4)
	unit.set_behavior_state(BaseEnemy.BehaviorState.WINDUP)
	unit.has_air_slot = director.request_air_attack_slot(unit)
	player.position = Vector3(0, 14, -110)
	await physics_frame
	await physics_frame
	check(not unit.has_closed_to_attack_range and unit.behavior_state == BaseEnemy.BehaviorState.PURSUE and not unit.has_air_slot and unit.telegraph_timer <= 0, "Escaping player cancels attack and releases its slot")
	check(unit.velocity.z < 0, "Enemy pursues the player's new position")
	unit.queue_free()
	player.position = Vector3(0, 14, 0)

func _test_cover() -> void:
	await physics_frame
	var wall := StaticBody3D.new()
	wall.collision_layer = 2
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(24, 60, 8)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(0, 30, 20)
	arena.add_child(wall)
	var unit := _unit("rail_crawler", Vector3(0, 1, 40))
	unit.entry_grace_period = 0
	unit.set_physics_process(false)
	await physics_frame
	check(not unit.check_muzzle_line_of_sight(Vector3(0, 2, 40), player.position), "Buildings block enemy muzzle line of sight")
	unit.queue_free()
	wall.queue_free()

func _test_clear_street() -> void:
	await physics_frame
	var roadside: Array[Node3D] = []
	for side in [-1, 1]:
		var building := StaticBody3D.new()
		building.collision_layer = 2
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(14, 24, 38)
		shape.shape = box
		building.add_child(shape)
		building.position = Vector3(side * 12, 12, 70)
		arena.add_child(building)
		roadside.append(building)
	var unit := _unit("technical_truck", Vector3(1.4, 1, 95))
	var stayed_in_lane := true
	for tick in range(720):
		await physics_frame
		if unit.position.z > 50 and absf(unit.position.x) > 3.8:
			stayed_in_lane = false
		if shot_sources.has(unit.get_instance_id()):
			break
	check(stayed_in_lane, "Roadside buildings do not steer vehicles off a clear street")
	check(shot_sources.has(unit.get_instance_id()), "Ground unit crosses the town block and shoots after closing")
	unit._release_all_slots()
	unit.queue_free()
	for building in roadside:
		building.queue_free()

func _test_pause() -> void:
	await physics_frame
	var unit := _unit("attack_gunship", Vector3(0, 24, 95))
	await physics_frame
	var position_before := unit.position
	var grace_before := unit.entry_grace_timer
	paused = true
	await create_timer(0.10, true, false, true).timeout
	check(unit.position == position_before and is_equal_approx(unit.entry_grace_timer, grace_before), "Pause freezes enemy movement and entry clocks")
	paused = false
	unit.queue_free()
