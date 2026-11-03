shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;
uniform float age : hint_range(0.0, 1.0) = 0.0;
uniform float variation = 0.0;
void fragment() {
    vec2 p = UV * 2.0 - 1.0;
    float angle = atan(p.y, p.x);
    float radius = length(p);
    float wobble = sin(angle * 7.0 + variation) * 0.012 + sin(angle * 13.0 - variation) * 0.007;
    float front = mix(0.18, 0.90, age);
    float ring = 1.0 - smoothstep(0.015, 0.065, abs(radius + wobble - front));
    float inner = (1.0 - smoothstep(0.01, 0.035, abs(radius - front * 0.72))) * 0.32;
    float breakup = mix(0.5, 1.0, smoothstep(-0.6, 0.5, sin(angle * 17.0 + variation) * sin(angle * 9.0)));
    ALBEDO = vec3(0.75, 0.88, 0.90);
    ROUGHNESS = 0.28;
    ALPHA = (ring + inner) * breakup * pow(1.0 - age, 1.5) * 0.58;
}
