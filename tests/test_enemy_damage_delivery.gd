extends SceneTree

func _init() -> void:
	print("--- TESTING ENEMY DAMAGE DELIVERY TO PLAYER ---")
	var runner = DamageDeliveryRunner.new()
	root.add_child(runner)

class DamageDeliveryRunner extends Node:
	var player: Node3D
	var spawner: Node
	var test_gunship: BaseEnemy
	var test_tank: BaseEnemy
	var initial_hp: float = 0.0
	var ticks = 0

	func _ready() -> void:
		var p_scene = preload("res://scenes/player/player.tscn")
		player = p_scene.instantiate()
		player.position = Vector3(0, 14, 0)
		add_child(player)
		initial_hp = player.current_hull

		var sp_script = preload("res://src/enemies/enemy_spawner.gd")
		spawner = sp_script.new()
		add_child(spawner)

		# Allow attacks immediately
		var cd = get_node_or_null("/root/CombatDirector")
		if cd:
			cd.is_wave_active = true
			cd.current_wave = 1
			cd.max_air_slots = 3
			cd.max_heavy_slots = 3

		# Spawn an assault APC and attack gunship right in front of the player
		test_tank = spawner._create_enemy_node("assault_apc")
		test_tank.position = Vector3(0.0, 1.0, 20.0)
		add_child(test_tank)

		test_gunship = spawner._create_enemy_node("attack_gunship")
		test_gunship.position = Vector3(0.0, 16.0, 24.0)
		add_child(test_gunship)

	func _physics_process(delta: float) -> void:
		ticks += 1

		if ticks == 60:
			var current_hp = player.current_hull
			var hp_lost = initial_hp - current_hp
			print("At Tick 60: Player Initial HP = %.1f | Current HP = %.1f | Damage Taken = %.1f" % [initial_hp, current_hp, hp_lost])
			if current_hp < initial_hp:
				print("[PASS] ENEMY DAMAGE DELIVERY VERIFIED: Player hull decreased from enemy fire!")
				get_tree().quit(0)
			else:
				# Check at tick 120
				pass

		if ticks == 120:
			var current_hp = player.current_hull
			var hp_lost = initial_hp - current_hp
			print("At Tick 120: Player Initial HP = %.1f | Current HP = %.1f | Damage Taken = %.1f" % [initial_hp, current_hp, hp_lost])
			if current_hp < initial_hp:
				print("[PASS] ENEMY DAMAGE DELIVERY VERIFIED: Player hull decreased from enemy fire!")
				get_tree().quit(0)
			else:
				print("[FAIL] Player took no damage after 120 ticks.")
				get_tree().quit(1)
