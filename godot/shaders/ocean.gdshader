shader_type spatial;
render_mode cull_disabled;
varying vec3 world_pos;
float shore_sample(float x){return 151.0+6.0*sin(x*.035)+3.0*sin(x*.079+.8);}
float shore(float x){
    // Match ocean.glb's coastline vertices, including the sparse western coast.
    // Evaluating the sine between those vertices makes foam cut across the beach.
    float a = floor(x);
    float b = a + 1.0;
    if (x < -96.0) {
        if (x < -2000.0) { a = -3000.0; b = -2000.0; }
        else if (x < -1000.0) { a = -2000.0; b = -1000.0; }
        else if (x < -500.0) { a = -1000.0; b = -500.0; }
        else if (x < -200.0) { a = -500.0; b = -200.0; }
        else { a = -200.0; b = -96.0; }
    } else if (x > 224.0) {
        if (x < 350.0) { a = 224.0; b = 350.0; }
        else if (x < 600.0) { a = 350.0; b = 600.0; }
        else if (x < 1100.0) { a = 600.0; b = 1100.0; }
        else if (x < 2100.0) { a = 1100.0; b = 2100.0; }
        else { a = 2100.0; b = 3100.0; }
    }
    return mix(shore_sample(a), shore_sample(b), clamp((x-a)/(b-a), 0.0, 1.0));
}
void vertex(){
    world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    float offshore=smoothstep(0.0,22.0,world_pos.z-shore(world_pos.x));
    VERTEX.y+=(sin(world_pos.z*.18+world_pos.x*.045-TIME*.8)*.13+sin(world_pos.x*.31+TIME*.6)*.045)*offshore;
}
void fragment(){
    float distance_to_shore=world_pos.z-shore(world_pos.x);
    float deep=smoothstep(3.0,100.0,distance_to_shore);
    float ripple=sin(world_pos.x*.37+world_pos.z*.22+TIME*.6)*sin(world_pos.z*.53-TIME*.8);
    float detail=1.0-smoothstep(.15,1.0,length(fwidth(world_pos.xz)));
    vec3 shallow=vec3(.035,.36,.35);
    vec3 ocean=vec3(.018,.095,.18);
    vec3 color=mix(shallow,ocean,deep)+ripple*.006*detail;
    // Blend the river material into the estuary, then into ocean swells.
    float river_rip=sin(world_pos.x*8.0+world_pos.z*3.5+TIME*1.8)*sin(world_pos.z*12.0-TIME*2.0);
    vec3 river_color=mix(vec3(.025,.20,.20),vec3(.08,.38,.34),river_rip*.5+.5);
    color=mix(river_color,color,smoothstep(88.0,108.0,world_pos.z));
    float wave=sin(distance_to_shore*2.4-TIME*1.5+sin(world_pos.x*.7)*.3)*.5+.5;
    float mouth=1.0-smoothstep(12.0,18.0,abs(world_pos.x-(.1474+6.0*sin((world_pos.z-88.0)*.045))));
    float foam=(1.0-smoothstep(.0,2.8,distance_to_shore))*smoothstep(.45,.8,wave)*(1.0-mouth);
    foam*=smoothstep(-.8,.1,distance_to_shore);
    // Offshore crests arrive in parallel sets, retaining the original shore wash.
    // Positive time sends these rows toward land (decreasing shore distance).
    float swell_phase=distance_to_shore*(6.2831853/5.5)+TIME*.85+sin(world_pos.x*.7)*.3;
    float crest=sin(swell_phase)*.5+.5;
    float crest_width=max(fwidth(swell_phase)*.08,.015);
    float rows=smoothstep(.90-crest_width,.99+crest_width,crest);
    float row_envelope=smoothstep(1.8,4.0,distance_to_shore)*(1.0-smoothstep(14.0,22.0,distance_to_shore));
    float row_variation=.78+.22*sin(world_pos.x*.19+sin(world_pos.x*.043)+TIME*.22);
    foam=max(foam,rows*row_envelope*row_variation*(1.0-mouth)*.72);
    ALBEDO=mix(color,vec3(.76,.87,.80),foam*.40);
    NORMAL=normalize(NORMAL+vec3(ripple*.016,0.0,cos(world_pos.z*.6+TIME)*.012)*detail);
    METALLIC=.12; ROUGHNESS=.26; SPECULAR=.5;
}
