class_name DebriefScreen
extends Control
## Minimal end-of-run overlay. The paused battlefield remains visible underneath.
const LOGICAL_SIZE := Vector2(1280, 720)
const GOLD := Color("ffd275")

@onready var outcome_label: Label = get_node_or_null("VBox/OutcomeLabel")
@onready var breakdown_label: Label = get_node_or_null("VBox/BreakdownLabel")
@onready var retry_button: Button = get_node_or_null("VBox/HBox/RetryButton")
var quit_button: Button
var backdrop: ColorRect
var result_layout: Control
var save_status_label: Label
var last_summary: Dictionary = {}
var reveal_tween: Tween
var _leaving: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 50
	visible = false
	_build_ui()

func _build_ui() -> void:
	if is_instance_valid(result_layout):
		return
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	var pixel_theme := Theme.new()
	pixel_theme.default_font = preload("res://src/effects/floating_text.gd").get_pixel_font()
	pixel_theme.default_font_size = 20
	pixel_theme.set_color("font_color", "Button", Color("fff0d0"))
	pixel_theme.set_color("font_hover_color", "Button", Color.WHITE)
	pixel_theme.set_color("font_focus_color", "Button", Color.WHITE)
	pixel_theme.set_color("font_outline_color", "Button", Color("38161c"))
	pixel_theme.set_constant("outline_size", "Button", 3)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var fill := Color("812c2b")
		if state == "hover":
			fill = Color("aa3e30")
		elif state == "pressed":
			fill = Color("5d2327")
		elif state == "disabled":
			fill = Color("34242a")
		pixel_theme.set_stylebox(state, "Button", _button_style(fill, Color("b58a55")))
	var focus := _button_style(Color.TRANSPARENT, Color("fff0bd"))
	focus.shadow_size = 0
	pixel_theme.set_stylebox("focus", "Button", focus)
	theme = pixel_theme

	backdrop = ColorRect.new()
	backdrop.name = "GameplayDimmer"
	backdrop.color = Color(0.015, 0.01, 0.025, 0.66)
	backdrop.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)
	move_child(backdrop, 0)
	result_layout = Control.new()
	result_layout.name = "GameOverLayout"
	result_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(result_layout)
	if not outcome_label:
		outcome_label = Label.new()
		result_layout.add_child(outcome_label)
	else:
		outcome_label.reparent(result_layout)
	outcome_label.name = "GameOverTitle"
	outcome_label.position = Vector2(90, 180)
	outcome_label.size = Vector2(1100, 108)
	outcome_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outcome_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	outcome_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outcome_label.add_theme_font_size_override("font_size", 72)
	outcome_label.add_theme_color_override("font_color", GOLD)
	outcome_label.add_theme_color_override("font_outline_color", Color("37151a"))
	outcome_label.add_theme_constant_override("outline_size", 8)
	outcome_label.add_theme_color_override("font_shadow_color", Color("09080b"))
	outcome_label.add_theme_constant_override("shadow_offset_x", 4)
	outcome_label.add_theme_constant_override("shadow_offset_y", 6)

	var actions := HBoxContainer.new()
	actions.name = "Actions"
	actions.position = Vector2(362, 490)
	actions.add_theme_constant_override("separation", 28)
	result_layout.add_child(actions)
	if not retry_button:
		retry_button = Button.new()
		actions.add_child(retry_button)
	else:
		retry_button.reparent(actions)
	retry_button.name = "PlayAgainButton"
	retry_button.text = "PLAY AGAIN"
	retry_button.custom_minimum_size = Vector2(264, 64)
	retry_button.pressed.connect(_on_retry_pressed)
	quit_button = Button.new()
	quit_button.name = "QuitButton"
	quit_button.text = "QUIT"
	quit_button.custom_minimum_size = Vector2(264, 64)
	quit_button.add_theme_stylebox_override("normal", _button_style(Color("2e242b"), Color("9e805d")))
	quit_button.pressed.connect(_on_quit_pressed)
	actions.add_child(quit_button)
	for pair in [[retry_button, quit_button], [quit_button, retry_button]]:
		for direction in ["focus_neighbor_left", "focus_neighbor_right", "focus_neighbor_top", "focus_neighbor_bottom", "focus_next", "focus_previous"]:
			pair[0].set(direction, pair[0].get_path_to(pair[1]))
	save_status_label = Label.new()
	save_status_label.position = Vector2(190, 580)
	save_status_label.size = Vector2(900, 40)
	save_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	save_status_label.add_theme_font_size_override("font_size", 11)
	save_status_label.add_theme_color_override("font_color", Color("ffac87"))
	save_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	save_status_label.hide()
	result_layout.add_child(save_status_label)
	if not breakdown_label:
		breakdown_label = Label.new()
		add_child(breakdown_label)
	else:
		breakdown_label.reparent(self)
	breakdown_label.hide()
	var legacy := get_node_or_null("VBox")
	if legacy:
		legacy.hide()
		legacy.queue_free()
	resized.connect(_fit_layout)
	_fit_layout()

func _button_style(fill: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(3)
	style.set_corner_radius_all(3)
	style.shadow_color = Color("100d12")
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 5)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

func _fit_layout() -> void:
	if not is_instance_valid(result_layout):
		return
	var fit := minf(size.x / LOGICAL_SIZE.x, size.y / LOGICAL_SIZE.y)
	result_layout.size = LOGICAL_SIZE
	result_layout.scale = Vector2.ONE * fit
	result_layout.position = (size - LOGICAL_SIZE * fit) * 0.5

