shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float saturation : hint_range(0.0, 1.5) = 0.96;
uniform float shadow_lift : hint_range(0.0, 0.15) = 0.018;
uniform float warmth : hint_range(-0.1, 0.1) = 0.008;

// Light Post-Processing Parameters
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.08;
uniform float vignette_opacity : hint_range(0.0, 1.0) = 0.06;
uniform float chromatic_aberration : hint_range(0.0, 0.008) = 0.0;

void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 uv_center = uv - 0.5;
    float dist_sq = dot(uv_center, uv_center);

    // 1. Subtle Radial Chromatic Aberration (Micro lens dispersion towards screen borders)
    vec2 ca_offset = uv_center * dist_sq * (chromatic_aberration * 6.0);
    vec3 scene = texture(screen_texture, uv).rgb;
    if (chromatic_aberration > 0.0) {
        scene.r = texture(screen_texture, uv + ca_offset).r;
        scene.b = texture(screen_texture, uv - ca_offset).b;
    }

    // 2. Tactical Color Grading & Luma Lift
    float luma = dot(scene, vec3(0.2126, 0.7152, 0.0722));
    vec3 graded = mix(vec3(luma), scene, saturation);
    float shadows = 1.0 - smoothstep(0.05, 0.48, luma);
    float highlights = smoothstep(0.35, 0.90, luma);

    // Restore dark road and armor detail without washing out the bright landscape
    graded += vec3(1.05, 1.0, 0.92) * shadow_lift * shadows;
    graded *= vec3(1.0 + warmth * highlights, 1.0, 1.0 - warmth * highlights);

    // Gentle highlight shoulder; avoid hard white roof clipping
    vec3 shoulder = graded - max(graded - vec3(0.78), vec3(0.0)) * 0.28;

    // 3. Subtle Cinematic Corner Vignette (Soft perimeter falloff to draw focus to action)
    vec2 vig_uv = uv_center * vec2(1.15, 1.0);
    float v_dist = dot(vig_uv, vig_uv);
    float vignette = smoothstep(0.18, 0.65, v_dist) * vignette_opacity * vignette_intensity;
    shoulder *= (1.0 - vignette);

    COLOR = vec4(clamp(shoulder, vec3(0.0), vec3(1.0)), 1.0);
}
