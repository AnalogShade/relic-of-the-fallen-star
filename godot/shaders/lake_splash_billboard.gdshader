shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D splash_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform float age : hint_range(0.0, 1.0) = 0.0;
varying float opacity;

void vertex() {
	float t = clamp((age - INSTANCE_CUSTOM.r * 0.12) / 0.88, 0.0, 1.0);
	float fade_in = smoothstep(0.0, 0.10, t);
	opacity = fade_in * pow(1.0 - t, 1.2) * INSTANCE_CUSTOM.b;
	if (INSTANCE_CUSTOM.g > 0.5) { UV.x = 1.0 - UV.x; }
	// Anchor the transparent splash fan at the waterline, then open and dissolve it.
	VERTEX.y = (VERTEX.y + 0.5) * mix(0.18, 1.0, smoothstep(0.0, 0.40, t));
	VERTEX.x *= mix(0.70, 1.15, t);
	vec3 right = INV_VIEW_MATRIX[0].xyz * length(MODEL_MATRIX[0].xyz);
	vec3 up = INV_VIEW_MATRIX[1].xyz * length(MODEL_MATRIX[1].xyz);
	vec3 normal = INV_VIEW_MATRIX[2].xyz;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right, 0.0), vec4(up, 0.0), vec4(normal, 0.0), MODEL_MATRIX[3]);
}

void fragment() {
	vec4 splash = texture(splash_texture, UV);
	float alpha = splash.a * opacity;
	if (alpha < 0.015) { discard; }
	ALBEDO = splash.rgb;
	ALPHA = alpha;
}
