extends SceneTree
## Production public spawning + real projectile, lifecycle and rig contract checks.
const SpawnerScript = preload("res://src/enemies/enemy_spawner.gd")
const ROLES := ["attack_gunship", "rocket_gunship", "interceptor", "escort_fighter", "attack_wing", "heavy_bomber", "torpedo_vtol", "stealth_vtol", "minelayer"]
var failures := 0
var checks := 0
var stage: Node3D
var player: Node3D
var spawner: Node
var enemies: Dictionary = {}
class DamageProbe extends CharacterBody3D:
	var hits := 0
	var accepted_damage := 0.0
	func take_damage(value: Variant, _source: String = "", _position: Vector3 = Vector3.ZERO) -> void:
		hits += 1
		accepted_damage += value.raw_damage if value is RefCounted else float(value)

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", message)

func run() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 2
	var floor_col := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(1200, 1, 1200)
	floor_col.shape = floor_shape
	floor_body.add_child(floor_col)
	stage.add_child(floor_body)
	player = preload("res://scenes/player/player.tscn").instantiate()
	player.position = Vector3(0, 28, 0)
	stage.add_child(player)
	player.debug_invulnerable = true
	player.set_physics_process(false)
	player.set_process(false)
	spawner = SpawnerScript.new()
	stage.add_child(spawner)
	spawner.set_process(false)
	var gm := root.get_node("GameManager")
	gm.current_state = gm.RunState.ACTIVE
	var director := root.get_node("CombatDirector")
	director.set_process(false)
	director.current_wave = 20
	director.target_population = 30
	director.is_wave_active = true
	director.max_air_slots = 12
	director.max_heavy_slots = 12
	await physics_frame
	await physics_frame
	for i in ROLES.size():
		var role: String = ROLES[i]
		# No bypass: exercise real eligibility and custom-position spawn rules.
		var enemy = spawner.spawn_enemy_type(role, Vector3(100 + i * 11, 30, 100))
		check(enemy != null, role + " public spawn without bypass")
		if not enemy: continue
		enemies[role] = enemy
		enemy.set_physics_process(false)
		enemy.position = Vector3(0, 28, 38)
		var rig = enemy.get_node("Visuals")
		check(rig.has_node("CosmeticOffset/Model") and rig.get_weapon_socket() != null, role + " one model and bound socket")
		check(enemy.scale.is_equal_approx(Vector3.ONE) and not enemy.has_node("Visuals/AnimatedRotor"), role + " physics scale and no legacy rotor")
		check(enemy.get_node("CollisionShape3D").shape.size.x < 4, role + " hull collision excludes empty sweep")
		var before: Vector3 = rig.get_weapon_origin()
		for query in 12: rig.get_weapon_socket()
		check(rig.outlet_index == 0 and rig.get_weapon_origin().is_equal_approx(before), role + " socket queries pure")
		_test_rotors(rig, role)
		_test_shot(enemy, role)
		# Keep isolated fixtures out of each other's collision and flight tests.
		enemy.position = Vector3(100 + i * 12, 32, 100)
	# Same underlying mesh resource across Viperhawk roles, with distinct tint materials.
	var torpedo = enemies.get("torpedo_vtol")
	var stealth = enemies.get("stealth_vtol")
	var minelayer = enemies.get("minelayer")
	if torpedo and stealth and minelayer:
		var body_path := "Visuals/CosmeticOffset/Model/Body"
		check(torpedo.get_node(body_path).mesh == stealth.get_node(body_path).mesh and stealth.get_node(body_path).mesh == minelayer.get_node(body_path).mesh, "Viperhawk roles share identical mesh resources")
		check(torpedo.get_node(body_path).get_active_material(0) != stealth.get_node(body_path).get_active_material(0) and stealth.get_node(body_path).get_active_material(0) != minelayer.get_node(body_path).get_active_material(0), "Viperhawk roles have distinct materials")
	# Boss through the actual wave-10 director route; no direct constructor.
	director.current_wave = 10
	director.wave_boss_spawned = false
	director._check_wave_10_boss()
	var bosses := get_nodes_in_group("bosses")
	check(bosses.size() == 1, "wave-10 route creates one Heavy Gunship Boss")
	if not bosses.is_empty():
		var boss = bosses[0]
		boss.set_process(false)
		boss.position = Vector3(0, 30, 45)
		var rig = boss.get_node("Visuals")
		check(rig.has_node("CosmeticOffset/Model/Upper_Rotor") and rig.has_node("CosmeticOffset/Model/Lower_Rotor"), "boss separate coaxial rotors")
		_test_rotors(rig, "heavy_gunship_boss")
		boss.target_player = player
		var n := get_nodes_in_group("combat_projectiles").size()
		boss._fire_spread_volley(5, 95.0, player.global_position)
		check(get_nodes_in_group("combat_projectiles").size() == n + 5 and rig.outlet_index == 5, "boss spread uses five socket launches")
		check(boss.telegraph_label != null, "boss warning label exists on replacement rig")
		boss.damage_receiver.take_damage(DamageData.new(140.0,GameConstants.WeaponType.MACHINE_GUN,null))
		check(boss.current_stage == boss.BossStage.ESCALATION, "boss damage enters escalation phase")
		boss.damage_receiver.take_damage(DamageData.new(60.0,GameConstants.WeaponType.MACHINE_GUN,null))
		check(boss.current_stage == boss.BossStage.FINAL, "boss damage enters final phase")
		var credits_before: int = gm.banked_credits
		var salvage_before: int = gm.carried_salvage
		var objectives_before: int = gm.counted_objectives
		boss._on_destroyed(null)
		boss._on_destroyed(null)
		check(gm.banked_credits == credits_before + 1320 and gm.carried_salvage == salvage_before + 10 and gm.counted_objectives == objectives_before + 1, "boss settlement and rewards occur once")
		gm.change_state(gm.RunState.ACTIVE)
	await process_frame
	# Harbor route must still construct destructible modular engines + launch bay.
	gm.selected_biome = "harbor"
	director.wave_boss_spawned = false
	director._check_wave_10_boss()
	bosses = get_nodes_in_group("bosses")
	if not bosses.is_empty():
		var titan = bosses[0]
		check("components" in titan and titan.components.has("launch_bay") and titan._engine_count() == 4 and not titan.get_node("Visuals").has_node("CosmeticOffset/Model"), "Airborne Titan retains modular engines and launch bay")
		titan.queue_free()
	else: check(false, "Airborne Titan actual route")
	gm.selected_biome = "town"
	# Orphaned rockets keep their snapshotted strength and bearing after owner death.
	var owner := Node3D.new()
	stage.add_child(owner)
	var orphan_hit := DamageData.new(24.0, GameConstants.WeaponType.ROCKET, owner, false, 14.0)
	owner.free()
	var clone := orphan_hit.clone_scaled(0.5)
	check(clone != null and clone.attacker == null and clone.raw_damage == 12.0 and clone.has_source_position, "freed firing owner preserves safe blast clone")
	# Blocked launches must neither create ordnance nor consume a selected tube.
	var rocket_fixture = enemies.get("rocket_gunship")
	if rocket_fixture:
		rocket_fixture.position = Vector3(0, 28, 38)
		rocket_fixture.cached_lead_aim = player.global_position
		var wall := StaticBody3D.new()
		wall.collision_layer = 2
		wall.position = Vector3(0, 28, 20)
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(30, 15, 3)
		col.shape = box
		wall.add_child(col)
		stage.add_child(wall)
		await physics_frame
		await physics_frame
		var rig = rocket_fixture.get_node("Visuals")
		var prior: int = rig.outlet_index
		var projectiles := get_nodes_in_group("combat_projectiles").size()
		check(not rocket_fixture._fire_rocket(2) and rig.outlet_index == prior and get_nodes_in_group("combat_projectiles").size() == projectiles, "obstructed rocket neither launches nor consumes outlet")
		wall.queue_free()
		await physics_frame
		await physics_frame
		var distinct := {}
		for shot in 8:
			var socket = rig.get_weapon_socket()
			distinct[socket.name] = true
			var x: float = socket.position.x
			check((x < 0) == (rig.outlet_index % 2 == 0), "rocket outlet alternates left/right")
			check(rocket_fixture._fire_rocket(shot % 3 + 1), "unobstructed rocket outlet launches")
		check(distinct.size() == 8, "rocket uses eight distinct tube mouths")
		rocket_fixture.position = Vector3(100, 32, 100)
	# Real pause/resume: callbacks must leave rotor bases unchanged while paused.
	var rocket = enemies.get("rocket_gunship")
	if rocket:
		var rc = rocket.get_node("Visuals/RotorController")
		var before: Basis = rc.main_rotor.basis
		paused = true
		await create_timer(0.08, true).timeout
		check(rc.main_rotor.basis.is_equal_approx(before), "tree pause freezes rotor")
		paused = false
		await create_timer(0.04).timeout
		check(not rc.main_rotor.basis.is_equal_approx(before), "resume continues rotor")
	# One real brain at a time: entry, permission, warning, projectile, then death.
	for role in ROLES:
		if not enemies.has(role): continue
		var enemy = enemies[role]
		enemy.position = Vector3(0, 30, 42)
		enemy.rotation = Vector3.ZERO
		enemy.velocity = Vector3.ZERO
		enemy.entry_grace_timer = 0.0
		enemy.entry_grace_period = 0.0
		enemy.set_behavior_state(BaseEnemy.BehaviorState.PURSUE)
		var rig = enemy.get_node("Visuals")
		var start_index: int = rig.outlet_index
		enemy.set_physics_process(true)
		var fired := false
		for tick in 900:
			await physics_frame
			if rig.outlet_index > start_index:
				fired = true
				break
		check(fired, role + " live AI produces real attack after warning/slot lifecycle")
		enemy.set_physics_process(false)
		enemy.position = Vector3(100, 32, 100)
		if role == "rocket_gunship":
			var count_before: int = rig.outlet_index
			enemy.damage_receiver.is_dead = true
			enemy._fire_rocket(1)
			check(rig.outlet_index == count_before, "death during salvo cannot launch")
			enemy.damage_receiver.is_dead = false
	# Swept real bullets/rockets hit a compound collider once, never once per shape.
	for shot in get_nodes_in_group("combat_projectiles"): shot.queue_free()
	await process_frame
	var probe := DamageProbe.new()
	probe.position = Vector3(40,28,-12)
	probe.collision_layer = 1
	probe.collision_mask = 0
	for i in 2:
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(4,4,4)
		col.shape = shape
		probe.add_child(col)
	stage.add_child(probe)
	await physics_frame
	var gunship = enemies.get("attack_gunship")
	if gunship:
		gunship.position = Vector3(40,28,12)
		gunship.rotation = Vector3.ZERO
		gunship.target_player = probe
		gunship._fire_gun(probe.global_position)
		for tick in 40: await physics_frame
		check(probe.hits == 1 and is_equal_approx(probe.accepted_damage, 8.0 * gunship.combat_damage_multiplier), "swept cannon delivers scaled damage once")
		gunship.target_player = player
	var rocket_damage = enemies.get("rocket_gunship")
	if rocket_damage:
		probe.hits = 0
		probe.accepted_damage = 0.0
		rocket_damage.position = Vector3(40,28,12)
		rocket_damage.rotation = Vector3.ZERO
		rocket_damage.target_player = probe
		rocket_damage.cached_lead_aim = probe.global_position
		rocket_damage._fire_rocket(2)
		for tick in 40: await physics_frame
		check(probe.hits == 1 and probe.accepted_damage > 0, "rocket blast damages compound collider once")
		rocket_damage.target_player = player
	probe.queue_free()
	for enemy in enemies.values(): enemy.queue_free()
	for shot in get_nodes_in_group("combat_projectiles"): shot.queue_free()
	await process_frame
	gm.current_state = gm.RunState.MENU
	print("AIR_INTEGRATION_RESULT checks=", checks, " failures=", failures)
	quit(1 if failures else 0)

