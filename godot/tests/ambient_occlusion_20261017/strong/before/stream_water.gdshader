shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;

uniform sampler2D banks : filter_linear, repeat_disable;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform vec2 z_limits;
uniform float current_speed : hint_range(0.0, 2.0) = 0.65;
uniform float ripple_strength : hint_range(0.0, 0.4) = 0.13;
uniform vec3 shallow_color : source_color = vec3(0.24, 0.43, 0.37);
uniform vec3 deep_color : source_color = vec3(0.035, 0.19, 0.18);
varying vec3 local_pos;
varying mat3 local_to_view;

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
vec2 flow_coords(vec2 p) {
	float t = clamp((p.y - z_limits.x) / (z_limits.y - z_limits.x), 0.0, 1.0);
	float center = texture(banks, vec2(t, 0.5)).r;
	return vec2(p.x - center, p.y);
}
float waves(vec2 p) {
	vec2 q = flow_coords(p);
	q.y -= TIME * current_speed;
	float broad = noise(q * vec2(2.0, 1.6));
	float fine = noise(q * vec2(5.5, 3.8) + vec2(8.3, -TIME * 0.19));
	return broad * 0.65 + fine * 0.35;
}
void vertex() {
	local_pos = VERTEX;
	local_to_view = mat3(MODELVIEW_MATRIX);
	// Keep the existing banks and water level; only a few millimeters of motion.
	VERTEX.y += (waves(VERTEX.xz) - 0.5) * 0.012;
}
void fragment() {
	float h = waves(local_pos.xz);
	float dx = (waves(local_pos.xz + vec2(0.035, 0.0)) - h) / 0.035;
	float dz = (waves(local_pos.xz + vec2(0.0, 0.035)) - h) / 0.035;
	NORMAL = normalize(local_to_view * vec3(-dx * ripple_strength, 1.0, -dz * ripple_strength));
	float raw_depth = texture(depth_texture, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV, raw_depth) * 2.0 - 1.0;
	vec4 background = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float thickness = max(0.0, -background.z / background.w + VERTEX.z);
	float absorption = 1.0 - exp(-thickness * 0.75);
	vec2 q = flow_coords(local_pos.xz);
	float t = clamp((local_pos.z - z_limits.x) / (z_limits.y - z_limits.x), 0.0, 1.0);
	float width = texture(banks, vec2(t, 0.5)).g;
	float edge = smoothstep(0.78, 1.0, abs(q.x) / width);
	float foam_noise = noise(q * vec2(4.0, 2.5) - vec2(0.0, TIME * current_speed));
	float foam = edge * smoothstep(0.58, 0.82, foam_noise) * 0.24;
	ALBEDO = mix(mix(shallow_color, deep_color, absorption) * (0.92 + h * 0.16), vec3(0.72, 0.80, 0.73), foam);
	METALLIC = 0.0;
	SPECULAR = 0.65;
	ROUGHNESS = mix(0.16, 0.32, foam);
	ALPHA = clamp(0.28 + absorption * 0.62 + foam, 0.28, 0.93);
}
