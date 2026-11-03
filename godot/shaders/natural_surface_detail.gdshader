shader_type spatial;

// Keep the existing palette and faceted mesh; add only small surface variations.
uniform vec4 base_color : source_color = vec4(0.3, 0.25, 0.15, 1.0);
uniform float base_roughness : hint_range(0.0, 1.0) = 0.9;
uniform float base_specular : hint_range(0.0, 1.0) = 0.2;
uniform int detail_kind = 0; // 0: bark, 1: stone, 2: existing moss.
uniform bool use_vertex_color = false;
varying vec3 detail_world_position;
varying vec3 detail_view_position;

float surface_hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float surface_noise(vec3 p) {
	vec3 cell = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(surface_hash(cell), surface_hash(cell + vec3(1,0,0)), f.x),
			mix(surface_hash(cell + vec3(0,1,0)), surface_hash(cell + vec3(1,1,0)), f.x), f.y),
		mix(mix(surface_hash(cell + vec3(0,0,1)), surface_hash(cell + vec3(1,0,1)), f.x),
			mix(surface_hash(cell + vec3(0,1,1)), surface_hash(cell + vec3(1,1,1)), f.x), f.y), f.z);
}

void vertex() {
	detail_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	detail_view_position = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 p = detail_world_position;
	float detail;
	float height;
	float contrast;
	float strength;
	if (detail_kind == 0) {
		// Elongated, irregular grain: no photographic cracks or black outlines.
		float warp = surface_noise(p * vec3(0.7, 0.16, 0.7));
		float grain = surface_noise(p * vec3(14.0, 0.8, 14.0) + vec3(warp, 0.0, warp));
		float fine = surface_noise(p * vec3(42.0, 3.5, 42.0));
		detail = smoothstep(0.25, 0.75, grain) * 0.75 + fine * 0.25;
		height = detail * 0.009;
		contrast = 0.22;
		strength = 0.65;
	} else {
		// Soft mineral mottling and small grains, matching the scale of the ground noise.
		float patches = surface_noise(p * 2.1);
		float grain = surface_noise(p * 8.0);
		float fine = surface_noise(p * 32.0);
		detail = patches * 0.45 + grain * 0.40 + fine * 0.15;
		height = (grain * 0.7 + fine * 0.3) * 0.008;
		contrast = detail_kind == 2 ? 0.12 : 0.32;
		strength = detail_kind == 2 ? 0.3 : 0.7;
	}
	// Fine detail fades at distance to preserve the original broad colour shapes.
	float near_detail = 1.0 - smoothstep(16.0, 65.0, length(detail_view_position));
	vec3 original_color = base_color.rgb;
	if (use_vertex_color) {
		original_color *= COLOR.rgb;
	}
	ALBEDO = original_color * (1.0 + (detail - 0.5) * contrast * near_detail);
	ROUGHNESS = clamp(base_roughness + (detail - 0.5) * 0.035 * near_detail, 0.0, 1.0);
	SPECULAR = base_specular;
	// Surface-gradient bump changes lighting only, not vertices or collision geometry.
	vec3 n = normalize(NORMAL);
	vec3 dx = dFdx(detail_view_position);
	vec3 dy = dFdy(detail_view_position);
	vec3 rx = cross(dy, n);
	vec3 ry = cross(n, dx);
	float determinant = dot(dx, rx);
	vec3 gradient = sign(determinant) * (dFdx(height) * rx + dFdy(height) * ry);
	if (abs(determinant) > 0.000001) {
		NORMAL = normalize(abs(determinant) * n - gradient * strength * near_detail);
	}
}
