shader_type spatial;
render_mode unshaded, blend_mix, cull_front, depth_draw_never, depth_test_disabled, fog_disabled, shadows_disabled;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform mat4 volume_inverse;
uniform float debut_degrade = 0.0;
uniform float noir_complet = 2.8;
uniform float douceur = 1.0;
// Entrance plane, in the ellipsoid's normalized coordinates.
uniform float mouth_z = 0.68421;

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
	float a = dot(d, d);
	float b = dot(o, d);
	float c = dot(o, o) - 1.0;
	float discriminant = b * b - a * c;
	if (discriminant <= 0.0) { discard; }
	float entry = max(0.0, (-b - sqrt(discriminant)) / a);
	float leave = (-b + sqrt(discriminant)) / a;
	// Only rays coming through the actual mouth may see the interior darkness.
	if (o.z > mouth_z) {
		if (d.z >= -0.00001) { discard; }
		float mouth_entry = (mouth_z - o.z) / d.z;
		if (mouth_entry > leave) { discard; }
		vec3 mouth = o + d * mouth_entry;
		if (abs(mouth.x) > 0.75 || mouth.y < -0.56 || mouth.y > 0.68) { discard; }
		entry = max(entry, mouth_entry);
	} else if (o.z < -0.95 || dot(o.xy, o.xy) > 1.0) {
		discard;
	}
	leave = min(leave, length(surface - eye));
	float distance_inside = max(0.0, leave - entry);
	// Integrate through the volume, stopping at visible opaque geometry.
	// This darkens the stone itself instead of drawing a visible black shell.
	float opacity = smoothstep(debut_degrade, max(debut_degrade + 0.01, noir_complet), distance_inside);
	ALBEDO = vec3(0.0);
	ALPHA = pow(opacity, douceur);
}
