shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 base_color : source_color = vec4(1.0);
// Non-destructive Hue/Saturation adjustment of the red color range.
uniform float hue_shift : hint_range(-1.0, 1.0) = 0.0;
uniform float saturation_scale : hint_range(0.0, 2.0) = 1.0;
uniform float value_scale : hint_range(0.0, 2.0) = 1.0;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool normal_enabled = false;
uniform float normal_scale = 1.0;
uniform sampler2D orm_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform bool orm_enabled = false;
uniform float roughness_value = 1.0;
uniform float metallic_value = 0.0;

vec3 rgb_to_hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

vec3 linear_to_srgb(vec3 c) {
	return mix(c * 12.92, 1.055 * pow(max(c, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void fragment() {
	vec3 original = texture(albedo_texture, UV).rgb * base_color.rgb;
	// Evaluate hue in perceptual sRGB, like an image editor, rather than linear RGB.
	vec3 hsv = rgb_to_hsv(OUTPUT_IS_SRGB ? original : linear_to_srgb(original));
	float red_distance = min(hsv.x, 1.0 - hsv.x);
	float reds = (1.0 - smoothstep(0.035, 0.06, red_distance)) * smoothstep(0.08, 0.18, hsv.y);
	// The atlas's light peach skin is outside the dark/midtone red cloth range.
	reds *= 1.0 - smoothstep(0.65, 0.82, hsv.z);
	vec3 adjusted = hsv;
	adjusted.x = fract(hsv.x + hue_shift);
	adjusted.y = clamp(hsv.y * saturation_scale, 0.0, 1.0);
	adjusted.z = clamp(hsv.z * value_scale, 0.0, 1.0);
	// Scale the painted values rather than flattening the cloth to a solid color.
	vec3 shifted = hsv_to_rgb(adjusted);
	ALBEDO = mix(original, OUTPUT_IS_SRGB ? shifted : srgb_to_linear(shifted), reds);
	vec3 orm = texture(orm_texture, UV).rgb;
	ROUGHNESS = roughness_value * (orm_enabled ? orm.g : 1.0);
	METALLIC = metallic_value * (orm_enabled ? orm.b : 1.0);
	if (normal_enabled) {
		NORMAL_MAP = texture(normal_texture, UV).rgb;
		NORMAL_MAP_DEPTH = normal_scale;
	}
}
