uniform bool stream_stones_enabled = false;
uniform sampler2D stream_footprint : filter_linear, repeat_disable;
uniform vec4 stream_rect;

// World-space rounded cobbles, shared by the bed and the terrain bank seals.
void stream_stones(vec3 p, inout vec3 color, inout float roughness) {
	if (!stream_stones_enabled) { return; }
	vec2 uv = (p.xz-stream_rect.xy)/stream_rect.zw;
	if (any(lessThan(uv,vec2(0.0))) || any(greaterThan(uv,vec2(1.0)))) { return; }
	float width = 1.05+noise(p.xz*1.7)*0.65;
	float coverage = 0.0;
	float water_height = 0.0;
	for (int i=0; i<13; i++) {
		float angle = float(i)*2.399963;
		vec2 offset = i == 0 ? vec2(0.0) : vec2(cos(angle),sin(angle))*width;
		vec2 sample_value = texture(stream_footprint,uv+offset/stream_rect.zw).rg;
		if (sample_value.r > 0.01) { water_height = sample_value.g/max(sample_value.r,0.001); }
		coverage = max(coverage,sample_value.r*(i==0 ? 1.0 : 0.9));
	}
	float blend = smoothstep(0.12,0.78,coverage)*(1.0-smoothstep(0.9,1.8,p.y-water_height));
	if (blend < 0.001) { return; }
	vec2 q = p.xz*6.5;
	q += vec2(noise(p.xz*11.0),noise(p.xz*11.0+23.0))*0.28;
	vec2 cell = floor(q);
	vec2 f = fract(q);
	float first = 10.0;
	float second = 10.0;
	vec2 stone = vec2(0.0);
	for (int y=-1;y<=1;y++) {
		for (int x=-1;x<=1;x++) {
			vec2 g = vec2(float(x),float(y));
			vec2 id = cell+g;
			vec2 center = vec2(hash(id),hash(id+vec2(37.4,17.1)))*0.7+0.15;
			float d = length((g+center-f)*vec2(1.0,1.16));
			if (d<first) { second=first;first=d;stone=id; }
			else { second=min(second,d); }
		}
	}
	float joint = smoothstep(0.035,0.16,second-first)*(1.0-smoothstep(0.36,0.60,first));
	float variation = hash(stone+vec2(5.7,11.2));
	vec3 cobble = mix(vec3(0.24,0.26,0.25),vec3(0.53,0.55,0.52),variation);
	cobble = mix(cobble,vec3(0.39,0.35,0.29),smoothstep(0.79,1.0,variation)*0.5);
	cobble *= (0.82+0.22*(1.0-smoothstep(0.0,0.65,first)))*(0.92+0.16*noise(p.xz*65.0));
	vec3 gravel = mix(vec3(0.22,0.23,0.21)*(0.85+0.25*noise(p.xz*38.0)),cobble,joint);
	float wet = 1.0-smoothstep(0.0,0.45,p.y-water_height);
	color = mix(color,gravel*mix(1.0,0.72,wet),blend);
	roughness = mix(roughness,mix(0.91,0.65,wet),blend);
}
