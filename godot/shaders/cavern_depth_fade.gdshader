shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

// Coordinates of the exported Blender mesh: the mouth faces +Z in Godot.
// An overlay preserves the original PBR textures, normals and exterior lighting.
uniform mat4 cave_inverse;
uniform float fade_start = 0.1;
uniform float fade_end = -3.8;
varying float tunnel_z;
varying vec3 tunnel_position;
varying vec3 tunnel_normal;

#include "res://shaders/cavern_aperture.gdshaderinc"

void vertex() {
	tunnel_position = (cave_inverse * MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	tunnel_normal = mat3(cave_inverse) * MODEL_NORMAL_MATRIX * NORMAL;
	tunnel_z = tunnel_position.z;
}

void fragment() {
	vec3 eye = (cave_inverse * INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float darkness = smoothstep(0.0, 1.0, (fade_start - tunnel_z) / (fade_start - fade_end));
	ALBEDO = vec3(0.0);
	// The inclined cave exposes more of its outside: darken inward-facing stone.
	vec3 radial = normalize(vec3(tunnel_position.x, tunnel_position.y - 2.0, 0.0));
	float interior = 1.0 - smoothstep(-0.15, 0.08, dot(normalize(tunnel_normal), radial));
	ALPHA = darkness * interior * cave_aperture(eye, tunnel_position);
}
