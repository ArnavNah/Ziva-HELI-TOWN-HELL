extends Node

## AudioManager — Central sound manager with procedural audio synthesis for Heli-Town Hell (Page 24).
## Procedurally generates 16-bit PCM waveform SFX (weapons, explosions, alarms, chimes)
## with a 16-channel AudioStreamPlayer pool and auto-listens to EventBus signals.

var master_volume: float = 1.0
var sfx_volume: float = 1.0
var music_volume: float = 0.8

var is_screen_shake_enabled: bool = true
var screen_shake_level: int = 2 # 0: Off, 1: Low, 2: Full
var reduce_flashes: bool = false
var high_contrast: bool = false

# Procedural Sound Cache
var sound_cache: Dictionary = {}
var player_pool: Array[AudioStreamPlayer] = []
const POOL_SIZE: int = 16
var current_pool_idx: int = 0

const MIX_RATE: int = 22050
const BGM_BPM: float = 128.0

# Procedural BGM Players & Dynamic State
var music_mode: String = "calm" # "calm", "combat", "boss", "silent"
var bgm_player_calm: AudioStreamPlayer
var bgm_player_combat: AudioStreamPlayer
var bgm_player_boss: AudioStreamPlayer
var super_active_timer: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio_pool()
	_generate_procedural_sounds()
	_setup_bgm_players()
	_connect_event_bus()

func _process(delta: float) -> void:
	_update_bgm_crossfade(delta)
	for player in player_pool:
		if player.playing:
			player.volume_db = -80.0 if master_volume * sfx_volume <= 0.001 else clampf(linear_to_db(master_volume * sfx_volume) + float(player.get_meta("volume_offset", 0.0)), -80.0, 6.0)

func _exit_tree() -> void:
	if is_instance_valid(bgm_player_calm):
		bgm_player_calm.stop()
		bgm_player_calm.stream = null
	if is_instance_valid(bgm_player_combat):
		bgm_player_combat.stop()
		bgm_player_combat.stream = null
	if is_instance_valid(bgm_player_boss):
		bgm_player_boss.stop()
		bgm_player_boss.stream = null
	for p in player_pool:
		if is_instance_valid(p):
			p.stop()
			p.stream = null
	sound_cache.clear()

func _setup_audio_pool() -> void:
	for i in range(POOL_SIZE):
		var p = AudioStreamPlayer.new()
		p.name = "AudioPlayer_%d" % i
		p.bus = "Master"
		add_child(p)
		player_pool.append(p)

func _setup_bgm_players() -> void:
	bgm_player_calm = AudioStreamPlayer.new()
	bgm_player_calm.name = "BGM_Calm"
	bgm_player_calm.bus = "Master"
	bgm_player_calm.stream = sound_cache.get("bgm_calm")
	bgm_player_calm.volume_db = -80.0
	add_child(bgm_player_calm)

	bgm_player_combat = AudioStreamPlayer.new()
	bgm_player_combat.name = "BGM_Combat"
	bgm_player_combat.bus = "Master"
	bgm_player_combat.stream = sound_cache.get("bgm_combat")
	bgm_player_combat.volume_db = -80.0
	add_child(bgm_player_combat)

	bgm_player_boss = AudioStreamPlayer.new()
	bgm_player_boss.name = "BGM_Boss"
	bgm_player_boss.bus = "Master"
	bgm_player_boss.stream = sound_cache.get("bgm_boss")
	bgm_player_boss.volume_db = -80.0
	add_child(bgm_player_boss)

	if is_inside_tree():
		if bgm_player_calm.stream:
			bgm_player_calm.play()
		if bgm_player_combat.stream:
			bgm_player_combat.play()
		if bgm_player_boss.stream:
			bgm_player_boss.play()

func _update_bgm_crossfade(delta: float) -> void:
	if not is_instance_valid(bgm_player_calm) or not is_instance_valid(bgm_player_combat) or not is_instance_valid(bgm_player_boss):
		return

	if is_inside_tree():
		if not bgm_player_calm.playing and bgm_player_calm.stream:
			bgm_player_calm.play()
		if not bgm_player_combat.playing and bgm_player_combat.stream:
			bgm_player_combat.play()
		if not bgm_player_boss.playing and bgm_player_boss.stream:
			bgm_player_boss.play()

	var effective_vol: float = master_volume * music_volume
	if get_tree().paused:
		effective_vol *= 0.45
	var base_db: float = -80.0
	if effective_vol > 0.005:
		base_db = linear_to_db(effective_vol * 0.70)

	var target_calm: float = base_db if music_mode == "calm" else -80.0
	var target_combat: float = base_db if music_mode == "combat" else -80.0
	var target_boss: float = base_db if music_mode == "boss" else -80.0

	var lerp_speed: float = clampf(delta * 4.0, 0.0, 1.0)
	bgm_player_calm.volume_db = lerpf(bgm_player_calm.volume_db, target_calm, lerp_speed)
	bgm_player_combat.volume_db = lerpf(bgm_player_combat.volume_db, target_combat, lerp_speed)
	bgm_player_boss.volume_db = lerpf(bgm_player_boss.volume_db, target_boss, lerp_speed)

	# Devastation Super pitch excitation
	if super_active_timer > 0.0:
		super_active_timer -= delta
		bgm_player_combat.pitch_scale = lerpf(bgm_player_combat.pitch_scale, 1.08, clampf(delta * 6.0, 0.0, 1.0))
		bgm_player_boss.pitch_scale = lerpf(bgm_player_boss.pitch_scale, 1.08, clampf(delta * 6.0, 0.0, 1.0))
	else:
		bgm_player_combat.pitch_scale = lerpf(bgm_player_combat.pitch_scale, 1.0, clampf(delta * 4.0, 0.0, 1.0))
		bgm_player_boss.pitch_scale = lerpf(bgm_player_boss.pitch_scale, 1.0, clampf(delta * 4.0, 0.0, 1.0))

