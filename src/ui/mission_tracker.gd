extends CanvasLayer

var manager: Node
var title: Label
var instruction: Label
var details: Label
var progress: ProgressBar
var action: Button
var refresh_timer := 0.0
var panel: PanelContainer
var column: VBoxContainer

class Navigation extends Control:
	var manager: Node
	func _draw() -> void:
		if not is_instance_valid(manager) or not manager.is_mission_active or not is_instance_valid(manager.objective_site): return
		var camera := get_viewport().get_camera_3d()
		if not camera: return
		var world: Vector3 = manager.objective_site.global_position + Vector3.UP * 5
		var point := camera.unproject_position(world)
		var center := size * 0.5
		var direction := point - center
		if camera.is_position_behind(world): direction = -direction
		if direction.length_squared() < 1: direction = Vector2.DOWN
		var safe := Rect2(Vector2(42, 110), size - Vector2(84, 180))
		var offscreen := camera.is_position_behind(world) or not safe.has_point(point)
		if offscreen:
			var half := safe.size * 0.5
			var scale_factor := minf(half.x / maxf(absf(direction.x), 0.001), half.y / maxf(absf(direction.y), 0.001))
			point = safe.get_center() + direction * scale_factor
		var color: Color = manager.objective_site.marker_color
		draw_circle(point, 16, Color(0.03, 0.08, 0.1, 0.85))
		draw_arc(point, 16, 0, TAU, 24, color, 2, true)
		if offscreen:
			var forward := direction.normalized()
			var right := forward.orthogonal()
			draw_colored_polygon(PackedVector2Array([point + forward * 11, point - forward * 7 + right * 7, point - forward * 7 - right * 7]), color)
		else:
			draw_line(point + Vector2(-6, 0), point + Vector2(6, 0), color, 2)
			draw_line(point + Vector2(0, -6), point + Vector2(0, 6), color, 2)

func _ready() -> void:
	name = "MissionTracker"
	layer = 6
	var root_control := Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)
	var navigation := Navigation.new()
	navigation.name = "MissionNavigation"
	navigation.manager = manager
	navigation.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	navigation.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(navigation)
	panel = PanelContainer.new()
	panel.name = "MissionBriefing"
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 22
	panel.offset_top = -226
	panel.offset_right = 342
	panel.offset_bottom = -26
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.075, 0.08, 0.94)
	style.border_color = Color("b6a06c")
	style.set_border_width_all(1)
	style.border_width_left = 4
	style.set_corner_radius_all(5)
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 13
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	root_control.add_child(panel)
	column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	panel.add_child(column)
	title = _label(column, 18, Color("f7d498"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.x = 280
	instruction = _label(column, 14, Color("f0efdf"))
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction.custom_minimum_size.x = 280
	details = _label(column, 13, Color("8ed5c9"))
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.custom_minimum_size.x = 280
	progress = ProgressBar.new()
	progress.custom_minimum_size.y = 7
	progress.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("62d6c2")
	progress.add_theme_stylebox_override("fill", fill)
	column.add_child(progress)
	action = Button.new()
	action.text = "REQUEST SORTIE EXTRACTION"
	action.custom_minimum_size.y = 32
	var button_style := StyleBoxFlat.new()
	button_style.bg_color = Color("284944")
	button_style.border_color = Color("b9c9a0")
	button_style.set_border_width_all(1)
	button_style.set_content_margin_all(7)
	action.add_theme_stylebox_override("normal", button_style)
	action.pressed.connect(func():
		var flow = get_node_or_null("/root/UIFlow")
		if flow: flow.block_held_input()
		if manager.is_mission_active and manager.active_mission_id == "sortie_extraction": manager.confirm_sortie_extraction()
		else: manager.request_sortie_extraction()
	)
	column.add_child(action)

func _label(parent: Node, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _process(delta: float) -> void:
	refresh_timer -= delta
	if refresh_timer > 0: return
	refresh_timer = 0.1
	var gm = get_node("/root/GameManager")
	visible = gm.current_state in [gm.RunState.ACTIVE, gm.RunState.PAUSED, gm.RunState.UPGRADE_CHOICE, gm.RunState.BOSS_DECISION]
	if not visible: return
	get_child(0).get_node("MissionNavigation").queue_redraw()
	var active: bool = manager.is_mission_active
	title.text = str(manager.active_mission_data.get("title", "TACTICAL OPERATIONS")) if active else "TACTICAL OPERATIONS"
	instruction.text = manager.status_text if active else (manager.result_text if manager.result_timer > 0 else "Next task incoming. Patrol the sector.")
	var player = get_tree().get_first_node_in_group("player")
	var distance := 0
	if active and is_instance_valid(manager.objective_site) and is_instance_valid(player):
		distance = int(player.global_position.distance_to(manager.objective_site.global_position))
	details.text = "%s  /  %dm  /  %ds left" % [manager.phase, distance, maxi(0, int(manager.active_mission_data.get("time_limit", 240.0) - manager.mission_timer))] if active else "MISSIONS AWARD CREDITS + PHYSICAL XP"
	if active and manager.passengers_aboard > 0: details.text += "  /  %d ABOARD" % manager.passengers_aboard
	if active and manager.active_mission_id == "clear_airspace":
		details.text += "  /  AIR %d/%d" % [manager.current_kills, int(manager.active_mission_data.get("target_kills", 10))]
	if active and manager.active_mission_id == "escort_convoy" and is_instance_valid(manager.objective_site):
		var receiver = manager.objective_site.get_node("DamageReceiver")
		details.text += "  /  TRANSPORT %d%%" % int(100.0 * receiver.current_health / receiver.max_health)
	progress.visible = active
	progress.max_value = maxf(1, manager.progress_goal)
	progress.value = manager.hold_progress
	var cd = get_node("/root/CombatDirector")
	var is_exfil: bool = active and manager.active_mission_id == "sortie_extraction"
	action.visible = (is_exfil and manager.phase == "READY") or (not is_exfil and cd.current_wave >= 3)
	action.text = "CONFIRM END SORTIE / EXTRACT" if is_exfil else "ABORT TASK / REQUEST EXFIL" if active else "REQUEST SORTIE EXTRACTION"
	panel.offset_top = -26.0 - maxf(140.0, column.get_combined_minimum_size().y + 25.0)
