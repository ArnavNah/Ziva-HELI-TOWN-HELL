extends Control
## Reference-style live telemetry. All text uses the same font as the main menu.
const FontSource = preload("res://src/effects/floating_text.gd")
const StatIcon = preload("res://src/ui/pixel_hud_icon.gd")
var elapsed_label: Label
var coins_label: Label
var kills_label: Label
var score_label: Label
var high_score_label: Label
var high_score_toast: Label
var level_label: Label
var stage_timer: Label
var wave_subtitle: Label
var hp_label: Label
var fuel_caption: Label
var hull_bar: ProgressBar
var fuel_bar: ProgressBar
var super_bar: ProgressBar
var xp_bar: ProgressBar
var ammo_label: Label
var flare_label: Label
var mission_label: Label
var cargo_label: Label
var task_panel: Panel
var fps_label: Label

var last_known_xp: int = 0
var xp_gain_float: Label = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = "SurvivalHUD"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var pixel_theme := Theme.new()
	pixel_theme.default_font = FontSource.get_pixel_font()
	pixel_theme.default_font_size = 10
	pixel_theme.set_color("font_color", "Label", Color("f0f0e4"))
	pixel_theme.set_color("font_outline_color", "Label", Color("152228"))
	pixel_theme.set_constant("outline_size", "Label", 3)
	theme = pixel_theme
	xp_bar = bar(Vector2.ZERO, Vector2(0, 7), Color("65bfc9"))
	xp_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	xp_bar.offset_bottom = 7
	var stats := HBoxContainer.new()
	stats.position = Vector2(18, 23)
	stats.add_theme_constant_override("separation", 24)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stats)
	elapsed_label = stat(stats, "clock", "0:00", 64, Color("f0f0e4"))
	coins_label = stat(stats, "coin", "0", 48, Color("ffe276"))
	kills_label = stat(stats, "skull", "0", 48, Color("f0f0e4"))
	score_label = stat(stats, "star", "0", 72, Color("5ce6c6"))
	high_score_label = stat(stats, "trophy", "0", 72, Color("ffd24d"))
	xp_gain_float = label("", Vector2(18, 10), 10, Color("4deeea"))
	xp_gain_float.visible = false
	hull_bar = bar(Vector2(18, 60), Vector2(244, 18), Color("d92c38"))
	hp_label = label("140/140", Vector2(18, 60), 10)
	hp_label.size = Vector2(244, 18)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fuel_bar = bar(Vector2(18, 84), Vector2(244, 6), Color("3ec6a6"))
	fuel_caption = label("FUEL 100%", Vector2(18, 97), 8, Color("8fe0c3"))
	ammo_label = label("Machine Gun: 300/300", Vector2(18, 117), 10)
	flare_label = label("FLARES: 3/3", Vector2(18, 138), 10)
	super_bar = bar(Vector2(18, 162), Vector2(244, 5), Color("a188ea"))
	label("SUPER", Vector2(18, 174), 8, Color("b2a1d8"))
	stage_timer = label("0:45", Vector2.ZERO, 22)
	stage_timer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	stage_timer.offset_left = -160
	stage_timer.offset_right = 160
	stage_timer.offset_top = 23
	stage_timer.offset_bottom = 52
	stage_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_subtitle = label("WAVE 1", Vector2.ZERO, 8, Color("b6c6bc"))
	wave_subtitle.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	wave_subtitle.offset_left = -180
	wave_subtitle.offset_right = 180
	wave_subtitle.offset_top = 57
	wave_subtitle.offset_bottom = 73
	wave_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	high_score_toast = label("", Vector2.ZERO, 12, Color("ffd700"))
	high_score_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	high_score_toast.offset_left = -260
	high_score_toast.offset_right = 260
	high_score_toast.offset_top = 78
	high_score_toast.offset_bottom = 100
	high_score_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	high_score_toast.visible = false
	if has_node("/root/EventBus"):
		var eb = get_node("/root/EventBus")
		if "high_score_beaten" in eb:
			eb.high_score_beaten.connect(_on_high_score_beaten)
	level_label = label("LVL 1", Vector2.ZERO, 20)
	level_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	level_label.offset_left = -190
	level_label.offset_right = -20
	level_label.offset_top = 23
	level_label.offset_bottom = 54
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fps_label = label("60 FPS", Vector2.ZERO, 9, Color("76e5c9"))
	fps_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	fps_label.offset_left = -190
	fps_label.offset_right = -20
	fps_label.offset_top = 58
	fps_label.offset_bottom = 74
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	task_panel = Panel.new()
	task_panel.position = Vector2(18, 198)
	task_panel.size = Vector2(468, 52)
	task_panel.add_theme_stylebox_override("panel", style(Color(0.025, 0.05, 0.06, 0.78)))
	task_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(task_panel)
	mission_label = label("[ ] AIR DEFENSE PATROL", Vector2(26, 205), 10)
	cargo_label = label("CARGO", Vector2(26, 227), 9, Color("edce7d"))
	for item in [mission_label, cargo_label]:
		item.size.x = 450
		item.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