func _generate_procedural_sounds() -> void:
	sound_cache["mg_fire"] = _create_mg_sound()
	sound_cache["missile_fire"] = _create_missile_sound()
	sound_cache["rocket_fire"] = _create_rocket_sound()
	sound_cache["shotgun_fire"] = _create_shotgun_sound()
	sound_cache["explosion"] = _create_explosion_sound(0.55, 0.4)
	sound_cache["explosion_heavy"] = _create_explosion_sound(1.1, 0.7)
	sound_cache["flare"] = _create_flare_sound()
	sound_cache["hit"] = _create_hit_sound()
	sound_cache["pickup"] = _create_pickup_sound()
	sound_cache["lock_beep"] = _create_beep_sound(980.0, 0.08)
	sound_cache["alarm"] = _create_alarm_sound()
	sound_cache["super"] = _create_super_sound()
	sound_cache["level_up"] = _create_level_up_sound()
	sound_cache["upgrade_offer"] = sound_cache["level_up"]
	sound_cache["upgrade_applied"] = _create_pickup_sound()
	sound_cache["pickup_xp"] = _create_pickup_sound()
	sound_cache["crit_hit"] = _create_crit_sound()
	sound_cache["compliment"] = _create_compliment_sound()
	sound_cache["ui_click"] = _create_ui_click_sound()
	sound_cache["ui_hover"] = _create_ui_hover_sound()
	sound_cache["ui_buy"] = _create_ui_buy_sound()
	sound_cache["ui_denied"] = _create_ui_denied_sound()
	sound_cache["victory_fanfare"] = _create_victory_sound()
	sound_cache["defeat_sound"] = _create_defeat_sound()
	sound_cache["new_high_score"] = _create_high_score_sound()
	sound_cache["helicopter_rotor"] = _create_helicopter_rotor_stream()
	sound_cache["thunder"] = _create_thunder_sound()
	sound_cache["touchdown"] = _create_touchdown_sound()

	# 3 Phase-synchronized procedural BGM streams
	sound_cache["bgm_calm"] = _create_calm_stream()
	sound_cache["bgm_combat"] = _create_combat_stream()
	sound_cache["bgm_boss"] = _create_boss_stream()

func _connect_event_bus() -> void:
	var bus: Node = null
	if is_inside_tree() and has_node("/root/EventBus"):
		bus = get_node("/root/EventBus")
	elif get_parent() and get_parent().has_node("EventBus"):
		bus = get_parent().get_node("EventBus")
	if not bus:
		return
	if bus.weapon_fired.is_connected(_on_weapon_fired):
		return
	bus.weapon_fired.connect(_on_weapon_fired)
	bus.flares_deployed.connect(_on_flares_deployed)
	bus.salvo_launched.connect(_on_salvo_launched)
	bus.super_activated.connect(_on_super_activated)
	bus.pickup_collected.connect(_on_pickup_collected)
	bus.entity_destroyed.connect(_on_entity_destroyed)
	bus.player_damaged.connect(_on_player_damaged)
	bus.boss_spawned.connect(_on_boss_spawned)
	bus.boss_defeated.connect(_on_boss_defeated)
	bus.wave_started.connect(_on_wave_started)
	bus.run_completed.connect(_on_run_completed)
	bus.run_state_changed.connect(_on_run_state_changed)
	if "high_score_beaten" in bus:
		bus.high_score_beaten.connect(func(_new_s, _old_s): play_sfx("new_high_score"))

# ------------------------------------------------------------------------------
# Playback API
# ------------------------------------------------------------------------------
func set_music_mode(mode: String) -> void:
	music_mode = mode

func get_music_mode() -> String:
	return music_mode

func get_helicopter_rotor_stream() -> AudioStreamWAV:
	if sound_cache.has("helicopter_rotor"):
		return sound_cache["helicopter_rotor"]
	var s = _create_helicopter_rotor_stream()
	sound_cache["helicopter_rotor"] = s
	return s