func _test_rotors(rig: Node, role: String) -> void:
	var rc = rig.get_node_or_null("RotorController")
	if not rc: return
	rc.set_process(false)
	check(not rc._parts.is_empty(), role + " rotor bindings resolved")
	var results: Array[Basis] = []
	for fps in [30, 60, 120]:
		rc.reset_for_spawn()
		rc.set_speed_multiplier(0.35)
		var elapsed := 0.0
		while elapsed < 0.373 - 0.000001:
			var dt := minf(1.0 / fps, 0.373 - elapsed)
			rc._process(dt)
			elapsed += dt
		results.append(rc._parts[0].node.basis)
	check(results[0].is_equal_approx(results[1]) and results[1].is_equal_approx(results[2]), role + " equal-time 30/60/120 FPS with smooth speed response")
	for part in rc._parts:
		check(part.node.position.is_equal_approx(part.rest.origin), role + " shaft pivot stationary: " + str(part.node.name))
	rc.reset_for_spawn()
	check(is_equal_approx(rc._speed_multiplier, 1.0), role + " reset enters at flight speed")
	rc.set_process(true)

func _test_shot(enemy: Node3D, role: String) -> void:
	var rig = enemy.get_node("Visuals")
	var expected: Vector3 = rig.get_weapon_origin()
	var expected_socket: Node = rig.get_weapon_socket()
	var old := get_nodes_in_group("combat_projectiles")
	match role:
		"attack_gunship": enemy._fire_gun(player.global_position)
		"rocket_gunship":
			enemy.cached_lead_aim = player.global_position
			check(enemy._fire_rocket(1), "rocket direct launch succeeds")
		"interceptor":
			enemy.cached_aim_point = player.global_position
			enemy._fire_interceptor_round()
		"minelayer":
			enemy._drop_proximity_mine()
			var mine = stage.get_child(stage.get_child_count() - 1)
			check(mine.global_position.is_equal_approx(rig.get_drop_origin("MineDrop")), "mine uses underside drop socket")
			check(mine.arm_timer == 1.5 and mine.lifetime == 25.0, "mine arming delay/lifetime preserved")
			mine.queue_free()
			return
		_: enemy._fire_single_shot(player.global_position)
	var shots := get_nodes_in_group("combat_projectiles")
	var created: Node3D
	for shot in shots:
		if not old.has(shot): created = shot
	check(created != null, role + " creates projectile")
	if created:
		check(created.global_position.is_equal_approx(expected), role + " projectile starts at selected visible socket")
		check(created.collision_mask == 3, role + " projectile excludes own hostile collision layer")
		var matching_flash := false
		for flash in root.get_node("FXManager").muzzle_pool:
			if flash.source_node == expected_socket and flash.initial_transform.origin.is_equal_approx(expected): matching_flash = true
		check(matching_flash, role + " muzzle effect shares projectile socket")
		if role == "interceptor": check(is_equal_approx(created.velocity.length(), 310.0), "interceptor preserves authoritative 310 speed")
		if role == "torpedo_vtol": check(created.is_homing and created.speed == 72.0, "VTOL preserves missile homing/speed")
		if role == "heavy_bomber": check(is_equal_approx(created.velocity.y, -35.0), "bomber preserves drop velocity")
		created.queue_free()
	check(rig.outlet_index == 1, role + " successful shot advances one outlet")
