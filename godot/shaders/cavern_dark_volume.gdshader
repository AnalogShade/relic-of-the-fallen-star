shader_type spatial;
render_mode unshaded, blend_mix, cull_front, depth_draw_never, depth_test_disabled, fog_disabled, shadows_disabled;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform mat4 cave_inverse;
uniform vec3 bounds_min = vec3(-2.15, -1.5, -5.1);
uniform vec3 bounds_max = vec3(2.15, 5.1, 0.1);

#include "res://shaders/cavern_aperture.gdshaderinc"

void fragment() {
	float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	// GL Compatibility uses OpenGL NDC depth [-1, 1].
	vec4 view_position = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
	view_position /= view_position.w;
	vec3 surface = (cave_inverse * INV_VIEW_MATRIX * view_position).xyz;
	vec3 eye = (cave_inverse * INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float aperture = cave_aperture(eye, surface);
	if (aperture <= 0.0) { discard; }
	vec3 direction = normalize(surface - eye);
	vec3 safe_direction = mix(vec3(0.00001), direction, greaterThan(abs(direction), vec3(0.00001)));
	vec3 a = (bounds_min - eye) / safe_direction;
	vec3 b = (bounds_max - eye) / safe_direction;
	vec3 near_planes = min(a, b);
	vec3 far_planes = max(a, b);
	float entry = max(max(near_planes.x, near_planes.y), max(near_planes.z, 0.0));
	float exit_distance = min(min(far_planes.x, far_planes.y), far_planes.z);
	float distance_inside = max(0.0, min(exit_distance, length(surface - eye)) - entry);
	ALBEDO = vec3(0.0);
	ALPHA = smoothstep(0.0, 3.4, distance_inside) * aperture;
}