func play_sfx(sfx_name: String, pitch_scale: float = 1.0, volume_offset_db: float = 0.0) -> void:
	if sfx_volume <= 0.0 or master_volume <= 0.0:
		return
	if not sound_cache.has(sfx_name):
		return

	var stream = sound_cache[sfx_name]
	var player = player_pool[current_pool_idx]
	current_pool_idx = (current_pool_idx + 1) % POOL_SIZE

	if not is_inside_tree() or not player.is_inside_tree():
		return

	player.stream = stream
	player.pitch_scale = clampf(pitch_scale, 0.5, 2.0)
	var final_db = linear_to_db(master_volume * sfx_volume) + volume_offset_db
	player.set_meta("volume_offset", volume_offset_db)
	player.volume_db = clampf(final_db, -80.0, 6.0)
	player.play()

func trigger_alarm(alarm_name: String) -> void:
	match alarm_name:
		"sam_lock":
			play_sfx("lock_beep", 1.0, 2.0)
		"critical_hull", "low_fuel":
			play_sfx("alarm", 1.0, 2.0)
		_:
			play_sfx("alarm", 1.0, 0.0)

func set_master_volume(val: float) -> void:
	master_volume = clampf(val, 0.0, 1.0)

func set_sfx_volume(val: float) -> void:
	sfx_volume = clampf(val, 0.0, 1.0)

func set_music_volume(val: float) -> void:
	music_volume = clampf(val, 0.0, 1.0)

# ------------------------------------------------------------------------------
# EventBus Callbacks
# ------------------------------------------------------------------------------
func _on_weapon_fired(weapon_id: int, _ammo: int) -> void:
	match weapon_id:
		0: # Machine Gun
			play_sfx("mg_fire", randf_range(0.95, 1.08), -2.0)
		1: # Missile
			play_sfx("missile_fire", 1.0, 0.0)
		2: # Rocket
			play_sfx("rocket_fire", 0.95, 1.0)
		3: # Shotgun
			play_sfx("shotgun_fire", randf_range(0.92, 1.05), 1.0)

func _on_flares_deployed(_charges: int) -> void:
	play_sfx("flare", 1.0, 1.0)

func _on_salvo_launched(_count: int) -> void:
	play_sfx("missile_fire", 1.2, 2.0)

func _on_super_activated() -> void:
	play_sfx("super", 1.0, 3.0)
	super_active_timer = 5.0

var last_pickup_sfx_time: float = 0.0

func _on_pickup_collected(pickup_type: String, _val: float) -> void:
	var now = float(Time.get_ticks_msec()) * 0.001
	if now - last_pickup_sfx_time < 0.045:
		return
	last_pickup_sfx_time = now
	play_sfx("pickup_xp" if pickup_type == "XP_GEM" else "pickup", randf_range(0.95, 1.05), -1.0)

func _on_entity_destroyed(entity: Node, _weapon: String, _score: int, _xp: int) -> void:
	if is_instance_valid(entity) and (entity.is_in_group("enemies") or entity.is_in_group("player") or entity.is_in_group("bosses")):
		return
	play_sfx("explosion", randf_range(0.9, 1.15), 0.0)

func _on_player_damaged(_hull: float, _max_hull: float, _dmg: float) -> void:
	play_sfx("hit", randf_range(0.85, 1.1), 2.0)

func _on_boss_spawned(_boss: Node) -> void:
	play_sfx("explosion_heavy", 0.8, 3.0)
	set_music_mode("boss")

func _on_boss_defeated() -> void:
	play_sfx("level_up", 1.0, 3.0)
	set_music_mode("calm")

func _on_wave_started(wave_number: int, _theme: String, _duration: float) -> void:
	if wave_number >= 10:
		set_music_mode("boss")
	else:
		set_music_mode("combat")

func _on_run_completed(_success: bool, _stats: Dictionary) -> void:
	set_music_mode("calm")

func _on_run_state_changed(new_state: int, _old_state: int) -> void:
	# GameManager.RunState: 0: MENU, 1: TUTORIAL, 2: ACTIVE, 3: PAUSED, 4: UPGRADE_CHOICE, 5: BOSS_DECISION, 6: EXTRACTION, 7: RESULTS
	if new_state in [0, 1, 3, 4, 5, 7, 8]:
		set_music_mode("calm")
	elif new_state == 2:
		if has_node("/root/CombatDirector") and get_node("/root/CombatDirector").current_wave >= 10:
			set_music_mode("boss")
		else:
			set_music_mode("combat")

# ------------------------------------------------------------------------------
# Procedural Audio Synthesis (16-bit PCM WAV Generators)
# ------------------------------------------------------------------------------
func _build_wav(samples: PackedByteArray) -> AudioStreamWAV:
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = samples
	return wav

