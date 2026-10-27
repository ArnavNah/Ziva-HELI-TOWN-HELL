extends SceneTree

## Verification Test: Real City Street Ground Spawning
## Validates that all 7 modeled ground vehicles spawn on actual road corridors in the real city environment.

const Specs = preload("res://src/enemies/enemy_data.gd")
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
	call_deferred("_run_test")

func _run_test() -> void:
	print("\n=======================================================")
	print("=== REAL CITY STREET GROUND VEHICLE SPAWNING TEST ===")
	print("=======================================================\n")

	# Instantiate main game scene
	var game = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game

	# Wait for city and systems to initialize
	for f in range(10):
		await process_frame

	var spawner = game.get_node_or_null("EnemySpawner")
	if not spawner:
		var spawners = get_nodes_in_group("enemy_spawners")
		if not spawners.is_empty():
			spawner = spawners[0]

	check(spawner != null, "Found active EnemySpawner in main game scene")

	var player = get_first_node_in_group("player")
	check(player != null, "Found PlayerHelicopter in main game scene")

	var center_pos = player.global_position if player else Vector3.ZERO
	print("Player position: ", center_pos)

	var cd = game.get_node_or_null("/root/CombatDirector")
	if cd:
		cd.start_wave_director()
		cd.use_credit_director = true
		cd.target_population = 20

	var card_source = cd.catalog if (cd and cd.catalog) else CatalogClass.new()

	print("\n--- Testing Street Placement & Spawning for Each Modeled Vehicle ---")
	for v_id in MODELED_GROUND:
		# 1. Test find_valid_spawn_position on road
		var spawn_pos = spawner.find_valid_spawn_position("ground", center_pos, v_id)
		check(spawn_pos != Vector3.INF, "Found valid street spawn point for '%s': %s" % [v_id, str(spawn_pos)])

		# 2. Verify road distance
		var dist_to_road = UrbanPathfinder.distance_to_nearest_road(spawn_pos)
		check(dist_to_road <= 3.0, "'%s' spawn position is within road corridor (dist: %.2f m)" % [v_id, dist_to_road])

		# 3. Test spawn_director_card through real catalog card at its unlocked wave
		var card = card_source.get_card_by_id(v_id + "_solo")
		check(card != null, "Catalog contains solo card for '%s'" % v_id)
		if card:
			if cd:
				cd.current_wave = card.gate_wave
				cd.fast_wallet = 500.0
				cd.slow_wallet = 500.0
			var stream = card.allowed_streams[0] if not card.allowed_streams.is_empty() else "fast"
			var spawned = spawner.spawn_director_card(card, stream)
			check(spawned.size() == 1, "Direct card purchase spawned '%s' at Wave %d (count: %d)" % [v_id, card.gate_wave, spawned.size()])
			if spawned.size() > 0:
				var unit = spawned[0]
				check(unit.is_in_group("enemies"), "Spawned unit is in 'enemies' group")
				check(unit.get_node_or_null("Visuals") != null, "Spawned unit has 'Visuals' rig")
				check(unit.get_node_or_null("Turret") != null, "Spawned unit has 'Turret' rig")

	print("\n=======================================================")
	print("CITY SPAWN TEST SUMMARY: %d / %d passed (%d failures)" % [tests_run - failures, tests_run, failures])
	print("=======================================================\n")

	game.queue_free()
	quit(0 if failures == 0 else 1)
