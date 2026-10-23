class_name TacticalRadar
extends Control
## Camera-aligned local map with a compass, actual heading, roads and live markers.
@export var radar_radius_pixels: float = 75.0
@export var world_detection_radius: float = 160.0
var redraw_timer := 0.0
var map_right := Vector3.RIGHT
var map_forward := Vector3.FORWARD
var player: Node3D
var pixel_font: Font
var margin := 12.0

enum RadarZoomMode { AUTO_SPEED, CLOSE, WIDE }
var zoom_mode: RadarZoomMode = RadarZoomMode.AUTO_SPEED
var pulse_time: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2.ONE * (radar_radius_pixels + margin) * 2
	pixel_font = preload("res://src/effects/floating_text.gd").get_pixel_font()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_M:
			zoom_mode = ((zoom_mode + 1) % 3) as RadarZoomMode

func _process(delta: float) -> void:
	pulse_time += delta
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and player is CharacterBody3D:
		var target_radius := 160.0
		match zoom_mode:
			RadarZoomMode.AUTO_SPEED:
				var spd = Vector2(player.velocity.x, player.velocity.z).length()
				target_radius = lerpf(140.0, 220.0, clampf(spd / 36.0, 0.0, 1.0))
			RadarZoomMode.CLOSE:
				target_radius = 120.0
			RadarZoomMode.WIDE:
				target_radius = 260.0
		if "radar_range_multiplier" in player:
			target_radius *= player.radar_range_multiplier
		world_detection_radius = lerpf(world_detection_radius, target_radius, delta * 3.0)

	redraw_timer -= delta
	if redraw_timer > 0:
		return
	redraw_timer = 0.05
	update_orientation()
	queue_redraw()

func update_orientation() -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	var camera := get_viewport().get_camera_3d()
	if camera:
		var right := camera.global_transform.basis.x
		var forward := -camera.global_transform.basis.z
		map_right = Vector3(right.x, 0, right.z).normalized()
		map_forward = Vector3(forward.x, 0, forward.z).normalized()
		if map_forward.length_squared() < 0.1:
			map_forward = Vector3.UP.cross(map_right).normalized()
		else:
			map_right = map_forward.cross(Vector3.UP).normalized()

func map_center() -> Vector2:
	return Vector2.ONE * (radar_radius_pixels + margin)

func world_offset_to_map(offset: Vector3) -> Vector2:
	return Vector2(offset.dot(map_right), -offset.dot(map_forward)) * radar_radius_pixels / maxf(world_detection_radius, 1.0)

func project_world_position(world_position: Vector3, clamp_to_edge: bool = false) -> Vector2:
	if not is_instance_valid(player):
		return map_center()
	var offset := world_offset_to_map(world_position - player.global_position)
	if clamp_to_edge:
		offset = offset.limit_length(radar_radius_pixels - 7)
	return map_center() + offset

func is_alive(node: Node) -> bool:
	if not is_instance_valid(node) or not node is Node3D:
		return false
	var receiver := node.get_node_or_null("DamageReceiver")
	return receiver == null or not receiver.is_dead

