extends SceneTree
var failures: int = 0
func _initialize() -> void:
	call_deferred("run")
func verify(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures += 1
func run() -> void:
	if OS.get_environment("ZIVA_TEST_DATA_DIR").is_empty():
		quit(1)
		return
	await process_frame
	var flow = root.get_node("UIFlow")
	flow.begin_run("nighthawk")
	var deadline := Time.get_ticks_msec() + 60000
	while flow.busy and Time.get_ticks_msec() < deadline:
		await process_frame
	verify(not flow.busy and current_scene.name == "MainGame", "real readiness handoff")
	verify(current_scene.player.aircraft_type == "nighthawk", "chosen aircraft reaches gameplay")
	verify(flow.last_loading_metrics.world_frames > 10, "animation advances throughout town preparation")
	flow.load_destination("res://scenes/missing.tscn")
	for i in 8:
		await process_frame
	verify(flow.loader.phase == flow.loader.Phase.FAILED, "invalid resource shows failure UI")
	flow.loader._back()
	for i in 10:
		await process_frame
	verify(not flow.busy and not paused and current_scene.name == "MainMenu", "Back recovers to menu")
	flow.load_destination("res://tests/fixtures/menu_unready.tscn")
	for i in 60:
		if flow.loader.phase == flow.loader.Phase.FAILED:
			break
		await process_frame
	verify(flow.loader.phase == flow.loader.Phase.FAILED, "unready scene fails safely")
	flow.loader._back()
	for i in 10:
		await process_frame
	verify(not flow.busy and current_scene.name == "MainMenu", "initialization failure Back recovers")
	quit(1 if failures else 0)
