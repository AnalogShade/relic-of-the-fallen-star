shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.12, 0.7, 1.0, 0.7);
uniform float halo : hint_range(0.0, 1.0) = 0.0;
varying float seed;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i), hash(i+vec2(1,0)), f.x), mix(hash(i+vec2(0,1)), hash(i+vec2(1,1)), f.x), f.y);
}
void vertex() {
	seed = dot(MODEL_MATRIX[3].xyz, vec3(0.71, 1.37, 0.93));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(INV_VIEW_MATRIX[0].xyz * length(MODEL_MATRIX[0].xyz), 0.0), vec4(INV_VIEW_MATRIX[1].xyz * length(MODEL_MATRIX[1].xyz), 0.0), vec4(INV_VIEW_MATRIX[2].xyz, 0.0), MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float flow = noise(p*4.0 + vec2(seed, -TIME*3.0));
	float wisps = noise(vec2(radius*8.0 - TIME*4.0, angle*3.0 + TIME) + seed);
	float edge = pow(max(0.0, 1.0 - radius + (flow-0.5)*0.22*(1.0-halo)), 2.2);
	float detail = mix(0.45 + wisps*0.9, 0.75, halo);
	vec3 energy = mix(tint.rgb, vec3(0.65, 0.96, 1.0), pow(max(0.0, 1.0-radius), 3.0)*(1.0-halo));
	ALBEDO = energy;
	ALPHA = edge * detail * tint.a * COLOR.a;
}
