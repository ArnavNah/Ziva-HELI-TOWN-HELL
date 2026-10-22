shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

// Tactical Toon & Stepped Surface Shader (Page Spec: Compare against Lambert / optional quantization)
// Supports optional vertex snapping (off by default) and 3-tier quantized stepped lighting.

uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.55;
uniform float metallic : hint_range(0.0, 1.0) = 0.15;
uniform bool enable_toon_steps = false;
uniform bool enable_vertex_snapping = false;
uniform float snap_resolution : hint_range(32.0, 512.0) = 180.0;

void vertex() {
	if (enable_vertex_snapping) {
		vec4 snapped = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
		if (abs(snapped.w) > 0.0001) {
			snapped.xy = floor(snapped.xy * snap_resolution / snapped.w) * snapped.w / snap_resolution;
		}
		POSITION = snapped;
	}
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	ALBEDO = tex.rgb * albedo_color.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
}

void light() {
	float n_dot_l = max(dot(NORMAL, LIGHT), 0.0);
	if (enable_toon_steps) {
		// 3-tier stepped toon quantization: shadow tier (0.35), mid tier (0.72), full tier (1.0)
		float band = mix(0.35, 0.72, smoothstep(0.12, 0.16, n_dot_l));
		band = mix(band, 1.0, smoothstep(0.62, 0.66, n_dot_l));
		DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * band * ATTENUATION / 3.14159265;
	} else {
		// Standard smooth Lambert diffuse
		DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * n_dot_l * ATTENUATION / 3.14159265;
	}
}
