shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

void vertex() {
	// Camera-facing discs; retain each particle's individual scale.
	float size = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * size,
		INV_VIEW_MATRIX[1] * size, INV_VIEW_MATRIX[2] * size, MODEL_MATRIX[3]);
}

void fragment() {
	float radius = length(UV - vec2(0.5)) * 2.0;
	ALBEDO = COLOR.rgb;
	ALPHA = (1.0 - smoothstep(0.22, 1.0, radius)) * COLOR.a;
}
