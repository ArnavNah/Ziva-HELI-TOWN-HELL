shader_type canvas_item;

// Professional Tactical Low-Health Blood & Damage Vignette
// Provides immersive, high-end peripheral crimson blood pooling, pulsing heartbeat,
// and hit trauma flash that never obstructs central crosshair aiming.

uniform float blood_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_speed : hint_range(1.0, 12.0) = 4.0;
uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 blood_color : source_color = vec4(0.88, 0.04, 0.04, 1.0);
uniform vec4 deep_blood_color : source_color = vec4(0.52, 0.02, 0.04, 1.0);

// Procedural pseudo-noise for organic cellular blood edges
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 3; i++) {
		v += a * noise(p);
		p = rot * p * 2.0;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	if (blood_intensity <= 0.001 && hit_flash <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		vec2 uv = UV;
		vec2 center_offset = uv - vec2(0.5);
		
		// Radial distance from screen center (0.0 at center, ~0.71 at edges, ~1.0 at corners)
		float dist = length(center_offset) * 1.414;
		
		// Heartbeat pulse rhythm (systolic spike followed by diastolic fade)
		float beat_phase = TIME * pulse_speed;
		float beat = pow(max(0.0, sin(beat_phase)), 3.0) * 0.35;
		
		// Organic capillary & blood splatter distortion
		float edge_noise = fbm(uv * 7.0 + vec2(sin(TIME * 0.2), cos(TIME * 0.2)) * 0.10);
		float spatter = fbm(uv * 18.0) * 0.35;
		
		// Blood reaches inwards from borders as health drops
		float inner_rim = clamp(0.75 - (blood_intensity * 0.42 + beat * 0.15 + hit_flash * 0.28), 0.22, 0.80);
		float outer_rim = inner_rim + 0.30;
		float blood_mask = smoothstep(inner_rim, outer_rim, dist + (edge_noise - 0.5) * 0.22 + (spatter - 0.5) * 0.20);
		
		// Pronounced corner blood pooling
		float corner_factor = pow(abs(center_offset.x) * 2.0, 2.0) * pow(abs(center_offset.y) * 2.0, 2.0) * 3.5;
		blood_mask = clamp(blood_mask + corner_factor * 0.85, 0.0, 1.0);
		
		// Color grading: rich arterial crimson inside, dark coagulated dried blood on outer edges
		vec3 col = mix(blood_color.rgb, deep_blood_color.rgb, smoothstep(0.35, 0.90, dist));
		
		// Hit flash illuminates blood with intense crimson shock
		col += vec3(0.40, 0.05, 0.05) * hit_flash;
		
		// Alpha calculation: prominent, punchy, tactical look
		float base_alpha = blood_intensity * 0.92 + beat * 0.25 + hit_flash * 0.70;
		float final_alpha = blood_mask * clamp(base_alpha, 0.0, 0.95);
		COLOR = vec4(col, final_alpha);
	}
}
