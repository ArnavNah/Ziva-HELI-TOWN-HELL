class_name PauseMenu
extends Control

## PauseMenu — In-game tactical pause menu with live mission telemetry, Resume, Restart, Settings, and Operations Center (Page 24).

const LoadingScreenScript = preload("res://src/ui/menus/loading_screen.gd")

@onready var panel: Panel = get_node_or_null("Panel")
@onready var resume_btn: Button = get_node_or_null("Panel/VBox/ResumeBtn")
@onready var restart_btn: Button = get_node_or_null("Panel/VBox/RestartBtn")
@onready var main_menu_btn: Button = get_node_or_null("Panel/VBox/MainMenuBtn")
@onready var settings_btn: Button = get_node_or_null("Panel/VBox/SettingsBtn")
@onready var quit_btn: Button = get_node_or_null("Panel/VBox/QuitBtn")

var telemetry_label: Label
var _listening_settings: bool = false

func _ready() -> void:
	theme = preload("res://src/ui/menus/menu_theme.gd").create()
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_enhance_ui()
	_connect_buttons()

func _connect_buttons() -> void:
	if resume_btn:
		resume_btn.pressed.connect(_on_resume_pressed)
	if restart_btn:
		restart_btn.pressed.connect(_on_restart_pressed)
	if main_menu_btn:
		main_menu_btn.pressed.connect(_on_main_menu_pressed)
	if settings_btn:
		settings_btn.pressed.connect(_on_settings_pressed)
	if quit_btn:
		quit_btn.pressed.connect(_on_quit_pressed)

