extends SceneTree

func _init() -> void:
	print("--- Testing Gatling Heavy Unit & Visuals Rig ---")
	var runner = GatlingTestRunner.new()
	root.add_child(runner)

class GatlingTestRunner extends Node:
	func _ready() -> void:
		var spawner = preload("res://src/enemies/enemy_spawner.gd").new()
		add_child(spawner)
		
		var enemy = spawner._create_enemy_node("gatling_heavy")
		add_child(enemy)
		
		var visuals = enemy.get_node_or_null("Visuals")
		assert(visuals != null, "Visuals node must be present")
		
		var turret = enemy.get_node_or_null("Turret")
		assert(turret != null, "Turret node must be present")
		
		var mount = turret.get_node_or_null("GunMount")
		assert(mount != null, "GunMount node must be present")
		
		var barrels = mount.get_node_or_null("RotaryBarrels")
		assert(barrels != null, "RotaryBarrels node must be present")
		
		var barrel_count = 0
		for child in barrels.get_children():
			if child.name.begins_with("GatlingBarrel_"):
				barrel_count += 1
		assert(barrel_count == 6, "Must have exactly 6 faceted barrels, got %d" % barrel_count)
		
		print("[PASS] Visual hierarchy verified: Visuals + Turret + GunMount + RotaryBarrels with 6 barrels.")
		
		# Test barrel spin in WINDUP state
		enemy.set_behavior_state(BaseEnemy.BehaviorState.WINDUP)
		var rot_start = barrels.rotation.z
		enemy._custom_process(0.1) # 100ms
		assert(enemy.current_barrel_spin_speed > 0.0, "Barrel spin speed should ramp up during windup")
		assert(barrels.rotation.z != rot_start, "RotaryBarrels should rotate during windup")
		print("[PASS] Windup barrel spin animation operational: speed = %.2f rad/s" % enemy.current_barrel_spin_speed)
		
		print("ALL GATLING HEAVY RIG TESTS PASSED!")
		get_tree().quit(0)
