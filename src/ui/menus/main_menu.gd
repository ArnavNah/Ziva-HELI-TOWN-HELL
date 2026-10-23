class_name MainMenu
extends Control

## MainMenu — Front-end operations center for Heli-Town Hell (Page 24 & 26).
## Manages mission launch, aircraft selection, Hangar armory, settings, and flight manual.

@export_file("*.tscn") var main_game_path: String = "res://scenes/main_game.tscn"
const LoadingScreenScript = preload("res://src/ui/menus/loading_screen.gd")

@onready var start_btn: Button = $VBoxContainer/StartBtn
@onready var academy_btn: Button = get_node_or_null("VBoxContainer/AcademyBtn")
@onready var hangar_btn: Button = $VBoxContainer/HangarBtn
@onready var settings_btn: Button = $VBoxContainer/SettingsBtn
@onready var manual_btn: Button = $VBoxContainer/ManualBtn
@onready var exit_btn: Button = $VBoxContainer/ExitBtn

@onready var credits_label: Label = $TopBar/CreditsLabel
@onready var salvage_label: Label = $TopBar/SalvageLabel
var high_score_label: Label
@onready var manual_dialog: AcceptDialog = $FlightManualDialog

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_node("/root/UIFlow").menu_ready()
	get_node("/root/GameManager").change_state(get_node("/root/GameManager").RunState.MENU)
	_setup_buttons()
	_update_wallet_display()
	_polish_operations_center()
	start_btn.grab_focus()
	for overlay in [get_node_or_null("HangarMenu"), get_node_or_null("SettingsMenu"), get_node_or_null("VehicleSelectionMenu")]:
		if overlay:
			overlay.visibility_changed.connect(_sync_overlay_focus)
	var v_menu = get_node_or_null("VehicleSelectionMenu")
	if v_menu and v_menu.has_signal("returned_to_menu"):
		v_menu.returned_to_menu.connect(func():
			_sync_overlay_focus()
			start_btn.grab_focus()
		)
	if manual_dialog:
		manual_dialog.confirmed.connect(func(): manual_btn.grab_focus())
		manual_dialog.canceled.connect(func(): manual_btn.grab_focus())

	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		var requested_tab: String = gm.pending_menu_tab
		gm.pending_menu_tab = ""
		if requested_tab == "hangar":
			call_deferred("_on_hangar_pressed")
		elif requested_tab == "aircraft":
			call_deferred("_on_start_pressed")

func _setup_buttons() -> void:
	var buttons = [start_btn, hangar_btn, settings_btn, manual_btn, exit_btn]
	for b in buttons:
		if b:
			b.mouse_entered.connect(func():
				if not b.disabled and has_node("/root/AudioManager"):
					get_node("/root/AudioManager").play_sfx("ui_hover")
			)
			b.focus_entered.connect(func():
				if not b.disabled and has_node("/root/AudioManager"):
					get_node("/root/AudioManager").play_sfx("ui_hover")
			)

	if start_btn:
		start_btn.pressed.connect(_on_start_pressed)
		start_btn.focus_neighbor_top = exit_btn.get_path()
		start_btn.focus_neighbor_bottom = hangar_btn.get_path()
	if academy_btn:
		academy_btn.visible = false
	if hangar_btn:
		hangar_btn.pressed.connect(_on_hangar_pressed)
		hangar_btn.focus_neighbor_top = start_btn.get_path()
		hangar_btn.focus_neighbor_bottom = settings_btn.get_path()
	if settings_btn:
		settings_btn.pressed.connect(_on_settings_pressed)
		settings_btn.focus_neighbor_top = hangar_btn.get_path()
		settings_btn.focus_neighbor_bottom = manual_btn.get_path()
	if manual_btn:
		manual_btn.pressed.connect(_on_manual_pressed)
		manual_btn.focus_neighbor_top = settings_btn.get_path()
		manual_btn.focus_neighbor_bottom = exit_btn.get_path()
	if exit_btn:
		exit_btn.pressed.connect(_on_exit_pressed)
		exit_btn.focus_neighbor_top = manual_btn.get_path()
		exit_btn.focus_neighbor_bottom = start_btn.get_path()


