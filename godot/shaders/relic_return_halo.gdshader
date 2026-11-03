shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform float awakening : hint_range(0.0, 1.0) = 0.0;
uniform float presence = 0.0;
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float pulse = 0.86 + 0.14 * sin(TIME * 2.0);
	float outer = exp(-pow((r - 0.82) * 95.0, 2.0));
	float inner = exp(-pow((r - 0.64) * 110.0, 2.0));
	float orbit = exp(-pow((r - 0.73) * 100.0, 2.0)) * pow(0.5 + 0.5 * sin(a * 12.0 - TIME * 0.65), 12.0);
	float spokes = pow(0.5 + 0.5 * cos(a * 24.0 + TIME * 0.18), 35.0);
	float runes = spokes * smoothstep(0.65, 0.68, r) * (1.0 - smoothstep(0.77, 0.79, r));
	float haze = exp(-r * r * 5.0) * 0.15;
	float ripple_radius = 0.18 + fract(TIME * 0.22) * 0.65;
	float ripple = exp(-pow((r - ripple_radius) * 40.0, 2.0)) * (1.0 - fract(TIME * 0.22)) * 0.16;
	vec3 turquoise = vec3(0.15, 0.85, 0.78);
	vec3 gold = vec3(1.0, 0.72, 0.28);
	vec3 light = turquoise * (outer + inner * 0.7 + haze + ripple) + gold * (orbit + runes * 0.85);
	ALBEDO = light;
	ALPHA = clamp(max(max(light.r, light.g), light.b), 0.0, 1.0) * awakening * pulse * (1.0 + presence * 0.3);
}
