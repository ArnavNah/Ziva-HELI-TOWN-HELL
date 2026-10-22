extends SceneTree

func _init() -> void:
	print("Instantiating main_game for Floating Combat Text & Kill Compliments verification...")
	var scene = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(scene)

	var runner = FCTVisualRunner.new()
	root.add_child(runner)

class FCTVisualRunner extends Node:
	var frame: int = 0
	var enemy1: Node
	var enemy2: Node

	func _process(_delta: float) -> void:
		frame += 1

		if frame == 10:
			var spawner = get_tree().root.get_node_or_null("MainGame/EnemySpawner")
			if spawner:
				print("Spawning test combatants...")
				enemy1 = spawner.spawn_enemy_type("flak_tank", Vector3(-9.0, 1.0, -14.0))
				enemy2 = spawner.spawn_enemy_type("attack_gunship", Vector3(9.0, 14.0, -18.0))

		if frame == 16:
			# Hit gunship with machine gun (normal damage "37" flying to the top)
			if enemy2 and is_instance_valid(enemy2):
				var rec2 = enemy2.get_node_or_null("DamageReceiver")
				if rec2:
					var d2 = DamageData.new(37.0, GameConstants.WeaponType.MACHINE_GUN, null, false)
					rec2.take_damage(d2)

		if frame == 20:
			# Kill the tank with lethal rocket hit -> triggers full kill sequence: compliment + kill damage text + bounty!
			if enemy1 and is_instance_valid(enemy1):
				var rec1 = enemy1.get_node_or_null("DamageReceiver")
				if rec1:
					var d1 = DamageData.new(180.0, GameConstants.WeaponType.ROCKET, null, false)
					d1.is_crit = true
					rec1.take_damage(d1)

		if frame == 35:
			print("Capturing screenshot of floating text and compliments...")
			var img = get_viewport().get_texture().get_image()
			if img and not img.is_empty():
				var out_dir = "C:/Users/Prime 3/.gemini/antigravity/brain/7fe842b3-2e28-4d17-b446-0deca635b154"
				var out_path = out_dir + "/combat_text_compliments_demo.png"
				var err = img.save_png(out_path)
				print("Saved screenshot with code: ", err, " to ", out_path)
			else:
				print("Viewport texture image was empty or unavailable.")
			get_tree().quit(0)
