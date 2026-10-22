shader_type canvas_item;
void fragment() {
	vec2 uv = UV;
	vec3 base = mix(vec3(0.027, 0.055, 0.071), vec3(0.075, 0.135, 0.16), uv.x);
	vec2 cell = abs(fract(uv * vec2(64.0, 36.0)) - 0.5);
	float grid = step(0.486, max(cell.x, cell.y));
	base += vec3(0.018, 0.033, 0.031) * grid;
	float halo = max(0.0, 1.0 - length((uv - vec2(0.76, 0.45)) * vec2(1.0, 1.3)) * 2.0);
	base += vec3(0.02, 0.045, 0.033) * halo;
	COLOR = vec4(base, 1.0);
}
