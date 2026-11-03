shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform sampler2D energy_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform float age = 0.0;
uniform float fade = 1.0;
uniform float texture_rotation = 0.0;
varying vec2 shell_uv;
void vertex() {
	float angle = atan(VERTEX.z, VERTEX.x);
	float uneven = sin(angle * 7.0 + age * 4.0) * 0.035 + sin(angle * 13.0 - age * 6.0) * 0.02;
	VERTEX.xz *= 1.0 + uneven;
	shell_uv = UV;
}
void fragment() {
	float angle = shell_uv.x * 6.283185 + texture_rotation + age * 0.13;
	float band = 0.32 + sin(shell_uv.y * 8.0 - age * 2.0) * 0.075;
	vec4 energy = texture(energy_texture, vec2(cos(angle), sin(angle)) * band + 0.5);
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim = pow(1.0 - facing, 1.6) * smoothstep(0.0, 0.2, facing);
	float mask = smoothstep(0.15, 0.68, energy.a);
	float lines = pow(max(0.0, sin(UV.x * 160.0 + UV.y * 45.0 - age * 18.0)), 9.0);
	ALBEDO = mix(vec3(0.3, 0.95, 0.83), energy.rgb, 0.55);
	EMISSION = ALBEDO * 2.0;
	ALPHA = (rim * 0.32 + lines * rim * 0.13) * mask * fade;
}
