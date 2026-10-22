shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    float wave = sin(world_pos.x * 0.9 + world_pos.z * 0.5 + TIME * 1.3)
        * sin(world_pos.z * 1.2 - TIME * 0.8);
    float ripple = smoothstep(0.78, 0.9, wave);
    ALBEDO = mix(vec3(0.12, 0.43, 0.48), vec3(0.51, 0.76, 0.68), ripple * 0.7);
    ROUGHNESS = 0.75;
}
