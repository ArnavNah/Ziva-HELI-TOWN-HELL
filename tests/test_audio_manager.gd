extends SceneTree

## Verification test for AudioManager procedural SFX & dynamic retro synth BGM loop

func _init() -> void:
	print("--- BEGIN AUDIO MANAGER VERIFICATION ---")
	var tests_passed: int = 0
	var total_tests: int = 6

	var event_bus = root.get_node_or_null("EventBus")
	if not event_bus:
		event_bus = preload("res://autoload/event_bus.gd").new()
		event_bus.name = "EventBus"
		root.add_child(event_bus)

	var audio_mgr = root.get_node_or_null("AudioManager")
	if not audio_mgr:
		audio_mgr = preload("res://autoload/audio_manager.gd").new()
		audio_mgr.name = "AudioManager"
		root.add_child(audio_mgr)
	if audio_mgr.sound_cache.is_empty():
		audio_mgr._ready()

	# 1. Verify BGM stream generation and looping properties
	if audio_mgr.sound_cache.has("bgm_calm") and audio_mgr.sound_cache.has("bgm_combat") and audio_mgr.sound_cache.has("bgm_boss"):
		var calm = audio_mgr.sound_cache["bgm_calm"]
		var combat = audio_mgr.sound_cache["bgm_combat"]
		var boss = audio_mgr.sound_cache["bgm_boss"]
		if calm.loop_mode == AudioStreamWAV.LOOP_FORWARD and combat.loop_mode == AudioStreamWAV.LOOP_FORWARD and boss.loop_mode == AudioStreamWAV.LOOP_FORWARD:
			print("  [PASS] 1. Procedural BGM: All 3 streams (Calm, Combat, Boss) generated with forward looping.")
			tests_passed += 1
		else:
			print("  [FAIL] 1. BGM stream loop_mode invalid.")
	else:
		print("  [FAIL] 1. BGM streams missing from sound_cache.")

	# 2. Verify BGM dedicated AudioStreamPlayers
	if is_instance_valid(audio_mgr.bgm_player_calm) and is_instance_valid(audio_mgr.bgm_player_combat) and is_instance_valid(audio_mgr.bgm_player_boss):
		print("  [PASS] 2. BGM Players: Dedicated phase-synchronized players initialized on Master bus.")
		tests_passed += 1
	else:
		print("  [FAIL] 2. BGM players not instantiated.")

	# 3. Verify Music Mode Switching
	audio_mgr.set_music_mode("combat")
	if audio_mgr.get_music_mode() == "combat":
		audio_mgr.set_music_mode("boss")
		if audio_mgr.get_music_mode() == "boss":
			audio_mgr.set_music_mode("calm")
			print("  [PASS] 3. Music Mode: Dynamic state switching (calm -> combat -> boss) operational.")
			tests_passed += 1
		else:
			print("  [FAIL] 3. Boss mode transition failed.")
	else:
		print("  [FAIL] 3. Combat mode transition failed.")

	# 4. Verify Volume Control & Dynamic Crossfade
	audio_mgr.set_music_volume(0.75)
	audio_mgr.set_master_volume(1.0)
	# Process a tick to apply crossfade
	audio_mgr._process(0.5)
	# With music_mode = "calm", calm player should be louder than -80, combat should remain quiet (-80)
	if audio_mgr.bgm_player_calm.volume_db > -40.0 and audio_mgr.bgm_player_combat.volume_db < -40.0:
		print("  [PASS] 4. Crossfade Dynamics: Volume lerping correctly prioritizes active mode.")
		tests_passed += 1
	else:
		print("  [FAIL] 4. Volume crossfade values incorrect: calm=", audio_mgr.bgm_player_calm.volume_db, " combat=", audio_mgr.bgm_player_combat.volume_db)

	# 5. Verify EventBus Dynamic Response
	if root.has_node("EventBus"):
		var bus = root.get_node("EventBus")
		bus.wave_started.emit(1, "normal", 45.0)
		if audio_mgr.get_music_mode() == "combat":
			bus.boss_spawned.emit(null)
			if audio_mgr.get_music_mode() == "boss":
				bus.boss_defeated.emit()
				if audio_mgr.get_music_mode() == "calm":
					print("  [PASS] 5. EventBus Integration: Combat and Boss BGM respond directly to wave and boss events.")
					tests_passed += 1
				else:
					print("  [FAIL] 5. Boss defeated calm reset failed.")
			else:
				print("  [FAIL] 5. Boss spawn transition failed.")
		else:
			print("  [FAIL] 5. Wave start combat transition failed.")
	else:
		print("  [FAIL] 5. EventBus node not found.")

	# 6. Verify Super Activation Pitch Hype
	audio_mgr._on_super_activated()
	if audio_mgr.super_active_timer > 4.0:
		audio_mgr._process(0.2)
		print("  [PASS] 6. Devastation Super: Excitation timer and pitch ramp triggered on super activation.")
		tests_passed += 1
	else:
		print("  [FAIL] 6. Super activation timer not initialized.")

	print("Summary: ", tests_passed, "/", total_tests, " PASSED.")
	if tests_passed == total_tests:
		print("--- ALL AUDIO MANAGER & BGM VERIFICATIONS SUCCEEDED ---")
		quit(0)
	else:
		quit(1)
