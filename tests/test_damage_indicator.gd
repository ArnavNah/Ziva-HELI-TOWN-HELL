extends "res://tests/test_menu_repair.gd"

func run() -> void:
	if OS.get_environment("ZIVA_TEST_DATA_DIR").is_empty():
		quit(1)
		return
	captures = DisplayServer.get_name() != "headless"
	root.size = Vector2i(1280, 720)
	var flow = root.get_node("UIFlow")
	var gm = root.get_node("GameManager")
	var bus = root.get_node("EventBus")
	flow.begin_run()
	if not await wait_run():
		check(false, "gameplay becomes ready")
		quit(1)
		return
	root.get_node("CombatDirector").stop_wave_director()
	var game = current_scene
	game.enemy_spawner.set_process(false)
	for group in ["enemies", "combat_projectiles", "enemy_projectiles"]:
		for unit in get_nodes_in_group(group):
			unit.queue_free()
	var player = game.player
	# Freeze flight only; hits still go through the real player damage method and EventBus.
	player.set_physics_process(false)
	player.set_process(false)
	player.camera.set_process(false)
	player.is_invulnerable = false
	player.armor_mitigation = 0.20
	player.current_hull = player.max_hull
	var camera: Camera3D = player.camera
	var indicator = game.hud.damage_indicator
	var attacker := Node3D.new()
	attacker.name = "TestGunship"
	game.add_child(attacker)
	var right: Vector3 = camera.global_basis.x.normalized()
	var up: Vector3 = camera.global_basis.y.normalized()
	attacker.global_position = player.global_position + right * 35.0
	var hp_before: float = player.current_hull
	var events: Array[float] = []
	bus.player_damaged.connect(func(_hull: float, _max: float, damage: float): events.append(damage))
	var payload = load("res://src/combat/damage_data.gd").new(10.0, GameConstants.WeaponType.MACHINE_GUN, attacker)
	player.take_damage(payload)
	check(indicator.visible and indicator.hits.size() == 1 and indicator.hits[0].directional, "an actual enemy hit produces one directional marker")
	check(is_equal_approx(hp_before - player.current_hull, 8.0) and is_equal_approx(indicator.hits[0].amount, 8.0) and events.size() == 1, "marker shows armor-adjusted damage and preserves the original damage signal")
	check(indicator.screen_direction(attacker.global_position).dot(Vector2.RIGHT) > 0.99, "source on camera right points right")
	check(indicator.screen_direction(player.global_position - right * 35.0).dot(Vector2.LEFT) > 0.99, "source on camera left points left")
	check(indicator.screen_direction(player.global_position + up * 35.0).dot(Vector2.UP) > 0.99, "source above the player on screen points up")
	check(indicator.screen_direction(player.global_position - up * 35.0).dot(Vector2.DOWN) > 0.99, "source below the player on screen points down")
	player.take_damage(payload)
	check(indicator.hits.size() == 1 and is_equal_approx(indicator.hits[0].amount, 16.0), "rapid hits from one direction combine without clutter")
	player.is_invulnerable = true
	player.take_damage(payload)
	check(events.size() == 2 and is_equal_approx(indicator.hits[0].amount, 16.0), "shielded hits do not create false damage feedback")
	player.is_invulnerable = false
	player.take_damage(0.0)
	player.take_damage(-10.0)
	check(events.size() == 2, "zero and negative amounts do not trigger incoming-hit feedback")
	var frozen_payload = load("res://src/combat/damage_data.gd").new(5.0, GameConstants.WeaponType.MACHINE_GUN, attacker)
	attacker.free()
	indicator.clear_indicators()
	player.take_damage(frozen_payload)
	check(indicator.hits.size() == 1 and indicator.hits[0].directional, "a projectile keeps its bearing after its firing enemy is freed")
	indicator.clear_indicators()
	var explosive = load("res://scenes/combat/projectile.tscn").instantiate()
	game.add_child(explosive)
	explosive.set_physics_process(false)
	explosive.damage_data = frozen_payload
	explosive.blast_radius = 8.0
	explosive._explode(player.global_position)
	check(indicator.hits.size() == 1 and indicator.hits[0].directional, "explosive hits also preserve the bearing of a destroyed firing enemy")
	explosive.queue_free()
	indicator.clear_indicators()
	player.take_damage(5.0, "Ground Impact")
	check(indicator.hits.size() == 1 and not indicator.hits[0].directional and indicator.hits[0].source_label == "Ground Impact", "collisions use neutral impact feedback without inventing an enemy direction")
	indicator.clear_indicators()
	for i in 20:
		var angle := TAU * float(i) / 20.0
		bus.player_hit.emit(1.0, player.global_position + (right * cos(angle) + up * sin(angle)) * 40.0, true, "Enemy")
	check(indicator.hits.size() <= indicator.MAX_MARKERS, "crossfire marker count stays bounded during sustained attacks")
	await create_timer(1.4).timeout
	check(indicator.hits.is_empty() and not indicator.visible and not indicator.is_processing(), "markers fade completely and stop processing when idle")
	# A camera rotation must change the indicated screen bearing.
	var original_transform := camera.global_transform
	var test_origin: Vector3 = player.global_position + right * 35.0
	camera.global_position = player.global_position + Vector3(40, 30, 0)
	camera.look_at(player.global_position, Vector3.UP)
	var projected: Vector2 = (camera.unproject_position(test_origin) - camera.unproject_position(player.global_position)).normalized()
	check(indicator.screen_direction(test_origin).dot(projected) > 0.97, "direction follows camera rotation rather than world compass axes")
	camera.global_transform = original_transform
	player.current_hull = player.max_hull
	player.take_damage(12.0, "Enemy", player.global_position + right * 35.0)
	await frames(3)
	await screenshot("incoming-damage-indicator")
	root.get_node("AudioManager").reduce_flashes = true
	await frames(2)
	await screenshot("incoming-damage-reduced-flashes")
	check(indicator.visible and indicator.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Reduced Flashes retains the marker and the overlay never blocks aiming clicks")
	gm.change_state(gm.RunState.PAUSED)
	check(not indicator.visible and indicator.hits.is_empty(), "pause clears combat indicators immediately")
	gm.change_state(gm.RunState.ACTIVE)
	player.take_damage(5.0, "Fuel Starvation")
	gm.change_state(gm.RunState.RESULTS)
	check(not indicator.visible and not indicator.is_processing(), "results clear the indicator and its processing")
	gm.change_state(gm.RunState.MENU)
	game.queue_free()
	await frames(10)
	var audio = root.get_node("AudioManager")
	audio.set_process(false)
	for child in audio.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	await create_timer(0.15).timeout
	print("DAMAGE_INDICATOR_RESULT checks=", checks, " failures=", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
