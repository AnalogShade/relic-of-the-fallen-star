shader_type spatial;
render_mode unshaded, blend_mix, cull_front, depth_draw_never, depth_test_disabled, fog_disabled, shadows_disabled;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
// Radius of the actual interior stone, sampled around 57 tunnel cross-sections.
uniform sampler2D interior_profile : repeat_enable, filter_linear;
uniform mat4 volume_inverse;
uniform float debut_degrade = 0.2;
uniform float noir_complet = 4.8;
uniform float douceur = 2.0;
uniform float densite = 3.2;

float density_at(vec3 p) {
	float tunnel_depth = 0.6 - p.z;
	float progress = clamp((tunnel_depth - debut_degrade) / max(0.1, noir_complet - debut_degrade), 0.0, 1.0);
	vec2 radial = p.xy - vec2(0.0, 1.8);
	float angle = atan(radial.y, radial.x) / 6.28318530718;
	float v = (clamp((0.8 - p.z) / 0.1, 0.0, 56.0) + 0.5) / 57.0;
	float radius = textureLod(interior_profile, vec2(angle + 0.5 / 64.0, v), 0.0).r;
	// Feather into the stone, so no bright slit remains between fog and wall.
	float inside = 1.0 - smoothstep(radius - 0.18, radius + 0.10, length(radial));
	return densite * pow(progress, douceur) * inside;
}

void fragment() {
	float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
	#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	#endif
	vec4 view_surface = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view_surface /= view_surface.w;
	vec3 surface = (INV_VIEW_MATRIX * view_surface).xyz;
	vec3 eye = INV_VIEW_MATRIX[3].xyz;
	if (PROJECTION_MATRIX[3][3] > 0.5) {
		eye = (INV_VIEW_MATRIX * vec4(view_surface.xy, 0.0, 1.0)).xyz;
	}
	vec3 world_direction = normalize(surface - eye);
	vec3 o = (volume_inverse * vec4(eye, 1.0)).xyz;
	vec3 d = (volume_inverse * vec4(world_direction, 0.0)).xyz;
	vec3 safe_d = mix(vec3(0.000001), d, greaterThan(abs(d), vec3(0.000001)));
	vec3 a = (vec3(-3.6, -1.8, -4.8) - o) / safe_d;
	vec3 b = (vec3(3.6, 5.4, 0.6) - o) / safe_d;
	vec3 near_planes = min(a, b);
	vec3 far_planes = max(a, b);
	float entry = max(0.0, max(near_planes.x, max(near_planes.y, near_planes.z)));
	float leave = min(length(surface - eye), min(far_planes.x, min(far_planes.y, far_planes.z)));
	// An exterior camera must look through the mouth, never through the roof/back.
	if (o.z > 0.6) {
		if (d.z >= -0.00001) { discard; }
		float mouth_t = (0.6 - o.z) / d.z;
		vec3 mouth = o + d * mouth_t;
		if (abs(mouth.x) > 3.3 || mouth.y < -0.6 || mouth.y > 4.8) { discard; }
		entry = max(entry, mouth_t);
	} else if (o.z < -4.8 || abs(o.x) > 3.5 || o.y > 5.3 || o.y < -1.5) {
		discard;
	}
	if (leave <= entry) { discard; }
	float step_length = (leave - entry) / 64.0;
	float optical_depth = 0.0;
	for (int i = 0; i < 64; i++) {
		vec3 p = o + d * (entry + (float(i) + 0.5) * step_length);
		optical_depth += density_at(p) * step_length;
	}
	ALBEDO = vec3(0.0);
	ALPHA = min(1.0, (1.0 - exp(-optical_depth)) / 0.998);
}
