shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform float ripple_strength : hint_range(0.0, 0.4) = 0.10;
uniform vec3 shallow_color : source_color = vec3(0.24, 0.43, 0.37);
uniform vec3 deep_color : source_color = vec3(0.035, 0.19, 0.18);
varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), u.x), u.y);
}
float waves(vec2 p) {
	// Crossing wind ripples; a lake has no river-shaped directional current.
	float broad = noise(p * vec2(1.6, 1.3) - vec2(TIME * 0.12, TIME * 0.07));
	float fine = noise(p * vec2(4.5, 3.5) + vec2(TIME * 0.09, -TIME * 0.13) + vec2(8.3));
	return broad * 0.65 + fine * 0.35;
}
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += (waves(world_pos.xz) - 0.5) * 0.012;
}
void fragment() {
	float h = waves(world_pos.xz);
	float dx = (waves(world_pos.xz + vec2(0.035, 0.0)) - h) / 0.035;
	float dz = (waves(world_pos.xz + vec2(0.0, 0.035)) - h) / 0.035;
	NORMAL = normalize(mat3(VIEW_MATRIX) * vec3(-dx * ripple_strength, 1.0, -dz * ripple_strength));
	float raw_depth = texture(depth_texture, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV, raw_depth) * 2.0 - 1.0;
	vec4 background = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float thickness = max(0.0, -background.z / background.w + VERTEX.z);
	float absorption = 1.0 - exp(-thickness * 0.75);
	// A narrow, broken contact band rather than foam over the entire lake.
	float contact = (1.0 - smoothstep(0.04, 0.30, thickness)) * smoothstep(0.005, 0.035, thickness);
	float foam_noise = noise(world_pos.xz * 3.0 - vec2(TIME * 0.12, TIME * 0.07));
	float foam = contact * smoothstep(0.56, 0.82, foam_noise) * 0.18;
	ALBEDO = mix(mix(shallow_color, deep_color, absorption) * (0.92 + h * 0.16), vec3(0.72, 0.80, 0.73), foam);
	METALLIC = 0.0;
	SPECULAR = 0.65;
	ROUGHNESS = mix(0.18, 0.32, foam);
	ALPHA = clamp(0.28 + absorption * 0.62 + foam, 0.28, 0.93);
}
