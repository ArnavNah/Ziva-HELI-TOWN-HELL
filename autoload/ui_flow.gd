extends Node
## Shared transition owner. Screens request destinations; GameManager owns simulation state.
var busy: bool = false
var input_armed: bool = true
var last_loading_metrics: Dictionary = {}
var loader: CanvasLayer
var confirmation: ConfirmationDialog
var hangar_origin: String = "main_menu"
var _release_frames: int = 0
const HELD_ACTIONS := ["fire_primary", "paint_salvo", "climb", "descend", "evasive_dash", "super_ability", "deploy_flares", "reload", "ui_accept", "pause"]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		confirm_action("Quit game?", "Your current run will end. Completed run rewards and purchases stay saved.", func(): get_tree().quit())

func _process(_delta: float) -> void:
	if busy or input_armed or get_tree().paused:
		return
	for action in HELD_ACTIONS:
		if InputMap.has_action(action) and Input.is_action_pressed(action):
			_release_frames = 0
			return
	_release_frames += 1
	if _release_frames >= 2:
		input_armed = true

func gameplay_input_allowed() -> bool:
	var gm = get_node("/root/GameManager")
	if not (not busy and input_armed and not get_tree().paused and gm.current_state in [gm.RunState.ACTIVE, gm.RunState.EXTRACTION, gm.RunState.TUTORIAL]):
		return false
	var player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and "is_dying" in player and player.is_dying:
		return false
	return true

func block_held_input() -> void:
	input_armed = false
	_release_frames = 0

func begin_run(aircraft: String = "") -> bool:
	return load_destination("res://scenes/main_game.tscn", aircraft)

func load_destination(path: String, aircraft: String = "") -> bool:
	if busy:
		return false
	busy = true
	block_held_input()
	var gm = get_node("/root/GameManager")
	if aircraft != "":
		gm.selected_aircraft = aircraft
	gm.change_state(gm.RunState.LOADING)
	_clear_transients()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	loader = load("res://src/ui/menus/loading_screen.gd").new()
	get_tree().root.add_child(loader)
	loader.start_loading(path, gm.selected_aircraft)
	return true

func finish_loading(scene: Node) -> void:
	if is_instance_valid(loader):
		last_loading_metrics = {"max_frame_ms": loader.frame_max_ms, "animated_frames": loader.frames_animated, "world_frames": loader.world_frames, "world_max_frame_ms": loader.world_max_ms}
	if scene and scene.has_method("activate_session"):
		scene.activate_session()
	busy = false
	loader = null
	block_held_input()

func return_to_menu(tab: String = "") -> void:
	if busy and not is_instance_valid(loader):
		return
	busy = true
	var had_loader: bool = is_instance_valid(loader)
	if had_loader:
		loader.queue_free()
	loader = null

	var is_test_or_headless: bool = not OS.get_environment("ZIVA_TEST_DATA_DIR").is_empty() or DisplayServer.get_name() == "headless"
	if is_test_or_headless or had_loader:
		_execute_return_to_menu(tab)
	else:
		_fade_and_return_to_menu(tab)

func _execute_return_to_menu(tab: String) -> void:
	_clear_transients()
	var gm = get_node("/root/GameManager")
	gm.pending_menu_tab = tab
	gm.change_state(gm.RunState.MENU)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var error := get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	if error != OK:
		busy = false
		push_error("Cannot open main menu: %s" % error_string(error))

func _fade_and_return_to_menu(tab: String) -> void:
	var curtain := CanvasLayer.new()
	curtain.layer = 128
	curtain.process_mode = Node.PROCESS_MODE_ALWAYS
	var rect := ColorRect.new()
	rect.color = Color("080f14")
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.modulate.a = 0.0
	curtain.add_child(rect)
	get_tree().root.add_child(curtain)

	var tween := curtain.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(rect, "modulate:a", 1.0, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(func():
		_execute_return_to_menu(tab)
		var out_tween := curtain.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		out_tween.tween_interval(0.04)
		out_tween.tween_property(rect, "modulate:a", 0.0, 0.20).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		out_tween.tween_callback(curtain.queue_free)
	)

func menu_ready() -> void:
	busy = false
	input_armed = true

func _clear_transients() -> void:
	get_node("/root/CombatDirector").stop_wave_director()
	if has_node("/root/FXManager"):
		get_node("/root/FXManager").clear_combat_effects()
	for group in ["combat_projectiles", "enemy_projectiles", "combat_explosions", "combat_sparks", "pickups", "combat_debris", "combat_flashes", "combat_dust"]:
		for node in get_tree().get_nodes_in_group(group):
			if is_instance_valid(node):
				node.queue_free()

func confirm_action(title: String, message: String, action: Callable, focus: Control = null) -> void:
	if busy or is_instance_valid(confirmation):
		return
	confirmation = ConfirmationDialog.new()
	var dialog := confirmation
	dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	dialog.title = title
	dialog.dialog_text = message
	dialog.ok_button_text = "Confirm"
	dialog.cancel_button_text = "Cancel"
	get_tree().root.add_child(dialog)
	dialog.confirmed.connect(action, CONNECT_ONE_SHOT)
	dialog.visibility_changed.connect(func():
		if not dialog.visible:
			confirmation = null
			if is_instance_valid(focus) and focus.is_visible_in_tree():
				focus.grab_focus()
			dialog.queue_free()
	)
	dialog.popup_centered(Vector2i(520, 160))
	dialog.get_cancel_button().grab_focus()
