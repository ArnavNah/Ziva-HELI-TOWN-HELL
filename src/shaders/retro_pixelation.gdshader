shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform bool enable_pixelation = false;
uniform float pixel_size : hint_range(1.0, 8.0) = 2.0;
uniform bool enable_dither = false;
uniform float color_depth : hint_range(8.0, 64.0) = 32.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	if (enable_pixelation && pixel_size > 1.0) {
		vec2 screen_size = vec2(textureSize(screen_texture, 0));
		vec2 coord = floor(uv * screen_size / pixel_size) * pixel_size / screen_size;
		uv = coord;
	}
	vec3 col = texture(screen_texture, uv).rgb;
	if (enable_dither) {
		int x = int(mod(FRAGCOORD.x / pixel_size, 4.0));
		int y = int(mod(FRAGCOORD.y / pixel_size, 4.0));
		mat4 bayer = mat4(
			vec4( 0.0, 12.0,  3.0, 15.0) / 16.0,
			vec4( 8.0,  4.0, 11.0,  7.0) / 16.0,
			vec4( 2.0, 14.0,  1.0, 13.0) / 16.0,
			vec4(10.0,  6.0,  9.0,  5.0) / 16.0
		);
		float dither = (bayer[x][y] - 0.5) / color_depth;
		col = floor((col + dither) * color_depth + 0.5) / color_depth;
	}
	COLOR = vec4(col, 1.0);
}
