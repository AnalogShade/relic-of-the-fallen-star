shader_type spatial;
render_mode cull_disabled;

uniform sampler2D blade_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float saturation : hint_range(0.0, 1.0) = 0.42;
uniform float brightness : hint_range(0.0, 1.0) = 0.92;

void fragment() {
	vec3 leaf = texture(blade_atlas, UV).rgb;
	float luminance = dot(leaf, vec3(0.2126, 0.7152, 0.0722));
	ALBEDO = mix(vec3(luminance), leaf, saturation) * brightness;
	ROUGHNESS = 0.84;
	SPECULAR = 0.2;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
