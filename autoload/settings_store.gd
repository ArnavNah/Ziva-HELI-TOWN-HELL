extends Node
signal changed(key: String)
signal save_failed(message: String)
const Storage = preload("res://src/ui/menus/game_storage.gd")
const DEFAULTS := {"master": 1.0, "sfx": 1.0, "music": 0.8, "shake": 2, "flashes": false, "telemetry": true, "fps": 0, "vsync": true, "window": 0}
var values: Dictionary = DEFAULTS.duplicate()
var last_error: String = ""
var save_path: String
var save_timer: Timer
var display_dialog: ConfirmationDialog
var _display_remaining: float = 0.0
var _display_snapshot: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	save_path = Storage.path_for("heli_town_settings.json")
	load_settings()
	save_timer = Timer.new()
	save_timer.one_shot = true
	save_timer.wait_time = 0.3
	save_timer.timeout.connect(flush)
	add_child(save_timer)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_min_size(Vector2i(960, 540))
	apply_all()

func load_settings() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var parser := JSON.new()
	var error := parser.parse(FileAccess.get_file_as_string(save_path))
	var parsed = parser.data if error == OK else null
	if not parsed is Dictionary:
		last_error = "Settings could not be read. Defaults are active."
		return
	for key in DEFAULTS:
		if parsed.has(key):
			values[key] = _validated(key, parsed[key])

func _validated(key: String, value: Variant) -> Variant:
	match key:
		"master", "sfx", "music": return clampf(float(value), 0.0, 1.0) if value is float or value is int else DEFAULTS[key]
		"shake", "window": return clampi(int(value), 0, 2) if value is float or value is int else DEFAULTS[key]
		"fps": return int(value) if value in [0, 60, 120] else 60
		_: return value if value is bool else DEFAULTS[key]

func set_value(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key):
		return
	values[key] = _validated(key, value)
	apply_all(false)
	changed.emit(key)
	save_timer.start()

func apply_all(include_display: bool = true) -> void:
	var am = get_node("/root/AudioManager")
	am.set_master_volume(values.master)
	am.set_sfx_volume(values.sfx)
	am.set_music_volume(values.music)
	am.screen_shake_level = values.shake
	am.reduce_flashes = values.flashes
	var gm = get_node("/root/GameManager")
	gm.set_target_fps(values.fps)
	gm.set_vsync(values.vsync)
	gm.show_fps_telemetry = values.telemetry
	if include_display:
		_apply_window(values.window)

func flush() -> bool:
	if save_timer:
		save_timer.stop()
	var error := Storage.write_json(save_path, values)
	last_error = "" if error == OK else "Settings were not saved: " + error_string(error)
	if error != OK:
		save_failed.emit(last_error)
	return error == OK

func restore_defaults() -> void:
	revert_display()
	# Display changes still use the Keep/Revert dialog.
	var old_window: int = values.window
	values = DEFAULTS.duplicate()
	values.window = old_window
	apply_all(false)
	changed.emit("")
	flush()
	if old_window != DEFAULTS.window:
		preview_display(DEFAULTS.window)

func _apply_window(mode: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, mode == 1)
	var screen := DisplayServer.window_get_current_screen()
	if mode == 2:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif mode == 1:
		DisplayServer.window_set_size(DisplayServer.screen_get_size(screen))
		DisplayServer.window_set_position(DisplayServer.screen_get_position(screen))
	else:
		DisplayServer.window_set_size(Vector2i(1280, 720))
		DisplayServer.window_set_position(DisplayServer.screen_get_position(screen) + Vector2i(Vector2(DisplayServer.screen_get_size(screen) - Vector2i(1280, 720)) * 0.5))

func preview_display(mode: int) -> void:
	if is_instance_valid(display_dialog):
		return
	_display_snapshot = {"mode": DisplayServer.window_get_mode(), "border": DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS), "size": DisplayServer.window_get_size(), "position": DisplayServer.window_get_position()}
	_apply_window(mode)
	display_dialog = ConfirmationDialog.new()
	display_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	display_dialog.title = "Keep display settings?"
	display_dialog.ok_button_text = "Keep"
	display_dialog.cancel_button_text = "Revert"
	get_tree().root.add_child(display_dialog)
	_display_remaining = 10.0
	display_dialog.confirmed.connect(func():
		values.window = mode
		_display_snapshot.clear()
		_close_display_dialog()
		flush()
		changed.emit("window")
	)
	display_dialog.canceled.connect(revert_display)
	display_dialog.popup_centered(Vector2i(480, 140))
	display_dialog.get_cancel_button().grab_focus()

func _process(delta: float) -> void:
	if is_instance_valid(display_dialog):
		_display_remaining -= delta
		display_dialog.dialog_text = "Reverting in %d seconds unless you choose Keep." % ceili(_display_remaining)
		if _display_remaining <= 0:
			revert_display()

func _close_display_dialog() -> void:
	if is_instance_valid(display_dialog):
		display_dialog.hide()
		display_dialog.queue_free()
	display_dialog = null

func revert_display() -> void:
	if not _display_snapshot.is_empty() and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, _display_snapshot.border)
		DisplayServer.window_set_size(_display_snapshot.size)
		DisplayServer.window_set_position(_display_snapshot.position)
		DisplayServer.window_set_mode(_display_snapshot.mode)
	_display_snapshot.clear()
	_close_display_dialog()
	changed.emit("window")
