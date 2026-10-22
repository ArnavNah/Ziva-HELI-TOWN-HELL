shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, repeat_disable;
uniform float damage_amount = 0.0;
uniform int fixed_tile = -1;
uniform bool world_mapping = false;
uniform float wind_strength = 0.0;
uniform float tile_meters = 8.0;
uniform bool enable_toon_steps = false;
uniform bool enable_vertex_snapping = false;
uniform float snap_resolution = 320.0;
varying vec3 world_pos;
varying vec3 local_pos;
varying vec3 local_normal;
varying float tile_index;
void vertex() {
    local_pos = VERTEX;
    local_normal = NORMAL;
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    VERTEX.x += sin(TIME * 1.8 + world_pos.x * 0.24 + world_pos.z * 0.19) * wind_strength * max(VERTEX.y, 0.0);
    tile_index = fixed_tile >= 0 ? float(fixed_tile) : UV2.x;
    vec4 projected = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
    if (enable_vertex_snapping) {
        if (projected.w > 0.1) {
            projected.xy = floor(projected.xy / projected.w * snap_resolution + 0.5) / snap_resolution * projected.w;
        }
    }
    POSITION = projected;
}
vec3 tile_sample(float id, vec2 coord, vec2 dx, vec2 dy) {
    vec2 cell = vec2(mod(id, 4.0), floor(id / 4.0));
    vec2 uv = (cell * 160.0 + 16.0 + fract(coord) * 128.0) / 640.0;
    // Derivatives are taken before fract, so tile seams do not select a blurry mip.
    // Four mip levels fit within the wrapped 16px gutters.
    float footprint = max(length(dx), length(dy));
    float limit_scale = min(1.0, 0.125 / max(footprint, 0.00001));
    return textureGrad(albedo_texture, uv, dx * 0.2 * limit_scale, dy * 0.2 * limit_scale).rgb;
}
void fragment() {
    vec2 coord = UV;
    if (world_mapping) {
        vec3 axis = abs(local_normal);
        coord = axis.y > max(axis.x, axis.z) ? world_pos.xz / tile_meters : (axis.x > axis.z ? world_pos.zy / tile_meters : world_pos.xy / tile_meters);
    }
    vec2 dx = dFdx(coord);
    vec2 dy = dFdy(coord);
    float id = floor(tile_index + 0.5);
    vec3 painted = tile_sample(id, coord, dx, dy);
    // Neutral paint carries deliberate vertex accents; masonry/roof keep authored hues.
    if (id == 4.0) {
        painted = painted / vec3(0.67, 0.63, 0.55) * COLOR.rgb * 0.75;
    } else {
        painted *= mix(vec3(1.0), COLOR.rgb, 0.18);
    }
    if (damage_amount > 0.0) {
        float wear = tile_sample(15.0, coord + vec2(0.21, 0.33), dx, dy).r;
        float scorch = (1.0 - smoothstep(0.13, 0.55, wear)) * damage_amount;
        painted = mix(painted, painted * vec3(0.32, 0.29, 0.26), scorch * 0.85);
    }
    ALBEDO = painted;
    ROUGHNESS = 1.0;
    METALLIC = 0.0;
}
void light() {
    float diffuse = max(dot(NORMAL, LIGHT), 0.0);
    float band = mix(0.40, 0.75, smoothstep(0.12, 0.18, diffuse));
    band = mix(band, 1.0, smoothstep(0.60, 0.68, diffuse));
    float lighting = enable_toon_steps ? band : diffuse * 0.88 + 0.12;
    DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * lighting * ATTENUATION / 3.14159265;
}
