shader_type spatial;
render_mode cull_disabled, blend_mix, unshaded;

uniform vec4 border_color : source_color = vec4(1.0, 0.15, 0.10, 0.38);
uniform vec4 line_color : source_color = vec4(1.0, 0.55, 0.20, 0.95);
uniform float grid_density_y = 0.6;
uniform float grid_density_h = 0.2;
uniform float pulse_intensity = 1.0;

void fragment() {
	float t = TIME * 2.5;
	// Laser scanlines drifting upwards
	float scan_y = step(0.85, fract(VERTEX.y * grid_density_y - t * 0.5));
	// Vertical energy barrier beams
	float fence_x = step(0.90, fract((VERTEX.x + VERTEX.z) * grid_density_h));
	// Warning chevron stripes along the bottom
	float chevron = 0.0;
	if (VERTEX.y < 8.0) {
		chevron = step(0.5, fract((VERTEX.x + VERTEX.z + VERTEX.y * 1.5) * 0.35)) * 0.4;
	}
	float grid = clamp(scan_y + fence_x + chevron, 0.0, 1.0);

	// Gentle ambient pulsation
	float pulse = 0.5 + 0.5 * sin(t * 2.0 + VERTEX.y * 0.3);

	// Height fade (bright from ground up to 35m, gradual fade to 55m)
	float h_factor = clamp(1.0 - (VERTEX.y / 55.0), 0.2, 1.0);

	vec3 col = mix(border_color.rgb, line_color.rgb, grid);
	col *= (1.2 + pulse * 0.4 * pulse_intensity + grid * 0.8);

	ALBEDO = col;
	ALPHA = clamp(mix(border_color.a, line_color.a, grid) * h_factor * (0.8 + 0.2 * pulse), 0.0, 0.95);
}