func _update_wallet_display() -> void:
	if not high_score_label and has_node("TopBar"):
		high_score_label = $TopBar.get_node_or_null("HighScoreLabel")
		if not high_score_label:
			high_score_label = Label.new()
			high_score_label.name = "HighScoreLabel"
			high_score_label.add_theme_color_override("font_color", Color("ffd700"))
			$TopBar.add_child(high_score_label)
	if has_node("/root/ProfileManager"):
		var pm = get_node("/root/ProfileManager")
		if credits_label:
			credits_label.text = "CREDITS: %d CR" % [pm.banked_credits]
		if salvage_label:
			salvage_label.text = "SALVAGE: %d" % [pm.salvage]
		if high_score_label:
			high_score_label.text = "HIGH SCORE: %d PTS" % [pm.high_score]

func _on_start_pressed() -> void:
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("ui_click")
	var v_menu = get_node_or_null("VehicleSelectionMenu")
	if v_menu:
		v_menu.visible = true
		v_menu.select_aircraft(v_menu.current_aircraft_idx)
		_sync_overlay_focus()
	else:
		get_node("/root/UIFlow").begin_run()

func _on_hangar_pressed() -> void:
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("ui_click")
	var hangar = get_node_or_null("HangarMenu")
	if hangar:
		if "caller_origin" in hangar:
			hangar.caller_origin = "main_menu"
		hangar.refresh_ui()
		hangar.visible = true
		if hangar.back_button:
			hangar.back_button.grab_focus()

func _on_settings_pressed() -> void:
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("ui_click")
	var settings = get_node_or_null("SettingsMenu")
	if settings and settings.has_method("toggle_settings"):
		if "caller_focus_node" in settings:
			settings.caller_focus_node = settings_btn
		settings.toggle_settings()
		if settings.visible and settings.master_slider:
			settings.master_slider.grab_focus()

func _on_manual_pressed() -> void:
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("ui_click")
	if manual_dialog:
		manual_dialog.dialog_text = ""
		var reference = manual_dialog.get_node_or_null("ControlsText")
		if not reference:
			reference = RichTextLabel.new()
			reference.name = "ControlsText"
			reference.custom_minimum_size = Vector2(800, 420)
			reference.scroll_active = true
			manual_dialog.add_child(reference)
		reference.text = get_node("/root/InputManager").controls_reference()
		manual_dialog.popup_centered(Vector2i(900, 540))

func _on_exit_pressed() -> void:
	get_node("/root/UIFlow").confirm_action("Quit game?", "Your completed rewards and purchases are saved.", get_node("/root/UIFlow").quit_game, exit_btn)

func _sync_overlay_focus() -> void:
	var v_menu = get_node_or_null("VehicleSelectionMenu")
	var v_visible: bool = v_menu.visible if v_menu else false
	var blocked: bool = $HangarMenu.visible or $SettingsMenu.visible or v_visible
	for control in [start_btn, academy_btn, hangar_btn, settings_btn, manual_btn, exit_btn]:
		if control:
			control.disabled = blocked
	if not blocked:
		_update_wallet_display()
		start_btn.grab_focus()

func _unhandled_input(_event: InputEvent) -> void:
	# Each topmost child owns Back and restores the correct return focus.
	pass

