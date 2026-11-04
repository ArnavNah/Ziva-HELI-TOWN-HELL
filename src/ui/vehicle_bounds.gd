extends RefCounted
## Cached source nodes, live transforms: animation and elite scaling stay current.
static func local_bounds(actor: Node3D, include_rotors: bool = false) -> AABB:
	var key := "_vehicle_bounds_sources_" + str(include_rotors)
	var now := Time.get_ticks_msec()
	var cache: Dictionary = actor.get_meta(key, {})
	if cache.is_empty() or now - int(cache.time) > 250:
		var sources: Array = []
		var visuals := actor.get_node_or_null("Visuals")
		if visuals:
			for mesh in visuals.find_children("*", "MeshInstance3D", true, false):
				var path := str(visuals.get_path_to(mesh)).to_lower()
				if "blur" in path or "cue" in path or "telegraph" in path: continue
				if not include_rotors and "rotor" in path: continue
				sources.append(weakref(mesh))
		if sources.is_empty():
			for col in actor.find_children("*", "CollisionShape3D", true, false):
				# Sensor/weak-point areas are not the vehicle's physical silhouette.
				if col.get_parent() == actor or col.get_parent() is StaticBody3D:
					sources.append(weakref(col))
		cache = {"time": now, "sources": sources}
		actor.set_meta(key, cache)
	var box := AABB()
	var found := false
	var inverse := actor.global_transform.affine_inverse()
	for source in cache.sources:
		var node: Node3D = source.get_ref()
		if not is_instance_valid(node): continue
		var shape_box := AABB()
		if node is MeshInstance3D:
			if not node.is_visible_in_tree() or not node.mesh: continue
			shape_box = node.get_aabb()
		elif node is CollisionShape3D:
			if node.disabled or not node.shape: continue
			var shape: Shape3D = node.shape
			if shape is BoxShape3D:
				shape_box = AABB(-shape.size * 0.5, shape.size)
			elif shape is SphereShape3D:
				shape_box = AABB(Vector3.ONE * -shape.radius, Vector3.ONE * shape.radius * 2)
			elif shape is CylinderShape3D or shape is CapsuleShape3D:
				var dimensions := Vector3(shape.radius * 2, shape.height, shape.radius * 2)
				shape_box = AABB(-dimensions * 0.5, dimensions)
			else: continue
		var transform: Transform3D = inverse * node.global_transform
		for corner in 8:
			var point: Vector3 = transform * shape_box.get_endpoint(corner)
			if not found:
				box = AABB(point, Vector3.ZERO)
				found = true
			else: box = box.expand(point)
	return box if found else AABB(Vector3(-2,-1,-2.5), Vector3(4,2,5))

static func screen_envelope(camera: Camera3D, actor: Node3D, fallback: Vector2) -> Rect2:
	var box := local_bounds(actor)
	var points: Array[Vector3] = []
	for i in 8: points.append(camera.to_local(actor.to_global(box.get_endpoint(i))))
	var clipped: Array[Vector3] = []
	var near_z := -maxf(camera.near, 0.01) - 0.001
	for point in points:
		if point.z <= near_z: clipped.append(point)
	# Clip all twelve box edges against the camera's near plane.
	for i in 8:
		for bit in [1,2,4]:
			var j: int = i ^ bit
			if j <= i: continue
			var a: Vector3 = points[i]
			var b: Vector3 = points[j]
			if (a.z <= near_z) != (b.z <= near_z):
				clipped.append(a.lerp(b, (near_z-a.z)/(b.z-a.z)))
	var viewport := camera.get_viewport().get_visible_rect().grow(-6)
	if clipped.is_empty(): return Rect2(fallback.clamp(viewport.position, viewport.end), Vector2.ZERO)
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for point in clipped:
		var screen := camera.unproject_position(camera.to_global(point)).clamp(viewport.position, viewport.end)
		min_p = min_p.min(screen)
		max_p = max_p.max(screen)
	var center := (min_p+max_p)*0.5
	var dimensions := (max_p-min_p+Vector2(8,8)).clamp(Vector2(36,32), viewport.size * 0.55)
	var origin := (center-dimensions*0.5).clamp(viewport.position, viewport.end-dimensions)
	return Rect2(origin, dimensions)
