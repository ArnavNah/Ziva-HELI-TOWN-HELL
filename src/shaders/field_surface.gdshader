shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform vec4 base_color : source_color = vec4(1.0);
uniform float variation : hint_range(0.0, 0.2) = 0.035;
uniform float wind_strength : hint_range(0.0, 0.5) = 0.0;
uniform bool use_texture = false;
uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec2 uv_scale = vec2(1.0);
uniform bool use_vertex_tint = true;
uniform float texture_strength : hint_range(0.0, 1.0) = 0.35;
varying vec3 world_pos;
varying vec3 world_normal;
float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}
void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.x += sin(TIME * 1.8 + world.x * 0.24 + world.z * 0.19)
		* wind_strength * max(VERTEX.y, 0.0);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	if (use_texture) {
		vec3 tex_col = texture(albedo_texture, UV * uv_scale).rgb;
		vec3 v_tint = use_vertex_tint ? COLOR.rgb : vec3(1.0);
		if (use_vertex_tint) {
			float detail = clamp(dot(tex_col, vec3(0.2126, 0.7152, 0.0722)) * 2.0, 0.65, 1.25);
			ALBEDO = base_color.rgb * v_tint * mix(1.0, detail, texture_strength);
		} else {
			ALBEDO = tex_col * base_color.rgb;
		}
	} else {
		float grain = (hash31(floor(world_pos * 1.5)) - 0.5) * variation;
		ALBEDO = base_color.rgb * COLOR.rgb * (1.0 + grain);
		ALBEDO *= mix(0.93, 1.04, smoothstep(0.3, 0.9, world_normal.y));
		float luminance = dot(ALBEDO, vec3(0.2126, 0.7152, 0.0722));
		ALBEDO = mix(vec3(luminance), ALBEDO, 0.97) * 0.95;
	}
	ROUGHNESS = 0.95;
	METALLIC = 0.0;
}
void light() {
	float diffuse = max(dot(NORMAL, LIGHT), 0.0);
	float band = mix(0.35, 0.72, smoothstep(0.12, 0.16, diffuse));
	band = mix(band, 1.0, smoothstep(0.62, 0.66, diffuse));
	// Attenuate the entire direct contribution: shadows must remain shadows.
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * band * ATTENUATION / 3.14159265;
}
