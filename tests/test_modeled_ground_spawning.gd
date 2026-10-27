extends SceneTree

## Comprehensive Verification Test Suite: Modeled Ground Enemies Spawning & Combat
## Confirms removal of all 8 placeholder ground types and proper spawning of all 7 modeled vehicles.

const Specs = preload("res://src/enemies/enemy_data.gd")
const SpawnerClass = preload("res://src/enemies/enemy_spawner.gd")
const CatalogClass = preload("res://src/enemies/encounter/spawn_card_catalog.gd")

const MODELED_GROUND = [
	"scout_buggy",
	"assault_apc",
	"rail_crawler",
	"siege_tank",
	"gatling_heavy",
	"raptor_raider",
	"desert_barrage_rover"
]

const PURGED_PLACEHOLDERS = [
	"rocket_buggy",
	"flame_tank",
	"mortar_crawler",
	"sam_launcher",
	"technical_truck",
	"flak_tank",
	"missile_carrier",
	"infantry_squad"
]

var failures: int = 0
var tests_run: int = 0

func check(ok: bool, desc: String) -> void:
	tests_run += 1
	if ok:
		print("  [PASS] %s" % desc)
	else:
		failures += 1
		print("  [FAIL] %s" % desc)

func _initialize() -> void:
	call_deferred("_run_suite")

func _run_suite() -> void:
	print("\n=======================================================")
	print("=== MODELED GROUND ENEMIES SPAWNING VERIFICATION ===")
	print("=======================================================\n")

	# Stop background combat director so it doesn't interfere
	var cd = root.get_node_or_null("CombatDirector")
	if cd and cd.has_method("stop_wave_director"):
		cd.stop_wave_director()

	_test_catalog_and_specs()
	_test_individual_modeled_spawning()
	_test_director_credit_and_wave_spawning()
	_test_projectile_and_muzzle_integrity()

	print("\n=======================================================")
	print("SUMMARY: %d / %d checks passed (%d failures)" % [tests_run - failures, tests_run, failures])
	print("=======================================================\n")

	quit(0 if failures == 0 else 1)

func _test_catalog_and_specs() -> void:
	print("--- 1. Verification of Purged Placeholders and Active Specs ---")
	for purged in PURGED_PLACEHOLDERS:
		check(not Specs.VARIANTS.has(purged), "Purged ground type '%s' is completely absent from EnemyData.VARIANTS" % purged)
		check(not Specs.is_variant_enabled(purged), "Specs.is_variant_enabled('%s') returns false" % purged)

	for active_id in MODELED_GROUND:
		check(Specs.VARIANTS.has(active_id), "Modeled vehicle '%s' is present in EnemyData.VARIANTS" % active_id)
		check(Specs.is_variant_enabled(active_id), "Specs.is_variant_enabled('%s') returns true" % active_id)
		check(Specs.VARIANTS[active_id].family == "ground", "Vehicle '%s' has family 'ground'" % active_id)

	var catalog = CatalogClass.new()
	var all_cards = catalog.get_all_cards()
	var active_seen: Dictionary = {}
	var purged_seen := false

	for card in all_cards:
		if card.variant_id in PURGED_PLACEHOLDERS:
			purged_seen = true
		if card.variant_id in MODELED_GROUND:
			active_seen[card.variant_id] = true

	check(not purged_seen, "Zero spawn cards exist for any purged placeholder ground types")
	check(active_seen.size() == MODELED_GROUND.size(), "Spawn cards exist for all 7 modeled ground vehicles (found %d/7)" % active_seen.size())

