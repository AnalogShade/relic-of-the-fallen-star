// Approved stream-side path style, shared by every world trail and village lane.
float forest_path_width(vec2 p) {
    return 1.30+smoothstep(.22,.78,noise(p*.19+7.0))*1.38;
}

float forest_path_edge(vec2 p) {
    return (noise(p*.73+12.0)-.5)*1.20
        +(noise(p*2.6)-.5)*.40+(noise(p*8.0)-.5)*.16;
}

// Sparse embedded brown stones over mottled, compacted earth, in world metres.
void forest_path_soil(vec2 p, out vec3 color, out float height) {
    float broad=noise(p*.42+13.0);
    float patches=noise(p*1.6+vec2(4.0,21.0));
    float grit=noise(p*38.0);
    color=mix(vec3(.205,.130,.077),vec3(.405,.291,.174),broad);
    color=mix(color,vec3(.29,.185,.104),smoothstep(.48,.82,patches)*.42);
    color=mix(color,vec3(.46,.345,.220),smoothstep(.55,.85,noise(p*3.7))*.30);
    color*=.88+.23*grit;

    vec2 q=p*5.2;
    vec2 cell=floor(q);
    vec2 f=fract(q);
    float stone_mask=0.0;
    float stone_height=0.0;
    vec3 stone_color=vec3(0.0);
    float aa=max(fwidth(q.x),fwidth(q.y))*.65+.015;
    for (int y=-1;y<=1;y++) {
        for (int x=-1;x<=1;x++) {
            vec2 id=cell+vec2(float(x),float(y));
            float seed=hash(id+37.2);
            vec2 center=vec2(hash(id),hash(id+19.4))*.7+.15;
            vec2 delta=(vec2(float(x),float(y))+center-f);
            delta*=vec2(1.0+seed*.7,1.5-seed*.4);
            float radius=mix(.10,.32,hash(id+71.0));
            float dist=max(length(delta),abs(delta.x)*.83+abs(delta.y)*.57);
            float pebble=(1.0-smoothstep(radius-aa,radius+aa,dist))*step(.65,seed);
            float dome=1.0-smoothstep(0.0,radius,dist);
            vec3 brown=mix(vec3(.245,.171,.110),vec3(.53,.413,.277),hash(id+9.8));
            brown*=.76+.35*dome;
            stone_color+=brown*pebble;
            stone_mask+=pebble;
            stone_height=max(stone_height,dome*pebble*.012);
        }
    }
    color=mix(color,stone_color/max(stone_mask,.001),clamp(stone_mask,0.0,1.0)*.86);
    height=stone_height+(grit-.5)*.0025+(patches-.5)*.004;
}
