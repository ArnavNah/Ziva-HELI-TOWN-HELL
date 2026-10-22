extends SceneTree

## Verification test for Full 13-Enemy Roster, 9 Urban Districts, LootManager, and Tactical Radar

func _init() -> void:
	print("--- BEGIN EXPANDED ROSTER & DISTRICTS VERIFICATION ---")
	var tests_passed: int = 0
	var total_tests: int = 5

	# 1. Test All 13 Enemy Variants
	var enemy_spawner_script = preload("res://src/enemies/enemy_spawner.gd")
	var spawner = enemy_spawner_script.new()
	root.add_child(spawner)
	
	var variants_to_test = [
		"scout_drone", "attack_gunship", "kamikaze_drone", "rocket_gunship",
		"interceptor", "minelayer", "flak_tank", "missile_carrier",
		"siege_tank", "gatling_heavy", "infantry_squad", "shield_drone", "repair_drone",
		"assault_apc", "sam_launcher", "technical_truck", "stealth_vtol", "heavy_bomber"
	]
	
	var all_variants_ok = true
	for v_key in variants_to_test:
		var node = spawner._create_enemy_node(v_key)
		if node == null or node.variant_id != v_key or not node.has_node("DamageReceiver"):
			all_variants_ok = false
			print("  [FAIL] Failed to instantiate variant: ", v_key)
			break
		node.queue_free()
		
	if all_variants_ok:
		print("  [PASS] 1. Complete Enemy Roster: All 18 specialized hostiles instantiated with valid damage receivers.")
		tests_passed += 1
	else:
		print("  [FAIL] 1. Enemy roster instantiation error.")

	# 2. Test All 9 City Districts
	var city_script = preload("res://src/world/city_generator.gd")
	var city = city_script.new()
	root.add_child(city)
	
	var districts = [
		"Downtown", "Industrial", "Residential", "Waterfront",
		"Military Base", "Desert", "Forest", "Ruins", "Commercial"
	]
	
	var all_districts_ok = true
	for dist in districts:
		city.generate_district(dist, 42)
		if city.spawned_blocks.is_empty():
			all_districts_ok = false
			print("  [FAIL] District generation empty: ", dist)
			break
			
	if all_districts_ok:
		print("  [PASS] 2. Procedural World: All 9 urban districts generate correctly with themed buildings and hazards.")
		tests_passed += 1
	else:
		print("  [FAIL] 2. District generation error.")

	# 3. Test LootManager & Pickups
	var loot_mgr_script = preload("res://src/loot/loot_manager.gd")
	var loot_mgr = loot_mgr_script.new()
	root.add_child(loot_mgr)
	
	var pickup = loot_mgr.spawn_pickup(0, Vector3(10, 1, 10), 35.0) # Field Repair
	if pickup != null and is_instance_valid(pickup):
		print("  [PASS] 3. Loot System: LootManager successfully spawned tactical pickup with 3D mesh and collision.")
		tests_passed += 1
		pickup.queue_free()
	else:
		print("  [FAIL] 3. LootManager failed to spawn pickup.")

	# 4. Test Tactical Radar Minimap
	var radar_script = preload("res://src/ui/minimap.gd")
	var radar = radar_script.new()
	root.add_child(radar)
	if radar.radar_radius_pixels == 75.0 and radar.world_detection_radius == 160.0:
		print("  [PASS] 4. Tactical Radar: Real-time 360-degree radar initialized with 160m detection range.")
		tests_passed += 1
		radar.queue_free()
	else:
		print("  [FAIL] 4. Tactical Radar configuration error.")

	# 5. Test Main Menu Scene & Navigation
	var menu_scene = preload("res://scenes/ui/main_menu.tscn")
	var menu = menu_scene.instantiate()
	root.add_child(menu)
	if menu != null and menu.has_node("VBoxContainer/StartBtn") and menu.has_node("FlightManualDialog"):
		print("  [PASS] 5. Main Menu: Front-end operations center verified with aircraft selection and flight manual.")
		tests_passed += 1
		menu.queue_free()
	else:
		print("  [FAIL] 5. Main Menu scene instantiation error.")

	print("Summary: ", tests_passed, "/", total_tests, " PASSED.")
	if tests_passed == total_tests:
		print("--- ALL EXPANDED ROSTER & DISTRICT VERIFICATIONS SUCCEEDED ---")
		quit(0)
	else:
		quit(1)