func stat(parent: HBoxContainer, icon: String, initial: String, width: float, color: Color) -> Label:
	var group := HBoxContainer.new()
	group.add_theme_constant_override("separation", 8)
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(group)
	var picture := StatIcon.new()
	picture.icon_name = icon
	group.add_child(picture)
	var value := Label.new()
	value.text = initial
	value.custom_minimum_size = Vector2(width, 22)
	value.add_theme_font_size_override("font_size", 14)
	value.add_theme_color_override("font_color", color)
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.add_child(value)
	return value

func label(text_value: String, position_value: Vector2, font_size: int, color: Color = Color("f0f0e4")) -> Label:
	var item := Label.new()
	item.text = text_value
	item.position = position_value
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	add_child(item)
	return item

func style(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	return box

func bar(position_value: Vector2, dimensions: Vector2, color: Color) -> ProgressBar:
	var item := ProgressBar.new()
	item.position = position_value
	item.size = dimensions
	item.show_percentage = false
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_theme_stylebox_override("background", style(Color("152329")))
	item.add_theme_stylebox_override("fill", style(color))
	add_child(item)
	item.size = dimensions
	return item

static func clock_text(seconds: float, countdown: bool = false) -> String:
	var whole := maxi(0, ceili(seconds) if countdown else floori(seconds))
	return "%d:%02d" % [int(whole / 60.0), whole % 60]

func refresh(manager: Node, player: Node3D) -> void:
	if manager:
		elapsed_label.text = clock_text(manager.run_time)
		coins_label.text = str(manager.coins_collected)
		kills_label.text = str(manager.kills_count)
		if score_label:
			score_label.text = str(manager.score)
		if high_score_label:
			var pm = get_node_or_null("/root/ProfileManager")
			var best: int = maxi(pm.high_score if pm else 0, manager.score)
			high_score_label.text = str(best)
			if manager.score > (pm.high_score if pm else 0) and (pm.high_score if pm else 0) > 0:
				high_score_label.add_theme_color_override("font_color", Color("ffd700"))
	var director := get_node_or_null("/root/CombatDirector")
	if director:
		if director.transition_timer > 0.0:
			stage_timer.text = clock_text(director.transition_timer, true)
			wave_subtitle.text = "WAVE %d / INCOMING" % (director.current_wave + 1)
		else:
			stage_timer.text = clock_text(director.wave_timer, true)
			wave_subtitle.text = "WAVE %d / %s" % [director.current_wave, str(director.active_theme).to_upper()]
	if is_instance_valid(player):
		hp_label.text = "%d/%d" % [maxi(0, int(player.current_hull)), int(player.max_hull)]
		fuel_caption.text = "FUEL %d%%" % int(100 * player.current_fuel / maxf(player.max_fuel, 1))
		var progression := get_node_or_null("/root/XpManager")
		if progression:
			var level: int = progression.current_level
			if progression.queued_level_ups > 0:
				level_label.text = "LVL %d [+%d]" % [level, progression.queued_level_ups]
				level_label.add_theme_color_override("font_color", Color("ffd700"))
			else:
				level_label.text = "LVL %d" % level
				level_label.remove_theme_color_override("font_color")

			# Coalesced XP feedback
			if progression.total_xp_collected > last_known_xp:
				var gain = progression.total_xp_collected - last_known_xp
				last_known_xp = progression.total_xp_collected
				if xp_gain_float and gain > 0:
					xp_gain_float.text = "+%d XP" % gain
					xp_gain_float.visible = true
					xp_gain_float.modulate.a = 1.0
					var tw = create_tween()
					tw.tween_interval(0.6)
					tw.tween_property(xp_gain_float, "modulate:a", 0.0, 0.4)
					tw.tween_callback(func(): if xp_gain_float: xp_gain_float.visible = false)
			elif progression.total_xp_collected < last_known_xp:
				last_known_xp = progression.total_xp_collected
			xp_bar.value = 100.0 * progression.get_progress_ratio()
	var scene := get_tree().current_scene
	var cargo := scene.get_node_or_null("CargoManager") if scene else null
	cargo_label.visible = cargo != null and cargo.current_state != 0
	task_panel.size.y = 52 if cargo_label.visible else 30

	if fps_label:
		if has_node("/root/GameManager") and not get_node("/root/GameManager").show_fps_telemetry:
			fps_label.visible = false
		else:
			fps_label.visible = true
			var current_fps := Engine.get_frames_per_second()
			var frame_ms := (1000.0 / maxf(float(current_fps), 1.0))
			fps_label.text = "%d FPS [%.1fms]" % [current_fps, frame_ms]
			if current_fps >= 58:
				fps_label.add_theme_color_override("font_color", Color("76e5c9"))
			elif current_fps >= 45:
				fps_label.add_theme_color_override("font_color", Color("ffd700"))
			else:
				fps_label.add_theme_color_override("font_color", Color("e76f51"))

func _on_high_score_beaten(new_s: int, _old_s: int) -> void:
	if high_score_toast:
		high_score_toast.text = "* NEW HIGH SCORE RECORD: %d PTS! *" % new_s
		high_score_toast.visible = true
		high_score_toast.modulate.a = 1.0
		var tw = create_tween()
		tw.tween_interval(3.5)
		tw.tween_property(high_score_toast, "modulate:a", 0.0, 0.8)
		tw.tween_callback(func(): high_score_toast.visible = false)
