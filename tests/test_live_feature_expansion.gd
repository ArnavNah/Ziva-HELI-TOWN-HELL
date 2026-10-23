extends SceneTree
const Damage = preload("res://src/combat/damage_data.gd")
var failures := 0
var checks := 0
func target_at(parent: Node3D, location: Vector3, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = location
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE
	shape.shape = box
	body.add_child(shape)
	var receiver = preload("res://src/combat/damage_receiver.gd").new()
	receiver.name = "DamageReceiver"
	body.add_child(receiver)
	parent.add_child(body)
	return body
func check(ok: bool, message: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", message)
	if not ok: failures += 1
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	if OS.get_environment("ZIVA_TEST_DATA_DIR").is_empty():
		quit(2)
		return
	var gm = root.get_node("GameManager")
	var director = root.get_node("CombatDirector")
	var xp = root.get_node("XpManager")
	for biome in ["town", "desert", "harbor"]:
		gm.selected_biome = biome
		var game = load("res://scenes/main_game.tscn").instantiate()
		root.add_child(game)
		current_scene = game
		while not game.session_started: await process_frame
		await physics_frame
		await physics_frame
		director.stop_wave_director()
		for enemy in get_nodes_in_group("enemies"): enemy.queue_free()
		await process_frame
		var player = game.get_node("PlayerHelicopter")
		player.set_process(false)
		player.set_physics_process(false)
		player.velocity = Vector3.ZERO
		player.current_fuel = player.max_fuel
		var mission = game.get_node("MissionManager")
		mission.set_process(false)
		mission.cancel_mission("Fixture", false)
		check(game.get_node("WeatherSystem").biome == biome, biome + " weather follows selection")
		check(game.get_node("CityGenerator").spawned_blocks.size() > 30, biome + " creates real district geometry")
		if biome == "town":
			player.current_hull = 35.0
			player.max_hull = 100.0
			player.armor_mitigation = 0
			player.evasion_chance = 0
			player.shield_timer = 0
			player.spawn_grace_timer = 0
			player.take_damage(99.0)
			check(player.current_hull == 1.0 and not player.is_dying, "real lethal hit at 35% leaves player alive")
			player.take_damage(20.0)
			check(player.current_hull == 1.0, "real follow-up blocked by mortal grace")
			check(player.get_protection_reasons().has("mortal_grace"), "grace has an explicit protection reason")
			player.mortal_protection.advance(16, 80, 100)
			player.current_hull = 80
			player.small_arms_armor = 2.0
			player.take_damage(Damage.new(10.0, 0))
			check(is_equal_approx(player.current_hull, 72), "real small arms plating reduces damage")
			var hostile := target_at(game, player.global_position + Vector3(2, 0, 0), 4)
			var structure := target_at(game, player.global_position + Vector3(-2, 0, 0), 2)
			await physics_frame
			await physics_frame
			var blast = load("res://scenes/combat/projectile.tscn").instantiate()
			game.add_child(blast)
			blast.damage_data = Damage.new(10, 2, player)
			blast.blast_radius = 6
			blast.collision_mask = 6
			blast._explode(player.global_position)
			check(player.current_hull == 72, "player explosive cannon and rockets cannot splash their owner")
			check(hostile.get_node("DamageReceiver").current_health < 100 and structure.get_node("DamageReceiver").current_health < 100, "player splash damages hostile and destructible world layers")
			var hostile_hp: float = hostile.get_node("DamageReceiver").current_health
			blast.damage_data = Damage.new(10, 2, hostile)
			blast.collision_mask = 3
			blast._explode(player.global_position)
			check(player.current_hull < 72 and hostile.get_node("DamageReceiver").current_health == hostile_hp, "enemy splash targets player without destroying its own cohort")
			blast.queue_free()
			hostile.queue_free()
			structure.queue_free()
			var counter = player.get_node("Countermeasures")
			var missile = load("res://scenes/combat/projectile.tscn").instantiate()
			game.add_child(missile)
			missile.global_position = player.global_position + Vector3(15, 0, 0)
			missile.velocity = Vector3(-50, 0, 0)
			missile.is_homing = true
			missile.target_node = player
			missile.set_physics_process(false)
			var hud = game.get_node("UI/CombatHUD")
			hud.missile_scan_timer = 0
			hud._update_missile_warnings(0.1)
			check(hud.incoming_missiles == 1 and hud.missile_urgent, "HUD detects real targeting missile within 25m")
			var friendly = load("res://scenes/combat/projectile.tscn").instantiate()
			game.add_child(friendly)
			friendly.is_homing = true
			friendly.target_node = game.get_node("Ground")
			friendly.set_physics_process(false)
			counter.current_charges = 3
			counter.cooldown_timer = 0
			counter.auto_chaff_enabled = true
			counter.auto_scan_timer = 0
			counter._process(0.1)
			check(counter.current_charges == 2 and not missile.is_homing, "automatic chaff spends one actual charge and diverts missile")
			check(friendly.is_homing, "flares preserve projectiles aimed elsewhere")
			missile.queue_free()
			friendly.queue_free()
			director.current_wave = 2
			await physics_frame
			check(mission.start_mission("rooftop_supply"), "rooftop supply finds a real building roof")
			if mission.is_mission_active:
				check(mission.objective_site.global_position.y > 4, "supply pad is above ground")
				player.global_position = mission.objective_site.global_position + Vector3.UP * 10
				var xp_before: int = xp.total_xp_collected
				mission._process_active_mission(8.1)
				check(not mission.is_mission_active, "securing roof completes supply event")
				var shields := 0
				var overdrives := 0
				for pickup in get_nodes_in_group("pickups"):
					if "pickup_type" in pickup:
						shields += int(pickup.pickup_type == 3)
						overdrives += int(pickup.pickup_type == 4)
				check(shields >= 1 and overdrives >= 1, "rare cache produces real shield and overdrive pickups")
				check(xp.total_xp_collected == xp_before, "cache XP awaits physical collection")
			mission.cancel_mission("fixture", false)
			check(mission.start_mission("destroy_sam"), "SAM event starts")
			var site = mission.objective_site
			director.is_wave_active = true
			mission.hazard_timer = 0
			mission._sam_hazard(0.1, player)
			check(mission.hazard_warning >= 1.4, "SAM attack has full 1.5s telegraph")
			var shots: int = get_nodes_in_group("combat_projectiles").size()
			mission._sam_hazard(1.6, player)
			check(get_nodes_in_group("combat_projectiles").size() == shots + 1, "SAM warning releases one real projectile")
			mission.cancel_mission("fixture", false)
			check(not director.heavy_slot_leases.has(site), "SAM cleanup releases attack lease")
			director.stop_wave_director()
		else:
			check(game.get_node("Ground/MeshInstance3D").material_override.get_shader_parameter("biome_blend") > 0.9, biome + " has distinct terrain shader palette")
			var boss = load("res://src/enemies/boss/modular_fortress_boss.gd").new()
			boss.fortress_kind = "ground" if biome == "desert" else "air"
			game.add_child(boss)
			boss.global_position = Vector3(0, 0.5 if biome == "desert" else 30, 76)
			boss.set_process(false)
			director.is_wave_active = true
			director.current_wave = 10
			director.set_process(false) # Isolate the boss's real frame loop from ordinary purchases.
			var start_pos: Vector3 = boss.global_position
			var shots_before: int = director.cumulative_shots_emitted
			boss.volley_timer = 0.1
			boss.set_process(true)
			for frame in range(160): await process_frame
			boss.set_process(false)
			check(boss.global_position.distance_to(start_pos) > 1.0, biome + " boss moves through its real frame loop")
			check(director.cumulative_shots_emitted > shots_before, biome + " boss telegraphs then fires real ordnance")
			director.stop_wave_director()
			director.set_process(true)
			check(boss.components.size() == 5, biome + " boss has five separately damageable subsystems")
			check(not boss.core_exposed(), biome + " boss core starts protected")
			if biome == "harbor":
				director.current_wave = 10
				director.is_wave_active = true
				director.fast_wallet = 0
				director.slow_wallet = 0
				var before: int = get_nodes_in_group("enemies").size()
				boss._summon_escort()
				check(get_nodes_in_group("enemies").size() == before, "carrier cannot summon without director funds")
				director.fast_wallet = 999
				director.slow_wallet = 999
				boss._summon_escort()
				check(get_nodes_in_group("enemies").size() > before and director.fast_wallet + director.slow_wallet < 1998, "carrier escort purchase creates real aircraft and spends director funds")
				for enemy in get_nodes_in_group("enemies"):
					if enemy != boss: enemy.queue_free()
				director.stop_wave_director()
			var hp: float = boss.damage_receiver.current_health
			boss.damage_receiver.take_damage(Damage.new(200, 2, player))
			check(boss.damage_receiver.current_health == hp, biome + " protected core rejects direct damage")
			var bank: int = gm.banked_credits
			var kills: int = gm.kills_count
			var ids: Array = boss.components.keys().duplicate()
			for id in ids:
				boss.components[id].get_node("DamageReceiver").take_damage(Damage.new(1000, 2, player))
			check(boss.components.is_empty() and boss.core_exposed(), biome + " destroying subsystems exposes core")
			check(gm.banked_credits == bank and gm.kills_count == kills, biome + " components do not multiply kill rewards")
			check(boss.current_stage != boss.BossStage.OPENING, biome + " subsystem damage advances combat phase")
			boss._fire_spread_volley(5, 85, player.global_position)
			check(boss.damage_receiver.current_health < hp, biome + " subsystem damage reaches real core integrity")
			boss.damage_receiver.take_damage(Damage.new(10000, 2, player))
			check(boss.defeat_settled and gm.current_state == gm.RunState.BOSS_DECISION, biome + " boss defeat enters existing settlement flow")
			var settled_bank: int = gm.banked_credits
			boss._on_destroyed(null)
			check(gm.banked_credits == settled_bank, biome + " repeated boss death cannot repay")
			gm.change_state(gm.RunState.ACTIVE)
			await process_frame
			paused = false
			director.wave_boss_spawned = false
			director.current_wave = 10
			player.global_position = Vector3(0, 15, 0)
			player.get_node("PlayerCamera").init_camera(player)
			for attempt in range(12):
				director._check_wave_10_boss()
				if director.wave_boss_spawned: break
			check(director.wave_boss_spawned, biome + " director routes wave ten to selected biome boss")
			for routed in get_nodes_in_group("bosses"):
				if not routed.is_queued_for_deletion():
					check("fortress_kind" in routed and routed.fortress_kind == ("ground" if biome == "desert" else "air"), biome + " director instantiates correct boss controller")
		paused = false
		game.queue_free()
		await process_frame
		await process_frame
		for projectile in get_nodes_in_group("combat_projectiles"): projectile.queue_free()
	gm.selected_biome = "town"
	var selection = load("res://src/ui/menus/vehicle_selection_menu.gd").new()
	selection.size = Vector2(1280, 720)
	root.add_child(selection)
	check(selection.biome_selector.item_count == 3, "aircraft screen exposes all three sortie choices")
	selection.biome_selector.select(2)
	selection.biome_selector.item_selected.emit(2)
	check(gm.selected_biome == "harbor", "visible sortie dropdown changes actual next-run selection")
	selection.queue_free()
	await process_frame
	gm.selected_biome = "town"
	print("LIVE_FEATURE_EXPANSION: %d checks / %d failures" % [checks, failures])
	quit(1 if failures else 0)
