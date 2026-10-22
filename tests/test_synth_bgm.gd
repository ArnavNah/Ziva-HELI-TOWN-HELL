extends SceneTree

const MIX_RATE: int = 22050
const BPM: float = 128.0

func _init() -> void:
	print("--- TESTING RETRO SYNTH BGM GENERATION ---")
	var t0 = Time.get_ticks_msec()
	
	var calm_wav = _create_calm_stream()
	var combat_wav = _create_combat_stream()
	var boss_wav = _create_boss_stream()
	
	var elapsed = Time.get_ticks_msec() - t0
	print("All 3 BGM streams generated in: ", elapsed, " ms")
	
	assert(calm_wav != null and calm_wav.data.size() > 0)
	assert(combat_wav != null and combat_wav.data.size() > 0)
	assert(boss_wav != null and boss_wav.data.size() > 0)
	assert(calm_wav.loop_mode == AudioStreamWAV.LOOP_FORWARD)
	assert(combat_wav.loop_mode == AudioStreamWAV.LOOP_FORWARD)
	assert(boss_wav.loop_mode == AudioStreamWAV.LOOP_FORWARD)
	
	print("Calm data bytes: ", calm_wav.data.size())
	print("Combat data bytes: ", combat_wav.data.size())
	print("Boss data bytes: ", boss_wav.data.size())
	print("--- RETRO SYNTH BGM GENERATION SUCCESSFUL ---")
	quit(0)

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
	var beat_dur: float = 60.0 / BPM
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
		
		# Analog warm sub drone
		var drone = (sin(73.42 * two_pi_t) * 0.40 + sin(146.83 * two_pi_t) * 0.20) * (0.8 + 0.2 * sin(t * 1.5))
		
		# Atmospheric 8th-note FM synth plucks
		var arp_freq = scale_notes[(sixteenth_idx / 2) % 4]
		var env = exp(-note_t * 9.0)
		var arp = sin(arp_freq * two_pi_t + sin(arp_freq * 2.0 * two_pi_t) * 0.3) * env * 0.35
		
		var sample = (drone + arp) * 20000.0
		bytes.encode_s16(i * 2, int(clampf(sample, -32767.0, 32767.0)))
		
	return _build_looping_wav(bytes, num_samples)

func _create_combat_stream() -> AudioStreamWAV:
	var beat_dur: float = 60.0 / BPM
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
			
		var sample = (bass + lead + kick + snare + hat) * 19000.0
		bytes.encode_s16(i * 2, int(clampf(sample, -32767.0, 32767.0)))
		
	return _build_looping_wav(bytes, num_samples)

func _create_boss_stream() -> AudioStreamWAV:
	var beat_dur: float = 60.0 / BPM
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
		
		var sample = (bass + kick + snare + alarm_arp) * 19000.0
		bytes.encode_s16(i * 2, int(clampf(sample, -32767.0, 32767.0)))
		
	return _build_looping_wav(bytes, num_samples)
