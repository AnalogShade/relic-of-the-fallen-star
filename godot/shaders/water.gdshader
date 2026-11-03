shader_type spatial;
render_mode cull_disabled;
varying vec3 world_pos;
void vertex(){
	world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	VERTEX.y+=sin(world_pos.z*3.0+TIME*1.6)*0.012+sin(world_pos.x*6.0-TIME)*0.007;
}
void fragment(){
	float rip=sin(world_pos.x*8.0+world_pos.z*3.5+TIME*1.8)*sin(world_pos.z*12.0-TIME*2.0);
	ALBEDO=mix(vec3(0.025,0.20,0.20),vec3(0.08,0.38,0.34),rip*0.5+0.5);
	NORMAL=normalize(NORMAL+vec3(rip*0.08,0.0,cos(world_pos.z*9.0+TIME)*0.045));
	METALLIC=0.35;ROUGHNESS=0.2;
	ALPHA=0.84;
}