func show_debrief(summary: Dictionary) -> void:
	_build_ui()
	last_summary = summary.duplicate(true)
	_leaving = false
	retry_button.disabled = false
	quit_button.disabled = false
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var is_success: bool = summary.get("successful", false)
	outcome_label.text = "VICTORY" if is_success else "GAME OVER"
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("victory_fanfare" if is_success else "defeat_sound")
	# Telemetry & Leaderboard String Formatting
	var dist_m = summary.get("distance_flown_m", 0.0)
	var dist_str = "%.1f km" % [dist_m / 1000.0] if dist_m >= 1000.0 else "%.0f m" % [dist_m]
	var minutes: int = int(float(summary.get("survival_time", 0.0)) / 60.0)
	var seconds: int = int(summary.get("survival_time", 0.0)) % 60

	var pm = get_node_or_null("/root/ProfileManager")
	var run_score: int = summary.get("score", 0)
	var career_high: int = int(summary.get("high_score", pm.high_score if pm else run_score))
	var is_new_high: bool = summary.get("is_new_high_score", run_score > int(summary.get("previous_high_score", career_high)))

	# Keep the settled run report available for export without showing a results panel.
	var text = "========================================================\n"
	if pm and not pm.last_error.is_empty():
		text += "REWARDS NOT SAVED: " + pm.last_error + "\n"
	text += "          TACTICAL OPERATIONS DEBRIEF REPORT\n"
	text += "========================================================\n\n"
	text += "• COMBAT OPERATIONAL METRICS:\n"
	text += "  Sortie Duration: %02d:%02d  |  Wave Reached: %d\n" % [minutes, seconds, summary.get("wave_reached", 1)]
	text += "  Coins Collected: %d\n" % summary.get("coins_collected", 0)
	text += "  Waves Cleared: %d\n" % summary.get("waves_cleared", maxi(0, int(summary.get("wave_reached", 1)) - 1))
	text += "  Hostiles Neutralized: %d Total (%d Ground Wrecks, %d Air Wing)\n" % [
		summary.get("kills", 0), summary.get("ground_kills", 0), summary.get("air_kills", 0)
	]
	text += "  Flight Odometer: %s  |  Combat Rating Score: %d PTS\n" % [
		dist_str, run_score
	]
	if is_new_high:
		text += "  >>> ★ NEW ALL-TIME CAREER HIGH SCORE! ★ <<<\n\n"
	else:
		text += "  Career Best High Score: %d PTS\n\n" % [career_high]

	if pm and pm.high_scores.size() > 0:
		text += "• TOP PILOT LEADERBOARD (HALL OF FAME):\n"
		var top_list = pm.get_top_high_scores(5)
		for entry in top_list:
			var r_num = entry.get("rank", 1)
			var r_score = entry.get("score", 0)
			var r_air = entry.get("aircraft", "APACHE")
			var r_wave = entry.get("wave", 1)
			var r_kills = entry.get("kills", 0)
			var is_current = (r_score == run_score and is_new_high)
			var marker = " [THIS SORTIE]" if is_current else ""
			text += "  #%d. %d PTS - %s (Wave %d, %d Kills)%s\n" % [r_num, r_score, r_air, r_wave, r_kills, marker]
		text += "\n"

	text += "• FINANCIAL SETTLEMENT BREAKDOWN:\n"
	text += "  Banked Mission Pay:        +%d CR\n" % [summary.get("banked_credits", 0)]
	if is_success:
		text += "  At-Risk Cargo/Bounties:    +%d CR [RECOVERED]\n" % [summary.get("at_risk_recovered", 0)]
		text += "  Strategic Salvage Carried: +%d CR (Converted)\n" % [summary.get("salvage_credits", 0)]
	else:
		text += "  At-Risk Cargo/Bounties:    -%d CR [LOST IN ACTION]\n" % [summary.get("at_risk_lost", 0)]
		text += "  Strategic Salvage Carried: -%d Units [FORFEITED]\n" % [summary.get("salvage_lost", 0)]
	text += "  Guaranteed Combat Pay:     +%d CR\n" % [summary.get("combat_pay", 0)]
	text += "--------------------------------------------------------\n"
	text += "  NET TRANSFERRED TO WALLET: +%d CR\n" % [summary.get("total_payout", 0)]
	text += "========================================================"

	if breakdown_label:
		breakdown_label.text = text


	var save_failed: bool = pm != null and not pm.last_error.is_empty()
	save_status_label.text = "REWARDS COULD NOT BE SAVED" if save_failed else ""
	save_status_label.visible = save_failed
	if reveal_tween and reveal_tween.is_valid():
		reveal_tween.kill()
	modulate.a = 0.0
	reveal_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	reveal_tween.tween_property(self, "modulate:a", 1.0, 0.2)
	retry_button.grab_focus()

func _leave_results(destination: String) -> void:
	if _leaving or get_node("/root/UIFlow").busy:
		return
	_leaving = true
	retry_button.disabled = true
	quit_button.disabled = true
	get_node("/root/UIFlow").return_to_menu(destination)

func _on_retry_pressed() -> void:
	_leave_results("aircraft")

func _on_quit_pressed() -> void:
	_leave_results("")

func _on_copy_pressed() -> void:
	# Export helper retained for the run-report tools; no extra button on this overlay.
	if breakdown_label:
		DisplayServer.clipboard_set(breakdown_label.text)
