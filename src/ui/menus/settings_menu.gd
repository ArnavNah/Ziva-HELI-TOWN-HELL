class_name SettingsMenu
extends Control
signal settings_closed()
var master_slider: HSlider
var sfx_slider: HSlider
var music_slider: HSlider
var master_pct_lbl: Label
var sfx_pct_lbl: Label
var music_pct_lbl: Label
var window_mode_btn: OptionButton
var fps_mode_btn: OptionButton
var vsync_btn: OptionButton
var shake_btn: OptionButton
var flash_check: CheckBox
var telemetry_check: CheckBox
var close_btn: Button
var tab_settings_btn: Button
var tab_controls_btn: Button
var settings_box: VBoxContainer
var controls_box: VBoxContainer
var caller_focus_node: Control
var status_label: Label
var _populating: bool = false

func _ready() -> void:
	theme = preload("res://src/ui/menus/menu_theme.gd").create()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui_layout()
	get_node("/root/SettingsStore").changed.connect(func(_key): _load_current_values())
	get_node("/root/SettingsStore").save_failed.connect(func(message): status_label.text = message)
	_load_current_values()

func toggle_settings() -> void:
	if visible:
		_close_settings()
	else:
		visible = true
		_load_current_values()
		master_slider.grab_focus()

func _close_settings() -> void:
	get_node("/root/SettingsStore").revert_display()
	if not get_node("/root/SettingsStore").flush():
		status_label.text = get_node("/root/SettingsStore").last_error
		return
	visible = false
	settings_closed.emit()
	if is_instance_valid(caller_focus_node) and caller_focus_node.is_visible_in_tree():
		caller_focus_node.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if visible and not event.is_echo() and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		_close_settings()
		get_viewport().set_input_as_handled()

func _row(title: String, control: Control) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = title
	label.custom_minimum_size.x = 180
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	settings_box.add_child(row)

func _option(items: Array, title: String) -> OptionButton:
	var option := OptionButton.new()
	for item in items:
		option.add_item(item)
	_row(title, option)
	return option

func _volume(title: String, key: String) -> Array:
	var box := HBoxContainer.new()
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(slider)
	var label := Label.new()
	label.custom_minimum_size.x = 50
	box.add_child(label)
	slider.value_changed.connect(func(value): _set_preference(key, value / 100.0))
	_row(title, box)
	return [slider, label]

