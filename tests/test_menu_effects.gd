extends SceneTree
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	print("PASS " if condition else "FAIL ", message)
	if not condition:
		failures.append(message)

func run() -> void:
	if OS.get_environment("ZIVA_TEST_DATA_DIR").is_empty():
		quit(1)
		return
	await process_frame
	var pm = root.get_node("ProfileManager")
	var store = root.get_node("SettingsStore")
	var original_path: String = pm.SAVE_PATH
	pm.wallet_credits = 10000
	pm.hangar_ranks.engine = 0
	pm.SAVE_PATH = original_path.path_join("missing/profile.json")
	check(not pm.buy_hangar_upgrade("engine") and pm.wallet_credits == 10000 and pm.hangar_ranks.engine == 0, "failed save rolls back purchase and rank")
	pm.SAVE_PATH = original_path
	await process_frame
	var corrupt := original_path + ".corrupt-test"
	var file := FileAccess.open(corrupt, FileAccess.WRITE)
	file.store_string("{invalid-json")
	file.close()
	var other = load("res://autoload/profile_manager.gd").new()
	other.SAVE_PATH = corrupt
	other.load_profile()
	check(not other.profile_valid and not other.save_profile(), "corrupt profile is write-protected")
	check(FileAccess.get_file_as_string(corrupt) == "{invalid-json", "corrupt original is preserved")
	other.free()
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var player = load("res://scenes/player/player.tscn").instantiate()
	world.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	var weapons = player.get_node("Weapons")
	weapons.set_process(false)
	for key in pm.hangar_ranks:
		pm.hangar_ranks[key] = 1
	for key in pm.perk_ranks:
		pm.perk_ranks[key] = 1
	pm.apply_loadout(player)
	check(is_equal_approx(weapons.damage_multipliers[0], 1.06), "ordnance rank changes real damage multiplier")
	check(is_equal_approx(player.armor_mitigation, 0.04), "airframe rank changes damage mitigation")
	check(is_equal_approx(player.dash_speed_multiplier, 1.2) and is_equal_approx(player.dash_cooldown_reduction, 0.4), "dash perk changes speed and cooldown")
	check(is_equal_approx(player.loot_multiplier, 1.15), "scavenger perk changes rewards")
	var pickup = load("res://src/loot/pickup.gd").new()
	pickup.pickup_type = pickup.PickupType.COIN
	pickup.pickup_value = 10
	world.add_child(pickup)
	var gm = root.get_node("GameManager")
	gm.start_new_run()
	var coins_before: int = gm.coins_collected
	pickup._apply_pickup_effect(player)
	check(gm.coins_collected == coins_before + 12, "scavenger bonus reaches actual coin reward")
	var enemy := Node3D.new()
	world.add_child(enemy)
	enemy.add_to_group("enemies")
	var receiver = load("res://src/combat/damage_receiver.gd").new()
	receiver.name = "DamageReceiver"
	receiver.max_health = 10000
	enemy.add_child(receiver)
	for mod in range(1, 9):
		var data = load("res://src/combat/damage_data.gd").new(100.0, (mod - 1) / 2, player, false, 10.0)
		weapons._apply_mods_to_damage((mod - 1) / 2, mod, data)
		match mod:
			1: check(data.burn_chance > 0 and data.emp_chance > 0, "incendiary mod and EMP perk combine")
			2:
				receiver.target_affinity = GameConstants.TargetAffinity.ARMORED
				var health: float = receiver.current_health
				receiver.take_damage(data)
				check(is_equal_approx(health - receiver.current_health, 100 * 0.85 * 1.35), "piercing mod boosts real armored damage")
			3:
				receiver.take_damage(data)
				check(receiver.emp_timer > 0 and receiver.is_emp_disabled, "EMP missile actually disrupts receiver")
			4:
				var projectile = load("res://scenes/combat/projectile.tscn").instantiate()
				world.add_child(projectile)
				projectile.setup(data)
				var before: int = get_nodes_in_group("combat_projectiles").size()
				projectile._spawn_mod_effects(Vector3(20, 0, 20))
				check(get_nodes_in_group("combat_projectiles").size() == before + 3, "cluster missile creates three bomblets")
				projectile.queue_free()
			5:
				check(is_equal_approx(data.blast_radius, 13.0), "napalm expands explosion radius")
				var projectile = load("res://scenes/combat/projectile.tscn").instantiate()
				world.add_child(projectile)
				projectile.setup(data)
				var health: float = receiver.current_health
				projectile._spawn_mod_effects(Vector3.ZERO)
				projectile.queue_free()
				await create_timer(0.6).timeout
				check(receiver.current_health < health, "napalm field deals persistent damage")
			6:
				receiver.target_affinity = GameConstants.TargetAffinity.STRUCTURE
				var health: float = receiver.current_health
				receiver.take_damage(data)
				check(is_equal_approx(health - receiver.current_health, 100 * GameConstants.DAMAGE_AFFINITY_MATRIX[2][2] * 1.45), "shaped charge boosts actual structure damage")
			7: check(data.shock_chance > 0, "shock mod sets status chance")
			8: check(is_equal_approx(data.raw_damage, 130.0), "slug increases real damage")
	store.set_value("flashes", true)
	root.get_node("FXManager").spawn_explosion(Vector3.ZERO)
	var container = get_nodes_in_group("combat_explosions").back()
	var light: OmniLight3D
	for child in container.get_children():
		if child is OmniLight3D:
			light = child
	check(light != null and light.light_energy < 1.0, "reduced flashes lowers actual explosion light")
	store.set_value("sfx", 0.0)
	store.set_value("master", 0.0)
	await process_frame
	check(root.get_node("AudioManager").sfx_volume == 0.0, "effects mute reaches audio owner")
	print("EFFECTS_RESULT checks=", checks, " failures=", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
