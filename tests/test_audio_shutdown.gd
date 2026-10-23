extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if OS.get_environment("ZIVA_TEST_DATA_DIR").is_empty():
		quit(2)
		return
	var audio = root.get_node("AudioManager")
	for i in 32:
		audio.play_sfx("explosion")
		await process_frame
	await audio.prepare_shutdown()
	var stopped := true
	for child in audio.get_children():
		if child is AudioStreamPlayer:
			stopped = stopped and not child.playing and child.stream == null
	print("PASS audio pool stops and releases stream handles" if stopped else "FAIL audio pool remains active")
	quit(0 if stopped else 1)