func _create_helicopter_rotor_stream() -> AudioStreamWAV:
	# 36 chops over 44100 samples = exactly 1225 samples per chop (18.0 Hz chop, 270 RPM Apache gunship)
	# 44100 samples = exactly 2.0s seamless loop at MIX_RATE 22050
	var chop_period = 1225
	var num_chops = 36
	var total_samples = chop_period * num_chops
	var bytes = PackedByteArray()
	bytes.resize(total_samples * 2)

	# Precomputed noise table to ensure seamless wrap
	var noise_len = 8192
	var noise_table: Array[float] = []
	for n in range(noise_len):
		noise_table.append(randf_range(-1.0, 1.0))

	var blade_weights = [1.0, 0.93, 1.04, 0.96] # 4-blade rotor aerodynamic variations

	for i in range(total_samples):
		var t = float(i) / float(MIX_RATE)
		var chop_idx = int(float(i) / float(chop_period))
		var blade_idx = chop_idx % 4
		var blade_weight = blade_weights[blade_idx]
		var sample_in_chop = i % chop_period
		var phase = float(sample_in_chop) / float(chop_period)
		var t_chop = float(sample_in_chop) / float(MIX_RATE)

		# 1. Asymmetric Blade-Vortex Interaction (BVI) Slap:
		# Sharp acoustic pressure wavefront + transient shockwave (220 Hz down to 120 Hz)
		var env_slap = exp(-phase * 18.0)
		var freq_slap = 240.0 * exp(-phase * 14.0) + 120.0
		var slap = sin(2.0 * PI * freq_slap * t_chop) * env_slap * blade_weight
		if phase < 0.08:
			var shock_pressure = sin(phase / 0.08 * PI)
			slap += shock_pressure * 0.50 * blade_weight

		# 2. Resonant Acoustic Body Thump (Synchronous 88 Hz fundamental + 176 Hz 1st harmonic)
		var env_thump = exp(-phase * 8.0) * sin(minf(phase * 4.5, 1.0) * PI)
		var thump = sin(2.0 * PI * 88.0 * t_chop) * env_thump * 0.82
		var thump_harm = sin(2.0 * PI * 176.0 * t_chop) * env_thump * 0.32

		# 3. Turbulent Vortex Shedding & Rotor Downwash Wash
		var wash_env = pow(sin(phase * PI), 1.5) * exp(-phase * 2.6)
		var n_idx = (i * 3) % noise_len
		var blade_wash = noise_table[n_idx] * wash_env * 0.38

		# 4. Turboshaft Jet Engine Whine (Dual tone 780 Hz & 1560 Hz + high-speed exhaust hiss)
		# Exactly 1560 & 3120 cycles in 44100 samples -> 100% phase-continuous across loop boundary
		var hiss_idx = (i * 5) % noise_len
		var exhaust = noise_table[hiss_idx] * 0.07
		var turbine = (sin(2.0 * PI * 780.0 * t) * 0.15 + sin(2.0 * PI * 1560.0 * t) * 0.08 + exhaust)

		# 5. Tail Rotor High-Speed Anti-Torque Whir (~90 Hz fundamental + 270 Hz harmonic)
		var tail_phase = float(sample_in_chop % int(chop_period / 5.0)) / (chop_period / 5.0)
		var tail_env = exp(-tail_phase * 6.5)
		var tail = (sin(2.0 * PI * 90.0 * t) * 0.14 + sin(2.0 * PI * 270.0 * t) * 0.06 * tail_env)

		# Combined and soft-saturated for authoritative military presence
		var combined = slap * 0.70 + (thump + thump_harm) * 0.65 + blade_wash * 0.35 + turbine * 0.32 + tail * 0.20
		var sample = tanh(combined * 1.55) * 0.88
		var int_val = int(clampf(sample * 32767.0, -32767.0, 32767.0))
		bytes.encode_s16(i * 2, int_val)

	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = total_samples
	return wav

func _create_mg_sound() -> AudioStreamWAV:
	var num_samples = int(0.06 * MIX_RATE)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / float(MIX_RATE)
		var env = exp(-t * 55.0)
		var noise = randf_range(-1.0, 1.0)
		var tone = sin(2.0 * PI * 160.0 * t)
		var sample = (tone * 0.4 + noise * 0.6) * env * 24000.0
		bytes.encode_s16(i * 2, int(clampf(sample, -32767.0, 32767.0)))
	return _build_wav(bytes)

func _create_missile_sound() -> AudioStreamWAV:
	var num_samples = int(0.32 * MIX_RATE)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / float(MIX_RATE)
		var env = 1.0 - (float(i) / float(num_samples))
		var freq = 130.0 + (t * 600.0)
		var tone = sin(2.0 * PI * freq * t)
		var noise = randf_range(-0.5, 0.5)
		var sample = (tone * 0.6 + noise * 0.4) * env * 22000.0
		bytes.encode_s16(i * 2, int(clampf(sample, -32767.0, 32767.0)))
	return _build_wav(bytes)

func _create_rocket_sound() -> AudioStreamWAV:
	var num_samples = int(0.42 * MIX_RATE)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / float(MIX_RATE)
		var env = exp(-t * 12.0)
		var sub = sin(2.0 * PI * 75.0 * t)
		var noise = randf_range(-0.8, 0.8)
		var sample = (sub * 0.6 + noise * 0.4) * env * 28000.0
		bytes.encode_s16(i * 2, int(clampf(sample, -32767.0, 32767.0)))
	return _build_wav(bytes)

