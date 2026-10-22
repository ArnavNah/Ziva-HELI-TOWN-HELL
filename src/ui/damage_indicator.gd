extends Control
## Short-lived incoming-hit markers; one lightweight canvas draw, no spawned particles.
const HIT_LIFETIME := 1.25
const MAX_MARKERS := 6
const MERGE_DOT := 0.90
const PIXEL_FONT = preload("res://src/effects/floating_text.gd")

var player: Node3D
var hits: Array[Dictionary] = []
var threat_warnings: Array[Dictionary] = []

func _ready() -> void:
	name = "DamageIndicator"
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_process(false)
	var bus := get_node_or_null("/root/EventBus")
	if bus:
		bus.player_hit.connect(_on_player_hit)
		bus.run_state_changed.connect(_on_run_state_changed)
		if bus.has_signal("threat_warning"):
			bus.threat_warning.connect(_on_threat_warning)

func _combat_is_visible() -> bool:
	if get_tree().paused:
		return false
	var gm := get_node_or_null("/root/GameManager")
	return gm == null or gm.current_state in [gm.RunState.ACTIVE, gm.RunState.EXTRACTION, gm.RunState.TUTORIAL]

func _on_run_state_changed(_new_state: int, _old_state: int) -> void:
	if not _combat_is_visible():
		clear_indicators()

func _find_player() -> bool:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node3D
	return is_instance_valid(player)

func _camera() -> Camera3D:
	return get_viewport().get_camera_3d()

func screen_direction(origin: Vector3) -> Vector2:
	var camera := _camera()
	if not camera or not is_instance_valid(player):
		return Vector2.ZERO
	if not camera.is_position_behind(origin):
		var projected := camera.unproject_position(origin) - camera.unproject_position(player.global_position)
		if projected.is_finite() and not projected.is_zero_approx():
			return projected.normalized()
	# Sources behind the camera need a basis projection to avoid a flipped arrow.
	var offset := origin - player.global_position
	var basis := camera.global_basis.orthonormalized()
	return Vector2(offset.dot(basis.x), -offset.dot(basis.y)).normalized()

func _on_player_hit(amount: float, origin: Vector3, has_direction: bool, source_label: String) -> void:
	if amount <= 0.0 or not _combat_is_visible() or not _find_player():
		return
	var direction := screen_direction(origin) if has_direction else Vector2.ZERO
	var directional := has_direction and not direction.is_zero_approx()
	for hit in hits:
		var same_sector: bool = hit.directional == directional
		if directional and same_sector:
			same_sector = screen_direction(hit.origin).dot(direction) >= MERGE_DOT
		if same_sector:
			hit.amount += amount
			hit.origin = origin
			hit.age = 0.0
			hit.source_label = source_label
			visible = true
			set_process(true)
			queue_redraw()
			return
	if hits.size() >= MAX_MARKERS:
		hits.pop_front()
	hits.append({"amount": amount, "origin": origin, "directional": directional, "age": 0.0, "source_label": source_label})
	visible = true
	set_process(true)
	queue_redraw()

func _on_threat_warning(origin: Vector3, threat_type: String, duration: float) -> void:
	if not _combat_is_visible() or not _find_player():
		return
	var dir := screen_direction(origin)
	if dir.is_zero_approx():
		return
	for tw in threat_warnings:
		if tw.direction.dot(dir) >= MERGE_DOT:
			tw.timer = maxf(tw.timer, duration)
			tw.origin = origin
			tw.threat_type = threat_type
			visible = true
			set_process(true)
			queue_redraw()
			return
	if threat_warnings.size() >= 4:
		threat_warnings.pop_front()
	threat_warnings.append({
		"origin": origin,
		"direction": dir,
		"threat_type": threat_type,
		"duration": duration,
		"timer": duration
	})
	visible = true
	set_process(true)
	queue_redraw()

func clear_indicators() -> void:
	hits.clear()
	threat_warnings.clear()
	visible = false
	set_process(false)
	queue_redraw()

func _process(delta: float) -> void:
	if not _combat_is_visible() or not _find_player():
		clear_indicators()
		return
	for i in range(hits.size() - 1, -1, -1):
		hits[i].age += delta
		if hits[i].age >= HIT_LIFETIME:
			hits.remove_at(i)
	for j in range(threat_warnings.size() - 1, -1, -1):
		threat_warnings[j].timer -= delta
		if threat_warnings[j].timer <= 0.0:
			threat_warnings.remove_at(j)
	if hits.is_empty() and threat_warnings.is_empty():
		clear_indicators()
	else:
		queue_redraw()

