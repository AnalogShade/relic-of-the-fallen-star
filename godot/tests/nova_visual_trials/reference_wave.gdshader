shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float radius = 0.1;
uniform float age = 0.0;
uniform float fade = 1.0;
void fragment() {
	vec2 p = (UV - 0.5) * 20.7;
	float r = length(p);
	float a = atan(p.y, p.x);
	float ripple = sin(a * 23.0 + age * 17.0) * 0.045 + sin(a * 41.0 - age * 9.0) * 0.025;
	float front = exp(-pow((r - radius + ripple) / 0.13, 2.0));
	float halo = exp(-pow((r - radius) / 0.65, 2.0)) * 0.3;
	float echo = exp(-pow((r - radius * 0.78) / 0.055, 2.0)) * 0.38;
	float threads = pow(max(0.0, sin(a * 32.0 + r * 3.0 - age * 12.0)), 14.0);
	float wake = smoothstep(radius - 2.0, radius, r) * (1.0 - smoothstep(radius, radius + 0.1, r)) * threads * 0.22;
	ALBEDO = mix(vec3(0.12, 0.65, 0.8), vec3(0.8, 1.0, 0.91), front);
	EMISSION = ALBEDO * 2.5;
	ALPHA = (front + halo + echo + wake) * fade;
}