func _create_shotgun_sound() -> AudioStreamWAV:
	var num_samples = int(0.14 * MIX_RATE)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / float(MIX_RATE)
		var env = exp(-t * 30.0)
		var noise = randf_range(-1.0, 1.0)
		var thump = sin(2.0 * PI * 110.0 * t)
		var sample = (thump * 0.5 + noise * 0.5) * env * 30000.0
		bytes.encode_s16(i * 2, int(clampf(sample, -32767.0, 32767.0)))
	return _build_wav(bytes)

func _create_explosion_sound(duration: float, rumble: float) -> AudioStreamWAV:
	var num_samples = int(duration * MIX_RATE)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / float(MIX_RATE)
		var env = exp(-t * (4.5 / duration))
		var noise = randf_range(-1.0, 1.0)
		var low_rumble = sin(2.0 * PI * 55.0 * t) * rumble
		var sample = (noise * (1.0 - rumble) + low_rumble) * env * 28000.0
		bytes.encode_s16(i * 2, int(clampf(sample, -32767.0, 32767.0)))
	return _build_wav(bytes)

func _create_thunder_sound() -> AudioStreamWAV:
	var num_samples = int(1.6 * MIX_RATE)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / float(MIX_RATE)
		var crack = exp(-t * 22.0) * randf_range(-1.0, 1.0) * 0.75
		var rumble_env = sin(clampf(t / 0.15, 0.0, 1.0) * PI * 0.5) * exp(-t * 2.2)
		var sub1 = sin(2.0 * PI * 42.0 * t + sin(2.0 * PI * 4.0 * t) * 1.5)
		var sub2 = sin(2.0 * PI * 68.0 * t) * 0.65
		var low_noise = randf_range(-0.4, 0.4) * exp(-t * 3.0)
		var sample = (crack + (sub1 + sub2 + low_noise) * rumble_env * 0.85) * 29000.0
		bytes.encode_s16(i * 2, int(clampf(sample, -32767.0, 32767.0)))
	return _build_wav(bytes)

func _create_touchdown_sound() -> AudioStreamWAV:
	var num_samples = int(0.24 * MIX_RATE)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / float(MIX_RATE)
		var env = exp(-t * 18.0)
		var thud = sin(2.0 * PI * 62.0 * exp(-t * 12.0) * t) * 0.7
		var hiss = randf_range(-0.35, 0.35) * exp(-t * 25.0)
		var sample = (thud + hiss) * env * 26000.0
		bytes.encode_s16(i * 2, int(clampf(sample, -32767.0, 32767.0)))
	return _build_wav(bytes)

func _create_flare_sound() -> AudioStreamWAV:
	var num_samples = int(0.35 * MIX_RATE)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / float(MIX_RATE)
		var env = exp(-t * 9.0)
		var noise = randf_range(-0.8, 0.8)
		var hiss = sin(2.0 * PI * 1800.0 * t) * 0.2
		var sample = (noise + hiss) * env * 20000.0
		bytes.encode_s16(i * 2, int(clampf(sample, -32767.0, 32767.0)))
	return _build_wav(bytes)

func _create_hit_sound() -> AudioStreamWAV:
	var num_samples = int(0.06 * MIX_RATE)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / float(MIX_RATE)
		var env = exp(-t * 60.0)
		var click = sin(2.0 * PI * 220.0 * t)
		var sample = click * env * 26000.0
		bytes.encode_s16(i * 2, int(clampf(sample, -32767.0, 32767.0)))
	return _build_wav(bytes)

func _create_pickup_sound() -> AudioStreamWAV:
	var num_samples = int(0.18 * MIX_RATE)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / float(MIX_RATE)
		var freq = 523.25 if t < 0.08 else 659.25 # C5 to E5 arpeggio
		var env = exp(-(fmod(t, 0.08)) * 25.0)
		var tone = sin(2.0 * PI * freq * t)
		var sample = tone * env * 18000.0
		bytes.encode_s16(i * 2, int(clampf(sample, -32767.0, 32767.0)))
	return _build_wav(bytes)

func _create_beep_sound(freq: float, duration: float) -> AudioStreamWAV:
	var num_samples = int(duration * MIX_RATE)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / float(MIX_RATE)
		var tone = 1.0 if sin(2.0 * PI * freq * t) > 0.0 else -1.0 # Square wave for sharp military warning
		var sample = tone * 15000.0
		bytes.encode_s16(i * 2, int(clampf(sample, -32767.0, 32767.0)))
	return _build_wav(bytes)

func _create_alarm_sound() -> AudioStreamWAV:
	var num_samples = int(0.25 * MIX_RATE)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / float(MIX_RATE)
		var freq = 650.0 if fmod(t, 0.12) < 0.06 else 440.0
		var tone = sin(2.0 * PI * freq * t)
		var sample = tone * 18000.0
		bytes.encode_s16(i * 2, int(clampf(sample, -32767.0, 32767.0)))
	return _build_wav(bytes)

