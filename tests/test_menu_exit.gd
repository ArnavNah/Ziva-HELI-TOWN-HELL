extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	if OS.get_environment("ZIVA_TEST_DATA_DIR").is_empty():
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	root.get_node("UIFlow").return_to_menu()
	for i in 8:
		await process_frame
	current_scene._on_exit_pressed()
	var dialog = root.get_node("UIFlow").confirmation
	if not is_instance_valid(dialog):
		print("FAIL Quit confirmation missing")
		quit(1)
		return
	print("PASS Quit confirmation opened")
	create_timer(2.0).timeout.connect(func():
		print("FAIL Confirm did not quit the isolated game process")
		quit(1)
	)
	dialog.confirmed.emit()
	print("PASS Confirm sent; normal process exit must precede the watchdog")
