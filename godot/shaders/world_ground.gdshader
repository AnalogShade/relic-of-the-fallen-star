shader_type spatial;
varying vec3 world_pos;
varying vec3 world_normal;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){
	vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}

float segment_distance(vec2 p, vec2 a, vec2 b) {
    vec2 ab = b-a;
    return length(p-a-ab*clamp(dot(p-a,ab)/dot(ab,ab),0.0,1.0));
}
#include "res://shaders/forest_trails.gdshaderinc"
#include "res://shaders/forest_path_soil.gdshaderinc"
// Village wear uses the editable Blender castle coordinates (no overlay planes).
vec2 castle_village_point(vec2 p) {
    vec2 d=p-vec2(-226.0,-32.0);
    return vec2(2.0+0.342897807*d.x-0.939372713*d.y,
                4.0-0.939372713*d.x-0.342897807*d.y);
}
float village_patch(vec2 p,vec2 center,vec2 radius) {
    float r=length((p-center)/radius);
    float irregular=(noise(p*1.8)-.5)*.12+(noise(p*.57)-.5)*.19;
    return 1.0-smoothstep(.72,1.10,r+irregular);
}
float castle_village_wear(vec3 wp) {
    vec2 p=castle_village_point(wp.xz);
    float wear=village_patch(p,vec2(12.0,-16.0),vec2(8.2,6.4));
    wear=max(wear,village_patch(p,vec2(-18.000,-12.000),vec2(4.5,4.5)));
    wear=max(wear,village_patch(p,vec2(-22.000,-4.000),vec2(4.5,4.5)));
    wear=max(wear,village_patch(p,vec2(-20.000,5.000),vec2(4.5,4.5)));
    wear=max(wear,village_patch(p,vec2(-24.000,15.000),vec2(4.5,4.5)));
    wear=max(wear,village_patch(p,vec2(-3.000,-18.500),vec2(4.5,4.5)));
    wear=max(wear,village_patch(p,vec2(2.000,-24.000),vec2(4.5,4.5)));
    wear=max(wear,village_patch(p,vec2(-6.000,-5.000),vec2(4.5,4.5)));
    wear=max(wear,village_patch(p,vec2(-10.000,4.000),vec2(4.5,4.5)));
    // Quarter layout from Blender, 2026-10-21: additive earth only.
    wear=max(wear,village_patch(p,vec2(-23.298,-12.428),vec2(4.5,4.8)));
    wear=max(wear,village_patch(p,vec2(-24.508,-3.021),vec2(4.5,4.8)));
    wear=max(wear,village_patch(p,vec2(-22.579,7.960),vec2(4.5,4.8)));
    wear=max(wear,village_patch(p,vec2(-20.237,17.207),vec2(4.5,4.8)));
    wear=max(wear,village_patch(p,vec2(-7.787,-7.798),vec2(4.5,4.8)));
    wear=max(wear,village_patch(p,vec2(-9.984,24.595),vec2(4.5,4.8)));
    wear=max(wear,village_patch(p,vec2(-9.603,2.849),vec2(4.5,4.8)));
    wear=max(wear,village_patch(p,vec2(-10.380,16.019),vec2(4.5,4.8)));
    float road=1000.0;
    road=min(road,segment_distance(p,vec2(-12.50,-26.00),vec2(-10.00,-20.00)));
    road=min(road,segment_distance(p,vec2(-10.00,-20.00),vec2(-11.00,-13.00)));
    road=min(road,segment_distance(p,vec2(-11.00,-13.00),vec2(-11.00,2.00)));
    road=min(road,segment_distance(p,vec2(-11.00,2.00),vec2(-21.00,14.00)));
    road=min(road,segment_distance(p,vec2(-11.00,-13.00),vec2(-19.00,-12.00)));
    road=min(road,segment_distance(p,vec2(-11.00,-5.00),vec2(-21.00,-4.00)));
    road=min(road,segment_distance(p,vec2(-11.00,2.00),vec2(-20.00,5.00)));
    road=min(road,segment_distance(p,vec2(-10.00,-20.00),vec2(-3.00,-18.50)));
    road=min(road,segment_distance(p,vec2(-3.00,-18.50),vec2(2.00,-24.00)));
    road=min(road,segment_distance(p,vec2(-3.00,-18.50),vec2(4.00,-20.00)));
    road=min(road,segment_distance(p,vec2(4.00,-20.00),vec2(12.00,-19.00)));
    road=min(road,segment_distance(p,vec2(-11.00,-5.00),vec2(-6.00,-5.00)));
    road=min(road,segment_distance(p,vec2(-11.00,2.00),vec2(-10.00,4.00)));
    road=min(road,segment_distance(p,vec2(-3.00,-18.50),vec2(-1.00,-12.00)));
    road=min(road,segment_distance(p,vec2(-10.0,-13.5),vec2(2.0,-13.5)));
    road=min(road,segment_distance(p,vec2(2.0,-13.5),vec2(3.8,-20.0)));
    road=min(road,segment_distance(p,vec2(3.8,-20.0),vec2(12.0,-20.0)));
    // Access lanes through the relocated residential quarter.
    road=min(road,segment_distance(p,vec2(-16.000,-13.000),vec2(-16.000,-3.000)));
    road=min(road,segment_distance(p,vec2(-16.000,-3.000),vec2(-16.000,8.000)));
    road=min(road,segment_distance(p,vec2(-16.000,8.000),vec2(-14.700,18.000)));
    road=min(road,segment_distance(p,vec2(-14.700,18.000),vec2(-11.500,23.000)));
    road=min(road,segment_distance(p,vec2(-16.000,-11.649),vec2(-20.781,-11.649)));
    road=min(road,segment_distance(p,vec2(-16.000,-2.742),vec2(-21.727,-2.742)));
    road=min(road,segment_distance(p,vec2(-16.000,6.856),vec2(-19.200,6.856)));
    road=min(road,segment_distance(p,vec2(-15.000,17.934),vec2(-17.373,17.934)));
    road=min(road,segment_distance(p,vec2(-16.000,-7.468),vec2(-10.401,-7.468)));
    road=min(road,segment_distance(p,vec2(-11.500,22.014),vec2(-11.422,22.014)));
    road=min(road,segment_distance(p,vec2(-16.000,1.458),vec2(-12.874,1.458)));
    road=min(road,segment_distance(p,vec2(-15.000,13.611),vec2(-12.041,13.611)));
    float width=forest_path_width(wp.xz);
    wear=max(wear,1.0-smoothstep(width-.20,width+.30,road+forest_path_edge(wp.xz)));
    return wear*(1.0-smoothstep(.30,.80,abs(wp.y-12.0)));
}
#include "res://shaders/stream_stones.gdshaderinc"
#include "res://shaders/hybrid_grass.gdshaderinc"
#include "res://shaders/mountain_ground.gdshaderinc"
void vertex(){
	world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment(){
	float n=noise(world_pos.xz*1.3)*0.65+noise(world_pos.xz*4.0)*0.25+noise(world_pos.xz*12.0)*0.1;
	vec3 grass=mix(vec3(0.13,0.19,0.055),vec3(0.34,0.40,0.13),n);
	vec3 rock=mix(vec3(0.19,0.24,0.23),vec3(0.43,0.46,0.38),n);
	float slope=1.0-abs(normalize(world_normal).y);
	float outer=smoothstep(0.0,12.0,max(max(abs(world_pos.x)-32.0,0.0),max(-40.0-world_pos.z,world_pos.z-24.0)));
	float rocky=max(smoothstep(0.17,0.42,slope),smoothstep(25.0,39.0,world_pos.y)*0.8)*outer;
	// Dirt belongs to the ground itself: no raised ribbon or rectangular ends.
    vec2 warped=world_pos.xz+vec2(noise(world_pos.xz*0.35),noise(world_pos.zx*0.35+19.0))*0.32;
    float d=trail_distance(warped);
    float width=forest_path_width(world_pos.xz);
    float edge=forest_path_edge(world_pos.xz);
    float worn=1.0-smoothstep(width-.20,width+.30,d+edge);
    worn*=1.0-smoothstep(0.20,0.36,slope);
    // Compacted earth around homes, bridge entrance and the public market.
    float village_wear=castle_village_wear(world_pos);
    worn=max(worn,village_wear*(1.0-smoothstep(.25,.50,slope)));
    vec3 dirt=mix(vec3(0.19,0.15,0.085),vec3(0.32,0.27,0.16),n);
    float flecks=smoothstep(0.80,0.94,noise(world_pos.xz*32.0));
    dirt=mix(dirt,vec3(0.40,0.37,0.27),flecks*0.22);
    float path_height=0.0;
    if (worn>.001) {
        forest_path_soil(world_pos.xz,dirt,path_height);
    }
    // Continuous world-space textures across all eleven new sectors.
    float expansion=max(world_pos.x-96.0,-world_pos.z-104.0);
    float mountain=smoothstep(0.0,26.0,expansion);
    float desert=smoothstep(39.0,93.0,expansion);
    float western_grass=1.0-smoothstep(96.0,144.0,-world_pos.x);
    mountain*=western_grass;
    desert*=western_grass;
    float northern_sand=smoothstep(168.0,195.0,-world_pos.z)*smoothstep(-210.0,-90.0,world_pos.x);
    desert=max(desert,northern_sand);
    float strata=noise(vec2(world_pos.y*1.8+noise(world_pos.xz*.14)*2.0,world_pos.x*.08));
    vec3 slate=mix(vec3(.22,.235,.25),vec3(.43,.44,.45),n*.65+strata*.35);
    float ripple=sin(world_pos.x*.95+world_pos.z*.43+noise(world_pos.xz*.13)*3.0)*.5+.5;
    vec3 sand=mix(vec3(.48,.32,.16),vec3(.72,.56,.32),n*.75+ripple*.25);
    vec3 dry_rock=mix(vec3(.37,.28,.20),vec3(.59,.45,.29),n);
    vec3 base=mix(mix(grass,rock,rocky),slate,mountain);
    base=mix(base,mix(sand,dry_rock,smoothstep(.19,.48,slope)),desert);
    ALBEDO=base;
    // Trampled earth follows the existing relief of the temporary bandit camp.
    float camp_radius=length((world_pos.xz-vec2(22.0,-60.0))/vec2(5.3,7.0));
    float camp_wear=(1.0-smoothstep(.60,1.05,camp_radius+(noise(world_pos.xz*1.8)-.5)*.16));
    float camp_access=1.0-smoothstep(.45,1.05,segment_distance(world_pos.xz,vec2(16.8,-56.0),vec2(21.0,-58.0)));
    ALBEDO=mix(ALBEDO,dirt,max(camp_wear*.70,camp_access*.62));
    // Southern littoral: world-space grass flecks, dry sand, then wet sand.
    float coast=smoothstep(92.0,135.0,world_pos.z+(noise(world_pos.xz*.19)-.5)*5.0);
    float grain=noise(world_pos.xz*34.0);
    float beach_ripple=sin(world_pos.x*1.6+world_pos.z*2.2+noise(world_pos.xz*.24)*3.0)*.5+.5;
    vec3 beach=mix(vec3(.59,.44,.25),vec3(.83,.69,.44),n*.65+grain*.2+beach_ripple*.15);
    float wet=1.0-smoothstep(.12,1.4,world_pos.y);
    beach=mix(beach,beach*vec3(.65,.72,.76),wet*.8);
    ALBEDO=mix(ALBEDO,beach,coast);
    // Damp sand and sparse green fringe belong to the oasis shore, in world space.
    vec2 lake_delta=(world_pos.xz-vec2(7.0,-213.0))/vec2(24.0,18.0);
    float lake_angle=atan(-lake_delta.y,lake_delta.x);
    float lake_r=length(lake_delta)/(1.0+.085*sin(3.0*lake_angle+.5)+.045*cos(5.0*lake_angle));
    float oasis_zone=smoothstep(183.0,195.0,-world_pos.z)*(1.0-smoothstep(1.15,1.5,lake_r));
    float damp=(1.0-smoothstep(5.6,6.35,world_pos.y))*oasis_zone;
    float fringe=smoothstep(.94,1.1,lake_r)*(1.0-smoothstep(1.13,1.4,lake_r))*smoothstep(.42,.67,noise(world_pos.xz*.7))*oasis_zone;
    ALBEDO=mix(ALBEDO,vec3(.34,.31,.17),damp*.65);
    ALBEDO=mix(ALBEDO,mix(vec3(.22,.29,.09),vec3(.38,.40,.15),n),fringe*.65);
    // Forêt maléfique: progressive corrupted soil darkening & browning
    // Primary zone: Western Hillside Clearing expanded to map boundaries
    vec2 c1_delta = (world_pos.xz - vec2(-215.0, -188.0)) / vec2(72.0, 96.0);
    float c1_dist = length(c1_delta) + (noise(world_pos.xz * 0.05) - 0.5) * 0.35 + (noise(world_pos.xz * 0.16) - 0.5) * 0.18;
    float mask1 = 1.0 - smoothstep(0.40, 1.05, c1_dist);
    // Boundary fade at the map edges to prevent any artifact in the void
    mask1 *= smoothstep(-288.0, -284.0, world_pos.x);
    mask1 *= smoothstep(-298.0, -290.0, world_pos.z);

    float corrupt_mask = mask1;
    vec3 corrupt_soil_dark = vec3(0.085, 0.06, 0.04);
    vec3 corrupt_soil_mid = vec3(0.18, 0.13, 0.085);
    vec3 corrupt_dirt = mix(corrupt_soil_dark, corrupt_soil_mid, n * 0.7 + noise(world_pos.xz * 0.4) * 0.3);
    vec3 corrupt_rock = mix(vec3(0.11, 0.10, 0.09), vec3(0.19, 0.17, 0.15), n);
    corrupt_dirt = mix(corrupt_dirt, corrupt_rock, smoothstep(0.18, 0.45, slope) * 0.7);
    ALBEDO = mix(ALBEDO, corrupt_dirt, corrupt_mask * 0.94);

    // Apply the approved brown earth after regional ground colors so trails
    // retain their texture throughout the mountains, dunes and corrupted forest.
    ALBEDO=mix(ALBEDO,dirt,worn*.88);

    // Conceal the grassy back wall of the spring beneath its existing rock arch.
    float spring_width = 1.0-smoothstep(3.7,4.6,abs(world_pos.x-6.4));
    float spring_depth = smoothstep(103.5,105.0,-world_pos.z)*(1.0-smoothstep(111.0,112.0,-world_pos.z));
    float spring_height = 1.0-smoothstep(2.6,3.5,world_pos.y);
    float spring_shadow = spring_width*spring_depth*spring_height;
    ALBEDO = mix(ALBEDO,vec3(0.003,0.004,0.004),spring_shadow);

    // Fine grain follows the ground; paths have no separate geometry.
    ROUGHNESS=mix(.95,.88,desert)+noise(world_pos.xz*21.0)*.035;
    ROUGHNESS=mix(ROUGHNESS,mix(.94,.48,wet),coast);
    ROUGHNESS=mix(ROUGHNESS,0.96,corrupt_mask*0.4);
    ROUGHNESS=mix(ROUGHNESS,.97,village_wear);
    SPECULAR=0.15;

    // Subtle relief on the paths; no added meshes or collisions.
    vec3 dpdx=dFdx(VERTEX);
    vec3 dpdy=dFdy(VERTEX);
    vec3 r1=cross(dpdy,NORMAL);
    vec3 r2=cross(NORMAL,dpdx);
    float determinant=dot(dpdx,r1);
    float soil_height=path_height*worn;
    NORMAL=normalize(NORMAL-sign(determinant)*(dFdx(soil_height)*r1+dFdy(soil_height)*r2)/max(abs(determinant),.00001));
    ROUGHNESS=mix(ROUGHNESS,.94,worn);

    // Detail the grass UNDER the unchanged soil mix, including its transition.
    // The dirt contribution itself is never multiplied by the grass texture.
    // Fade only inside the dirt-dominant end, leaving path interiors identical.
    float grass_clearance=1.0-smoothstep(.65,1.0,worn);
    float protected_ground=max(step(1.0,worn),max(camp_wear,camp_access));
    protected_ground=max(protected_ground,max(max(coast,damp),max(fringe,corrupt_mask)));
    protected_ground=max(protected_ground,max(max(mountain,desert),max(rocky,spring_shadow)));
    if (hybrid_grass_enabled && protected_ground <= 0.0) {
        float grass_mask=grass_clearance*(1.0-worn*.88)*hybrid_grass_stream_clearance(world_pos);
        ALBEDO+=grass*(hybrid_grass_modulation(world_pos.xz)-1.0)*hybrid_grass_strength*grass_mask;
    }
    // Reuse regional/path/grass exclusions; mountain detail cannot spill onto
    // the desert, coastal sand, corrupted ground, camps, spring or river gravel.
    float mountain_protected=max(max(coast,damp),max(fringe,corrupt_mask));
    mountain_protected=max(mountain_protected,max(max(camp_wear,camp_access),max(village_wear,spring_shadow)));
    mountain_protected=max(mountain_protected,1.0-hybrid_grass_stream_clearance(world_pos));
    mountain_protected=max(mountain_protected,worn);
    float mountain_mask=mountain_surface_mask(rocky,mountain,desert,mountain_protected);
    // Feather entirely on the mountain side, before the original sand begins.
    mountain_mask*=1.0-smoothstep(31.0,39.0,expansion);
    float original_rock_coverage=rocky*(1.0-mountain)+mountain;
    vec3 original_mountain_color=(rock*rocky*(1.0-mountain)+slate*mountain)/max(original_rock_coverage,.00001);
    float snow_mask=mountain_snow_mask(world_pos,normalize(world_normal),mountain_mask);
    float mountain_height=0.0;
    mountain_surface(world_pos,normalize(world_normal),original_mountain_color,mountain_mask,snow_mask,ALBEDO,ROUGHNESS,mountain_height);
    NORMAL=normalize(NORMAL-sign(determinant)*(dFdx(mountain_height)*r1+dFdy(mountain_height)*r2)/max(abs(determinant),.00001));
	stream_stones(world_pos, ALBEDO, ROUGHNESS);
    if (mountain_mask_preview==1) { ALBEDO=vec3(mountain_mask); }
    if (mountain_mask_preview==2) { ALBEDO=vec3(snow_mask); }
}
