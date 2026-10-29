extends CanvasLayer

var manager: Node
var title: Label
var instruction: Label
var details: Label
var progress: ProgressBar
var action: Button
var phase_label: Label
var progress_caption: Label
var refresh_timer := 0.0
var panel: PanelContainer
var column: VBoxContainer
var panel_style: StyleBoxFlat
var owned_pause_state := -1
var tactical_dialog: ConfirmationDialog

class Navigation extends Control:
	var manager: Node
	var last_point := Vector2.ZERO
	var last_offscreen := false

	func _clamp_to_play_area(point: Vector2) -> Vector2:
		var margin := 34.0
		var safe := Rect2(Vector2(margin, 78), size - Vector2(margin * 2.0, 212))
		point = point.clamp(safe.position, safe.end)
		# Reserve the bottom-left briefing and top-right radar corners.
		if point.x < 366.0 and point.y > size.y - 252.0:
			point.y = size.y - 252.0
		if point.x > size.x - 230.0 and point.y < 258.0:
			point.y = 258.0
		return point

	func _draw() -> void:
		if not is_instance_valid(manager) or not manager.is_mission_active or not is_instance_valid(manager.objective_site) or not manager.objective_site.marker_active:
			return
		var camera := get_viewport().get_camera_3d()
		if not camera: return
		var world: Vector3 = manager.objective_site.get_navigation_anchor()
		var point := camera.unproject_position(world)
		var center := size * 0.5
		var direction := point - center
		var behind := camera.is_position_behind(world)
		if behind: direction = -direction
		if direction.length_squared() < 1: direction = Vector2.DOWN
		var offscreen := behind or point != _clamp_to_play_area(point)
		if offscreen:
			var edge := center + direction.normalized() * maxf(size.x, size.y)
			point = _clamp_to_play_area(edge)
		last_point = point
		last_offscreen = offscreen
		var player = get_tree().get_first_node_in_group("player")
		var distance := int(player.global_position.distance_to(manager.objective_site.global_position)) if is_instance_valid(player) else 0
		# At close range the world beacon and its caption already identify the site.
		if not offscreen and distance < 40:
			return
		var color: Color = manager.objective_site.marker_color
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.005)
		draw_circle(point, 15, Color(0.015, 0.045, 0.055, 0.91))
		draw_arc(point, 15 + pulse * 2.0, 0, TAU, 24, color, 2.5, true)
		if offscreen:
			var forward := direction.normalized()
			var right := forward.orthogonal()
			draw_colored_polygon(PackedVector2Array([point + forward * 10, point - forward * 5 + right * 6, point - forward * 5 - right * 6]), color)
		else:
			draw_line(point + Vector2(-5, 0), point + Vector2(5, 0), color, 2)
			draw_line(point + Vector2(0, -5), point + Vector2(0, 5), color, 2)
		if is_instance_valid(player):
			var label := "%s  %dm" % [manager.objective_site.caption, distance]
			var font := get_theme_default_font()
			var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			var label_offset_y := -24.0 if point.y > size.y * 0.6 else 42.0
			var label_pos := _clamp_to_play_area(point + Vector2(-width * 0.5, label_offset_y))
			draw_rect(Rect2(label_pos - Vector2(5, 15), Vector2(width + 10, 21)), Color(0.015, 0.045, 0.055, 0.92), true)
			draw_string(font, label_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.018, 0.048, 0.055, 0.96)
	panel_style.border_color = Color("b6a06c")
	panel_style.set_border_width_all(1)
	panel_style.border_width_left = 4
	panel_style.set_corner_radius_all(5)
	panel_style.content_margin_left = 15
	panel_style.content_margin_right = 15
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", panel_style)
	root_control.add_child(panel)
	column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	panel.add_child(column)
	title = _label(column, 18, Color("f7d498"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.x = 280
	phase_label = _label(column, 12, Color("8ed5c9"))
	instruction = _label(column, 14, Color("f0efdf"))
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction.custom_minimum_size.x = 280
	details = _label(column, 13, Color("8ed5c9"))
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.custom_minimum_size.x = 280
	progress_caption = _label(column, 12, Color("c7ddd6"))
	progress = ProgressBar.new()
	progress.custom_minimum_size.y = 8
	progress.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("62d6c2")
	progress.add_theme_stylebox_override("fill", fill)
	column.add_child(progress)
	action = Button.new()
	action.focus_mode = Control.FOCUS_NONE # Flight A/RT must never activate a focused HUD button.
	action.text = "REQUEST SORTIE EXTRACTION"
	action.custom_minimum_size.y = 32
	var button_style := StyleBoxFlat.new()
	button_style.bg_color = Color("284944")
	button_style.border_color = Color("b9c9a0")
	button_style.set_border_width_all(1)
	button_style.set_content_margin_all(7)
	action.add_theme_stylebox_override("normal", button_style)
	action.pressed.connect(open_tactical_actions)
	column.add_child(action)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_echo() and event.is_action_pressed("mission_action"):
		open_tactical_actions()
		get_viewport().set_input_as_handled()

func _restore_owned_pause() -> void:
	var gm = get_node("/root/GameManager")
	var previous := owned_pause_state
	owned_pause_state = -1
	if previous >= 0 and gm.current_state == gm.RunState.PAUSED:
		gm.change_state(previous)
	get_node("/root/UIFlow").block_held_input()

func open_tactical_actions() -> void:
	if is_instance_valid(tactical_dialog):
		tactical_dialog.hide()
		return
	var gm = get_node("/root/GameManager")
	var flow = get_node("/root/UIFlow")
	if not flow.gameplay_input_allowed() or gm.current_state != gm.RunState.ACTIVE or is_instance_valid(flow.confirmation): return
	var exfil: bool = manager.is_mission_active and manager.active_mission_id == "sortie_extraction"
	var ready: bool = exfil and manager.phase == "READY"
	var allowed: bool = ready or (not exfil and get_node("/root/CombatDirector").current_wave >= 3)
	owned_pause_state = gm.current_state
	gm.change_state(gm.RunState.PAUSED)
	var message: String = manager.status_text + "\n\n" + ("Confirm to end this sortie and bank your rewards." if ready else "Confirm to request an extraction LZ. Your current task will be replaced." if allowed else "Secure the extraction LZ before confirming departure." if exfil else "Sortie extraction unlocks at wave 3. Continue the current objective.")
	flow.confirm_action("TACTICAL OPERATIONS / COMBAT PAUSED", message, func():
		_restore_owned_pause()
		if ready: manager.confirm_sortie_extraction()
		else: manager.request_sortie_extraction()
	)
	tactical_dialog = flow.confirmation
	if not is_instance_valid(tactical_dialog):
		_restore_owned_pause()
		return
	var dialog := tactical_dialog
	dialog.theme = preload("res://src/ui/menus/menu_theme.gd").create()
	var dialog_panel := StyleBoxFlat.new()
	dialog_panel.bg_color = Color("10232a")
	dialog_panel.border_color = Color("547779")
	dialog_panel.set_border_width_all(1)
	dialog_panel.set_content_margin_all(12)
	dialog.theme.set_stylebox("panel", "AcceptDialog", dialog_panel)
	dialog.set_meta("controller_tactical", true)
	dialog.set_meta("controller_open_frame", Engine.get_process_frames())
	dialog.get_ok_button().disabled = not allowed
	dialog.get_ok_button().text = "END SORTIE / EXTRACT" if ready else "REQUEST EXTRACTION"
	dialog.get_cancel_button().text = "RETURN TO FLIGHT [B]"
	dialog.add_button("CYCLE RADAR ZOOM", false, "radar")
	dialog.custom_action.connect(func(key):
		if key == "radar":
			var radar = get_tree().current_scene.find_child("TacticalRadar", true, false) if get_tree().current_scene else null
			if radar: radar.cycle_zoom()
	)
	dialog.window_input.connect(func(event: InputEvent):
		if event.is_action_pressed("mission_action") or event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
			dialog.hide()
			dialog.set_input_as_handled()
	)
	dialog.visibility_changed.connect(func():
		if not dialog.visible:
			_restore_owned_pause()
			tactical_dialog = null
	)
	dialog.get_cancel_button().grab_focus()

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
	var kind: String = str(manager.active_mission_data.get("kind", "")) if active else ""
	phase_label.text = "OBJECTIVE  /  %s" % manager.phase if active else "SECTOR PATROL"
	instruction.text = manager.status_text if active else (manager.result_text if manager.result_timer > 0 else "Next task incoming. Patrol the sector.")
	var player = get_tree().get_first_node_in_group("player")
	var distance := 0
	if active and is_instance_valid(manager.objective_site) and is_instance_valid(player):
		distance = int(player.global_position.distance_to(manager.objective_site.global_position))
	details.text = "%dm TO MARKER  •  %ds LEFT" % [distance, maxi(0, int(manager.active_mission_data.get("time_limit", 240.0) - manager.mission_timer))] if active else "MISSIONS AWARD CREDITS + PHYSICAL XP"
	if active and manager.passengers_aboard > 0: details.text += "  /  %d ABOARD" % manager.passengers_aboard
	if active and manager.active_mission_id == "clear_airspace":
		details.text += "  /  AIR %d/%d" % [manager.current_kills, int(manager.active_mission_data.get("target_kills", 10))]
	if active and manager.active_mission_id == "escort_convoy" and is_instance_valid(manager.objective_site):
		var receiver = manager.objective_site.get_node("DamageReceiver")
		details.text += "  /  TRANSPORT %d%%" % int(100.0 * receiver.current_health / receiver.max_health)
	progress.visible = active
	progress_caption.visible = active
	progress.max_value = maxf(1, manager.progress_goal)
	progress.value = manager.hold_progress
	if active:
		if kind == "escort":
			progress_caption.text = "ROUTE  %d / %d" % [int(manager.hold_progress), int(manager.progress_goal)]
		elif kind == "airspace":
			progress_caption.text = "AIRCRAFT  %d / %d" % [manager.current_kills, int(manager.progress_goal)]
		elif kind in ["hunt", "destroy"]:
			progress_caption.text = "TARGET DAMAGE  %d%%" % int(100.0 * manager.hold_progress / maxf(1.0, manager.progress_goal))
		else:
			progress_caption.text = "HOLD  %.1f / %.1f s" % [manager.hold_progress, manager.progress_goal]
	var objective_color: Color = manager.objective_site.marker_color if active and is_instance_valid(manager.objective_site) else Color("b6a06c")
	panel_style.border_color = objective_color
	phase_label.add_theme_color_override("font_color", objective_color)
	var cd = get_node("/root/CombatDirector")
	var is_exfil: bool = active and manager.active_mission_id == "sortie_extraction"
	action.visible = (is_exfil and manager.phase == "READY") or (not is_exfil and cd.current_wave >= 3)
	action.text = "CONFIRM END SORTIE / EXTRACT" if is_exfil else "ABORT TASK / REQUEST EXFIL" if active else "REQUEST SORTIE EXTRACTION"
	if get_node("/root/InputManager").controller_active: action.text += "  [VIEW]"
	panel.offset_top = -26.0 - maxf(140.0, column.get_combined_minimum_size().y + 25.0)
