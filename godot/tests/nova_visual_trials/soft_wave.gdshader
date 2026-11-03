shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float radius = 0.1;
uniform float age = 0.0;
uniform float fade = 1.0;
uniform float trail_strength = 0.0;
void fragment() {
	vec2 p = (UV - 0.5) * 20.7;
	float r = length(p);
	float a = atan(p.y, p.x);
	float ripple = sin(a * 23.0 + age * 17.0) * 0.045 + sin(a * 41.0 - age * 9.0) * 0.025;
	float front = exp(-pow((r - radius + ripple) / 0.26, 2.0)) * 0.76;
	float halo = exp(-pow((r - radius) / 0.95, 2.0)) * 0.30;
	float echo = exp(-pow((r - radius * 0.78) / 0.16, 2.0)) * 0.24;
	float threads = pow(max(0.0, sin(a * 32.0 + r * 3.0 - age * 12.0)), 8.0);
	float wake = smoothstep(radius - 2.0, radius - 0.2, r) * (1.0 - smoothstep(radius - 0.1, radius + 0.4, r)) * threads * 0.18;
	// Continuous inward tail: a local impression of radial motion, no screen blur.
	float behind = max(radius - r, 0.0);
	float trail = exp(-behind / 0.80) * (1.0 - smoothstep(radius - 0.12, radius + 0.40, r));
	trail *= smoothstep(0.0, 0.7, radius) * trail_strength * 0.48;
	float edge = 1.0 - smoothstep(9.7, 10.32, r);
	ALBEDO = mix(vec3(0.12, 0.65, 0.8), vec3(0.8, 1.0, 0.91), front);
	EMISSION = ALBEDO * 2.5;
	ALPHA = (front + halo + echo + wake + trail) * fade * edge;
}