func _create_super_sound() -> AudioStreamWAV:
	var num_samples = int(0.85 * MIX_RATE)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / float(MIX_RATE)
		var freq = 120.0 + (t * 850.0)
		var tone1 = sin(2.0 * PI * freq * t)
		var tone2 = sin(2.0 * PI * (freq * 1.5) * t) * 0.5
		var env = minf(t * 3.0, 1.0) * exp(-t * 2.0)
		var sample = (tone1 + tone2) * env * 24000.0
		bytes.encode_s16(i * 2, int(clampf(sample, -32767.0, 32767.0)))
	return _build_wav(bytes)

func _create_level_up_sound() -> AudioStreamWAV:
	var num_samples = int(0.35 * MIX_RATE)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / float(MIX_RATE)
		var freq = 523.25
		if t >= 0.2:
			freq = 783.99 # G5
		elif t >= 0.1:
			freq = 659.25 # E5
		var env = exp(-(fmod(t, 0.1)) * 20.0)
		var tone = sin(2.0 * PI * freq * t)
		var sample = tone * env * 20000.0
		bytes.encode_s16(i * 2, int(clampf(sample, -32767.0, 32767.0)))
	return _build_wav(bytes)

func _create_crit_sound() -> AudioStreamWAV:
	var num_samples = int(0.22 * MIX_RATE)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / float(MIX_RATE)
		var punch_freq = 320.0 * exp(-t * 18.0) + 70.0
		var chime_freq = 1760.0 # A6
		var punch = sin(2.0 * PI * punch_freq * t)
		var chime = sin(2.0 * PI * chime_freq * t) * 0.7
		var env = exp(-t * 16.0)
		var sample = (punch * 0.7 + chime * 0.5) * env * 25000.0
		bytes.encode_s16(i * 2, int(clampf(sample, -32767.0, 32767.0)))
	return _build_wav(bytes)

func _create_compliment_sound() -> AudioStreamWAV:
	var num_samples = int(0.28 * MIX_RATE)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / float(MIX_RATE)
		var freq = 659.25 # E5
		if t >= 0.16:
			freq = 1318.5 # E6 triumphant high note
		elif t >= 0.08:
			freq = 987.77 # B5
		var env = exp(-(fmod(t, 0.08)) * 14.0) * (1.0 - t / 0.32)
		var tone = sin(2.0 * PI * freq * t) + sin(2.0 * PI * (freq * 2.0) * t) * 0.3
		var sample = tone * env * 21000.0
		bytes.encode_s16(i * 2, int(clampf(sample, -32767.0, 32767.0)))
	return _build_wav(bytes)

func _create_ui_click_sound() -> AudioStreamWAV:
	var num_samples = int(0.04 * MIX_RATE)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / float(MIX_RATE)
		var freq = 1400.0 * exp(-t * 80.0) + 400.0
		var env = exp(-t * 90.0)
		var tone = sin(2.0 * PI * freq * t)
		var sample = tone * env * 22000.0
		bytes.encode_s16(i * 2, int(clampf(sample, -32767.0, 32767.0)))
	return _build_wav(bytes)

func _create_ui_buy_sound() -> AudioStreamWAV:
	var num_samples = int(0.24 * MIX_RATE)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / float(MIX_RATE)
		var freq = 587.33 if t < 0.10 else 880.0 # D5 -> A5
		var env = exp(-(fmod(t, 0.10)) * 22.0) * (1.0 - t / 0.28)
		var tone = sin(2.0 * PI * freq * t) + sin(2.0 * PI * (freq * 2.0) * t) * 0.25
		var sample = tone * env * 20000.0
		bytes.encode_s16(i * 2, int(clampf(sample, -32767.0, 32767.0)))
	return _build_wav(bytes)

func _create_ui_hover_sound() -> AudioStreamWAV:
	var num_samples = int(0.02 * MIX_RATE)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / float(MIX_RATE)
		var freq = 1760.0
		var env = exp(-t * 220.0)
		var tone = sin(2.0 * PI * freq * t)
		var sample = tone * env * 8000.0
		bytes.encode_s16(i * 2, int(clampf(sample, -32767.0, 32767.0)))
	return _build_wav(bytes)

func _create_ui_denied_sound() -> AudioStreamWAV:
	var num_samples = int(0.18 * MIX_RATE)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / float(MIX_RATE)
		var freq = 200.0 if t < 0.08 else 140.0 # Low double buzzer
		var tone = sin(2.0 * PI * freq * t) + sin(2.0 * PI * (freq * 2.0) * t) * 0.4
		var env = exp(-(fmod(t, 0.08)) * 28.0)
		var sample = tone * env * 20000.0
		bytes.encode_s16(i * 2, int(clampf(sample, -32767.0, 32767.0)))
	return _build_wav(bytes)