func _enhance_ui() -> void:
	if not panel:
		panel = Panel.new()
		panel.name = "Panel"
		add_child(panel)
		var vb = VBoxContainer.new()
		vb.name = "VBox"
		panel.add_child(vb)
	
	# Tactical military panel sizing & style
	panel.custom_minimum_size = Vector2(500, 480)
	panel.set_anchors_preset(PRESET_CENTER)
	panel.offset_left = -250
	panel.offset_top = -240
	panel.offset_right = 250
	panel.offset_bottom = 240

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.12, 0.96)
	style.border_color = Color(0.25, 0.45, 0.52, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)

	var vbox = panel.get_node_or_null("VBox")
	if vbox:
		vbox.add_theme_constant_override("separation", 8)
		var title = vbox.get_node_or_null("Title") as Label
		if title:
			title.text = "TACTICAL PAUSE // OPERATION ACTIVE"
			title.add_theme_font_size_override("font_size", 16)
			title.add_theme_color_override("font_color", Color(0.35, 0.9, 0.75))

		# Add telemetry readout card if not already added
		if not telemetry_label:
			telemetry_label = Label.new()
			telemetry_label.name = "TelemetryLabel"
			telemetry_label.add_theme_font_size_override("font_size", 11)
			telemetry_label.add_theme_color_override("font_color", Color(0.78, 0.85, 0.9))
			vbox.add_child(telemetry_label)
			# Move telemetry label right below Title
			vbox.move_child(telemetry_label, 1)

		# Collapsible Retro Shader Controls Card for in-game testing
		var debug_toggle_btn = Button.new()
		debug_toggle_btn.name = "DebugDisplayToggleBtn"
		debug_toggle_btn.visible = OS.has_feature("editor")
		debug_toggle_btn.text = "[+] DEBUG SHADER CONTROLS (F6-F10)"
		debug_toggle_btn.custom_minimum_size.y = 26
		debug_toggle_btn.add_theme_font_size_override("font_size", 10)
		vbox.add_child(debug_toggle_btn)
		vbox.move_child(debug_toggle_btn, 2)

		var shader_box = VBoxContainer.new()
		shader_box.name = "ShaderControls"
		shader_box.add_theme_constant_override("separation", 4)
		shader_box.visible = false

		debug_toggle_btn.pressed.connect(func():
			shader_box.visible = !shader_box.visible
			debug_toggle_btn.text = "[-] DEBUG SHADER CONTROLS (F6-F10)" if shader_box.visible else "[+] DEBUG SHADER CONTROLS (F6-F10)"
		)

		var btn_row = HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 6)
		
		var outline_btn = Button.new()
		outline_btn.name = "OutlineToggleBtn"
		var is_out = true
		if has_node("/root/ShaderManager"):
			is_out = get_node("/root/ShaderManager").outlines_enabled
		outline_btn.text = "Outlines: %s (F6)" % ("ON" if is_out else "OFF")
		outline_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		outline_btn.pressed.connect(func():
			if has_node("/root/ShaderManager"):
				var sm = get_node("/root/ShaderManager")
				sm.set_outlines_enabled(!sm.outlines_enabled)
				outline_btn.text = "Outlines: %s (F6)" % ("ON" if sm.outlines_enabled else "OFF")
		)
		btn_row.add_child(outline_btn)
		
		var res_btn = Button.new()
		res_btn.name = "ResToggleBtn"
		res_btn.text = "World: Native (F8)"
		res_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		res_btn.pressed.connect(func():
			if has_node("/root/ShaderManager"):
				var sm = get_node("/root/ShaderManager")
				var next_m = (sm.pixelation_mode + 1) % 3
				sm.set_pixelation_mode(next_m)
				var labels = ["Native", "2x blocks", "3x blocks"]
				res_btn.text = "World: %s (F8)" % labels[next_m]
		)
		btn_row.add_child(res_btn)
		
		var toon_btn = Button.new()
		toon_btn.name = "ToonToggleBtn"
		toon_btn.text = "Toon: OFF (F7)"
		toon_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		toon_btn.pressed.connect(func():
			if has_node("/root/ShaderManager"):
				var sm = get_node("/root/ShaderManager")
				sm.set_toon_shading_enabled(!sm.toon_shading_enabled)
				toon_btn.text = "Toon: %s (F7)" % ("ON" if sm.toon_shading_enabled else "OFF")
		)
		btn_row.add_child(toon_btn)
		
		shader_box.add_child(btn_row)
		vbox.add_child(shader_box)
		vbox.move_child(shader_box, 3)

		# Polish button text & minimum height
		var buttons = [resume_btn, restart_btn, settings_btn, main_menu_btn, quit_btn]
		for b in buttons:
			if b:
				b.custom_minimum_size.y = 36
				b.mouse_entered.connect(func():
					if not b.disabled and has_node("/root/AudioManager"):
						get_node("/root/AudioManager").play_sfx("ui_hover")
				)
				b.focus_entered.connect(func():
					if not b.disabled and has_node("/root/AudioManager"):
						get_node("/root/AudioManager").play_sfx("ui_hover")
				)

		if resume_btn and restart_btn and settings_btn and main_menu_btn and quit_btn:
			resume_btn.focus_neighbor_bottom = restart_btn.get_path()
			restart_btn.focus_neighbor_top = resume_btn.get_path()
			restart_btn.focus_neighbor_bottom = settings_btn.get_path()
			settings_btn.focus_neighbor_top = restart_btn.get_path()
			settings_btn.focus_neighbor_bottom = main_menu_btn.get_path()
			main_menu_btn.focus_neighbor_top = settings_btn.get_path()
			main_menu_btn.focus_neighbor_bottom = quit_btn.get_path()
			quit_btn.focus_neighbor_top = main_menu_btn.get_path()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_action_pressed("pause"):
		return
	var settings = get_parent().get_node_or_null("SettingsMenu")
	if settings and settings.visible:
		settings._close_settings()
	else:
		toggle_pause()
	get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	var gm = get_node("/root/GameManager")
	if not gm.current_state in [gm.RunState.ACTIVE, gm.RunState.EXTRACTION, gm.RunState.PAUSED] or get_node("/root/UIFlow").busy:
		return
	gm.toggle_pause()
	visible = gm.current_state == gm.RunState.PAUSED
	if visible:
		panel.visible = true
		_refresh_telemetry()
		_refresh_debug_labels()
		resume_btn.grab_focus()

