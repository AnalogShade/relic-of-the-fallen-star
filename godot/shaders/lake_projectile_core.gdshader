shader_type spatial;
render_mode unshaded, shadows_disabled;
varying vec3 object_pos;
void vertex() {
	object_pos = VERTEX;
	float fold = sin(VERTEX.y*18.0 + TIME*9.0 + sin(VERTEX.x*13.0 + TIME*5.0))*0.035;
	VERTEX += NORMAL*fold;
}
void fragment() {
	float vein = abs(sin(object_pos.y*19.0 + object_pos.z*11.0 + sin(object_pos.x*17.0 + TIME*6.0)*1.5 - TIME*10.0));
	float fissure = 1.0-smoothstep(0.06, 0.24, vein);
	float rim = pow(1.0-max(0.0, dot(normalize(NORMAL), normalize(VIEW))), 2.0);
	vec3 color = mix(vec3(0.025, 0.13, 0.32), vec3(0.15, 0.83, 1.0), fissure*0.8 + rim*0.5);
	ALBEDO = color;
	EMISSION = color * (0.4 + fissure*1.4);
}