func _build_ui_layout() -> void:
	for child in get_children():
		child.queue_free()
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.06, 0.08, 0.96)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 12)
	margin.add_child(main)
	var title := Label.new()
	title.text = "PILOT SETTINGS"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("ffd275"))
	main.add_child(title)
	var tabs := HBoxContainer.new()
	main.add_child(tabs)
	tab_settings_btn = Button.new()
	tab_settings_btn.text = "Preferences"
	tab_settings_btn.pressed.connect(func(): _switch_sub_view(true))
	tabs.add_child(tab_settings_btn)
	tab_controls_btn = Button.new()
	tab_controls_btn.text = "Flight controls"
	tab_controls_btn.pressed.connect(func(): _switch_sub_view(false))
	tabs.add_child(tab_controls_btn)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(content)
	settings_box = VBoxContainer.new()
	settings_box.add_theme_constant_override("separation", 16)
	content.add_child(settings_box)
	controls_box = VBoxContainer.new()
	controls_box.add_theme_constant_override("separation", 10)
	content.add_child(controls_box)
	window_mode_btn = _option(["Windowed", "Borderless desktop", "Fullscreen"], "Display mode")
	window_mode_btn.item_selected.connect(_on_window_mode_selected)
	fps_mode_btn = _option(["60 FPS", "120 FPS", "Uncapped"], "Frame rate limit")
	fps_mode_btn.item_selected.connect(_on_fps_mode_selected)
	vsync_btn = _option(["Off", "On"], "VSync")
	vsync_btn.item_selected.connect(_on_vsync_selected)
	var master := _volume("Master volume", "master")
	master_slider = master[0]
	master_pct_lbl = master[1]
	var sfx := _volume("Effects volume", "sfx")
	sfx_slider = sfx[0]
	sfx_pct_lbl = sfx[1]
	var music := _volume("Music volume", "music")
	music_slider = music[0]
	music_pct_lbl = music[1]
	shake_btn = _option(["Full", "Reduced", "Off"], "Camera shake")
	shake_btn.item_selected.connect(_on_shake_selected)
	flash_check = CheckBox.new()
	flash_check.text = "Reduce bright flashes"
	flash_check.toggled.connect(_on_flash_toggled)
	settings_box.add_child(flash_check)
	telemetry_check = CheckBox.new()
	telemetry_check.text = "Show FPS and frame time"
	telemetry_check.toggled.connect(_on_telemetry_toggled)
	settings_box.add_child(telemetry_check)
	var defaults := Button.new()
	defaults.text = "Restore settings defaults"
	defaults.pressed.connect(func(): get_node("/root/UIFlow").confirm_action("Restore settings?", "This resets preferences only. Purchases and records stay saved.", func(): get_node("/root/SettingsStore").restore_defaults(), defaults))
	settings_box.add_child(defaults)
	var actions: Dictionary = get_node("/root/InputManager").CONTROL_LABELS
	var aim := Label.new()
	aim.text = "Aim: mouse  |  Weapons: 1–4 / mouse wheel"
	controls_box.add_child(aim)
	for action in actions:
		var names: Array[String] = []
		for event in InputMap.action_get_events(action):
			var name_text: String = get_node("/root/InputManager").binding_label(event)
			if not names.has(name_text):
				names.append(name_text)
		var label := Label.new()
		label.text = actions[action] + ": " + " / ".join(names)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		controls_box.add_child(label)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main.add_child(status_label)
	close_btn = Button.new()
	close_btn.text = "Done [Esc / Back]"
	close_btn.custom_minimum_size.y = 42
	close_btn.pressed.connect(_on_close_pressed)
	main.add_child(close_btn)
	_switch_sub_view(true)

func _switch_sub_view(show_settings: bool) -> void:
	settings_box.visible = show_settings
	controls_box.visible = not show_settings
	tab_settings_btn.disabled = show_settings
	tab_controls_btn.disabled = not show_settings

func _load_current_values() -> void:
	_populating = true
	var store = get_node("/root/SettingsStore")
	var v: Dictionary = store.values
	window_mode_btn.select(v.window)
	fps_mode_btn.select([60, 120, 0].find(int(v.fps)))
	vsync_btn.select(int(v.vsync))
	master_slider.set_value_no_signal(v.master * 100)
	sfx_slider.set_value_no_signal(v.sfx * 100)
	music_slider.set_value_no_signal(v.music * 100)
	master_pct_lbl.text = "%d%%" % int(v.master * 100)
	sfx_pct_lbl.text = "%d%%" % int(v.sfx * 100)
	music_pct_lbl.text = "%d%%" % int(v.music * 100)
	shake_btn.select(2 - int(v.shake))
	flash_check.set_pressed_no_signal(v.flashes)
	telemetry_check.set_pressed_no_signal(v.telemetry)
	status_label.text = store.last_error if not store.last_error.is_empty() else "Changes save automatically."
	_populating = false

func _set_preference(key: String, value: Variant) -> void:
	if not _populating:
		get_node("/root/SettingsStore").set_value(key, value)

func _on_window_mode_selected(idx: int) -> void:
	if not _populating:
		get_node("/root/SettingsStore").preview_display(idx)
func _on_master_changed(value: float) -> void:
	_set_preference("master", value / 100.0)
func _on_sfx_changed(value: float) -> void:
	_set_preference("sfx", value / 100.0)
func _on_music_changed(value: float) -> void:
	_set_preference("music", value / 100.0)
func _on_shake_selected(idx: int) -> void:
	_set_preference("shake", 2 - idx)
func _on_flash_toggled(value: bool) -> void:
	_set_preference("flashes", value)
func _on_fps_mode_selected(idx: int) -> void:
	_set_preference("fps", [60, 120, 0][idx])
func _on_vsync_selected(idx: int) -> void:
	_set_preference("vsync", idx == 1)
func _on_telemetry_toggled(value: bool) -> void:
	_set_preference("telemetry", value)
func _on_close_pressed() -> void:
	_close_settings()
