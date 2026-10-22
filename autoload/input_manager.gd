extends Node

## InputManager — Ensures all Heli-Town Hell input actions are configured with keyboard, mouse, and gamepad events.
## Also provides clean normalized vectors for flight, turret aiming, and throttle.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input_actions()

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
	_add_action_joy_axis("yaw_left", JOY_AXIS_LEFT_X, -1.0)
	
	_add_action_key("yaw_right", KEY_D)
	_add_action_key("yaw_right", KEY_RIGHT)
	_add_action_joy_axis("yaw_right", JOY_AXIS_LEFT_X, 1.0)
	
	_add_action_key("strafe_left", KEY_Q)
	_add_action_joy_button("strafe_left", JOY_BUTTON_DPAD_LEFT)
	
	_add_action_key("strafe_right", KEY_E)
	_add_action_joy_button("strafe_right", JOY_BUTTON_DPAD_RIGHT)
	
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
	
	# 4. System / UI
	_add_action_key("pause", KEY_ESCAPE)
	_add_action_key("pause", KEY_P)
	_add_action_joy_button("pause", JOY_BUTTON_START)
	
	_add_action_key("ui_accept", KEY_ENTER)
	_add_action_joy_button("ui_accept", JOY_BUTTON_A)

func _add_action_key(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)

func _add_action_mouse_button(action: String, button_index: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev: InputEventMouseButton = InputEventMouseButton.new()
	ev.button_index = button_index
	InputMap.action_add_event(action, ev)

func _add_action_joy_button(action: String, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev: InputEventJoypadButton = InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)

func _add_action_joy_axis(action: String, axis: JoyAxis, direction: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev: InputEventJoypadMotion = InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = direction
	InputMap.action_add_event(action, ev)

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
	# Vertical: Down (-1) / Up (+1)
	var lift: float = Input.get_axis("descend", "climb")
	
	return {
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

const CONTROL_LABELS := {"thrust_forward": "Forward", "thrust_backward": "Brake / reverse", "yaw_left": "Turn left", "yaw_right": "Turn right", "strafe_left": "Strafe left", "strafe_right": "Strafe right", "climb": "Climb", "descend": "Descend", "evasive_dash": "Dash", "fire_primary": "Fire weapon", "paint_salvo": "Paint salvo (hold/release)", "deploy_flares": "Flares", "super_ability": "Devastation Super", "reload": "Reload", "pause": "Pause"}
func controls_reference() -> String:
	var text := "Aim: mouse | Weapons: 1–4 / mouse wheel\n\n"
	for action in CONTROL_LABELS:
		var names: Array[String] = []
		for event in InputMap.action_get_events(action):
			var label: String = binding_label(event)
			if not names.has(label):
				names.append(label)
		text += CONTROL_LABELS[action] + ": " + " / ".join(names) + "\n"
	return text

func binding_label(event: InputEvent) -> String:
	if event is InputEventKey:
		return OS.get_keycode_string(event.physical_keycode if event.physical_keycode != 0 else event.keycode)
	if event is InputEventMouseButton:
		return {MOUSE_BUTTON_LEFT: "Left click", MOUSE_BUTTON_RIGHT: "Right click", MOUSE_BUTTON_WHEEL_UP: "Wheel up", MOUSE_BUTTON_WHEEL_DOWN: "Wheel down"}.get(event.button_index, "Mouse button")
	if event is InputEventJoypadButton:
		return "Gamepad " + {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y", JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_START: "Start", JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right", JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down"}.get(event.button_index, "button")
	if event is InputEventJoypadMotion:
		if event.axis == JOY_AXIS_TRIGGER_LEFT:
			return "Gamepad LT"
		if event.axis == JOY_AXIS_TRIGGER_RIGHT:
			return "Gamepad RT"
		if event.axis == JOY_AXIS_LEFT_X:
			return "Left stick " + ("left" if event.axis_value < 0 else "right")
		if event.axis == JOY_AXIS_LEFT_Y:
			return "Left stick " + ("up" if event.axis_value < 0 else "down")
	return "Gamepad input"
