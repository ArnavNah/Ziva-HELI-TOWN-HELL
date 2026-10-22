extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	if OS.get_environment("ZIVA_TEST_DATA_DIR").is_empty():
		quit(1)
		return
	await process_frame
	var store = root.get_node("SettingsStore")
	var pm = root.get_node("ProfileManager")
	var gm = root.get_node("GameManager")
	var valid: bool = store.values.master == 0.0 and store.values.shake == 0 and store.values.flashes and not gm.show_fps_telemetry and gm.target_fps == 60
	valid = valid and pm.hangar_ranks.engine == 1 and pm.perk_ranks.emp_rounds == 1 and pm.equipped_mods[0] == 2 and gm.selected_aircraft == pm.selected_aircraft_id
	print("PASS settings, ranks, equipment and aircraft survive a fresh process" if valid else "FAIL process-restart persistence")
	quit(0 if valid else 1)
