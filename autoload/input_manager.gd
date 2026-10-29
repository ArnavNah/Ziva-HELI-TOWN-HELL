extends Node

signal input_mode_changed(controller: bool)
signal damage_rumble_requested(device: int, weak: float, strong: float, duration: float)
var rumble_enabled := true
var last_damage_rumble: Dictionary = {}
var _rumble_device := -1
var aim_direction := Vector2.UP
var _auto_aim_target: WeakRef
var controller_active := false
var active_joypad := -1
var aim_sensitivity := 1.0
var aim_deadzone := 0.18
var aim_invert_y := false
var virtual_aim := Vector2.ZERO
var aim_viewport := Vector2.ZERO
var aim_initialized := false
var controller_notice := ""
var notice_timer := 0.0

## InputManager — Ensures all Heli-Town Hell input actions are configured with keyboard, mouse, and gamepad events.
## Also provides clean normalized vectors for flight, turret aiming, and throttle.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input_actions()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

func _setup_input_actions() -> void:
	# 1. Flight Controls
	_add_action_key("thrust_forward", KEY_W)
	_add_action_key("thrust_forward", KEY_UP)
	_add_action_joy_axis("thrust_forward", JOY_AXIS_LEFT_Y, -1.0)
	
	_add_action_key("thrust_backward", KEY_S)
	_add_action_key("thrust_backward", KEY_DOWN)
	_add_action_joy_axis("thrust_backward", JOY_AXIS_LEFT_Y, 1.0)
	
	_add_action_key("yaw_left", KEY_A)
	_add_action_key("yaw_left", KEY_LEFT)
	_remove_joy_axis("yaw_left", JOY_AXIS_LEFT_X)
	_add_action_joy_button("yaw_left", JOY_BUTTON_DPAD_LEFT)
	
	_add_action_key("yaw_right", KEY_D)
	_add_action_key("yaw_right", KEY_RIGHT)
	_remove_joy_axis("yaw_right", JOY_AXIS_LEFT_X)
	_add_action_joy_button("yaw_right", JOY_BUTTON_DPAD_RIGHT)
	
	_add_action_key("strafe_left", KEY_Q)
	_remove_joy_button("strafe_left", JOY_BUTTON_DPAD_LEFT)
	_add_action_joy_axis("strafe_left", JOY_AXIS_LEFT_X, -1.0)
	
	_add_action_key("strafe_right", KEY_E)
	_remove_joy_button("strafe_right", JOY_BUTTON_DPAD_RIGHT)
	_add_action_joy_axis("strafe_right", JOY_AXIS_LEFT_X, 1.0)
	
	_add_action_key("climb", KEY_SPACE)
	_add_action_key("climb", KEY_SHIFT)
	_add_action_joy_button("climb", JOY_BUTTON_DPAD_UP)
	
	_add_action_key("descend", KEY_CTRL)
	_add_action_key("descend", KEY_C)
	_add_action_key("descend", KEY_Z)
	_add_action_joy_button("descend", JOY_BUTTON_DPAD_DOWN)
	
	# Evasive Dash
	_add_action_key("evasive_dash", KEY_ALT)
	_add_action_key("evasive_dash", KEY_X)
	_add_action_joy_button("evasive_dash", JOY_BUTTON_RIGHT_SHOULDER)
	_add_action_joy_button("evasive_dash", JOY_BUTTON_B)
	
	# 2. Combat Actions
	_add_action_mouse_button("fire_primary", MOUSE_BUTTON_LEFT)
	_add_action_key("fire_primary", KEY_J)
	_add_action_joy_button("fire_primary", JOY_BUTTON_A)
	_add_action_joy_axis("fire_primary", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	
	_add_action_mouse_button("paint_salvo", MOUSE_BUTTON_RIGHT)
	_add_action_joy_axis("paint_salvo", JOY_AXIS_TRIGGER_LEFT, 1.0)
	
	_add_action_key("deploy_flares", KEY_F)
	_add_action_joy_button("deploy_flares", JOY_BUTTON_LEFT_SHOULDER)
	
	_add_action_key("reload", KEY_R)
	_add_action_joy_button("reload", JOY_BUTTON_X)
	
	_add_action_key("super_ability", KEY_V)
	_add_action_key("super_ability", KEY_G)
	_add_action_joy_button("super_ability", JOY_BUTTON_Y)
	
	# 3. Weapons Selection
	_add_action_key("weapon_1", KEY_1)
	_add_action_key("weapon_2", KEY_2)
	_add_action_key("weapon_3", KEY_3)
	_add_action_key("weapon_4", KEY_4)
	
	_add_action_mouse_button("next_weapon", MOUSE_BUTTON_WHEEL_DOWN)
	_add_action_mouse_button("prev_weapon", MOUSE_BUTTON_WHEEL_UP)
	_add_action_joy_button("prev_weapon", JOY_BUTTON_LEFT_STICK)
	_add_action_joy_button("next_weapon", JOY_BUTTON_RIGHT_STICK)
	_add_action_joy_axis("aim_left", JOY_AXIS_RIGHT_X, -1.0)
	_add_action_joy_axis("aim_right", JOY_AXIS_RIGHT_X, 1.0)
	_add_action_joy_axis("aim_up", JOY_AXIS_RIGHT_Y, -1.0)
	_add_action_joy_axis("aim_down", JOY_AXIS_RIGHT_Y, 1.0)
	for action in ["aim_left", "aim_right", "aim_up", "aim_down"]:
		InputMap.action_set_deadzone(action, 0.0) # One radial deadzone below, not two axial ones.
	for action in ["thrust_forward", "thrust_backward", "strafe_left", "strafe_right", "yaw_left", "yaw_right"]:
		InputMap.action_set_deadzone(action, 0.20)
	InputMap.action_set_deadzone("fire_primary", 0.15)
	InputMap.action_set_deadzone("paint_salvo", 0.15)
	_add_action_key("mission_action", KEY_T)
	_add_action_joy_button("mission_action", JOY_BUTTON_BACK)
	_add_action_key("radar_zoom", KEY_M)
	
	# 4. System / UI
	_add_action_key("pause", KEY_ESCAPE)
	_add_action_key("pause", KEY_P)
	_add_action_joy_button("pause", JOY_BUTTON_START)
	
	_add_action_key("ui_accept", KEY_ENTER)
	_add_action_joy_button("ui_accept", JOY_BUTTON_A)
	_add_action_joy_button("ui_cancel", JOY_BUTTON_B)
	for mapping in [["ui_left", JOY_BUTTON_DPAD_LEFT], ["ui_right", JOY_BUTTON_DPAD_RIGHT], ["ui_up", JOY_BUTTON_DPAD_UP], ["ui_down", JOY_BUTTON_DPAD_DOWN]]:
		_add_action_joy_button(mapping[0], mapping[1])
	for mapping in [["ui_left", JOY_AXIS_LEFT_X, -1.0], ["ui_right", JOY_AXIS_LEFT_X, 1.0], ["ui_up", JOY_AXIS_LEFT_Y, -1.0], ["ui_down", JOY_AXIS_LEFT_Y, 1.0]]:
		_add_action_joy_axis(mapping[0], mapping[1], mapping[2])
		InputMap.action_set_deadzone(mapping[0], 0.35)

func _remove_joy_axis(action: String, axis: int) -> void:
	if not InputMap.has_action(action): return
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion and event.axis == axis: InputMap.action_erase_event(action, event)

func _remove_joy_button(action: String, button: int) -> void:
	if not InputMap.has_action(action): return
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and event.button_index == button: InputMap.action_erase_event(action, event)

func _add_action_key(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = keycode
	if not InputMap.action_has_event(action, ev): InputMap.action_add_event(action, ev)

func _add_action_mouse_button(action: String, button_index: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev: InputEventMouseButton = InputEventMouseButton.new()
	ev.button_index = button_index
	if not InputMap.action_has_event(action, ev): InputMap.action_add_event(action, ev)

func _add_action_joy_button(action: String, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev: InputEventJoypadButton = InputEventJoypadButton.new()
	ev.device = -1
	ev.button_index = button
	if not InputMap.action_has_event(action, ev): InputMap.action_add_event(action, ev)

func _add_action_joy_axis(action: String, axis: JoyAxis, direction: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev: InputEventJoypadMotion = InputEventJoypadMotion.new()
	ev.device = -1
	ev.axis = axis
	ev.axis_value = direction
	if not InputMap.action_has_event(action, ev): InputMap.action_add_event(action, ev)

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		_set_controller_mode(true, event.device)
	elif event is InputEventJoypadMotion:
		var threshold := aim_deadzone if event.axis in [JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y] else 0.25
		if absf(event.axis_value) > threshold:
			_set_controller_mode(true, event.device)
	elif event is InputEventMouseMotion and event.relative.length() > 2.0:
		_set_controller_mode(false)
	elif (event is InputEventMouseButton or event is InputEventKey) and event.is_pressed():
		_set_controller_mode(false)

func _set_controller_mode(enabled: bool, device: int = -1) -> void:
	if enabled:
		active_joypad = device
		notice_timer = 0.0
		controller_notice = ""
	if controller_active == enabled: return
	controller_active = enabled
	aim_initialized = false
	_auto_aim_target = null
	if not enabled: stop_damage_rumble()
	input_mode_changed.emit(enabled)

func aim_stick() -> Vector2:
	var raw := Vector2(Input.get_action_raw_strength("aim_right") - Input.get_action_raw_strength("aim_left"), Input.get_action_raw_strength("aim_down") - Input.get_action_raw_strength("aim_up"))
	var magnitude := minf(1.0, raw.length())
	if magnitude <= aim_deadzone: return Vector2.ZERO
	var response := (magnitude - aim_deadzone) / (1.0 - aim_deadzone)
	return raw.normalized() * response * Vector2(1, -1 if aim_invert_y else 1)

func advance_controller_aim(delta: float, viewport_size: Vector2, initial_point: Vector2) -> void:
	if viewport_size.x <= 48 or viewport_size.y <= 48: return
	if not aim_initialized:
		aim_direction = (initial_point - viewport_size * 0.5).normalized()
		if aim_direction.is_zero_approx(): aim_direction = Vector2.UP
		aim_initialized = true
	aim_viewport = viewport_size
	var scale := minf(viewport_size.x / 1280.0, viewport_size.y / 720.0)
	var stick := aim_stick()
	if not stick.is_zero_approx(): aim_direction = stick.normalized()
	# Directional twin-stick intent, anchored to the helicopter rather than a
	# cursor that must be dragged across the screen while the camera moves.
	var anchor := viewport_size * Vector2(0.5, 0.58)
	var camera := get_viewport().get_camera_3d()
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if camera and player: anchor = camera.unproject_position(player.global_position)
	virtual_aim = anchor + aim_direction * 220.0 * aim_sensitivity * scale
	virtual_aim = virtual_aim.clamp(Vector2(24, 24), viewport_size - Vector2(24, 24))

func set_auto_aim_target(target: Node3D) -> void:
	_auto_aim_target = weakref(target) if is_instance_valid(target) else null

func get_aim_screen_position() -> Vector2:
	if controller_active:
		var target: Node3D = _auto_aim_target.get_ref() if _auto_aim_target else null
		var camera := get_viewport().get_camera_3d()
		if is_instance_valid(target) and not target.is_queued_for_deletion() and camera and not camera.is_position_behind(target.global_position):
			var receiver := target.get_node_or_null("DamageReceiver")
			if not receiver or not receiver.is_dead:
				var col := target.get_node_or_null("CollisionShape3D") as Node3D
				return camera.unproject_position(col.global_position if col else target.global_position + Vector3.UP * 0.75)
		return virtual_aim if aim_initialized else get_viewport().get_visible_rect().size * 0.5
	return get_viewport().get_mouse_position()

func _process(delta: float) -> void:
	notice_timer = maxf(0.0, notice_timer - delta)
	if controller_active:
		var back: bool = Input.is_action_just_pressed("ui_cancel")
		var tactical_back: bool = Input.is_action_just_pressed("mission_action") or Input.is_action_just_pressed("pause")
		if back or tactical_back:
			for dialog in get_tree().root.find_children("*", "AcceptDialog", true, false):
				if dialog.visible and (back or dialog.get_meta("controller_tactical", false)):
					if Engine.get_process_frames() <= int(dialog.get_meta("controller_open_frame", -100)) + 1: continue
					get_node("/root/UIFlow").block_held_input()
					dialog.canceled.emit()
					dialog.hide()
					break
	var flow = get_node_or_null("/root/UIFlow")
	var playing: bool = flow != null and flow.gameplay_input_allowed()
	if not playing or not rumble_enabled: stop_damage_rumble()
	var mouse_mode := Input.MOUSE_MODE_HIDDEN if controller_active and playing else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != mouse_mode: Input.mouse_mode = mouse_mode
	if not controller_active or not playing: return
	var player = get_tree().get_first_node_in_group("player")
	var camera := get_viewport().get_camera_3d()
	if not is_instance_valid(player) or not camera: return
	var initial: Vector2 = camera.unproject_position(player.global_position - player.global_basis.z * 35.0 - Vector3.UP * minf(12, player.global_position.y * 0.7))
	advance_controller_aim(delta, get_viewport().get_visible_rect().size, initial)

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected or device != active_joypad or not controller_active: return
	stop_damage_rumble()
	_set_controller_mode(false)
	active_joypad = -1
	controller_notice = "CONTROLLER DISCONNECTED / RECONNECT OR USE KEYBOARD + MOUSE"
	notice_timer = 8.0
	for action in ["aim_left", "aim_right", "aim_up", "aim_down", "thrust_forward", "thrust_backward", "yaw_left", "yaw_right", "strafe_left", "strafe_right", "climb", "descend", "fire_primary", "paint_salvo", "evasive_dash", "reload", "deploy_flares", "super_ability", "next_weapon", "prev_weapon", "mission_action", "ui_accept", "ui_cancel", "ui_left", "ui_right", "ui_up", "ui_down", "pause"]:
		Input.action_release(action)
	var flow = get_node_or_null("/root/UIFlow")
	if flow: flow.block_held_input()
	var player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and player.has_node("Salvo"): player.get_node("Salvo").cancel_painting()
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.current_state in [gm.RunState.ACTIVE, gm.RunState.EXTRACTION]:
		var pause_menu = get_tree().current_scene.find_child("PauseMenu", true, false) if get_tree().current_scene else null
		if pause_menu: pause_menu.toggle_pause()
		else: gm.toggle_pause()

# ------------------------------------------------------------------------------
# Input Query Helpers
# ------------------------------------------------------------------------------
func get_flight_input() -> Dictionary:
	if has_node("/root/UIFlow") and not get_node("/root/UIFlow").gameplay_input_allowed():
		return {}
	var yaw: float = Input.get_axis("yaw_left", "yaw_right")
	# Heading relative thrust: Forward (+1) / Reverse (-1)
	var thrust: float = Input.get_axis("thrust_backward", "thrust_forward")
	# Strafe: Left (-1) / Right (+1)
	var strafe: float = Input.get_axis("strafe_left", "strafe_right")
	if controller_active:
		# Camera-relative translation stays intuitive even during a manual turn.
		var move := Vector2(strafe, -thrust).limit_length(1.0)
		var camera := get_viewport().get_camera_3d()
		var player := get_tree().get_first_node_in_group("player") as Node3D
		if camera and player:
			var right := Vector3(camera.global_basis.x.x, 0, camera.global_basis.x.z).normalized()
			var forward := Vector3(-camera.global_basis.z.x, 0, -camera.global_basis.z.z).normalized()
			var movement := right * move.x - forward * move.y
			strafe = movement.dot(player.global_basis.x)
			thrust = movement.dot(-player.global_basis.z)
	# Vertical: Down (-1) / Up (+1)
	var lift: float = Input.get_axis("descend", "climb")
	
	return {
		"direct_move": controller_active,
		"yaw": yaw,
		"thrust": thrust,
		"strafe": strafe,
		"lift": lift,
		"dash": Input.is_action_just_pressed("evasive_dash"),
		"fire": Input.is_action_pressed("fire_primary"),
		"salvo": Input.is_action_pressed("paint_salvo"),
		"salvo_released": Input.is_action_just_released("paint_salvo"),
		"flare": Input.is_action_just_pressed("deploy_flares"),
		"super": Input.is_action_just_pressed("super_ability"),
		"reload": Input.is_action_just_pressed("reload")
	}

const CONTROL_LABELS := {"thrust_forward": "Forward", "thrust_backward": "Brake / reverse", "yaw_left": "Turn left", "yaw_right": "Turn right", "strafe_left": "Strafe left", "strafe_right": "Strafe right", "climb": "Climb", "descend": "Descend", "evasive_dash": "Dash", "fire_primary": "Fire weapon", "paint_salvo": "Paint salvo (hold/release)", "deploy_flares": "Flares", "super_ability": "Devastation Super", "reload": "Reload", "next_weapon": "Next weapon", "prev_weapon": "Previous weapon", "mission_action": "Mission / extraction + radar", "pause": "Pause"}
func controls_reference() -> String:
	var text := "Left stick: move in any direction | Right stick: aim + auto-lock\nD-pad: turn + altitude | L3/R3: weapons | View: mission | Start: pause\n\n"
	for action in CONTROL_LABELS:
		var names: Array[String] = []
		for event in InputMap.action_get_events(action):
			var label: String = binding_label(event)
			if not names.has(label):
				names.append(label)
		text += CONTROL_LABELS[action] + ": " + " / ".join(names) + "\n"
	return text

func play_damage_rumble(damage: float) -> void:
	var flow := get_node_or_null("/root/UIFlow")
	if not rumble_enabled or not controller_active or active_joypad < 0 or damage <= 0 or not flow or not flow.gameplay_input_allowed(): return
	var intensity := clampf(damage / 30.0, 0.0, 1.0)
	var weak := lerpf(0.28, 0.80, intensity)
	var strong := lerpf(0.12, 0.65, intensity)
	var duration := lerpf(0.12, 0.28, intensity)
	_rumble_device = active_joypad
	last_damage_rumble = {"device":active_joypad, "weak":weak, "strong":strong, "duration":duration}
	damage_rumble_requested.emit(active_joypad, weak, strong, duration)
	if active_joypad in Input.get_connected_joypads():
		Input.start_joy_vibration(active_joypad, weak, strong, duration)

func stop_damage_rumble() -> void:
	if _rumble_device >= 0 and _rumble_device in Input.get_connected_joypads(): Input.stop_joy_vibration(_rumble_device)
	_rumble_device = -1

func _exit_tree() -> void:
	stop_damage_rumble()

func binding_label(event: InputEvent) -> String:
	if event is InputEventKey:
		return OS.get_keycode_string(event.physical_keycode if event.physical_keycode != 0 else event.keycode)
	if event is InputEventMouseButton:
		return {MOUSE_BUTTON_LEFT: "Left click", MOUSE_BUTTON_RIGHT: "Right click", MOUSE_BUTTON_WHEEL_UP: "Wheel up", MOUSE_BUTTON_WHEEL_DOWN: "Wheel down"}.get(event.button_index, "Mouse button")
	if event is InputEventJoypadButton:
		return "Gamepad " + {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y", JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_START: "Start/Menu", JOY_BUTTON_BACK: "View/Back", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right", JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down"}.get(event.button_index, "button")
	if event is InputEventJoypadMotion:
		if event.axis in [JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]: return "Right stick"
		if event.axis == JOY_AXIS_TRIGGER_LEFT:
			return "Gamepad LT"
		if event.axis == JOY_AXIS_TRIGGER_RIGHT:
			return "Gamepad RT"
		if event.axis == JOY_AXIS_LEFT_X:
			return "Left stick " + ("left" if event.axis_value < 0 else "right")
		if event.axis == JOY_AXIS_LEFT_Y:
			return "Left stick " + ("up" if event.axis_value < 0 else "down")
	return "Gamepad input"
