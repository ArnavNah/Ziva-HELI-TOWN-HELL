extends SceneTree

var failures := 0
var passes := 0
var warning_duration := 0.0
var arena: Node3D
var spawner: EnemySpawner
var cd: Node
var gm: Node

func _init() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	print("PASS " if ok else "FAIL ", description)
	if ok: passes += 1
	else: failures += 1

func clear_enemies() -> void:
	for enemy in get_nodes_in_group("enemies"):
		enemy.free()

func freeze_enemies() -> void:
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_process(false)
		enemy.set_physics_process(false)

func reset(wave: int = 1) -> void:
	clear_enemies()
	cd.start_wave_director()
	if wave > 1: cd._setup_wave(wave)
	cd.fast_eval_timer = 999.0
	cd.slow_eval_timer = 999.0

func run() -> void:
	cd = root.get_node("CombatDirector")
	gm = root.get_node("GameManager")
	gm.current_state = gm.RunState.ACTIVE
	cd.set_process(false)
	arena = Node3D.new()
	root.add_child(arena)
	spawner = EnemySpawner.new()
	arena.add_child(spawner)
	spawner.set_process(false)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 2
	floor_body.collision_mask = 0
	var floor_collision := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(1500, 1, 1500)
	floor_collision.shape = floor_box
	floor_body.position.y = -0.5
	floor_body.add_child(floor_collision)
	arena.add_child(floor_body)
	await physics_frame
	await physics_frame

	reset()
	cd.wave_timer = 0.01
	var wallet_before: float = cd.fast_wallet
	cd._process(1.0 / 60.0)
	check(not cd.is_wave_active and is_equal_approx(cd.fast_wallet, wallet_before), "Wave completion stops purchases/income in the same frame")
	for tick in range(182): cd._process(1.0 / 60.0)
	check(cd.current_wave == 2 and cd.is_wave_active, "Natural three-second intermission advances wave 1 to wave 2")
	reset()
	cd.fast_wallet = 0
	cd.slow_wallet = 0
	cd._process(5.0)
	check(cd.active_combat_time <= 0.1 and cd.fast_wallet < 1.0, "Five-second stall does not pay five seconds of income")
	for state in [gm.RunState.PAUSED, gm.RunState.UPGRADE_CHOICE, gm.RunState.BOSS_DECISION, gm.RunState.RESULTS, gm.RunState.LOADING]:
		gm.current_state = state
		var time_before: float = cd.active_combat_time
		var money_before: float = cd.fast_wallet
		cd._process(0.1)
		check(cd.active_combat_time == time_before and cd.fast_wallet == money_before, "Non-combat state %d freezes director" % state)
		check(spawner.spawn_enemy_type("scout_buggy", Vector3(60, 0.1, 0)) == null, "Public spawning rejects non-combat state %d" % state)
	gm.current_state = gm.RunState.ACTIVE

	reset(4)
	cd.fast_wallet = 60
	var shield_card: SpawnCard = cd.catalog.get_card_by_id("scout_buggy_shielded")
	var shield_units: Array = spawner.spawn_director_card(shield_card, "fast")
	check(shield_units.size() == 1, "Real shield-card purchase places an enemy")
	if shield_units.size() == 1:
		var receiver = shield_units[0].get_node("DamageReceiver")
		check(is_equal_approx(receiver.shield_health, receiver.max_health * 0.5), "Purchased shield uses real shield_health at scaled hull strength")
	check(cd.reserved_population == 0 and cd.spawn_transactions.is_empty() and cd.fast_wallet == 40, "Shield purchase commits exact cost and releases reservation")
	freeze_enemies()
	reset(5)
	cd.slow_wallet = 120
	var elites: Array = spawner.spawn_director_card(cd.catalog.get_card_by_id("assault_apc_elite"), "slow")
	check(elites.size() == 1, "Elite APC card places successfully")
	if elites.size() == 1:
		var spec: Dictionary = EnemyData.get_spec("assault_apc")
		var expected: float = spec.base_hull * 1.7 * EnemyData.get_wave_scaling(5).health
		check(is_equal_approx(elites[0].get_node("DamageReceiver").max_health, expected), "Elite and wave hull scaling applied once by BaseEnemy")
	freeze_enemies()

	reset()
	cd.target_population = 1
	var a = spawner.spawn_enemy_type("scout_buggy", Vector3(60, 0.1, 0))
	var b = spawner.spawn_enemy_type("scout_buggy", Vector3(-60, 0.1, 0))
	check(a != null and b == null and cd.get_active_enemy_count() == 1, "Custom-position public spawns respect total capacity")
	check(spawner.spawn_enemy_type("rail_crawler", Vector3(90, 0.1, 0)) == null, "Public spawning enforces wave unlocks")
	clear_enemies()
	cd.target_population = 40
	for i in range(6): spawner.spawn_enemy_type("scout_buggy", Vector3(60 + i * 10, 0.1, 0))
	check(cd.get_active_enemy_count() == 5, "Custom-position public spawns respect variant cap")
	check(spawner.spawn_enemy_type("infantry_squad", Vector3.ZERO, true) == null, "Fixture bypass cannot re-enable disabled roster")
	freeze_enemies()

	reset()
	cd.fast_wallet = 60
	var card: SpawnCard = cd.catalog.get_card_by_id("scout_buggy_duo")
	var token: int = cd.reserve_spawn_card(card, "fast")
	check(token > 0 and cd.reserved_population == 2 and cd.fast_wallet == 36, "Group reserves per-member cost and population atomically")
	check(cd.settle_spawn_member(token, false, 0) and not cd.settle_spawn_member(token, false, 0), "Repeated callback for one group member is rejected")
	check(cd.settle_spawn_member(token, false, 1), "Second group member refunds independently")
	check(not cd.settle_spawn_member(token, false) and cd.fast_wallet == 60 and cd.reserved_population == 0, "Duplicate settlement cannot mint credits")
	var stale: int = cd.reserve_spawn_card(card, "fast")
	cd.start_wave_director()
	check(not cd.settle_spawn_member(stale, true) and cd.reserved_population == 0, "Run reset invalidates old reservations")

	var camera := Camera3D.new()
	arena.add_child(camera)
	camera.position = Vector3(0, 200, 0)
	camera.look_at(Vector3.ZERO, Vector3.FORWARD)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1000
	camera.far = 1000
	camera.make_current()
	reset(4)
	cd.fast_wallet = 60
	var no_units: Array = spawner.spawn_director_card(shield_card, "fast")
	check(no_units.is_empty(), "Fully visible spawn ring defers all forty attempts instead of allowing pop-in")
	check(cd.fast_wallet == 60 and cd.reserved_population == 0, "Hidden-placement failure refunds the entire purchase")
	var edge := camera.project_position(Vector2(-2, root.get_visible_rect().size.y * 0.5), 60.0)
	check(not camera.is_position_in_frustum(edge) and spawner.is_spawn_visible(camera, edge, "rail_crawler"), "Frustum guard rejects a visible model whose root is outside the viewport")
	camera.current = false
	var seq1: Array = []
	var seq2: Array = []
	spawner.reset_encounter(9182)
	for i in range(5): seq1.append(spawner.find_valid_spawn_position("air", Vector3.ZERO, "hunter_drone"))
	spawner.reset_encounter(9182)
	for i in range(5): seq2.append(spawner.find_valid_spawn_position("air", Vector3.ZERO, "hunter_drone"))
	check(seq1 == seq2 and seq1[0] != Vector3.INF, "Seed reproduces real air placement including altitude")
	var valid_ground := spawner.find_valid_spawn_position("ground", Vector3.ZERO, "scout_buggy")
	check(valid_ground != Vector3.INF and is_equal_approx(valid_ground.y, 0.1), "Ground placement verifies floor and returns its surface height")

	camera.position = Vector3(0, 10, 0)
	camera.rotation = Vector3.ZERO
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.make_current()
	var enemy = spawner.spawn_enemy_type("siege_tank", Vector3(0, 0.1, 60), true)
	enemy.set_process(false)
	enemy.set_physics_process(false)
	root.get_node("EventBus").threat_warning.connect(func(_pos, _kind, duration): warning_duration = duration)
	enemy.start_telegraph(0.4)
	check(enemy.telegraph_timer >= 1.5 and warning_duration == enemy.telegraph_timer, "Offscreen heavy warning matches real windup timer")
	check(not enemy.update_telegraph(enemy.global_position, Vector3.ZERO, 0.4), "Offscreen attack cannot finish windup after 0.4 seconds")
	check(enemy.update_telegraph(enemy.global_position, Vector3.ZERO, 1.11), "Offscreen windup eventually permits firing")
	clear_enemies()

	# Administrative retirement is delayed and never treated as a kill.
	camera.current = false
	var target := Node3D.new()
	arena.add_child(target)
	target.add_to_group("player")
	var remote = spawner.spawn_enemy_type("scout_buggy", Vector3(220, 0.1, 0), true)
	remote.set_process(false)
	remote.set_physics_process(false)
	var xp_before: int = root.get_node("XpManager").total_xp_collected
	var score_before: int = gm.score
	cd.active_combat_time = 0
	spawner._check_administrative_retirements(cd)
	check(not remote.is_queued_for_deletion(), "Distant enemy remains during retirement dwell")
	cd.active_combat_time = 8.1
	spawner._check_administrative_retirements(cd)
	check(remote.is_queued_for_deletion(), "Distant unengaged enemy retires after dwell")
	await process_frame
	check(root.get_node("XpManager").total_xp_collected == xp_before and gm.score == score_before, "Completed administrative deletion grants no XP or score")
	# Boss registration, physical rig, timer gating and continuation remain coherent.
	target.remove_from_group("player")
	cd._setup_wave(10)
	var bosses := get_nodes_in_group("bosses")
	check(bosses.size() == 1, "Wave ten creates one boss")
	if bosses.size() == 1:
		var boss = bosses[0]
		boss.set_process(false)
		boss.set_physics_process(false)
		check(boss.has_node("Visuals") and boss.has_node("CollisionShape3D") and boss.collision_layer == 4, "Director boss has visible geometry and a damageable physical collider")
		cd._check_wave_10_boss()
		check(get_nodes_in_group("bosses").size() == 1, "Repeated director evaluation does not duplicate the boss")
		cd.wave_timer = 0
		cd._complete_current_wave()
		check(cd.is_wave_active and cd.current_wave == 10, "Live boss prevents timer-only wave completion")
		var dialog = load("res://src/ui/boss_decision_dialog.gd").new()
		arena.add_child(dialog)
		var credits_before: int = gm.banked_credits
		var salvage_before: int = gm.carried_salvage
		var hit = preload("res://src/combat/damage_data.gd").new(100000.0)
		boss.get_node("DamageReceiver").take_damage(hit)
		check(gm.current_state == gm.RunState.BOSS_DECISION and dialog.visible, "Real boss destruction opens the paused decision")
		check(gm.banked_credits == credits_before + 1320 and gm.carried_salvage == salvage_before + 10, "Boss plus decision UI award bounty and salvage only once")
		boss._on_destroyed(hit)
		check(gm.banked_credits == credits_before + 1320, "Duplicate boss destruction callback cannot repay rewards")
		dialog._on_overdrive_pressed()
		check(cd.current_wave == 11 and cd.active_theme == "Endless Overdrive" and gm.current_state == gm.RunState.ACTIVE and not paused, "Decision button resumes real endless continuation")
	cd.stop_wave_director()
	arena.free()
	print("DIRECTOR_REGRESSIONS: %d passed, %d failed" % [passes, failures])
	quit(1 if failures else 0)