func _draw() -> void:
	var center := map_center()
	var radius := radar_radius_pixels
	draw_circle(center + Vector2(1, 2), radius + 4, Color(0, 0, 0, 0.65))
	draw_circle(center, radius + 2, Color("a28b6b"))
	draw_circle(center, radius, Color(0.02, 0.085, 0.10, 0.93))
	draw_arc(center, radius - 1, 0, TAU, 64, Color("304d52"), 2)
	if not is_instance_valid(player):
		return
	_draw_roads()
	_draw_perimeter()
	for node in get_tree().get_nodes_in_group("pickups"):
		if is_instance_valid(node) and not node.is_collected:
			var offset := world_offset_to_map(node.global_position - player.global_position)
			if offset.length() < radius - 5:
				var color := Color("ffc94f") if node.pickup_type == Pickup.PickupType.COIN else Color("6dcbd4")
				draw_rect(Rect2(center + offset - Vector2.ONE * 1.5, Vector2.ONE * 3), color)
	for node in get_tree().get_nodes_in_group("enemies"):
		if not is_alive(node):
			continue
		var offset := world_offset_to_map(node.global_position - player.global_position)
		if offset.length() > radius - 6:
			continue
		var position_value := center + offset
		if node.is_in_group("bosses"):
			draw_colored_polygon(PackedVector2Array([position_value + Vector2(0, -5), position_value + Vector2(5, 0), position_value + Vector2(0, 5), position_value + Vector2(-5, 0)]), Color("dc8cfa"))
		else:
			var family := "air"
			if "variant_id" in node:
				family = EnemyData.VARIANTS.get(node.variant_id, {}).get("family", "air")
			if family == "ground":
				draw_rect(Rect2(position_value - Vector2.ONE * 2.5, Vector2.ONE * 5), Color("ff5654"))
			else:
				draw_colored_polygon(PackedVector2Array([position_value + Vector2(0, -3), position_value + Vector2(3, 3), position_value + Vector2(-3, 3)]), Color("f4b852"))
	for node in get_tree().get_nodes_in_group("installations"):
		if is_alive(node):
			var offset := world_offset_to_map(node.global_position - player.global_position)
			if offset.length() < radius - 6:
				var pos_val := center + offset
				if node.is_in_group("sam_sites"):
					var is_locked: bool = ("current_state" in node and (node.current_state == 2 or node.current_state == 3))
					var sam_color := Color("ff3322") if is_locked else Color("ff7733")
					var pulse := 0.5 + 0.5 * sin(pulse_time * (12.0 if is_locked else 4.5))
					var d_size: float = 4.5 + (1.5 * pulse if is_locked else 0.0)
					var diamond := PackedVector2Array([
						pos_val + Vector2(0, -d_size),
						pos_val + Vector2(d_size, 0),
						pos_val + Vector2(0, d_size),
						pos_val + Vector2(-d_size, 0)
					])
					draw_colored_polygon(diamond, sam_color)
					draw_arc(pos_val, d_size + 2.5, 0, TAU, 16, Color(sam_color.r, sam_color.g, sam_color.b, 0.65), 1.2)
				else:
					draw_rect(Rect2(pos_val - Vector2.ONE * 3, Vector2.ONE * 6), Color("ec914e"), false, 2)
	for objective in get_tree().get_nodes_in_group("mission_objectives"):
		if not is_instance_valid(objective) or not objective.marker_active: continue
		var point := project_world_position(objective.global_position, true)
		var color: Color = objective.marker_color
		draw_colored_polygon(PackedVector2Array([point + Vector2(0, -5), point + Vector2(5, 0), point + Vector2(0, 5), point + Vector2(-5, 0)]), color)
		draw_arc(point, 7, 0, TAU, 16, color, 1.5)
	_draw_cargo_marker()
	_draw_compass()
	var heading := world_offset_to_map(-player.global_transform.basis.z).normalized()
	var angle := heading.angle() + PI * 0.5
	var arrow := PackedVector2Array()
	for point in [Vector2(0, -7), Vector2(4, 5), Vector2(0, 2), Vector2(-4, 5)]:
		arrow.append(center + point.rotated(angle))
	draw_colored_polygon(arrow, Color("58caff"))

func _draw_compass() -> void:
	var cardinals := {"N": Vector3.FORWARD, "E": Vector3.RIGHT, "S": Vector3.BACK, "W": Vector3.LEFT}
	for text_value in cardinals:
		var direction := world_offset_to_map(cardinals[text_value]).normalized()
		var location := map_center() + direction * (radar_radius_pixels + 9) + Vector2(-5, 4)
		draw_string(pixel_font, location + Vector2(1, 1), text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.BLACK)
		draw_string(pixel_font, location, text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("e4ded0"))