func _refresh_telemetry() -> void:
	if not telemetry_label:
		return
	var gm = get_node_or_null("/root/GameManager")
	var wave_num: int = gm.current_wave if gm else 1
	var run_time: float = gm.run_time if gm else 0.0
	var kills: int = gm.kills_count if gm else 0
	var score_val: int = gm.score if gm else 0
	var banked: int = gm.banked_credits if gm else 0
	var at_risk: int = gm.at_risk_credits if gm else 0
	var salvage_val: int = gm.carried_salvage if gm else 0

	var player = get_tree().get_first_node_in_group("player")
	var hull_pct: int = 100
	var fuel_pct: int = 100
	if player:
		if "current_hull" in player and "max_hull" in player and player.max_hull > 0:
			hull_pct = int((player.current_hull / player.max_hull) * 100.0)
		if "current_fuel" in player and "max_fuel" in player and player.max_fuel > 0:
			fuel_pct = int((player.current_fuel / player.max_fuel) * 100.0)

	var minutes: int = int(float(run_time) / 60.0)
	var seconds: int = int(run_time) % 60

	var pm = get_node_or_null("/root/ProfileManager")
	var high_val: int = pm.high_score if pm else 0
	var is_record: bool = score_val > high_val and high_val > 0

	var txt = "--- MISSION TELEMETRY ---\n"
	txt += "Flight Time: %02d:%02d | Tactical Wave: %d\n" % [minutes, seconds, wave_num]
	txt += "Airframe Hull: %d%% | Fuel Reserves: %d%%\n" % [hull_pct, fuel_pct]
	txt += "Confirmed Kills: %d | Sortie Score: %d PTS (High: %d PTS)\n" % [kills, score_val, maxi(score_val, high_val)]
	if is_record:
		txt += "★ NEW ALL-TIME HIGH SCORE SET ON THIS SORTIE! ★\n"
	txt += "Credits: %d Banked | %d At-Risk | Salvage: %d" % [banked, at_risk, salvage_val]
	telemetry_label.text = txt

func _on_resume_pressed() -> void:
	if visible:
		toggle_pause()

func _on_restart_pressed() -> void:
	get_node("/root/UIFlow").confirm_action("Restart sortie?", "Current run progress will be lost. Permanent purchases stay saved.", func(): get_node("/root/UIFlow").begin_run(), restart_btn)

func _on_main_menu_pressed() -> void:
	get_node("/root/UIFlow").confirm_action("Return to main menu?", "Current run progress will be lost. Completed rewards stay saved.", func(): get_node("/root/UIFlow").return_to_menu(), main_menu_btn)

func _on_settings_pressed() -> void:
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("ui_click")
	var settings = get_parent().get_node_or_null("SettingsMenu")
	if settings and settings.has_method("toggle_settings"):
		if "caller_focus_node" in settings:
			settings.caller_focus_node = settings_btn
		settings.toggle_settings()
		if settings.visible:
			panel.visible = false
			if not _listening_settings:
				_listening_settings = true
				if settings.has_signal("settings_closed"):
					settings.settings_closed.connect(func():
						if visible:
							panel.visible = true
							if settings_btn:
								settings_btn.grab_focus()
					)
				else:
					settings.visibility_changed.connect(func():
						if not settings.visible and visible:
							panel.visible = true
							if settings_btn:
								settings_btn.grab_focus()
					)

func _on_quit_pressed() -> void:
	get_node("/root/UIFlow").confirm_action("Quit game?", "Current run progress will be lost. Permanent purchases stay saved.", get_node("/root/UIFlow").quit_game, quit_btn)

func _refresh_debug_labels() -> void:
	var manager = get_node("/root/ShaderManager")
	var labels := {"OutlineToggleBtn": "Outlines: %s (F6)" % ("ON" if manager.outlines_enabled else "OFF"), "ToonToggleBtn": "Toon: %s (F7)" % ("ON" if manager.toon_shading_enabled else "OFF"), "ResToggleBtn": "World: %s (F8)" % ["Native", "2x blocks", "3x blocks"][manager.pixelation_mode]}
	for key in labels:
		var button = panel.find_child(key, true, false)
		if button:
			button.text = labels[key]
