shader_type spatial;
render_mode unshaded, blend_mix, cull_front, depth_draw_never, fog_disabled, shadows_disabled;

uniform float debut_degrade : hint_range(0.0, 0.95) = 0.0;
uniform float noir_complet : hint_range(0.05, 1.0) = 0.8;
uniform float douceur : hint_range(0.2, 4.0) = 1.0;
varying float profondeur;

void vertex() {
	// Node transforms stretch the complete gradient along with its geometry.
	profondeur = clamp(0.5 - VERTEX.y / 5.2, 0.0, 1.0);
}

void fragment() {
	float fin = max(noir_complet, debut_degrade + 0.001);
	ALBEDO = vec3(0.0);
	ALPHA = pow(smoothstep(debut_degrade, fin, profondeur), douceur);
}