func _polish_operations_center() -> void:
	var teal := Color("385e66")
	var paper := Color("e1ece2")
	var pixel_font := preload("res://src/effects/floating_text.gd").get_pixel_font()
	var ui_theme := Theme.new()
	ui_theme.default_font_size = 16
	for type_name in ["Button", "OptionButton"]:
		ui_theme.set_stylebox("normal", type_name, _pixel_plate(teal, Color("23323d")))
		ui_theme.set_stylebox("hover", type_name, _pixel_plate(Color("497b83"), Color("91afb2")))
		ui_theme.set_stylebox("pressed", type_name, _pixel_plate(Color("294952"), Color("80a2a6")))
		ui_theme.set_stylebox("disabled", type_name, _pixel_plate(Color("243a40"), Color("20242b")))
		ui_theme.set_stylebox("focus", type_name, _style(Color(0, 0, 0, 0), Color("bccdca"), 2))
		ui_theme.set_color("font_color", type_name, paper)
		ui_theme.set_color("font_hover_color", type_name, Color.WHITE)
		ui_theme.set_color("font_focus_color", type_name, Color.WHITE)
		ui_theme.set_color("font_outline_color", type_name, Color("162c34"))
		ui_theme.set_constant("outline_size", type_name, 2)
	ui_theme.set_stylebox("panel", "PanelContainer", _style(Color("10191d"), Color("546a6d"), 2))
	ui_theme.set_stylebox("panel", "PopupMenu", _style(Color("142930"), Color("819da2"), 2))
	ui_theme.set_color("font_color", "Label", paper)
	theme = ui_theme
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	$Background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var backdrop := TextureRect.new()
	backdrop.name = "PixelHangarBackdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.texture = load("res://assets/ui/pixel_hangar_menu.png")
	$Background.add_child(backdrop)
	$TopBar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	$TopBar.offset_left = 80
	$TopBar.offset_top = -32
	$TopBar.offset_right = -80
	$TopBar.offset_bottom = -8
	$TopBar.add_theme_constant_override("separation", 10)
	$TopBar/TitleLabel.text = ""
	for label in [credits_label, salvage_label, high_score_label]:
		if label:
			label.add_theme_font_override("font", pixel_font)
			label.add_theme_font_size_override("font_size", 10)
			if label == high_score_label:
				label.add_theme_color_override("font_color", Color("ffd700"))
			else:
				label.add_theme_color_override("font_color", Color("869c98"))
	var box := $VBoxContainer as VBoxContainer
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	box.position = Vector2(88, 177)
	box.size = Vector2(254, 0)
	box.grow_horizontal = Control.GROW_DIRECTION_END
	box.grow_vertical = Control.GROW_DIRECTION_END
	box.add_theme_constant_override("separation", 16)
	var pixel_theme := ui_theme.duplicate() as Theme
	pixel_theme.default_font = pixel_font
	pixel_theme.default_font_size = 14
	box.theme = pixel_theme
	var actions := [start_btn, hangar_btn, settings_btn, manual_btn, exit_btn]
	var texts := ["SELECT AIRFRAME", "HANGAR & ARMORY", "PILOT SETTINGS", "FLIGHT MANUAL", "EXIT"]
	for index in actions.size():
		var button: Button = actions[index]
		if not button:
			continue
		box.move_child(button, index)
		button.text = texts[index]
		button.custom_minimum_size = Vector2(254, 44)
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_theme_font_size_override("font_size", 14)
		_decorate_plate(button)
	if academy_btn:
		academy_btn.visible = false
	var a_lbl = get_node_or_null("VBoxContainer/AircraftLabel")
	if a_lbl:
		a_lbl.visible = false
	var a_sel = get_node_or_null("VBoxContainer/AircraftSelect")
	if a_sel:
		a_sel.visible = false
	var footer := _label("TACTICAL SURVIVAL / READY TO FLY", Vector2.ZERO, 12, paper)
	footer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	footer.offset_left = -210
	footer.offset_right = 210
	footer.offset_top = -42
	footer.offset_bottom = -20
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_override("font", pixel_font)
	# All menu actions stay live Controls above the image.
	for overlay in [get_node_or_null("HangarMenu"), get_node_or_null("SettingsMenu"), get_node_or_null("VehicleSelectionMenu")]:
		if overlay:
			move_child(overlay, get_child_count() - 1)
	modulate.a = 0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.3)

func _pixel_plate(fill: Color, edge: Color) -> StyleBoxFlat:
	var plate := _style(fill, edge, 3)
	plate.border_width_left = 6
	plate.border_width_bottom = 5
	plate.shadow_color = Color("241746")
	plate.shadow_size = 4
	plate.shadow_offset = Vector2(4, 5)
	return plate

func _decorate_plate(button: Button) -> void:
	var rivets := Control.new()
	rivets.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rivets.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(rivets)
	rivets.draw.connect(func():
		for x in [12.0, button.size.x - 15.0]:
			for y in [11.0, button.size.y - 14.0]:
				rivets.draw_rect(Rect2(x, y, 3, 5), Color("152d35"))
				rivets.draw_rect(Rect2(x, y, 3, 2), Color("90acae"))
	)

func _style(fill: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style

func _label(text_value: String, pos: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

