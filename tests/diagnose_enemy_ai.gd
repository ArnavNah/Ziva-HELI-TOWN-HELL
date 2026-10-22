extends SceneTree

func _init() -> void:
	print("--- DIAGNOSING ENEMY AI IN MAIN GAME ---")
	var scene = load("res://scenes/main_game.tscn").instantiate()
	root.add_child(scene)

	var diag = DiagRunner.new()
	diag.scene = scene
	root.add_child(diag)

class DiagRunner extends Node:
	var frame = 0
	var scene: Node
	var initial_hp = -1.0
	var damage_taken = false
	var total_enemy_shots = 0

	func _process(delta: float) -> void:
		frame += 1

		var player = get_tree().get_first_node_in_group("player")
		if player and initial_hp < 0.0:
			initial_hp = player.current_hull

		if player and initial_hp > 0.0 and player.current_hull < initial_hp:
			damage_taken = true

		var projs = get_tree().get_nodes_in_group("enemy_projectiles")
		if projs.size() > total_enemy_shots:
			total_enemy_shots = projs.size()

		if frame >= 180 and frame % 60 == 0:
			var p_hp = player.current_hull if player else -1.0
			var enemies = get_tree().get_nodes_in_group("enemies")
			var moving_enemies = 0
			for e in enemies:
				if is_instance_valid(e) and "velocity" in e and (e.velocity as Vector3).length() > 0.5:
					moving_enemies += 1
			print("[Frame %d] Player HP: %.1f/%s | Active Enemies: %d (Moving: %d) | Total Projectiles Spawned: %d | Damage Taken: %s" % [
				frame, p_hp, str(initial_hp), enemies.size(), moving_enemies, total_enemy_shots, str(damage_taken)
			])

		if frame == 650:
			print("\n--- DIAGNOSTIC RESULTS ---")
			print("Damage Taken By Player: ", damage_taken)
			print("Total Projectiles Recorded: ", total_enemy_shots)
			if damage_taken or total_enemy_shots > 0:
				print("AI COMBAT ENGAGEMENT VERIFIED!")
			else:
				print("WARNING: No shots recorded yet.")
			get_tree().quit(0)
