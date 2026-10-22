extends SceneTree

const UrbanPathfinder = preload("res://src/world/urban_pathfinder.gd")

func _init() -> void:
	print("--- TESTING URBAN PATHFINDER ROAD NETWORK ---")
	var p1 = Vector3(76.0, 0.5, 76.0)
	var p2 = Vector3(0.0, 0.5, 0.0)
	var path = UrbanPathfinder.find_street_path(p1, p2)
	print("Path from %s to %s has %d waypoints:" % [str(p1), str(p2), path.size()])
	for i in range(path.size()):
		print("  WP[%d]: %s" % [i, str(path[i])])

	if path.size() >= 3 and path[path.size() - 1].distance_to(p2) < 2.0:
		print("[PASS] UrbanPathfinder generated valid street path to destination!")
		quit(0)
	else:
		print("[FAIL] UrbanPathfinder path invalid or incomplete.")
		quit(1)
