extends CharacterBody3D

signal objective_destroyed
var site_kind: String = "evac"
var caption: String = "LANDING ZONE"
var marker_color := Color("66dbc8")
var marker_active := true
var indicator: Node3D
var progress_mesh: MeshInstance3D
var dish: Node3D
var caption_label: Label3D
var beacon: Node3D
var beacon_core: MeshInstance3D
var progress := 0.0
var payload: Node3D
var material_cache: Dictionary = {}
var box_cache: Dictionary = {}

func configure(kind: String, text: String, color: Color, destructible: bool = false, friendly: bool = false) -> void:
	site_kind = kind
	caption = text
	marker_color = color
	collision_layer = 4 if destructible else 0
	collision_mask = 6 if kind == "convoy" else 0
	add_to_group("mission_objectives")
	add_to_group("mission_targets")
	if destructible:
		if not friendly: add_to_group("hostile_mission_targets")
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(5, 3, 6)
		collision.shape = shape
		collision.position.y = 1.5
		add_child(collision)
		var receiver = preload("res://src/missions/objective_receiver.gd").new()
		receiver.name = "DamageReceiver"
		receiver.friendly = friendly
		receiver.max_health = 180.0 if friendly else 110.0
		receiver.current_health = receiver.max_health
		receiver.destroyed.connect(func(_data): objective_destroyed.emit())
		add_child(receiver)
	_build()

func material(color: Color, luminous: bool = false) -> StandardMaterial3D:
	var key := str(color) + str(luminous)
	if material_cache.has(key): return material_cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	if luminous:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_cache[key] = mat
	return mat

func box(parent: Node3D, dimensions: Vector3, location: Vector3, color: Color) -> MeshInstance3D:
	if not box_cache.has(dimensions):
		var shape := BoxMesh.new()
		shape.size = dimensions
		box_cache[dimensions] = shape
	var mesh: BoxMesh = box_cache[dimensions]
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material(color)
	instance.position = location
	parent.add_child(instance)
	return instance

