extends SceneTree

func _initialize() -> void:
	call_deferred("_test")

func _test() -> void:
	root.size = Vector2i(1280, 720)
	var menu: VehicleSelectionMenu = load("res://scenes/ui/vehicle_selection_menu.tscn").instantiate()
	root.add_child(menu)
	menu.visible = true

	await process_frame
	await process_frame

	print("Initial aircraft idx: ", menu.current_aircraft_idx)

	# 1. Test clicking Card_1 (Nighthawk)
	var card1 = menu.card_buttons[1]
	print("Card 1 global rect: ", card1.get_global_rect())
	var card1_pos = card1.get_global_rect().get_center()

	# Emit mouse click on card 1
	var mb_down = InputEventMouseButton.new()
	mb_down.button_index = MOUSE_BUTTON_LEFT
	mb_down.pressed = true
	mb_down.position = card1_pos
	mb_down.global_position = card1_pos
	root.push_input(mb_down)
	await process_frame

	var mb_up = InputEventMouseButton.new()
	mb_up.button_index = MOUSE_BUTTON_LEFT
	mb_up.pressed = false
	mb_up.position = card1_pos
	mb_up.global_position = card1_pos
	root.push_input(mb_up)
	await process_frame

	print("Aircraft idx after clicking Card 1: ", menu.current_aircraft_idx)

	# 2. Test dragging on 3D stage
	var initial_rot = menu.turntable_root.rotation.y if menu.turntable_root else 0.0
	print("Initial turntable rot: ", initial_rot)

	var stage_pos = Vector2(400, 300) # Open area in showroom
	var drag_down = InputEventMouseButton.new()
	drag_down.button_index = MOUSE_BUTTON_LEFT
	drag_down.pressed = true
	drag_down.position = stage_pos
	drag_down.global_position = stage_pos
	root.push_input(drag_down)
	await process_frame
	print("is_dragging after drag_down: ", menu.is_dragging)

	var drag_move = InputEventMouseMotion.new()
	drag_move.position = stage_pos + Vector2(50, 0)
	drag_move.global_position = stage_pos + Vector2(50, 0)
	drag_move.relative = Vector2(50, 0)
	root.push_input(drag_move)
	await process_frame
	print("turntable_rot after drag_move: ", menu.turntable_root.rotation.y if menu.turntable_root else 0.0)

	var drag_up = InputEventMouseButton.new()
	drag_up.button_index = MOUSE_BUTTON_LEFT
	drag_up.pressed = false
	drag_up.position = stage_pos + Vector2(50, 0)
	drag_up.global_position = stage_pos + Vector2(50, 0)
	root.push_input(drag_up)
	await process_frame

	var final_rot = menu.turntable_root.rotation.y if menu.turntable_root else 0.0
	print("Final turntable rot after drag: ", final_rot)

	# 3. Test deploy button
	var deploy_pos = menu.deploy_btn.get_global_rect().get_center()
	print("Deploy btn rect: ", menu.deploy_btn.get_global_rect())

	# 4. Test back button
	print("Back btn rect: ", menu.back_btn.get_global_rect())

	quit(0)
