shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float age = 0.0;
uniform float fade = 1.0;
void fragment() {
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 3.0);
	float lines = pow(max(0.0, sin(UV.x * 160.0 + UV.y * 45.0 - age * 18.0)), 18.0);
	float equator = exp(-pow((UV.y - 0.5) / 0.075, 2.0));
	ALBEDO = vec3(0.3, 0.95, 0.83);
	EMISSION = ALBEDO * 2.0;
	ALPHA = (rim * 0.22 + lines * rim * 0.25 + equator * 0.25) * fade;
}
