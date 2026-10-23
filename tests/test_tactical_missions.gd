extends SceneTree

const Manager = preload("res://src/missions/mission_manager.gd")
var passes := 0
var failures := 0
var arena: Node3D
var player: CharacterBody3D
var manager: Node
var gm: Node

class FakeEnemy extends Node3D:
	var variant_id := "hunter_drone"
	var target: Node3D
	var activity_player: Node3D

func _init() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	print("PASS " if ok else "FAIL ", description)
	if ok: passes += 1
	else: failures += 1

func hold(seconds: float) -> void:
	for i in range(ceili(seconds * 10)):
		manager._process(0.1)

func run() -> void:
	if OS.get_environment("ZIVA_TEST_DATA_DIR").is_empty():
		push_error("Use an isolated ZIVA_TEST_DATA_DIR")
		quit(1)
		return
	gm = root.get_node("GameManager")
	gm.start_new_run("apache")
	root.get_node("CombatDirector").stop_wave_director()
	root.get_node("CombatDirector").current_wave = 4
	arena = Node3D.new()
	root.add_child(arena)
	current_scene = arena
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 2
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1000, 2, 1000)
	collision.shape = shape
	floor_body.position.y = -1
	floor_body.add_child(collision)
	arena.add_child(floor_body)
	var ceiling := floor_body.duplicate()
	ceiling.position.y = 64
	arena.add_child(ceiling)
	player = load("res://scenes/player/player.tscn").instantiate()
	arena.add_child(player)
	player.position = Vector3(0, 15, 0)
	player.set_process(false)
	player.set_physics_process(false)
	manager = Manager.new()
	manager.name = "MissionManager"
	arena.add_child(manager)
	manager.set_process(false)
	await physics_frame
	await physics_frame
	var xp = root.get_node("XpManager")
	for key in ["rescue_crew", "medevac", "vip_extraction", "black_box_recovery"]:
		check(manager.start_mission(key), "Places real pickup and delivery sites: " + key)
		if not manager.is_mission_active: continue
		check(manager.pickup_site.global_position != Vector3.ZERO and manager.delivery_site.global_position.distance_to(manager.pickup_site.global_position) > 75, "Sites are distinct reachable street locations")
		var credits_before: int = gm.banked_credits
		manager.complete_active_mission()
		check(gm.banked_credits == credits_before and manager.is_mission_active, "Cannot claim rewards before pickup/delivery")
		player.global_position = manager.pickup_site.global_position + Vector3.UP * 35
		hold(0.5)
		check(manager.hold_progress == 0, "High-altitude flyover cannot board payload")
		player.global_position = manager.pickup_site.global_position + Vector3.UP * 12
		player.velocity = Vector3(15, 0, 0)
		hold(0.5)
		check(manager.hold_progress == 0, "High-speed flyover cannot board payload")
		player.velocity = Vector3.ZERO
		var before: float = manager.mission_timer
		paused = true
		hold(1)
		check(manager.mission_timer == before, "Pause freezes mission clock and boarding")
		paused = false
		hold(4.1)
		check(manager.phase == "DELIVER" and not manager.pickup_site.payload.visible, "Boarding changes the active marker and removes recovered payload")
		player.global_position = manager.delivery_site.global_position + Vector3.UP * 12
		var xp_before: int = xp.total_xp_collected
		var reward_value: int = manager.active_mission_data.base_xp
		hold(4.1)
		check(not manager.is_mission_active and gm.banked_credits == credits_before + int(manager.active_mission_data.base_cr), "Delivery settles exact mission credits once")
		check(xp.total_xp_collected == xp_before, "Mission completion does not directly grant XP")
		var drops := get_nodes_in_group("xp_drops")
		check(not drops.is_empty(), "Mission reward exists as a physical XP cache")
		if not drops.is_empty():
			drops.back().body_entered.emit(player)
			check(xp.total_xp_collected == xp_before + reward_value, "Physical collection awards the mission XP value")
		manager.complete_active_mission()
		check(gm.banked_credits == credits_before + int(manager.active_mission_data.base_cr), "Repeated completion cannot repay credits")
		# Clear queued draft presentation to isolate the next mission fixture.
		xp.reset_run()
		await process_frame
		await physics_frame
	check(manager.start_mission("destroy_radar"), "Radar strike places a damageable installation")
	var credits: int = gm.banked_credits
	check(manager.objective_site.is_in_group("hostile_mission_targets"), "Installation is a real turret/salvo target without joining enemy population")
	var hit = preload("res://src/combat/damage_data.gd").new(500.0, 0, player)
	manager.objective_site.get_node("DamageReceiver").take_damage(hit)
	check(not manager.is_mission_active and gm.banked_credits == credits + 350, "Real radar destruction completes its bound mission")
	await physics_frame
	check(manager.start_mission("defend_beacon"), "Defence uses an actual beacon position")
	player.global_position = Vector3.ZERO
	hold(0.5)
	check(manager.hold_progress == 0, "Origin is not a placeholder defence objective")
	player.global_position = manager.objective_site.global_position + Vector3.UP * 15
	hold(25.1)
	check(not manager.is_mission_active, "Holding the real beacon completes defence")
	await physics_frame
	check(manager.start_mission("clear_airspace"), "Airspace patrol creates a marked sector")
	var air := FakeEnemy.new()
	arena.add_child(air)
	air.add_to_group("enemies")
	air.global_position = manager.objective_site.global_position
	var air_receiver = preload("res://src/combat/damage_receiver.gd").new()
	air_receiver.name = "DamageReceiver"
	air.add_child(air_receiver)
	manager.register_kill_for_mission(air)
	check(manager.current_kills == 0, "Living aircraft cannot count as a kill")
	air_receiver.is_dead = true
	manager.register_kill_for_mission(air)
	manager.register_kill_for_mission(air)
	check(manager.current_kills == 1, "A dead aircraft contributes once even if callback repeats")
	air.free()
	manager.cancel_mission("Next test", false)
	await physics_frame
	var marked := FakeEnemy.new()
	marked.variant_id = "scout_buggy"
	arena.add_child(marked)
	marked.add_to_group("enemies")
	marked.position = Vector3(76, 0.1, 0)
	var marked_receiver = preload("res://src/combat/damage_receiver.gd").new()
	marked_receiver.name = "DamageReceiver"
	marked.add_child(marked_receiver)
	check(manager.start_mission("high_value_target"), "HVT mission marks an actual live hostile")
	check(manager.borrowed_target == marked and marked.is_in_group("mission_targets"), "Marked HVT is protected from administrative retirement")
	marked_receiver.take_damage(hit)
	check(not manager.is_mission_active, "Only the marked target's destruction completes the hunt")
	marked.free()
	await physics_frame
	check(manager.start_mission("escort_convoy"), "Escort mission creates a transport and street route")
	var transport = manager.objective_site
	var receiver = transport.get_node("DamageReceiver")
	var health_before: float = receiver.current_health
	receiver.take_damage(hit)
	check(receiver.current_health == health_before, "Friendly transport ignores player fire")
	var attacker := FakeEnemy.new()
	attacker.variant_id = "scout_buggy"
	attacker.target = player
	arena.add_child(attacker)
	attacker.add_to_group("enemies")
	attacker.global_position = transport.global_position + Vector3(20, 0, 0)
	manager._redirect_escort_threats()
	check(attacker.target == transport, "Nearby ground hostile receives the transport as its real combat target")
	player.global_position = transport.global_position + Vector3.UP * 15
	var route_start: Vector3 = transport.global_position
	for i in range(20): manager._process(0.1)
	check(transport.global_position.distance_to(route_start) > 1, "Escort transport physically moves along its route")
	var hostile_hit = preload("res://src/combat/damage_data.gd").new(500.0)
	receiver.take_damage(hostile_hit)
	check(not manager.is_mission_active and "Transport destroyed" in manager.result_text, "Losing the convoy fails without rewards")
	check(attacker.target == player, "Convoy cleanup restores redirected hostile targets")
	attacker.free()
	await physics_frame
	check(manager.start_mission("escort_convoy"), "Convoy can start again after a failed escort")
	for i in range(1200):
		if not manager.is_mission_active: break
		player.global_position = manager.objective_site.global_position + Vector3.UP * 15
		manager._process(0.1)
	check(not manager.is_mission_active and "MISSION COMPLETE" in manager.result_text, "Traversing the full convoy route completes escort")
	await physics_frame
	var cargo = preload("res://src/missions/cargo_manager.gd").new()
	cargo.name = "CargoManager"
	arena.add_child(cargo)
	cargo.set_process(false)
	check(manager.start_mission("cargo_run"), "Cargo mission routes the existing cargo controller to visible sites")
	player.global_position = cargo.pickup_pos + Vector3.UP * 12
	player.velocity = Vector3.ZERO
	for i in range(15): cargo._process(0.1)
	manager._process(0.1)
	check(cargo.current_state == cargo.CargoState.CARRYING and manager.phase == "DELIVER", "Real cargo loading switches to delivery guidance")
	player.global_position = cargo.dropoff_pos + Vector3.UP * 12
	for i in range(10): cargo._process(0.1)
	check(not manager.is_mission_active, "Real cargo delivery event completes its tactical mission")
	await physics_frame
	check(manager.start_mission("medevac"), "Can start a fresh mission after failure")
	manager.active_mission_data.time_limit = 0.1
	hold(0.2)
	check(not manager.is_mission_active, "Expired extraction fails cleanly")
	await physics_frame
	check(manager.start_mission("sortie_extraction"), "Manual sortie exfil has a real LZ")
	check(not manager.confirm_sortie_extraction(), "Cannot end sortie before securing LZ")
	player.global_position = manager.objective_site.global_position + Vector3.UP * 12
	player.velocity = Vector3.ZERO
	hold(5.1)
	check(manager.phase == "READY" and gm.current_state == gm.RunState.ACTIVE, "Secured LZ waits for explicit confirmation")
	check(manager.confirm_sortie_extraction() and gm.current_state == gm.RunState.RESULTS, "Confirmed extraction settles sortie through GameManager")
	check(not manager.confirm_sortie_extraction(), "Extraction cannot settle twice")
	arena.queue_free()
	await process_frame
	print("TACTICAL_MISSIONS: %d passed, %d failed" % [passes, failures])
	quit(0 if failures == 0 else 1)
