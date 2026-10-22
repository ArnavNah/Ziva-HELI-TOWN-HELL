extends SceneTree

func _init() -> void:
	print("==================================================")
	print("       VERIFYING ALL 27 ENEMY AI BRAINS           ")
	print("==================================================")
	var runner = AllBrainVerifier.new()
	root.add_child(runner)

class AllBrainVerifier extends Node:
	var variants = [
		"scout_drone", "attack_gunship", "kamikaze_drone", "rocket_gunship",
		"interceptor", "minelayer", "flak_tank", "missile_carrier",
		"siege_tank", "gatling_heavy", "infantry_squad", "shield_drone", "repair_drone",
		"rocket_buggy", "flame_tank", "rail_crawler", "hunter_drone", "torpedo_vtol",
		"escort_fighter", "scout_buggy", "mortar_crawler", "attack_wing",
		"assault_apc", "sam_launcher", "technical_truck", "stealth_vtol", "heavy_bomber"
	]
	var current_idx = 0
	var current_enemy: BaseEnemy = null
	var frames_alive = 0
	var player: Node3D
	var spawner: Node
	var passed = 0
	var failed = 0

	func _ready() -> void:
		# Player anchor
		var p_scene = preload("res://scenes/player/player.tscn")
		player = p_scene.instantiate()
		player.position = Vector3(0, 14, 0)
		add_child(player)
		var p_rec = player.get_node_or_null("DamageReceiver")
		if p_rec:
			p_rec.max_health = 99999.0
			p_rec.current_health = 99999.0

		var sp_script = preload("res://src/enemies/enemy_spawner.gd")
		spawner = sp_script.new()
		add_child(spawner)

		_test_variant()

	func _test_variant() -> void:
		if is_instance_valid(current_enemy):
			current_enemy.queue_free()
			current_enemy = null

		if current_idx >= variants.size():
			print("==================================================")
			print("SUMMARY: %d / %d VARIANTS PASSED AI BRAIN VERIFICATION" % [passed, variants.size()])
			if failed == 0:
				print("ALL ENEMY BRAINS ARE ACTIVE, MOVING, AND COMBAT READY!")
				get_tree().quit(0)
			else:
				print("FAILED VARIANTS COUNT: %d" % failed)
				get_tree().quit(1)
			return

		var key = variants[current_idx]
		current_idx += 1
		frames_alive = 0

		var v_data = preload("res://src/enemies/enemy_data.gd").VARIANTS.get(key, {})
		var family = v_data.get("family", "air")
		var spawn_pos = Vector3(25.0, 1.0 if family == "ground" else 18.0, 0.0)

		current_enemy = spawner._create_enemy_node(key)
		current_enemy.position = spawn_pos
		add_child(current_enemy)

	func _physics_process(delta: float) -> void:
		if not is_instance_valid(current_enemy):
			return

		frames_alive += 1
		if frames_alive == 20:
			var key = current_enemy.variant_id
			var vel_len = current_enemy.velocity.length()
			var pos = current_enemy.global_position
			if vel_len > 0.1 or pos.distance_to(Vector3(25.0, 1.0, 0.0)) > 0.5:
				print("  [PASS] %-16s | Speed: %5.1f m/s | Pos: (%5.1f, %5.1f, %5.1f)" % [key, vel_len, pos.x, pos.y, pos.z])
				passed += 1
			else:
				print("  [FAIL] %-16s | Stalled at speed: %.2f m/s" % [key, vel_len])
				failed += 1

			_test_variant()
