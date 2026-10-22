@tool
extends SceneTree

func _init() -> void:
	print("--- TESTING SCOUT BUGGY ELITE SCALING ---")
	var normal_body_pos = Vector3(0, 1.18, 0)
	var body_roof_rel = Vector3(0, 0.146 * 4.0, 0.130 * 4.0)
	var normal_turret_pos = normal_body_pos + body_roof_rel
	print("Normal turret pos:", normal_turret_pos)
	
	# Apply 1.2x scaling (as done in BaseEnemy._apply_modifiers)
	var elite_visuals_scale = 1.2
	var elite_body_world_roof = (normal_body_pos * elite_visuals_scale) + (body_roof_rel * elite_visuals_scale)
	
	var elite_turret_pos = normal_turret_pos * 1.2
	print("Elite body roof world pos:", elite_body_world_roof)
	print("Elite turret pos:", elite_turret_pos)
	print("Difference:", elite_body_world_roof.distance_to(elite_turret_pos))
	
	if elite_body_world_roof.distance_to(elite_turret_pos) < 0.001:
		print("[PASS] Elite turret and body remain 100% perfectly aligned!")
	else:
		print("[FAIL] Mismatch detected!")
	quit()
