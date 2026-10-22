import math
import struct
import wave
import random

def generate_helicopter_sound(output_path="assets/audio/sfx/helicopter_rotor_loop.wav"):
    sample_rate = 22050
    # 45 chops over 44100 samples = exactly 980 samples per chop (22.5 Hz chop, 337.5 RPM Apache)
    chop_period_samples = 980
    num_chops = 45
    total_samples = chop_period_samples * num_chops # 44100 samples = exactly 2.0 seconds
    
    samples = []
    
    # Random noise table with seamless wrap
    noise_len = 8192
    random.seed(42)
    noise_table = [random.uniform(-1.0, 1.0) for _ in range(noise_len)]
    
    for i in range(total_samples):
        t = float(i) / float(sample_rate)
        
        # 1. Main Rotor Blade Chop (22.5 Hz pulse train)
        phase_chop = (i % chop_period_samples) / float(chop_period_samples) # 0.0 to 1.0
        
        # Asymmetric aerodynamic blade impulse: sharp pressure rise, turbulent expansion
        # Characteristic "whop" waveform
        if phase_chop < 0.18:
            pulse = math.sin(phase_chop / 0.18 * math.pi)
        elif phase_chop < 0.55:
            pulse = -0.45 * math.sin((phase_chop - 0.18) / 0.37 * math.pi)
        else:
            pulse = 0.0
            
        # Add acoustic harmonics to the blade slap (55Hz sub, 110Hz body, 220Hz slap)
        sub_thump = math.sin(2.0 * math.pi * 55.0 * t) * (0.8 + 0.2 * pulse)
        body_thump = math.sin(2.0 * math.pi * 110.0 * t) * (pulse ** 2 if pulse > 0 else 0)
        
        # Blade turbulence noise modulated by chop phase
        n_idx = int((t * 2400.0)) % noise_len
        n_val = noise_table[n_idx]
        blade_wash = n_val * (0.35 * max(0.0, pulse) + 0.10)
        
        chop_layer = (pulse * 0.55 + sub_thump * 0.35 + body_thump * 0.25 + blade_wash * 0.25)
        
        # 2. Turboshaft Jet Engine Turbine Whine (dual tone 1250 Hz & 2500 Hz)
        turbine_tone1 = math.sin(2.0 * math.pi * 1260.0 * t) * 0.09
        turbine_tone2 = math.sin(2.0 * math.pi * 2520.0 * t) * 0.04
        # Turboshaft steady exhaust hiss
        n_hiss_idx = int((t * 5200.0)) % noise_len
        exhaust_hiss = noise_table[n_hiss_idx] * 0.06
        turbine_layer = turbine_tone1 + turbine_tone2 + exhaust_hiss
        
        # 3. Tail Rotor High-Speed Whir (~75 Hz)
        tail_rotor = math.sin(2.0 * math.pi * 75.0 * t) * 0.12
        
        # Combined Signal
        combined = (chop_layer * 0.72) + (turbine_layer * 0.45) + (tail_rotor * 0.30)
        
        # Soft saturation / tube compression to give heavy military warmth
        val = math.tanh(combined * 1.5) * 0.85
        
        # 16-bit PCM int clamp
        int_sample = int(clamp(val * 32767.0, -32767.0, 32767.0))
        samples.append(int_sample)
        
    import os
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with wave.open(output_path, "wb") as wav_file:
        wav_file.setnchannels(1) # Mono for 3D positional audio
        wav_file.setsampwidth(2) # 16-bit
        wav_file.setframerate(sample_rate)
        packed = struct.pack(f"<{len(samples)}h", *samples)
        wav_file.writeframes(packed)
        
    print(f"Generated seamless helicopter rotor loop: {output_path} ({total_samples} samples, {total_samples/sample_rate:.2f}s)")

def clamp(v, low, high):
    return max(low, min(high, v))

if __name__ == "__main__":
    generate_helicopter_sound()