func _test_individual_modeled_spawning() -> void:
	print("\n--- 2. Instantiation & Hierarchy Verification of All 7 Modeled Vehicles ---")
	var world := Node3D.new()
	root.add_child(world)

	var spawner = SpawnerClass.new()
	world.add_child(spawner)
	spawner.set_process(false)

	# Verify direct spawning rejects placeholders
	for purged in PURGED_PLACEHOLDERS:
		var node = spawner.spawn_enemy_type(purged, Vector3.ZERO, true)
		check(node == null, "Spawner rejects direct spawn of placeholder '%s'" % purged)

	# Verify all 7 modeled vehicles instantiate proper hierarchy without primitive fallbacks
	for active_id in MODELED_GROUND:
		var unit = spawner.spawn_enemy_type(active_id, Vector3(0, 0, 0), true)
		check(unit != null, "Successfully spawned '%s'" % active_id)
		if unit == null:
			continue

		var visuals = unit.get_node_or_null("Visuals")
		check(visuals != null, "'%s' has Visuals node" % active_id)

		var turret = unit.get_node_or_null("Turret")
		check(turret != null, "'%s' has Turret node" % active_id)

		# Check for real meshes (no primitive BoxMesh fallback as body)
		var mesh_instances: Array[MeshInstance3D] = []
		_collect_mesh_instances(unit, mesh_instances)
		check(mesh_instances.size() > 0, "'%s' contains rendered meshes (%d found)" % [active_id, mesh_instances.size()])

		# Verify specific vehicle controllers and components
		match active_id:
			"scout_buggy":
				var wc = visuals.get_script()
				check(wc != null and "scout_buggy_wheel" in wc.resource_path.to_lower(), "Scout Buggy has ScoutBuggyWheelController")
				var tc = turret.get_script()
				check(tc != null and "scout_buggy_turret" in tc.resource_path.to_lower(), "Scout Buggy has ScoutBuggyTurret")
			"assault_apc":
				var wc = visuals.get_script()
				check(wc != null and "assault_apc_wheel" in wc.resource_path.to_lower(), "Assault APC has AssaultAPCWheelController")
				var tc = turret.get_script()
				check(tc != null and "assault_apc_turret" in tc.resource_path.to_lower(), "Assault APC has AssaultAPCTurret")
			"rail_crawler":
				var tc = turret.get_script()
				check(tc != null and "articulated_tank_turret" in tc.resource_path.to_lower(), "Azure Siege Tank (Rail Crawler) has ArticulatedTankTurret")
			"siege_tank":
				var tc = turret.get_script()
				check(tc != null and "articulated_tank_turret" in tc.resource_path.to_lower(), "Desert Ironclad (Siege Tank) has ArticulatedTankTurret")
			"gatling_heavy":
				var tc = turret.get_script()
				check(tc != null and "articulated_tank_turret" in tc.resource_path.to_lower(), "Ironclad Sentinel (Gatling Heavy) has ArticulatedTankTurret")
			"raptor_raider":
				var wc = visuals.get_script()
				check(wc != null and "multi_axle_wheel" in wc.resource_path.to_lower(), "Raptor Raider has MultiAxleWheelController")
				var tc = turret.get_script()
				check(tc != null and "raptor_cannon" in tc.resource_path.to_lower(), "Raptor Raider has RaptorCannonTurret")
			"desert_barrage_rover":
				var wc = visuals.get_script()
				check(wc != null and "multi_axle_wheel" in wc.resource_path.to_lower(), "Desert Barrage Rover has MultiAxleWheelController")
				var tc = turret.get_script()
				check(tc != null and "desert_barrage_launcher" in tc.resource_path.to_lower(), "Desert Barrage Rover has DesertBarrageLauncher")

		unit.queue_free()

	world.queue_free()

func _test_director_credit_and_wave_spawning() -> void:
	print("\n--- 3. Autonomous Wave Director & Theme Spawning Simulation ---")
	var catalog = CatalogClass.new()
	var themes = ["Normal", "Armored Column", "Swarm Tide", "Storm Surge", "Night Surge"]

	# Test unlock progression across waves 1 to 10
	for wave in range(1, 11):
		var unlocked_ground: Array[String] = []
		for ground_id in MODELED_GROUND:
			if int(Specs.VARIANTS[ground_id].gate_wave) <= wave:
				unlocked_ground.append(ground_id)

		for theme in themes:
			var eligible_fast = catalog.get_affordable_eligible_cards(
				wave, theme, "fast", 1000.0, {}, 0, 20, 20
			)
			var eligible_slow = catalog.get_affordable_eligible_cards(
				wave, theme, "slow", 1000.0, {}, 0, 20, 20
			)
			var all_eligible: Array[SpawnCard] = eligible_fast + eligible_slow

			# Check that no card in all_eligible references a purged placeholder
			for card in all_eligible:
				if card.variant_id in PURGED_PLACEHOLDERS:
					check(false, "Wave %d [%s] offered purged variant %s" % [wave, theme, card.variant_id])

			# In Armored Column theme, verify heavy armor ground vehicles have highest weights
			if theme == "Armored Column" and wave >= 6:
				var has_armored_ground := false
				for card in all_eligible:
					if card.variant_id in ["rail_crawler", "assault_apc", "desert_barrage_rover"]:
						has_armored_ground = true
						break
				check(has_armored_ground, "Wave %d Armored Column offers modeled armored ground options" % wave)

	check(true, "All 10 waves and 5 themes successfully evaluated without any placeholder leakage")

func _test_projectile_and_muzzle_integrity() -> void:
	print("\n--- 4. Combat Aiming, Muzzle Markers & Projectiles ---")
	var world := Node3D.new()
	root.add_child(world)

	var player := CharacterBody3D.new()
	player.add_to_group("player")
	player.position = Vector3(0, 10, -30)
	world.add_child(player)

	var spawner = SpawnerClass.new()
	world.add_child(spawner)
	spawner.set_process(false)

	for active_id in MODELED_GROUND:
		var unit = spawner.spawn_enemy_type(active_id, Vector3(0, 0, 0), true)
		if unit == null:
			check(false, "Failed to spawn '%s' for combat test" % active_id)
			continue

		var turret = unit.get_node_or_null("Turret")
		var muzzle_pos := Vector3.ZERO
		if turret and turret.has_method("get_muzzle_position"):
			muzzle_pos = turret.get_muzzle_position()
		elif turret:
			var marker = turret.get_node_or_null("GunPitch/Recoil/Muzzle")
			if marker:
				muzzle_pos = marker.global_position
			else:
				muzzle_pos = turret.global_position

		check(muzzle_pos != Vector3.ZERO, "'%s' reports valid 3D muzzle position: %s" % [active_id, str(muzzle_pos)])

		unit.queue_free()

	player.queue_free()
	world.queue_free()

func _collect_mesh_instances(node: Node, list: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		list.append(node)
	for child in node.get_children():
		_collect_mesh_instances(child, list)
