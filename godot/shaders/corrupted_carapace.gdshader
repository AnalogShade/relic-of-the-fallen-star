shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
void fragment() {
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.4);
	float veins = pow(max(0.0, sin(UV.x * 60.0 + sin(UV.y * 34.0 + TIME) * 3.0)), 12.0);
	ALBEDO = vec3(0.5, 0.18, 0.8);
	EMISSION = ALBEDO * 1.6;
	ALPHA = rim * 0.5 + veins * 0.12;
}