func _create_victory_sound() -> AudioStreamWAV:
	var num_samples = int(0.65 * MIX_RATE)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / float(MIX_RATE)
		var freq = 523.25 # C5
		if t >= 0.40:
			freq = 1046.50 # C6
		elif t >= 0.26:
			freq = 783.99 # G5
		elif t >= 0.13:
			freq = 659.25 # E5
		var step_t = fmod(t, 0.13) if t < 0.40 else (t - 0.40)
		var env = exp(-step_t * (12.0 if t < 0.40 else 5.0))
		var tone = sin(2.0 * PI * freq * t) + sin(2.0 * PI * (freq * 1.5) * t) * 0.2
		var sample = tone * env * 23000.0
		bytes.encode_s16(i * 2, int(clampf(sample, -32767.0, 32767.0)))
	return _build_wav(bytes)

func _create_high_score_sound() -> AudioStreamWAV:
	# 5-note ascending fanfare chime (C5 -> E5 -> G5 -> B5 -> C6) with rich sparkling harmonics
	var num_samples = int(0.85 * MIX_RATE)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / float(MIX_RATE)
		var freq = 523.25 # C5
		if t >= 0.50:
			freq = 1046.50 # C6
		elif t >= 0.38:
			freq = 987.77 # B5
		elif t >= 0.26:
			freq = 783.99 # G5
		elif t >= 0.13:
			freq = 659.25 # E5
		var step_t = fmod(t, 0.125) if t < 0.50 else (t - 0.50)
		var env = exp(-step_t * (10.0 if t < 0.50 else 3.8))
		# Crystal retro chime harmonics
		var tone = sin(2.0 * PI * freq * t) + sin(4.0 * PI * freq * t) * 0.3 + sin(6.0 * PI * freq * t) * 0.12
		var sample = tone * env * 24000.0
		bytes.encode_s16(i * 2, int(clampf(sample, -32767.0, 32767.0)))
	return _build_wav(bytes)

func _create_defeat_sound() -> AudioStreamWAV:
	var num_samples = int(0.70 * MIX_RATE)
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / float(MIX_RATE)
		var freq = 130.0 * exp(-t * 3.5) + 38.0
		var env = exp(-t * 4.0)
		var tone = sin(2.0 * PI * freq * t)
		var noise = randf_range(-0.4, 0.4) * exp(-t * 7.0)
		var sample = (tone * 0.7 + noise * 0.3) * env * 26000.0
		bytes.encode_s16(i * 2, int(clampf(sample, -32767.0, 32767.0)))
	return _build_wav(bytes)

# ------------------------------------------------------------------------------
# Procedural Retro Synth BGM Generators (8-beat loops at 128 BPM)
# ------------------------------------------------------------------------------
func _build_looping_wav(samples: PackedByteArray, num_samples: int) -> AudioStreamWAV:
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = samples
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = num_samples
	return wav

func _create_calm_stream() -> AudioStreamWAV:
	var beat_dur: float = 60.0 / BGM_BPM
	var num_samples: int = int(8.0 * beat_dur * float(MIX_RATE))
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	var sixteenth_dur: float = beat_dur * 0.25
	var inv_mix_rate: float = 1.0 / float(MIX_RATE)
	var scale_notes = [293.66, 349.23, 440.0, 523.25]
	var two_pi: float = 2.0 * PI
	
	for i in range(num_samples):
		var t = float(i) * inv_mix_rate
		var sixteenth_idx = int(t / sixteenth_dur) % 32
		var note_t = fmod(t, sixteenth_dur)
		var two_pi_t = two_pi * t
		
		# Analog warm sub drone (D2: 73.42Hz, D3: 146.83Hz)
		var drone = (sin(73.42 * two_pi_t) * 0.40 + sin(146.83 * two_pi_t) * 0.20) * (0.8 + 0.2 * sin(t * 1.5))
		
		# Atmospheric 8th-note FM synth plucks
		var arp_freq = scale_notes[int(sixteenth_idx / 2.0) % 4]
		var env = exp(-note_t * 9.0)
		var arp = sin(arp_freq * two_pi_t + sin(arp_freq * 2.0 * two_pi_t) * 0.3) * env * 0.35
		
		var sample = (drone + arp) * 19000.0
		bytes.encode_s16(i * 2, int(clampf(sample, -32767.0, 32767.0)))
		
	return _build_looping_wav(bytes, num_samples)

