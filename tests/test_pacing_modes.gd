extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	print("=== INVESTIGATING FRAME PACING MODES ===")
	var vsync_mode = DisplayServer.window_get_vsync_mode()
	var screen = DisplayServer.window_get_current_screen()
	var refresh_rate = DisplayServer.screen_get_refresh_rate(screen)
	print("Current screen refresh rate: ", refresh_rate, " Hz")
	print("Default VSync mode: ", vsync_mode)

	# Test 1: VSync Enabled, max_fps = 0
	print("\n--- TEST 1: VSync ENABLED, max_fps = 0 ---")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	Engine.max_fps = 0
	var res1 = await measure_frames(60)
	print("Result: %.2f FPS, avg frame time: %.2f ms, min: %.2f ms, max: %.2f ms" % [res1.fps, res1.avg_ms, res1.min_ms, res1.max_ms])

	# Test 2: VSync Enabled, max_fps = 60
	print("\n--- TEST 2: VSync ENABLED, max_fps = 60 ---")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	Engine.max_fps = 60
	var res2 = await measure_frames(60)
	print("Result: %.2f FPS, avg frame time: %.2f ms, min: %.2f ms, max: %.2f ms" % [res2.fps, res2.avg_ms, res2.min_ms, res2.max_ms])

	# Test 3: VSync Disabled, max_fps = 60
	print("\n--- TEST 3: VSync DISABLED, max_fps = 60 ---")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 60
	var res3 = await measure_frames(60)
	print("Result: %.2f FPS, avg frame time: %.2f ms, min: %.2f ms, max: %.2f ms" % [res3.fps, res3.avg_ms, res3.min_ms, res3.max_ms])

	# Test 4: VSync Disabled, max_fps = 0 (Uncapped)
	print("\n--- TEST 4: VSync DISABLED, max_fps = 0 (Uncapped) ---")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var res4 = await measure_frames(60)
	print("Result: %.2f FPS, avg frame time: %.2f ms, min: %.2f ms, max: %.2f ms" % [res4.fps, res4.avg_ms, res4.min_ms, res4.max_ms])

	quit(0)

func measure_frames(count: int) -> Dictionary:
	var times: Array[float] = []
	# Warm up 10 frames
	for i in 10:
		await process_frame

	var last = Time.get_ticks_usec()
	for f in count:
		await process_frame
		var now = Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now

	var total = 0.0
	var min_t = 9999.0
	var max_t = 0.0
	for t in times:
		total += t
		if t < min_t: min_t = t
		if t > max_t: max_t = t
	var avg = total / float(times.size())
	return {
		"fps": 1000.0 / avg,
		"avg_ms": avg,
		"min_ms": min_t,
		"max_ms": max_t
	}
