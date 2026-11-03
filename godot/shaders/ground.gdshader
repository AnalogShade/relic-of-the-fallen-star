shader_type spatial;
varying vec3 world_pos;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
	vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
#include "res://shaders/stream_stones.gdshaderinc"
#include "res://shaders/hybrid_grass.gdshaderinc"
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
	float n=noise(world_pos.xz*1.3)*0.65+noise(world_pos.xz*4.0)*0.25+noise(world_pos.xz*12.0)*0.1;
	ALBEDO=mix(vec3(0.13,0.19,0.055),vec3(0.34,0.40,0.13),n);
	ROUGHNESS=0.92;
	if (hybrid_grass_enabled) {
		float grass_mask=hybrid_grass_stream_clearance(world_pos);
		ALBEDO*=1.0+(hybrid_grass_modulation(world_pos.xz)-1.0)*hybrid_grass_strength*grass_mask;
	}
	stream_stones(world_pos, ALBEDO, ROUGHNESS);
}
