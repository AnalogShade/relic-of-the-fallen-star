shader_type spatial;
render_mode cull_disabled;
varying vec3 world_pos;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
	vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() {
	world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	VERTEX.y+=sin(world_pos.x*.9+world_pos.z*.45+TIME*.7)*.009;
}
void fragment() {
	vec2 p=world_pos.xz;
	float swell=noise(p*.32+vec2(TIME*.025,-TIME*.018));
	float small=noise(p*2.1+vec2(TIME*.06,TIME*.035));
	float ripple=sin(p.x*2.0+p.y*1.1+swell*7.0+TIME*.9);
	ALBEDO=mix(vec3(.025,.19,.18),vec3(.045,.28,.24),swell*.8+small*.2);
	ALBEDO+=vec3(.045,.065,.045)*pow(max(ripple,0.0),18.0)*.24;
	NORMAL=normalize(NORMAL+vec3((small-.5)*.04,0.0,ripple*.023));
	ROUGHNESS=.30;METALLIC=.12;SPECULAR=.36;
	ALPHA=0.84;
}
