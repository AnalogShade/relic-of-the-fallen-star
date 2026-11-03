shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

void fragment() {
	float radius = length((UV - 0.5) * 2.0);
	float halo = pow(max(0.0, 1.0 - radius), 2.0);
	float breath = 0.96 + sin(TIME * 0.35) * 0.04;
	ALBEDO = vec3(0.48, 0.035, 0.012) * breath;
	ALPHA = halo * 0.48;
}
