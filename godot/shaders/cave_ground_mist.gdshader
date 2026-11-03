shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform vec4 mist_color : source_color = vec4(0.48, 0.60, 0.65, 0.08);
uniform bool round_patch = true;
uniform float layer_phase = 0.0;
varying vec3 world_position;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float boundary = round_patch ? length(p) : max(abs(p.x), abs(p.y));
	float edge = 1.0 - smoothstep(0.64, 1.0, boundary);
	vec2 drift = vec2(TIME * 0.035, -TIME * 0.022);
	float cloud = noise(world_position.xz * 0.6 + drift + layer_phase);
	cloud = cloud * 0.65 + noise(world_position.xz * 1.7 - drift) * 0.35;
	ALBEDO = mist_color.rgb;
	ALPHA = mist_color.a * edge * smoothstep(0.12, 0.85, cloud);
}