func _draw_roads() -> void:
	var scene := get_tree().current_scene
	var city := scene.get_node_or_null("CityGenerator") if scene else null
	if not city:
		return
	var spacing: float = city.block_size
	var half_width: float = city.grid_width * spacing * 0.5
	var half_depth: float = city.grid_depth * spacing * 0.5
	var position_value := player.global_position
	var range_value := world_detection_radius
	for index in range(floori((position_value.x - range_value) / spacing), ceili((position_value.x + range_value) / spacing) + 1):
		var x := index * spacing
		if absf(x) <= half_width:
			map_line(Vector3(x, 0, -half_depth), Vector3(x, 0, half_depth), Color(0.16, 0.28, 0.29, 0.45), 3 if index == 0 else 2)
	for index in range(floori((position_value.z - range_value) / spacing), ceili((position_value.z + range_value) / spacing) + 1):
		var z := index * spacing
		if absf(z) <= half_depth:
			map_line(Vector3(-half_width, 0, z), Vector3(half_width, 0, z), Color(0.16, 0.28, 0.29, 0.45), 3 if index == 0 else 2)

func _draw_perimeter() -> void:
	var limit := GameConstants.BOUNDARY_HARD_RADIUS
	for sign_value in [-1.0, 1.0]:
		map_line(Vector3(sign_value * limit, 0, -limit), Vector3(sign_value * limit, 0, limit), Color("bc7e53"), 2)
		map_line(Vector3(-limit, 0, sign_value * limit), Vector3(limit, 0, sign_value * limit), Color("bc7e53"), 2)

func map_line(world_a: Vector3, world_b: Vector3, color: Color, width_value: float) -> void:
	var a := world_offset_to_map(world_a - player.global_position)
	var b := world_offset_to_map(world_b - player.global_position)
	var points := clip_line_to_circle(a, b, radar_radius_pixels - 3)
	if not points.is_empty():
		draw_line(map_center() + points[0], map_center() + points[1], color, width_value)

static func clip_line_to_circle(a: Vector2, b: Vector2, radius: float) -> PackedVector2Array:
	var direction := b - a
	var length_squared := direction.length_squared()
	if length_squared < 0.001:
		return PackedVector2Array()
	var projection := 2.0 * a.dot(direction)
	var determinant := projection * projection - 4.0 * length_squared * (a.length_squared() - radius * radius)
	if determinant < 0:
		return PackedVector2Array()
	var root_value := sqrt(determinant)
	var enter := maxf(0, (-projection - root_value) / (2 * length_squared))
	var leave := minf(1, (-projection + root_value) / (2 * length_squared))
	if leave <= enter:
		return PackedVector2Array()
	return PackedVector2Array([a + direction * enter, a + direction * leave])

func _draw_cargo_marker() -> void:
	var scene := get_tree().current_scene
	var cargo := scene.get_node_or_null("CargoManager") if scene else null
	if not cargo or cargo.current_state == 0:
		return
	var is_dropoff: bool = cargo.current_state >= 4
	var destination: Vector3 = cargo.dropoff_pos if is_dropoff else cargo.pickup_pos
	var location := project_world_position(destination, true)
	var col := Color("55ff88") if is_dropoff else Color("ffd700")
	var pulse := fmod(pulse_time * 2.0, 1.0)

	# Pulsing radar beacon expansion wave
	draw_arc(location, 4.0 + pulse * 6.5, 0, TAU, 16, Color(col.r, col.g, col.b, 1.0 - pulse), 1.5)
	# Tactical beacon diamond icon
	var icon := PackedVector2Array([
		location + Vector2(0, -4.5),
		location + Vector2(4.5, 0),
		location + Vector2(0, 4.5),
		location + Vector2(-4.5, 0)
	])
	draw_colored_polygon(icon, col)
	# Crosshair pip
	draw_line(location + Vector2(-2.5, 0), location + Vector2(2.5, 0), Color.BLACK, 1.5)
	draw_line(location + Vector2(0, -2.5), location + Vector2(0, 2.5), Color.BLACK, 1.5)
