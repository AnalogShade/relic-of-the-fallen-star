shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform sampler2D energy_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform float fade = 1.0;
varying vec4 particle_data;
void vertex() {
	// Camera-facing wisps, preserving each particle's individual size.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(INV_VIEW_MATRIX[0].xyz * length(MODEL_MATRIX[0].xyz), 0.0),
		vec4(INV_VIEW_MATRIX[1].xyz * length(MODEL_MATRIX[1].xyz), 0.0),
		vec4(INV_VIEW_MATRIX[2].xyz * length(MODEL_MATRIX[2].xyz), 0.0),
		MODEL_MATRIX[3]);
	particle_data = INSTANCE_CUSTOM;
}
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float angle = particle_data.b * 6.283185;
	mat2 rotation = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle)));
	// Read different smoky fragments of the generated texture, not a whole ring.
	vec2 patch = rotation * p * 0.12 + vec2(0.76, 0.44 + particle_data.g * 0.10);
	vec4 mist = texture(energy_texture, patch);
	float soft_edge = pow(max(0.0, 1.0 - dot(p, p)), 2.0);
	ALBEDO = mix(vec3(0.12, 0.65, 0.68), mist.rgb, 0.7);
	EMISSION = ALBEDO * 1.8;
	ALPHA = soft_edge * (0.2 + mist.a * 0.8) * particle_data.r * fade;
}
