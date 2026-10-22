extends SceneTree

func _init() -> void:
	print("--- TESTING ALL 18 ENEMY AI BRAINS ---")
	var runner = AllEnemyBrainRunner.new()
	root.add_child(runner)

class AllEnemyBrainRunner extends Node:
	var spawner: Node
	var player: Node3D
	var variants = [
		"scout_drone", "attack_gunship", "kamikaze_drone", "rocket_gunship",
		"interceptor", "minelayer", "flak_tank", "missile_carrier",
		"siege_tank", "gatling_heavy", "infantry_squad", "shield_drone", "repair_drone",
		"rocket_buggy", "flame_tank", "rail_crawler", "hunter_drone", "torpedo_vtol",
		"escort_fighter", "scout_buggy", "mortar_crawler", "attack_wing",
		"assault_apc", "sam_launcher", "technical_truck", "stealth_vtol", "heavy_bomber"
	]
	var current_idx = 0
	var current_unit: BaseEnemy = null
	var unit_ticks = 0
	var shots_fired = 0
	var initial_hp = 0.0

	func _ready() -> void:
		# Create Player
		var p_scene = preload("res://scenes/player/player.tscn")
		player = p_scene.instantiate()
		player.position = Vector3(0, 14, 0)
		add_child(player)
		initial_hp = player.current_hull

		# Create Spawner
		var sp_script = preload("res://src/enemies/enemy_spawner.gd")
		spawner = sp_script.new()
		add_child(spawner)

		# Ensure CombatDirector wave is active
		var cd = get_node_or_null("/root/CombatDirector")
		if cd:
			cd.is_wave_active = true
			cd.current_wave = 5
			cd.max_air_slots = 5
			cd.max_heavy_slots = 5

		_test_next_variant()

	func _test_next_variant() -> void:
		if is_instance_valid(current_unit):
			current_unit.queue_free()
			current_unit = null

		if current_idx >= variants.size():
			print("\n--- ALL 18+ ENEMY VARIANTS TESTED ---")
			get_tree().quit(0)
			return

		var v_key = variants[current_idx]
		current_idx += 1
		unit_ticks = 0
		shots_fired = 0

		var v_data = preload("res://src/enemies/enemy_data.gd").VARIANTS.get(v_key, {})
		var family = v_data.get("family", "air")
		var spawn_pos = Vector3(25.0, 1.0 if family == "ground" else 18.0, 0.0)

		current_unit = spawner._create_enemy_node(v_key)
		current_unit.position = spawn_pos
		add_child(current_unit)

	func _physics_process(delta: float) -> void:
		if not is_instance_valid(current_unit):
			return

		unit_ticks += 1

		# Check if enemy fired a projectile
		var projs = get_tree().get_nodes_in_group("enemy_projectiles")
		if projs.size() > shots_fired:
			shots_fired = projs.size()

		# After 35 ticks (~0.58s): evaluate
		if unit_ticks >= 35:
			var v_key = current_unit.variant_id
			var moved = current_unit.velocity.length()
			print("Variant: %-16s | Vel: %4.1f m/s | Shots: %d | Pos: %s" % [v_key, moved, shots_fired, str(current_unit.global_position)])
			# Clean up projectiles
			for p in projs:
				if is_instance_valid(p):
					p.queue_free()
			_test_next_variant()