func _draw() -> void:
	if not _find_player():
		return
	var camera := _camera()
	if not camera or camera.is_position_behind(player.global_position):
		return
	var viewport_size := get_viewport_rect().size
	var center := camera.unproject_position(player.global_position)
	# Keep the ring readable on small windows without covering the helicopter.
	var ui_scale := clampf(minf(viewport_size.x / 1280.0, viewport_size.y / 720.0), 0.75, 1.5)
	var radius := 78.0 * ui_scale
	var reduced := false
	var audio := get_node_or_null("/root/AudioManager")
	if audio:
		reduced = audio.reduce_flashes
	for hit in hits:
		# Hold briefly, then fade once. No repeating flashes or full-screen overlay.
		var opacity := 1.0 - smoothstep(0.35, HIT_LIFETIME, float(hit.age))
		var color := Color("ff765d")
		if reduced:
			color = Color("e9ad86")
			opacity *= 0.72
		color.a = opacity
		var dark := Color(0.10, 0.045, 0.055, opacity * 0.95)
		var text_pos := center + Vector2(0, radius + 24.0 * ui_scale)
		if hit.directional:
			var direction := screen_direction(hit.origin)
			if direction.is_zero_approx():
				continue
			var angle := direction.angle()
			draw_arc(center, radius, angle - 0.30, angle + 0.30, 9, dark, 9.0 * ui_scale)
			draw_arc(center, radius, angle - 0.28, angle + 0.28, 9, color, 5.0 * ui_scale)
			var tip := center + direction * (radius - 12.0 * ui_scale)
			var tangent := direction.orthogonal() * 6.0 * ui_scale
			var foot := tip + direction * 8.0 * ui_scale
			draw_colored_polygon(PackedVector2Array([tip, foot + tangent, foot - tangent]), color)
			text_pos = center + direction * (radius + 24.0 * ui_scale)
		else:
			# A collision or fuel tick has no attacker bearing; use four small brackets.
			for i in 4:
				var angle := float(i) * PI * 0.5 + PI * 0.25
				draw_arc(center, radius * 0.70, angle - 0.10, angle + 0.10, 3, dark, 7.0 * ui_scale)
				draw_arc(center, radius * 0.70, angle - 0.10, angle + 0.10, 3, color, 3.0 * ui_scale)
		var caption := "-%d" % maxi(1, ceili(float(hit.amount)))
		if not hit.directional:
			var reason := str(hit.source_label).to_lower()
			caption += " FUEL" if reason.contains("fuel") else (" IMPACT" if reason.contains("crash") or reason.contains("impact") else " HULL")
		var font := PIXEL_FONT.get_pixel_font()
		var font_size := roundi(12.0 * ui_scale)
		var text_size := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var text_origin := text_pos + Vector2(-text_size.x * 0.5, text_size.y * 0.25)
		draw_string_outline(font, text_origin, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, dark)
		draw_string(font, text_origin, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

	# Draw active off-screen directional threat warnings (Section 7)
	for tw in threat_warnings:
		var dir := screen_direction(tw.origin)
		if dir.is_zero_approx():
			continue
		var angle := dir.angle()
		var warn_rad := radius + 18.0 * ui_scale
		var progress: float = clampf(tw.timer / maxf(0.1, tw.duration), 0.0, 1.0)
		var warn_color := Color("ffcc00") # Amber warning
		warn_color.a = 0.5 + 0.5 * sin((1.0 - progress) * 12.0) # Pulsing alpha during windup
		var dark_warn := Color(0.15, 0.12, 0.02, warn_color.a * 0.9)
		draw_arc(center, warn_rad, angle - 0.22, angle + 0.22, 5, dark_warn, 8.0 * ui_scale)
		draw_arc(center, warn_rad, angle - 0.20, angle + 0.20, 5, warn_color, 4.0 * ui_scale)

		# Warning chevron pointing outward toward incoming threat
		var c_tip := center + dir * (warn_rad + 10.0 * ui_scale)
		var c_tang := dir.orthogonal() * 7.0 * ui_scale
		var c_foot := c_tip - dir * 8.0 * ui_scale
		draw_colored_polygon(PackedVector2Array([c_tip, c_foot + c_tang, c_foot - c_tang]), warn_color)

		var font := PIXEL_FONT.get_pixel_font()
		var f_size := roundi(11.0 * ui_scale)
		var label_text: String = "! THREAT: %.1fs" % [tw.timer]
		var l_size := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, f_size)
		var l_origin := center + dir * (warn_rad + 26.0 * ui_scale) - Vector2(l_size.x * 0.5, -l_size.y * 0.25)
		draw_string_outline(font, l_origin, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, f_size, 3, dark_warn)
		draw_string(font, l_origin, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, f_size, warn_color)

