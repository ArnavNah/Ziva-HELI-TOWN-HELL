shader_type spatial;
render_mode cull_front, unshaded, blend_mix, depth_draw_opaque;

// Selective Silhouette Outline Shader (Page Spec: Inverted Hull for Characters & Important Props)
// Subtle, high-readability hairline tactical ink outline that grounds combat units without overwhelming geometry.

uniform vec4 outline_color : source_color = vec4(0.12, 0.14, 0.16, 0.70);
uniform float outline_width : hint_range(0.002, 0.04) = 0.008;
uniform bool outline_enabled = true;

void vertex() {
	if (outline_enabled) {
		VERTEX += NORMAL * outline_width;
	}
}

void fragment() {
	if (!outline_enabled) {
		discard;
	}
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a;
}
