extends SceneTree

func _init():
	print("--- STARTING LIVE GAMEPLAY SIMULATION ---")
	var scene_res = load("res://scenes/main_game.tscn")
	if scene_res == null:
		printerr("Failed to load res://scenes/main_game.tscn")
		quit(1)
		return
	var main_scene = scene_res.instantiate()
	root.add_child(main_scene)
	print("main_game.tscn instantiated and added to root.")
	
	var runner = SimulationRunner.new()
	root.add_child(runner)

class SimulationRunner extends Node:
	var frame_count: int = 0
	var max_frames: int = 300

	func _ready():
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(_delta: float) -> void:
		frame_count += 1
		var tree = get_tree()
		var player = tree.root.get_node_or_null("MainGame/PlayerHelicopter")
		var spawner = tree.root.get_node_or_null("MainGame/EnemySpawner")
		var cargo_mgr = tree.root.get_node_or_null("MainGame/CargoManager")
		
		if frame_count == 20:
			print("[Frame 20] Simulating player weapon firing (Machine Gun)...")
			if player:
				var weapons = player.get_node_or_null("Weapons")
				if weapons:
					weapons.try_fire()

		if frame_count == 40:
			print("[Frame 40] Simulating weapon switch & missile fire...")
			if player:
				var weapons = player.get_node_or_null("Weapons")
				if weapons:
					weapons.switch_weapon(1)
					weapons.try_fire()

		if frame_count == 60:
			print("[Frame 60] Simulating flare deployment & evasive dash...")
			if player:
				var cm = player.get_node_or_null("Countermeasures")
				if cm:
					cm.deploy_flares()
				if player.has_method("trigger_evasive_dash"):
					player.trigger_evasive_dash()

		if frame_count == 80:
			print("[Frame 80] Simulating salvo missile launch...")
			if player:
				var salvo = player.get_node_or_null("Salvo")
				if salvo:
					var dummy_target = Node3D.new()
					get_tree().root.add_child(dummy_target)
					dummy_target.global_position = Vector3(0, 10, -50)
					salvo.add_target_lock(dummy_target)
					salvo.launch_salvo()

		if frame_count == 100:
			print("[Frame 100] Simulating enemy wave spawning...")
			if spawner:
				if spawner.has_method("spawn_enemy_type"):
					var _scout = spawner.spawn_enemy_type("scout_drone", Vector3(10, 15, -30))
					var _gunship = spawner.spawn_enemy_type("attack_gunship", Vector3(-15, 20, -40))
					var _flak = spawner.spawn_enemy_type("flak_tank", Vector3(20, 0, -25))
				elif spawner.has_method("spawn_wave_enemy"):
					spawner.spawn_wave_enemy(1)
					spawner.spawn_wave_enemy(2)

		if frame_count == 130:
			print("[Frame 130] Simulating damage dealing and enemy death...")
			var enemies = get_tree().root.find_children("", "BaseEnemy", true, false)
			for e in enemies:
				if is_instance_valid(e) and e.has_node("DamageReceiver"):
					var dd = preload("res://src/combat/damage_data.gd").new(999.0, 0, null, true, 0.0)
					e.get_node("DamageReceiver").take_damage(dd)

		if frame_count == 160:
			print("[Frame 160] Simulating building collapse...")
			var buildings = get_tree().root.find_children("", "DestructibleBuilding", true, false)
			if buildings.size() > 0:
				var b = buildings[0]
				if is_instance_valid(b) and b.has_node("DamageReceiver"):
					var dd = preload("res://src/combat/damage_data.gd").new(5000.0, 2, null, true, 0.0)
					b.get_node("DamageReceiver").take_damage(dd)

		if frame_count == 190:
			print("[Frame 190] Simulating cargo contract...")
			if cargo_mgr and cargo_mgr.has_method("generate_contract"):
				var contract = cargo_mgr.generate_contract(1, Vector3.ZERO)
				if contract and cargo_mgr.has_method("accept_contract"):
					cargo_mgr.accept_contract(contract)

		if frame_count == 220:
			print("[Frame 220] Simulating Level-up Upgrade dialog & choice selection...")
			if player:
				var prog = player.get_node_or_null("RunProgression")
				if prog and prog.has_method("add_run_xp"):
					prog.add_run_xp(100)
					prog.apply_upgrade_choice("Overclock Rounds")

		if frame_count == 250:
			print("[Frame 250] Simulating Boss Spawn...")
			if spawner and spawner.has_method("spawn_boss"):
				spawner.spawn_boss()

		if frame_count == 270:
			print("[Frame 270] Simulating Super Devastation...")
			if player:
				var super_mod = player.get_node_or_null("DevastationSuper")
				if super_mod:
					super_mod.add_charge(100.0)
					if super_mod.has_method("try_activate_super"):
						super_mod.try_activate_super()

		if frame_count >= max_frames:
			print("[Frame 300] ALL GAMEPLAY SIMULATION FRAMES COMPLETED WITHOUT CRASH!")
			get_tree().quit(0)
