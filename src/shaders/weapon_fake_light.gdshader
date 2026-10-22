shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

// Weapon Fake Light Shader — Unshaded Additive UV Falloff Shader
// Inspired by @Smitty_Games "Game Dev Hack about Lights" (https://www.youtube.com/shorts/JP9b5E_G-QY)
// Produces fake light patches, muzzle flashes, and impact bursts without real scene lights or bloom dependencies.
// Depth testing is strictly enabled to respect town geometry and prevent shining through walls.

uniform vec4 tint_color : source_color = vec4(1.0, 0.8, 0.4, 1.0);
uniform float intensity : hint_range(0.0, 10.0) = 2.0;
uniform float falloff_exponent : hint_range(0.1, 8.0) = 2.0;
uniform float uv_scale_x : hint_range(0.1, 10.0) = 1.0;
uniform float uv_scale_y : hint_range(0.1, 10.0) = 1.0;
uniform float core_radius : hint_range(0.0, 1.0) = 0.22;
uniform float core_brightness : hint_range(1.0, 10.0) = 2.8;

// Shape types:
// 0: Radial Star / Soft Core (Player Amber Core + Soft Edge)
// 1: Pointed Diamond Burst (Hostile Pointed / Spiked Red-Orange Burst)
// 2: Directional Fan / Forward Muzzle Flash
// 3: Surface Light Patch (Conforming Ground/Wall Disc, pure edge falloff)
uniform int shape_type : hint_range(0, 3) = 0;
uniform bool is_billboard = false;

void vertex() {
	if (is_billboard) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
			INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
			INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz),
			MODEL_MATRIX[3]
		);
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(uv_scale_x, uv_scale_y);
	vec4 base_color = tint_color * COLOR;
	float alpha = 0.0;
	float core = 0.0;

	if (shape_type == 0) {
		// Radial Star / Soft Core:
		// Circular distance with soft radial falloff and central bright core
		float r = length(p) * 2.0;
		alpha = pow(clamp(1.0 - r, 0.0, 1.0), falloff_exponent);
		core = smoothstep(core_radius, 0.0, r) * core_brightness;
	} else if (shape_type == 1) {
		// Pointed Diamond Burst (Hostile):
		// Sharp diamond falloff + 4-point star cross spikes
		float r_diamond = (abs(p.x) + abs(p.y)) * 1.5;
		float diamond_mask = pow(clamp(1.0 - r_diamond, 0.0, 1.0), falloff_exponent);
		float spikes = pow(clamp(1.0 - abs(p.x) * 4.0, 0.0, 1.0) * clamp(1.0 - abs(p.y) * 4.0, 0.0, 1.0), 2.0);
		alpha = clamp(diamond_mask + spikes * 0.45, 0.0, 1.0);
		float r_center = length(p) * 2.0;
		core = smoothstep(core_radius * 0.85, 0.0, r_center) * (core_brightness * 1.2);
	} else if (shape_type == 2) {
		// Directional Fan / Forward Burst:
		// Stretched along Y axis (representing forward direction) with progressive fan widening
		float forward_dist = length(vec2(p.x * 2.2, p.y));
		alpha = pow(clamp(1.0 - forward_dist, 0.0, 1.0), falloff_exponent);
		core = smoothstep(core_radius, 0.0, forward_dist) * core_brightness;
	} else {
		// Surface Light Patch:
		// Pure circular disc with gentle quadratic falloff fading to absolute zero at quad edge
		float r = length(p) * 2.0;
		alpha = pow(clamp(1.0 - r, 0.0, 1.0), falloff_exponent);
		core = 0.0; // Flat, subtle ambient spill without blinding core
	}

	if (alpha <= 0.001) {
		discard;
	}

	vec3 out_rgb = base_color.rgb * (1.0 + core) * intensity;
	ALBEDO = out_rgb;
	ALPHA = clamp(alpha * base_color.a, 0.0, 1.0);
}
