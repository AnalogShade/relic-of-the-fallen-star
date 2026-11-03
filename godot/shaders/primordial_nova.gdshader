shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform sampler2D energy_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform float radius = 0.1;
uniform float age = 0.0;
uniform float fade = 1.0;
uniform float texture_strength = 1.0;
uniform float texture_rotation = 0.0;
uniform float layer_opacity = 1.0;
void fragment() {
	vec2 p = (UV - 0.5) * 25.2;
	float r = length(p);
	float a = atan(p.y, p.x);
	// Rotate the generated annulus gently; stretch its radius unevenly over time.
	float turn = texture_rotation + age * 0.13;
	mat2 rotation = mat2(vec2(cos(turn), sin(turn)), vec2(-sin(turn), cos(turn)));
	float distortion = 1.0 + sin(a * 7.0 + age * 4.0) * 0.045 + sin(a * 13.0 - age * 6.0) * 0.025;
	vec2 tex_uv = rotation * p / (max(radius, 0.08) * 2.45 * distortion) + 0.5;
	vec4 energy = texture(energy_texture, tex_uv);
	float bounds = smoothstep(0.0, 0.035, tex_uv.x) * smoothstep(0.0, 0.035, tex_uv.y);
	bounds *= (1.0 - smoothstep(0.965, 1.0, tex_uv.x)) * (1.0 - smoothstep(0.965, 1.0, tex_uv.y));
	float density = energy.a * bounds;
	float luminance = dot(energy.rgb, vec3(0.2126, 0.7152, 0.0722));
	float ripple = sin(a * 23.0 + age * 17.0) * 0.045 + sin(a * 41.0 - age * 9.0) * 0.025;
	// Keep a faint trace of the original wave, broken up by the texture.
	float front = exp(-pow((r - radius + ripple) / 0.17, 2.0));
	float core = front * (0.08 + density * 0.36);
	float edge = 1.0 - smoothstep(11.8, 12.55, r);
	ALBEDO = mix(vec3(0.12, 0.65, 0.8), energy.rgb, 0.85);
	EMISSION = ALBEDO * (1.7 + luminance * 1.5);
	ALPHA = (density * texture_strength * (0.45 + luminance * 0.7) + core) * fade * edge * layer_opacity;
}
