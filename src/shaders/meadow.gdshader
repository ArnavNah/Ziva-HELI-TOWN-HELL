shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform sampler2D grass_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 grass_deep : source_color = vec4(0.18, 0.34, 0.13, 1.0);
uniform vec4 grass_mid : source_color = vec4(0.30, 0.50, 0.18, 1.0);
uniform vec4 grass_bright : source_color = vec4(0.44, 0.63, 0.25, 1.0);
uniform vec4 grass_warm : source_color = vec4(0.54, 0.66, 0.30, 1.0);
uniform float uv_scale = 0.125;
uniform bool enable_toon_steps = false;
uniform bool enable_vertex_snapping = false;
varying vec3 world_pos;
varying vec3 world_normal;
float hash21(vec2 p) {
    vec3 h = fract(vec3(p.xyx) * 0.1031);
    h += dot(h, h.yzx + 33.33);
    return fract((h.x + h.y) * h.z);
}
float noise21(vec2 p) {
    vec2 i = floor(p);
    vec2 f = smoothstep(vec2(0.0), vec2(1.0), fract(p));
    return mix(mix(hash21(i), hash21(i + vec2(1, 0)), f.x),
        mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1, 1)), f.x), f.y);
}
void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
    vec4 p = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
    if (enable_vertex_snapping) {
        if (p.w > 0.1) { p.xy = floor(p.xy / p.w * 320.0 + 0.5) / 320.0 * p.w; }
    }
    POSITION = p;
}
void fragment() {
    float patch = noise21(world_pos.xz * 0.042) * 0.72 + noise21(world_pos.xz * 0.11) * 0.28;
    vec3 meadow = mix(grass_deep.rgb, grass_mid.rgb, smoothstep(0.17, 0.48, patch));
    meadow = mix(meadow, grass_bright.rgb, smoothstep(0.47, 0.73, patch));
    meadow = mix(meadow, grass_warm.rgb, smoothstep(0.73, 0.90, patch) * 0.40);
    // Authored olive color clusters own the surface; broad variation stays quiet.
    vec3 texel = texture(grass_texture, world_pos.xz * uv_scale).rgb;
    meadow = mix(texel, meadow, 0.18) * mix(0.94, 1.04, patch);
    float slope = 1.0 - max(world_normal.y, 0.0);
    vec3 rock = vec3(0.46, 0.45, 0.36);
    ALBEDO = mix(meadow, rock, smoothstep(0.25, 0.55, slope));
    ROUGHNESS = 1.0;
}
void light() {
    float diffuse = max(dot(NORMAL, LIGHT), 0.0);
    float band = mix(0.45, 0.78, smoothstep(0.14, 0.19, diffuse));
    band = mix(band, 1.0, smoothstep(0.60, 0.66, diffuse));
    float lighting = enable_toon_steps ? band : diffuse * 0.88 + 0.12;
    DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * lighting * ATTENUATION / 3.14159265;
}