func _build() -> void:
	var charcoal := Color("293c3d")
	var sand := Color("a99d71")
	payload = Node3D.new()
	add_child(payload)
	if site_kind == "radar" or site_kind == "sam":
		box(self, Vector3(5, 1.6, 5), Vector3(0, 0.8, 0), charcoal)
		box(self, Vector3(4, 0.3, 4), Vector3(0, 1.75, 0), sand)
		dish = Node3D.new()
		dish.position.y = 2
		add_child(dish)
		if site_kind == "radar":
			box(dish, Vector3(0.25, 3, 0.25), Vector3(0, 1.5, 0), sand)
			var aerial = box(dish, Vector3(4, 1.7, 0.22), Vector3(0, 3, 0), marker_color)
			aerial.rotation.x = -0.3
		else:
			for x in [-1.2, 0.0, 1.2]:
				var tube = box(dish, Vector3(0.65, 0.65, 3), Vector3(x, 0.7, 0), sand)
				tube.rotation.x = -0.6
	elif site_kind == "convoy":
		box(self, Vector3(2.8, 1.5, 5), Vector3(0, 1.1, 0), sand)
		box(self, Vector3(2.5, 1.6, 2.8), Vector3(0, 2.4, 0.7), Color("e2ddba"))
		for side in [-1.0, 1.0]:
			box(self, Vector3(0.05, 0.25, 1), Vector3(side * 1.27, 2.5, 0.7), Color("b64a40"))
			box(self, Vector3(0.05, 1, 0.25), Vector3(side * 1.28, 2.5, 0.7), Color("b64a40"))
		box(self, Vector3(2.5, 0.5, 0.2), Vector3(0, 2, -2.5), Color("425f6c"))
		# Reuse the same wheel mesh/material as the combat vehicles.
		var wheel_resource = load("res://assets/Enemy/tank_game_ready/universal_wheel_mesh.res")
		if wheel_resource is Mesh:
			var controller = preload("res://src/enemies/ground/multi_axle_wheel_controller.gd").new()
			controller.name = "ConvoyWheels"
			controller.wheel_radius = 0.64
			for x in [-1.5, 1.5]:
				for z in [-1.7, 1.7]:
					var mount := Node3D.new()
					mount.name = ("FrontSteer" if z < 0 else "RearMount") + str(controller.get_child_count())
					mount.position = Vector3(x, 0.7, z)
					controller.add_child(mount)
					var spin := Node3D.new()
					spin.name = "WheelSpin"
					mount.add_child(spin)
					var wheel := MeshInstance3D.new()
					wheel.mesh = wheel_resource
					wheel.scale = Vector3.ONE * 1.2
					wheel.rotation.y = PI * 0.5 if x < 0 else -PI * 0.5
					spin.add_child(wheel)
			add_child(controller)
	elif site_kind != "marker":
		# Real pad geometry, perimeter lights and an H/medical cross; no costly lights.
		box(self, Vector3(12, 0.12, 12), Vector3(0, 0.06, 0), charcoal)
		for side in [-1.0, 1.0]:
			box(self, Vector3(0.28, 0.05, 10), Vector3(side * 5, 0.15, 0), marker_color)
			box(self, Vector3(10, 0.05, 0.28), Vector3(0, 0.15, side * 5), marker_color)
		box(self, Vector3(0.5, 0.06, 5), Vector3(-1.5, 0.18, 0), marker_color)
		box(self, Vector3(0.5, 0.06, 5), Vector3(1.5, 0.18, 0), marker_color)
		box(self, Vector3(3.5, 0.06, 0.5), Vector3(0, 0.18, 0), marker_color)
		if site_kind in ["crew", "medical", "vip"]:
			var count := 1 if site_kind == "vip" else 3
			for i in range(count):
				box(payload, Vector3(0.7, 1.3, 0.5), Vector3(-3 + i * 1.4, 0.8, 3), sand)
				box(payload, Vector3(0.55, 0.5, 0.55), Vector3(-3 + i * 1.4, 1.7, 3), Color("c69c74"))
		if site_kind in ["medical", "intel", "cargo", "crew"]:
			box(payload, Vector3(2, 0.8, 1), Vector3(3, 0.6, 2), Color("eee5c9") if site_kind == "medical" else sand)
			box(payload, Vector3(0.25, 0.9, 1.05), Vector3(3, 0.65, 2), marker_color)
		if site_kind in ["crew", "intel"]:
			var wreck = box(self, Vector3(2, 1.5, 4.5), Vector3(-3, 0.9, -2), Color("414442"))
			wreck.rotation.z = 0.35
			box(self, Vector3(6, 0.12, 0.3), Vector3(-2.5, 1.8, -2), charcoal)
			box(self, Vector3(0.2, 0.12, 5), Vector3(-2.5, 1.8, -2), charcoal)
	indicator = Node3D.new()
	add_child(indicator)
	# A segmented ring remains readable against the low-poly streets.
	for i in range(16):
		var angle := i * TAU / 16.0
		var segment = box(indicator, Vector3(1.6, 0.1, 0.26), Vector3(cos(angle) * 8, 0.24, sin(angle) * 8), marker_color)
		segment.rotation.y = -angle + PI * 0.5
	progress_mesh = box(indicator, Vector3(5, 0.14, 0.4), Vector3(0, 0.4, 7), marker_color)
	# Keep the objective legible above roofs, trees, and the helicopter silhouette.
	# The pad/target remains at its real physical position below this beacon.
	beacon = Node3D.new()
	beacon.name = "ObjectiveBeacon"
	add_child(beacon)
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(0.28, 9.0, 0.28)
	var beam := MeshInstance3D.new()
	beam.mesh = beam_mesh
	beam.position.y = 6.0
	var beam_material := StandardMaterial3D.new()
	beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_material.albedo_color = Color(marker_color.r, marker_color.g, marker_color.b, 0.62)
	beam.material_override = beam_material
	beacon.add_child(beam)
	var diamond_mesh := SphereMesh.new()
	diamond_mesh.radius = 0.9
	diamond_mesh.height = 1.8
	diamond_mesh.radial_segments = 4
	diamond_mesh.rings = 2
	beacon_core = MeshInstance3D.new()
	beacon_core.mesh = diamond_mesh
	beacon_core.position.y = 11.2
	beacon_core.material_override = material(marker_color, true)
	beacon.add_child(beacon_core)
	caption_label = Label3D.new()
	caption_label.text = caption
	caption_label.font_size = 48
	caption_label.pixel_size = 0.032
	caption_label.outline_size = 14
	caption_label.modulate = marker_color
	caption_label.position.y = 14
	caption_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	caption_label.no_depth_test = true
	add_child(caption_label)

func set_active_marker(active: bool) -> void:
	marker_active = active
	if indicator: indicator.visible = active
	if beacon: beacon.visible = active
	if caption_label: caption_label.visible = active

func set_collected() -> void:
	if payload: payload.visible = false
	if caption_label: caption_label.text = "RECOVERED"

func get_navigation_anchor() -> Vector3:
	return global_position + Vector3.UP * 11.2

func set_progress(value: float) -> void:
	progress = clampf(value, 0.0, 1.0)
	if progress_mesh: progress_mesh.scale.x = maxf(0.01, progress)

func _process(delta: float) -> void:
	if dish: dish.rotation.y += delta * 0.3
	if marker_active and beacon_core:
		var pulse := 1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.004)
		beacon_core.scale = Vector3.ONE * pulse
