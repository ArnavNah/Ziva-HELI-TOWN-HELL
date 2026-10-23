extends SceneTree

var checks := 0
var failed := 0

class Target extends StaticBody3D:
	var received := 0.0
	func take_damage(data: RefCounted) -> void:
		received += data.raw_damage

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", message)
	if not ok:
		failed += 1

func add_box(body: CollisionObject3D) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE
	shape.shape = box
	body.add_child(shape)
	root.add_child(body)

func run() -> void:
	root.get_node("UIFlow").busy = true
	var fx: Node = root.get_node("FXManager")
	var sleeping := 0
	for pool in [fx.muzzle_pool, fx.impact_pool, fx.patch_pool, fx.trail_pool]:
		for effect in pool:
			if not effect.is_processing():
				sleeping += 1
	check(sleeping == 128, "all 128 idle pooled effects have processing disabled")
	var muzzle: Node3D = fx.muzzle_pool[0]
	var impact: Node3D = fx.impact_pool[0]
	var patch: Node3D = fx.patch_pool[0]
	var trail: Node3D = fx.trail_pool[0]
	var profile: RefCounted = fx.get_profile("player_missile")
	var projectile := Node3D.new()
	root.add_child(projectile)
	muzzle.activate(profile, Transform3D.IDENTITY)
	impact.activate(Vector3.ZERO, Vector3.UP, Color.WHITE)
	patch.activate_at_surface(Vector3.ZERO, Vector3.UP, Color.WHITE, 1.0, 0.08)
	trail.attach_to_projectile(projectile, profile)
	for effect in [muzzle, impact, patch, trail]:
		check(effect.active and effect.is_processing() and effect.visible, "activating %s wakes its callback" % effect.get_class())
	paused = true
	var elapsed: float = muzzle.elapsed
	await create_timer(0.1, true).timeout
	check(muzzle.active and muzzle.elapsed == elapsed, "active pooled effects remain frozen during pause")
	paused = false
	await create_timer(0.25).timeout
	for effect in [muzzle, impact, patch]:
		check(not effect.active and not effect.is_processing(), "expired flash or patch returns to sleep")
	trail.detach_cleanly()
	check(trail.is_processing() and not trail.exhaust_flare.visible, "detaching trail keeps processing to finish its fade")
	# A bounded pool can reuse an actively fading slot.
	trail.attach_to_projectile(projectile, profile)
	check(trail.exhaust_flare.visible and not trail.is_detaching, "reusing a fading trail restores its exhaust flare")
	trail.detach_cleanly()
	await create_timer(0.35).timeout
	check(not trail.active and not trail.is_processing(), "finished trail fade returns to sleep")
	muzzle.activate(profile, Transform3D.IDENTITY)
	check(muzzle.is_processing(), "expired muzzle slot can wake again")
	muzzle.deactivate()
	projectile.free()

	var wall := Target.new()
	wall.collision_layer = 2
	wall.position = Vector3(0, 1, -3)
	add_box(wall)
	var hostile := Target.new()
	hostile.collision_layer = 4
	hostile.position = Vector3(4, 1, -3)
	add_box(hostile)
	var enemy := BaseEnemy.new()
	enemy.position = Vector3(0, 1, 0)
	add_box(enemy)
	enemy.set_physics_process(false)
	await physics_frame
	await process_frame
	var space: PhysicsDirectSpaceState3D = enemy.get_world_3d().direct_space_state
	var hit: Dictionary = enemy._cast_probe(space, Vector3(0, 1, 0), Vector3(0, 1, -6), 2)
	check(hit.get("collider") == wall, "reused query detects world cover")
	var identity: int = enemy._probe_query.get_instance_id()
	hit = enemy._cast_probe(space, Vector3(0, 1, 0), Vector3(0, 1, -6), 4, true)
	check(hit.is_empty(), "hostile avoidance excludes self and resets the world mask")
	hit = enemy._cast_probe(space, Vector3(4, 1, 0), Vector3(4, 1, -6), 4, true)
	check(hit.get("collider") == hostile, "hostile avoidance still detects other enemies")
	hit = enemy._cast_probe(space, wall.position, wall.position + Vector3.FORWARD, 2, true)
	check(not hit.is_empty(), "inside-aware avoidance detects an enclosing obstacle")
	hit = enemy._cast_probe(space, wall.position, wall.position + Vector3.FORWARD, 2)
	check(hit.is_empty(), "weapon LOS resets the previous inside flag")
	check(enemy._probe_query.get_instance_id() == identity, "probes retain one query resource across different ray types")
	check(not enemy.check_muzzle_line_of_sight(Vector3(0, 1, 0), Vector3(0, 1, -6)), "real weapon LOS remains blocked by cover")
	check(enemy.check_muzzle_line_of_sight(Vector3(10, 1, 0), Vector3(10, 1, -6)), "real weapon LOS accepts a clear firing lane")
	var old_times: Array[int] = []
	var reused_times: Array[int] = []
	for batch in range(5):
		var begin := Time.get_ticks_usec()
		for index in range(3000):
			var query := PhysicsRayQueryParameters3D.create(Vector3(0, 1, 0), Vector3(0, 1, -6), 2)
			query.exclude = [enemy]
			space.intersect_ray(query)
		old_times.append(Time.get_ticks_usec() - begin)
		begin = Time.get_ticks_usec()
		for index in range(3000):
			enemy._cast_probe(space, Vector3(0, 1, 0), Vector3(0, 1, -6), 2)
		reused_times.append(Time.get_ticks_usec() - begin)
	old_times.sort()
	reused_times.sort()
	print("RAY_QUERY_BENCHMARK median_3000_allocated_usec=", old_times[2], " median_3000_reused_usec=", reused_times[2])

	var bullet: Node3D = load("res://scenes/combat/projectile.tscn").instantiate()
	bullet.position = Vector3(0, 1, 0)
	bullet.velocity = Vector3(0, 0, -600)
	bullet.collision_mask = 2
	bullet.damage_data = DamageData.new(13)
	root.add_child(bullet)
	bullet.set_physics_process(false)
	check(not bullet.raycast.enabled, "projectile disables the duplicate automatic raycast")
	bullet._physics_process(1.0 / 60.0)
	check(bullet.is_queued_for_deletion() and wall.received == 13, "disabled automatic raycast still sweeps a 600 m/s bullet into cover and applies damage")
	check(bullet.get_node("MeshInstance3D").cast_shadow == 0, "tiny emissive tracer skips shadow rendering")
	var tracer: CylinderMesh = bullet.get_node("MeshInstance3D").mesh
	check(tracer.radial_segments == 8 and tracer.rings == 1, "tracer uses bounded low-poly geometry")
	var friendly := Target.new()
	friendly.collision_layer = 1
	friendly.position = Vector3(4, 1, -1)
	add_box(friendly)
	var blast := Projectile.new()
	blast.damage_data = DamageData.new(10)
	blast.blast_radius = 8
	blast.collision_mask = 6
	root.add_child(blast)
	blast.set_physics_process(false)
	await physics_frame
	await process_frame
	blast._explode(hostile.position)
	check(hostile.received == 10 and friendly.received == 0, "player splash hits hostiles without damaging the player faction")
	blast.collision_mask = 3
	blast._explode(friendly.position)
	check(friendly.received == 10 and hostile.received == 10, "enemy splash hits player faction without damaging its own cohort")
	blast.free()
	friendly.free()
	enemy.free()
	wall.free()
	hostile.free()
	await process_frame
	print("COMBAT_QUERY_BUDGET ", checks - failed, "/", checks)
	quit(0 if failed == 0 else 1)
