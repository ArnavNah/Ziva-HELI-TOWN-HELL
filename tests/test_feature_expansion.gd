extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var guard = preload("res://src/player/mortal_protection.gd").new()
	check(guard.limit_damage(99.0, 35.0, 100.0) == 34.0, "35% lethal hit must leave 1 HP")
	check(guard.limit_damage(30.0, 1.0, 100.0) == 0.0, "grace blocks follow-up")
	guard.advance(0.6, 1.0, 100.0)
	check(guard.limit_damage(3.0, 1.0, 100.0) == 3.0, "grace must expire")
	guard.advance(16.0, 59.0, 100.0)
	check(not guard.armed, "low hull must not rearm")
	guard.advance(0.1, 60.0, 100.0)
	check(guard.armed, "60% recovery rearms after cooldown")
	guard = preload("res://src/player/mortal_protection.gd").new()
	check(guard.limit_damage(20.0, 35.0, 100.0) == 20.0, "nonlethal first burst hit")
	guard.advance(0.1, 15.0, 100.0)
	check(guard.limit_damage(20.0, 15.0, 100.0) == 14.0, "burst snapshot survives subsequent lethal hit")
	guard = preload("res://src/player/mortal_protection.gd").new()
	check(guard.limit_damage(60.0, 30.0, 100.0) == 60.0, "low hull not eligible")
	var cards = preload("res://src/resources/upgrade_card_database.gd").get_master_deck()
	var ids := {}
	for card in cards: ids[card.card_id] = true
	for card in cards:
		for required in card.required_cards:
			check(ids.has(required), "missing prerequisite " + required)
	var weapon = preload("res://src/player/player_weapons.gd").new()
	weapon.apply_subsystem_upgrade(0, {"blast_radius_add": 3.0, "damage_mult": 0.40})
	var data = preload("res://src/combat/damage_data.gd").new(10.0, 0, null, true, 0.0)
	weapon.apply_subsystem_damage(0, data)
	check(is_equal_approx(data.blast_radius, 3.0), "evolution must change real cannon blast")
	weapon.free()
	# Compile the changed production paths as well as the isolated policy.
	check(load("res://src/player/player_helicopter.gd") != null, "player compiles")
	check(load("res://src/ui/hud.gd") != null, "HUD compiles")
	check(load("res://src/player/player_camera.gd") != null, "camera compiles")
	var boss_script = load("res://src/enemies/boss/modular_fortress_boss.gd")
	check(boss_script != null and boss_script.can_instantiate(), "bosses compile")
	var audio = root.get_node("AudioManager")
	check(audio.get_helicopter_rotor_stream().loop_mode == AudioStreamWAV.LOOP_FORWARD, "existing rotor recording loops")
	var fixture_path := "res://artifacts/feature-expansion/audio-fixture"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixture_path + "/music"))
	for stem in ["bgm_calm", "bgm_combat", "bgm_boss"]:
		var sample := AudioStreamWAV.new()
		sample.format = AudioStreamWAV.FORMAT_16_BITS
		sample.mix_rate = 22050
		var silence := PackedByteArray()
		silence.resize(22050 * 2)
		sample.data = silence
		check(sample.save_to_wav(fixture_path + "/music/" + stem + ".wav") == OK, "create isolated audio fixture " + stem)
	audio._load_sample_overrides(fixture_path)
	check(audio.recorded_music_layers, "three matching supplied WAVs enable additive music")
	check(is_equal_approx(audio.sound_cache.bgm_boss.get_length(), 1.0), "music loader uses the supplied recording")
	audio.set_music_mode("boss")
	audio.super_active_timer = 2.0
	audio._update_bgm_crossfade(1.0)
	check(audio.bgm_player_calm.volume_db > -40 and audio.bgm_player_combat.volume_db > -40 and audio.bgm_player_boss.volume_db > -40, "boss music blends all three recorded stems")
	check(audio.bgm_player_calm.pitch_scale == 1 and audio.bgm_player_combat.pitch_scale == 1 and audio.bgm_player_boss.pitch_scale == 1, "overdrive preserves recorded stem pitch alignment")
	print("FEATURE EXPANSION: %d checks / %d failures" % [checks, failures])
	quit(1 if failures else 0)
