extends "res://tests/test_menu_repair.gd"
## Reproduce real flight, weapon fire, enemy damage, and the building-collision break.

func run() -> void:
	if OS.get_environment("ZIVA_TEST_DATA_DIR").is_empty():
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	var flow = root.get_node("UIFlow")
	var gm = root.get_node("GameManager")
	flow.return_to_menu()
	await frames(10)
	await click(current_scene.start_btn)
	await click(current_scene.get_node("VehicleSelectionMenu").deploy_btn)
	var ready := await wait_run()
	check(ready, "menu and aircraft selection launch a ready game")
	if not ready:
		quit(1)
		return
	var game = current_scene
	var player = game.player
	root.get_node("CombatDirector").stop_wave_director()
	game.enemy_spawner.set_process(false)
	for unit in get_nodes_in_group("enemies"):
		unit.queue_free()
	await frames(4)
	check(flow.gameplay_input_allowed() and not paused, "flight controls arm after loading")
	var start_pos: Vector3 = player.global_position
	Input.action_press("thrust_forward")
	Input.action_press("climb")
	Input.action_press("fire_primary")
	var weapons = player.get_node("Weapons")
	var ammo_before: int = weapons.weapon_states[weapons.current_weapon_idx].ammo
	for i in 45:
		await physics_frame
	Input.action_release("thrust_forward")
	Input.action_release("climb")
	Input.action_release("fire_primary")
	check(player.global_position.distance_to(start_pos) > 5.0 and player.global_position.y > start_pos.y, "actual flight inputs move and climb")
	check(weapons.weapon_states[weapons.current_weapon_idx].ammo < ammo_before, "actual fire input operates the weapon")
	# A real collision with a destructible wall must use the DamageData receiver API.
	player.set_physics_process(false)
	player.set_process(false)
	var building = load("res://scenes/world/destructible_building.tscn").instantiate()
	building.position = Vector3(0, 100, 0)
	building.max_building_health = 1000.0
	game.add_child(building)
	player.global_position = Vector3(-20, 107, 0)
	player.max_hull = 1000.0
	player.current_hull = 1000.0
	player.is_invulnerable = false
	player.collision_resistance = 0.0
	player.impact_damage_cooldown = 0.0
	var receiver = building.get_node("DamageReceiver")
	var damage_packets: Array[RefCounted] = []
	receiver.damaged.connect(func(_amount: float, _remaining: float, packet: RefCounted): damage_packets.append(packet))
	await physics_frame
	var collided := false
	for i in 60:
		await physics_frame
		player.velocity = Vector3(38, 0, 0)
		player.move_and_slide()
		for j in player.get_slide_collision_count():
			if player.get_slide_collision(j).get_collider() == building:
				collided = true
		if collided:
			player._process_collision_damage(1.0 / 60.0, Vector3(38, 0, 0))
			break
	check(collided, "regression test physically hits a building wall")
	check(receiver.current_health < 1000.0 and player.current_hull < 1000.0, "ramming damages both the building and aircraft without a debugger break")
	check(not damage_packets.is_empty() and damage_packets[0] is DamageData and damage_packets[0].attacker == player, "collision delivers a valid attributed DamageData packet")
	player.global_position = Vector3(0, 20, 0)
	player.velocity = Vector3.ZERO
	building.queue_free()
	await physics_frame
	# Modded enemy shots may outlive their source; cluster and fire effects must remain valid.
	var attacker := Node3D.new()
	game.add_child(attacker)
	attacker.global_position = Vector3(10, 20, 0)
	var packet = DamageData.new(5.0, GameConstants.WeaponType.ROCKET, attacker)
	packet.cluster_count = 3
	packet.lingering_fire = true
	attacker.free()
	var shot = load("res://scenes/combat/projectile.tscn").instantiate()
	game.add_child(shot)
	shot.set_physics_process(false)
	shot.damage_data = packet
	shot.blast_radius = 4.0
	var old_projectiles: int = get_nodes_in_group("combat_projectiles").size()
	var old_fields: int = get_nodes_in_group("combat_explosions").size()
	shot._spawn_mod_effects(Vector3(20, 20, 0))
	check(get_nodes_in_group("combat_projectiles").size() == old_projectiles + 3 and get_nodes_in_group("combat_explosions").size() == old_fields + 1, "cluster rounds and lingering fire survive a freed firing enemy")
	shot.queue_free()
	player.take_damage(packet)
	check(game.hud.damage_indicator.visible, "incoming damage feedback still works after collisions")
	player.set_physics_process(true)
	player.set_process(true)
	player.override_flight_input = {"thrust": 0.0, "yaw": 0.0, "strafe": 0.0, "lift": 0.0, "dash": false}
	await frames(4)
	check(gm.current_state == gm.RunState.ACTIVE and not paused, "gameplay continues after the previously fatal collision path")
	player.take_damage(99999.0, "Regression test")
	for i in 300:
		await process_frame
		if game.debrief_screen.visible:
			break
	check(game.debrief_screen.visible and gm.current_state == gm.RunState.RESULTS, "death reaches the minimal game-over overlay")
	await click(game.debrief_screen.retry_button)
	await frames(12)
	check(current_scene.name == "MainMenu" and current_scene.get_node("VehicleSelectionMenu").visible, "Play Again opens aircraft selection after a real crash sequence")
	var selection = current_scene.get_node("VehicleSelectionMenu")
	await click(selection.card_buttons[1])
	await click(selection.deploy_btn)
	check(await wait_run(), "a second run starts successfully after game over")
	check(gm.selected_aircraft == "nighthawk" and flow.gameplay_input_allowed(), "the selected aircraft is playable on the next run")
	flow.return_to_menu()
	await frames(12)
	current_scene.queue_free()
	await frames(12)
	var audio = root.get_node("AudioManager")
	audio.set_process(false)
	for child in audio.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	await create_timer(0.2).timeout
	print("DEBUGGER_PLAYABILITY_RESULT checks=", checks, " failures=", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
