extends SceneTree

const Card = preload("res://src/resources/upgrade_card.gd")
const Deck = preload("res://src/resources/upgrade_card_database.gd")
const Damage = preload("res://src/combat/damage_data.gd")
var checks := 0
var failures := 0

class Hostile extends Node3D:
	var variant_id := "scout_buggy"

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1

func run() -> void:
	if OS.get_environment("ZIVA_TEST_DATA_DIR").is_empty():
		quit(2)
		return
	var arena := Node3D.new()
	root.add_child(arena)
	var player = load("res://scenes/player/player.tscn").instantiate()
	arena.add_child(player)
	player.set_physics_process(false)
	var xp = root.get_node("XpManager")
	var sm = player.get_node("SubsystemManager")
	var weapons = player.get_node("Weapons")
	var salvo = player.get_node("Salvo")
	xp.reset_run()
	xp.current_level = 10 # Eligible level fixture for exercising the full deck.
	for card in Deck.get_master_deck():
		check(sm.apply_upgrade(card), "Actual catalog card applies: " + card.card_id)
	check(sm.applied_cards.size() == 38, "All 38 cards, including two evolutions, have valid controller contracts")
	var eligible = Deck.get_eligible_cards(player)
	var legendary_filtered := true
	for card in eligible:
		if card.rarity == Card.RarityTier.LEGENDARY:
			legendary_filtered = false
	check(legendary_filtered, "Applied one-time legendary cards leave the draft pool")
	xp.current_level = 1
	var level_gates := true
	for card in Deck.get_eligible_cards(player):
		if card.min_level > 1:
			level_gates = false
	check(level_gates, "Draft eligibility respects level unlocks")
	sm.unlocked_subsystems.assign([Card.SubsystemType.GLOBAL_TOME])
	var subsystem_gates := true
	for card in Deck.get_eligible_cards(player):
		if card.target_subsystem != Card.SubsystemType.GLOBAL_TOME:
			subsystem_gates = false
	check(subsystem_gates, "Draft eligibility respects locked subsystems")
	sm.unlocked_subsystems.assign([0, 1, 2, 3])
	var gated = Card.create("audit_prerequisite", "Prerequisite", "", Card.RarityTier.COMMON, Card.SubsystemType.GLOBAL_TOME, {})
	gated.required_cards = PackedStringArray(["unowned_card"])
	check(not sm.is_card_eligible(gated) and not sm.apply_upgrade(gated), "Unmet prerequisites reject both drafting and application")
	xp.current_level = 10
	var rocket := GameConstants.WeaponType.ROCKET
	var missile := GameConstants.WeaponType.MISSILE
	var cannon := GameConstants.WeaponType.MACHINE_GUN
	weapons._launch_weapon_projectiles(rocket, weapons.weapon_states[rocket])
	var shots = get_nodes_in_group("combat_projectiles")
	check(shots.size() == int(GameConstants.WEAPONS[rocket].projectile_count) + 4, "Rocket cards add four actual projectiles per trigger")
	var rocket_shot = shots[0]
	# Original 140% expansion plus the Inferno evolution's additional 25%.
	check(is_equal_approx(rocket_shot.blast_radius, float(GameConstants.WEAPONS[rocket].blast_radius) * 2.65), "Rocket blast-radius bonuses and Inferno evolution reach spawned projectiles")
	check(rocket_shot.damage_data.cluster_count == 3 and rocket_shot.damage_data.lingering_fire, "Spawned rockets carry clusters and lingering-fire payloads")
	for shot in shots:
		shot.free()
	weapons._launch_weapon_projectiles(cannon, weapons.weapon_states[cannon])
	shots = get_nodes_in_group("combat_projectiles")
	check(shots.size() == int(GameConstants.WEAPONS[cannon].projectile_count) + 3, "Cannon cards add three actual projectile streams")
	check(is_equal_approx(shots[0].blast_radius, 3.0), "Devastator evolution gives actual cannon projectiles an explosive radius")
	check(shots[0].damage_data.burn_chance > 0.0 and shots[0].damage_data.shock_chance > 0.0 and shots[0].damage_data.armored_bonus > 0.0, "Cannon projectiles carry burn, shock, and armor-piercing effects")
	for shot in shots:
		shot.free()
	var targets: Array[Node3D] = []
	for index in range(salvo.max_locks + 2):
		var target := Node3D.new()
		target.position = Vector3(index * 5, 50, -80)
		arena.add_child(target)
		targets.append(target)
		salvo.add_target_lock(target)
	check(salvo.current_locks.size() == 16, "Lock upgrades raise the actual salvo limit from six to sixteen")
	salvo._fire_salvo()
	shots = get_nodes_in_group("combat_projectiles")
	check(shots.size() == 19, "Micro-swarm card adds three actual missiles to a sixteen-lock salvo")
	check(is_equal_approx(shots[0].speed, GameConstants.SALVO_MISSILE_SPEED * 1.65), "Missile speed cards change launched salvo velocity")
	check(is_equal_approx(shots[0].homing_turn_rate, 8.0 * 1.35), "Missile turn-rate card changes real homing behavior")
	check(is_equal_approx(shots[0].damage_data.emp_duration, 3.5) and shots[0].damage_data.emp_chance == 1.0, "EMP card carries its 3.5-second outage into the hit payload")
	var receiver = load("res://src/combat/damage_receiver.gd").new()
	arena.add_child(receiver)
	receiver._check_status_procs(shots[0].damage_data)
	check(receiver.is_emp_disabled and is_equal_approx(receiver.emp_timer, 3.5), "Missile payload actually applies the specified EMP duration")
	for shot in shots:
		shot.free()
	# Exercise an explosion far from targets: bomblets must terminate the chain.
	var parent_shot = load("res://scenes/combat/projectile.tscn").instantiate()
	parent_shot.position = Vector3(0, 10000, 0)
	arena.add_child(parent_shot)
	var cluster_payload = Damage.new(10.0, rocket, player, false, 2.0)
	cluster_payload.cluster_count = 3
	parent_shot.setup(cluster_payload)
	var parent_id: int = parent_shot.get_instance_id()
	parent_shot._on_expire() # Exercise the actual blast + secondary-effects path.
	await process_frame
	var clusters_ok := true
	var children := 0
	for shot in get_nodes_in_group("combat_projectiles"):
		if shot.get_instance_id() != parent_id:
			children += 1
			clusters_ok = clusters_ok and shot.damage_data.cluster_count == 0
	check(children == 3 and clusters_ok, "Cluster bomblets spawn once and cannot recursively multiply (%d children)" % children)
	for shot in get_nodes_in_group("combat_projectiles"):
		shot.free()
	player.armor_mitigation = 0.0
	player.evasion_chance = 0.0
	player.spawn_grace_timer = 0.0
	player.shield_timer = 10.0
	player.shield_capacity = 50.0
	var hull: float = player.current_hull
	player.take_damage(20.0, "Test Projectile")
	check(player.current_hull == hull and player.shield_capacity == 30.0, "Energy shield absorbs damage against its finite capacity")
	player.take_damage(50.0, "Test Projectile")
	check(player.current_hull == hull - 20.0 and player.shield_timer == 0.0, "Depleted energy shield passes excess damage to hull")
	# Real pickup and kill events must share the same XP authority.
	xp.reset_run()
	var loot = load("res://src/loot/loot_manager.gd").new()
	root.get_node("GameManager").change_state(GameManager.RunState.ACTIVE)
	arena.add_child(loot)
	var enemy := Hostile.new()
	arena.add_child(enemy)
	enemy.add_to_group("enemies")
	root.get_node("EventBus").entity_destroyed.emit(enemy, "Machine Gun", 90, 3)
	check(xp.total_xp_collected == 0 and player.get_node("RunProgression").current_run_xp == 0, "Enemy kill does not award XP before physical collection")
	var drops = get_nodes_in_group("xp_drops")
	check(drops.size() == 1 and drops[0].xp_amount == 3, "Enemy kill emits one physical XP drop")
	drops[0]._on_body_entered(player)
	check(xp.total_xp_collected == 3 and player.get_node("RunProgression").current_run_xp == 3, "Collected drop updates XP authority and compatibility ledger once")
	var fresh_player = load("res://scenes/player/player.tscn").instantiate()
	arena.add_child(fresh_player)
	fresh_player.set_physics_process(false)
	check(is_equal_approx(fresh_player.get_node("MagnetSensor/CollisionShape3D").shape.radius, 12.0), "A new helicopter does not inherit the previous run's magnet radius")
	fresh_player.free()
	var ui = load("res://scenes/ui/level_up_ui.tscn").instantiate()
	arena.add_child(ui)
	await process_frame
	root.get_node("GameManager").start_new_run("apache")
	xp.add_xp(25)
	# The production overlay waits for its presentation delay before pausing combat.
	for frame in range(90):
		if ui.is_choosing: break
		await process_frame
	var key := InputEventKey.new()
	key.keycode = KEY_1
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	await process_frame
	check(not ui.is_choosing and not paused and xp.queued_level_ups == 0, "Keyboard choice works through real input while paused (choosing=%s, queued=%d)" % [ui.is_choosing, xp.queued_level_ups])
	key = InputEventKey.new()
	key.keycode = KEY_1
	key.pressed = false
	Input.parse_input_event(key)
	xp.add_xp(xp.target_xp)
	root.get_node("GameManager").change_state(GameManager.RunState.RESULTS)
	check(not ui.visible and not ui.is_choosing and paused, "Results state closes drafts without unpausing the game-over screen")
	root.get_node("GameManager").change_state(GameManager.RunState.MENU)
	root.get_node("GameManager").start_new_run("apache")
	check(xp.current_level == 1 and xp.total_xp_collected == 0 and xp.queued_level_ups == 0 and xp.xp_multiplier == 1.0, "Restart clears XP, level, pending cards, and XP bonuses")
	arena.free()
	await process_frame
	print("XP_UPGRADE_EFFECTS: ", checks - failures, "/", checks, " passed")
	quit(1 if failures else 0)