func _create_combat_stream() -> AudioStreamWAV:
	var beat_dur: float = 60.0 / BGM_BPM
	var num_samples: int = int(8.0 * beat_dur * float(MIX_RATE))
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	var sixteenth_dur: float = beat_dur * 0.25
	var inv_mix_rate: float = 1.0 / float(MIX_RATE)
	var two_pi: float = 2.0 * PI
	
	var bass_notes = [
		73.42, 146.83, 73.42, 146.83, 73.42, 146.83, 87.31, 146.83,
		73.42, 146.83, 73.42, 146.83, 73.42, 146.83, 110.0, 98.0,
		87.31, 174.61, 87.31, 174.61, 87.31, 174.61, 130.81, 174.61,
		87.31, 174.61, 87.31, 174.61, 87.31, 174.61, 110.0, 130.81
	]
	
	var lead_notes = [
		293.66, 349.23, 440.0, 523.25, 440.0, 349.23, 293.66, 349.23,
		440.0, 523.25, 587.33, 523.25, 440.0, 349.23, 440.0, 523.25,
		349.23, 440.0, 523.25, 659.25, 523.25, 440.0, 349.23, 440.0,
		523.25, 659.25, 698.46, 659.25, 523.25, 440.0, 523.25, 659.25
	]
	
	for i in range(num_samples):
		var t = float(i) * inv_mix_rate
		var sixteenth_idx = int(t / sixteenth_dur) % 32
		var note_t = fmod(t, sixteenth_dur)
		var beat_idx = int(t / beat_dur) % 8
		var beat_t = fmod(t, beat_dur)
		var two_pi_t = two_pi * t
		
		# Driving resonant electro-bass
		var b_freq = bass_notes[sixteenth_idx]
		var b_env = exp(-note_t * 18.0)
		var b_tone = sin(b_freq * two_pi_t) + 0.45 * sin(b_freq * 2.0 * two_pi_t)
		var bass = b_tone * b_env * 0.48
		
		# Retro cyber lead arp
		var l_freq = lead_notes[sixteenth_idx]
		var l_env = exp(-note_t * 12.0)
		var lead = sin(l_freq * two_pi_t) * l_env * 0.22
		
		# Punchy 90s arcade techno kick
		var kick_freq = 130.0 * exp(-beat_t * 28.0) + 42.0
		var kick = sin(two_pi * kick_freq * beat_t) * exp(-beat_t * 9.0) * 0.52
		
		# Snare backbeat on beats 2 & 4
		var snare = 0.0
		if beat_idx % 2 == 1:
			var s_env = exp(-beat_t * 22.0)
			var s_thump = sin(two_pi * 175.0 * beat_t) * 0.35
			var s_noise = (fmod(sin(t * 12345.67) * 43758.5453, 2.0) - 1.0) * 0.65
			snare = (s_thump + s_noise) * s_env * 0.42
			
		# Metallic 16th hi-hat
		var hat = 0.0
		if sixteenth_idx % 2 == 1:
			var h_env = exp(-note_t * 45.0)
			var h_noise = (fmod(sin(t * 98765.43) * 23421.1234, 2.0) - 1.0)
			hat = h_noise * h_env * 0.16
			
		var sample = (bass + lead + kick + snare + hat) * 18500.0
		bytes.encode_s16(i * 2, int(clampf(sample, -32767.0, 32767.0)))
		
	return _build_looping_wav(bytes, num_samples)

func _create_boss_stream() -> AudioStreamWAV:
	var beat_dur: float = 60.0 / BGM_BPM
	var num_samples: int = int(8.0 * beat_dur * float(MIX_RATE))
	var bytes = PackedByteArray()
	bytes.resize(num_samples * 2)
	var sixteenth_dur: float = beat_dur * 0.25
	var inv_mix_rate: float = 1.0 / float(MIX_RATE)
	var two_pi: float = 2.0 * PI
	
	# Urgent minor chords: Dm, Bb
	var chord_roots = [73.42, 58.27]
	
	for i in range(num_samples):
		var t = float(i) * inv_mix_rate
		var bar_idx = int(t / (beat_dur * 4.0)) % 2
		var beat_idx = int(t / beat_dur) % 8
		var beat_t = fmod(t, beat_dur)
		var sixteenth_idx = int(t / sixteenth_dur) % 32
		var note_t = fmod(t, sixteenth_dur)
		var two_pi_t = two_pi * t
		
		# Heavy aggressive saw bass
		var root = chord_roots[bar_idx]
		var b_env = exp(-note_t * 14.0)
		var saw = (fmod(t * root, 1.0) - 0.5) * 2.0
		var sub = sin(root * two_pi_t)
		var bass = (sub * 0.6 + saw * 0.4) * b_env * 0.55
		
		# Double-time industrial kick
		var sub_beat_t = fmod(beat_t, beat_dur * 0.5)
		var kick_freq = 150.0 * exp(-sub_beat_t * 32.0) + 40.0
		var kick = sin(two_pi * kick_freq * sub_beat_t) * exp(-sub_beat_t * 12.0) * 0.55
		
		# Harsh industrial snare on backbeats
		var snare = 0.0
		if beat_idx % 2 == 1:
			var s_env = exp(-beat_t * 18.0)
			var s_noise = (fmod(sin(t * 34567.89) * 43758.5453, 2.0) - 1.0)
			snare = s_noise * s_env * 0.48
			
		# Frantic alarm arpeggio (high pitch)
		var arp_notes = [587.33, 698.46, 880.0, 1046.50]
		var arp_freq = arp_notes[sixteenth_idx % 4]
		var a_env = exp(-note_t * 16.0)
		var alarm_arp = sin(arp_freq * two_pi_t) * a_env * 0.28
		
		var sample = (bass + kick + snare + alarm_arp) * 18500.0
		bytes.encode_s16(i * 2, int(clampf(sample, -32767.0, 32767.0)))
		
	return _build_looping_wav(bytes, num_samples)

