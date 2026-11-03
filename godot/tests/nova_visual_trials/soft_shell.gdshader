shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float age = 0.0;
uniform float fade = 1.0;
uniform float layer_weight = 1.0;
void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	// Broader Fresnel band, fading out before the exact mesh silhouette.
	float rim = pow(1.0 - facing, 1.7) * smoothstep(0.0, 0.23, facing);
	float lines = pow(max(0.0, sin(UV.x * 160.0 + UV.y * 45.0 - age * 18.0)), 9.0);
	float equator = exp(-pow((UV.y - 0.5) / 0.11, 2.0));
	ALBEDO = vec3(0.3, 0.95, 0.83);
	EMISSION = ALBEDO * 2.0;
	ALPHA = (rim * 0.28 + lines * rim * 0.16 + equator * 0.20 * smoothstep(0.0, 0.18, facing)) * fade * layer_weight;
}
