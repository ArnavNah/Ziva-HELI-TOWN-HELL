extends SceneTree

const Roads = preload("res://src/world/urban_pathfinder.gd")
const Receiver = preload("res://src/combat/damage_receiver.gd")
var checks := 0
var failed := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", message)
	if not ok:
		failed += 1

func run() -> void:
	Roads._ensure_initialized()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261023
	var positions: Array[Vector3] = []
	for index in range(10000):
		positions.append(Vector3(rng.randf_range(-450, 450), 0.5, rng.randf_range(-450, 450)))
	var exact := true
	for point in positions:
		var fast := Roads._nearest_point_id(point)
		var reference := Roads._astar.get_closest_point(point)
		if not Roads._astar.has_point(fast):
			exact = false
			break
		var fast_distance: float = point.distance_squared_to(Roads._astar.get_point_position(fast))
		var reference_distance: float = point.distance_squared_to(Roads._astar.get_point_position(reference))
		if absf(fast_distance - reference_distance) > 0.01:
			exact = false
			print("NEAREST_MISMATCH ", point, " ", fast_distance, " ", reference_distance)
			break
	check(exact, "10000 analytic road lookups match full graph search, including map edges")
	var begin := Time.get_ticks_usec()
	for point in positions:
		Roads._astar.get_closest_point(point)
	var reference_usec := Time.get_ticks_usec() - begin
	begin = Time.get_ticks_usec()
	for point in positions:
		Roads._nearest_point_id(point)
	var fast_usec := Time.get_ticks_usec() - begin
	print("ROAD_LOOKUP_BENCHMARK reference_usec=", reference_usec, " optimized_usec=", fast_usec)
	check(fast_usec < reference_usec, "analytic lookup reduces measured road lookup cost")
	var start := Vector3(-110, 0, -110)
	var end := Vector3(110, 0, 110)
	var path: PackedVector3Array = Roads.find_street_path(start, end)
	var expected: PackedVector3Array = path.duplicate()
	path.clear()
	check(Roads.find_street_path(start, end) == expected, "one vehicle cannot clear another vehicle's cached route")
	for index in range(180):
		Roads.find_street_path(positions[index], positions[index + 200])
	check(Roads._route_cache.size() <= 128 and Roads._route_keys.size() <= 128, "route cache remains bounded")
	var shared := StandardMaterial3D.new()
	var mesh := BoxMesh.new()
	mesh.material = shared
	var unit := Node3D.new()
	var actor := MeshInstance3D.new()
	actor.mesh = mesh
	unit.add_child(actor)
	var decoration := MeshInstance3D.new()
	decoration.mesh = mesh
	root.add_child(unit)
	root.add_child(decoration)
	root.get_node("ShaderManager").apply_selective_outline(unit)
	check(actor.material_overlay != null, "selected unit keeps its outline overlay")
	check(shared.next_pass == null and decoration.material_overlay == null, "outlining a unit never adds a draw pass to unrelated shared world material")
	check(actor.mesh == decoration.mesh and actor.mesh.material == shared, "outlines preserve shared mesh and base material identities")
	var captured: Dictionary = {}
	var listener: Callable = func(entity: Node, _weapon: String, score: int, xp: int) -> void:
		captured[entity.get_instance_id()] = {"score": score, "xp": xp}
	var bus: Node = root.get_node("EventBus")
	bus.entity_destroyed.connect(listener)
	for score_value in [140, 210]:
		var enemy := BaseEnemy.new()
		var receiver := Receiver.new()
		receiver.name = "DamageReceiver"
		enemy.add_child(receiver)
		root.add_child(enemy)
		enemy.set_physics_process(false)
		enemy.score_value = score_value
		var identity := enemy.get_instance_id()
		receiver.take_damage(DamageData.new(100000))
		check(captured.has(identity) and captured[identity].score == score_value and captured[identity].xp == 0, "enemy settlement uses configured %d points and zero direct XP" % score_value)
	bus.entity_destroyed.disconnect(listener)
	unit.free()
	decoration.free()
	await process_frame
	print("RUNTIME_BUDGET_FIXES ", checks - failed, "/", checks)
	await load("res://tests/runtime_cleanup.gd").finish(self, 0 if failed == 0 else 1)
