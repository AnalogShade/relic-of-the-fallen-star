// Independent procedural masks, in the same world coordinates as paths/grass.
uniform bool mountain_textures_enabled = false;
uniform bool mountain_snow_enabled = true;
uniform float mountain_tile_meters : hint_range(1.0, 64.0) = 24.0;
uniform float snow_tile_meters : hint_range(1.0, 12.0) = 4.0;
uniform float snow_line_meters : hint_range(20.0, 80.0) = 36.0;
uniform float snow_transition_meters : hint_range(1.0, 20.0) = 10.0;
// 0: beauty, 1: mountain mask, 2: snow mask.
uniform int mountain_mask_preview : hint_range(0, 2) = 0;
uniform sampler2D mountain_granite : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mountain_schist : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mountain_snow : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

// Edge-free periodic reconstruction: each raw image boundary receives zero
// weight, including imperfect AI-generated tile borders. No image resampling.
vec3 mountain_periodic(sampler2D tex, vec2 uv) {
    vec2 w = 0.5-0.5*cos(6.28318530718*uv);
    return texture(tex,uv).rgb*w.x*w.y
        + texture(tex,uv+vec2(.5,0.0)).rgb*(1.0-w.x)*w.y
        + texture(tex,uv+vec2(0.0,.5)).rgb*w.x*(1.0-w.y)
        + texture(tex,uv+vec2(.5)).rgb*(1.0-w.x)*(1.0-w.y);
}

vec3 mountain_triplanar(sampler2D tex, vec3 p, vec3 weights) {
    return mountain_periodic(tex,p.zy)*weights.x
        + mountain_periodic(tex,p.xz)*weights.y
        + mountain_periodic(tex,p.xy)*weights.z;
}

// Three overlapping, randomly rotated/offset tiles on a triangular lattice.
// Explicit derivatives keep filtering stable where the lattice cell changes.
vec3 mountain_random_tile(sampler2D tex, vec2 uv, vec2 cell, vec2 dx, vec2 dy) {
    float angle = floor(hash(cell+vec2(13.7,91.3))*4.0)*1.57079632679;
    mat2 turn = mat2(vec2(cos(angle),sin(angle)),vec2(-sin(angle),cos(angle)));
    vec2 offset = vec2(hash(cell+vec2(31.0,7.0)),hash(cell+vec2(5.0,59.0)));
    vec2 q = turn*uv+offset;
    vec2 gx = turn*dx;
    vec2 gy = turn*dy;
    vec2 w = .5-.5*cos(6.28318530718*q);
    return textureGrad(tex,q,gx,gy).rgb*w.x*w.y
        + textureGrad(tex,q+vec2(.5,0.0),gx,gy).rgb*(1.0-w.x)*w.y
        + textureGrad(tex,q+vec2(0.0,.5),gx,gy).rgb*w.x*(1.0-w.y)
        + textureGrad(tex,q+vec2(.5),gx,gy).rgb*(1.0-w.x)*(1.0-w.y);
}

vec3 mountain_stochastic(sampler2D tex, vec2 uv) {
    vec2 dx = dFdx(uv);
    vec2 dy = dFdy(uv);
    vec2 cell = floor(uv);
    vec2 f = fract(uv);
    vec2 c1;
    vec2 c2;
    vec3 w;
    if (f.x+f.y<1.0) {
        c1=cell+vec2(1.0,0.0);
        c2=cell+vec2(0.0,1.0);
        w=vec3(1.0-f.x-f.y,f.x,f.y);
    } else {
        c1=cell+vec2(0.0,1.0);
        c2=cell+vec2(1.0,0.0);
        cell+=vec2(1.0);
        w=vec3(f.x+f.y-1.0,1.0-f.x,1.0-f.y);
    }
    // Concentrate the blend to retain the large cracks and slab patterns.
    w=pow(w,vec3(3.0));
    w/=max(dot(w,vec3(1.0)),.00001);
    return mountain_random_tile(tex,uv,cell,dx,dy)*w.x
        + mountain_random_tile(tex,uv,c1,dx,dy)*w.y
        + mountain_random_tile(tex,uv,c2,dx,dy)*w.z;
}

vec3 mountain_rock_triplanar(sampler2D tex, vec3 p, vec3 weights) {
    return mountain_stochastic(tex,p.zy)*weights.x
        + mountain_stochastic(tex,p.xz)*weights.y
        + mountain_stochastic(tex,p.xy)*weights.z;
}

float mountain_surface_mask(float rocky, float region, float desert, float protected_mask) {
    // Exact original rock/slate contribution. Any sand/protected coverage
    // excludes the pixel entirely, including partially blended boundaries.
    float coverage = rocky*(1.0-region)+region;
    return desert>0.0 || protected_mask>0.0 ? 0.0 : clamp(coverage,0.0,1.0);
}

float mountain_snow_mask(vec3 p, vec3 normal, float mountain_mask) {
    float drift = (noise(p.xz*.13+vec2(73.0,29.0))-.5)*5.0
        + (noise(p.xz*.71)-.5)*1.6;
    float altitude = smoothstep(snow_line_meters,snow_line_meters+snow_transition_meters,p.y+drift);
    // Accumulates on summits/ledges, leaves steep faces exposed.
    float deposit = smoothstep(.40,.83,normal.y);
    return mountain_snow_enabled ? mountain_mask*altitude*deposit : 0.0;
}

void mountain_surface(vec3 p, vec3 normal, vec3 original_rock, float mask, float snow,
        inout vec3 albedo, inout float roughness, out float height) {
    height = 0.0;
    if (!mountain_textures_enabled || mask<=.001) { return; }
    vec3 weights = pow(abs(normal),vec3(4.0));
    weights /= max(dot(weights,vec3(1.0)),.0001);
    vec3 a = mountain_rock_triplanar(mountain_granite,p/mountain_tile_meters,weights);
    // Different phase/scale plus slow geological blending breaks repetition.
    vec3 b = mountain_rock_triplanar(mountain_schist,p/(mountain_tile_meters*1.173)+vec3(.37,.19,.61),weights);
    float variation = smoothstep(.24,.76,noise(p.xz*.047+vec2(17.0,61.0)));
    vec3 rock = mix(a,b,variation);
    rock *= mix(.70,.86,noise(p.xz*.11));
    vec3 finish = rock;
    float grain = dot(rock,vec3(.2126,.7152,.0722));
    height = grain*.012*mask;
    if (snow>.001) {
        vec3 ice = mountain_triplanar(mountain_snow,p/snow_tile_meters,weights);
        finish = mix(rock,ice*.82,clamp(snow/max(mask,.001),0.0,1.0));
        height *= 1.0-snow;
    }
    // Replace only the existing rock contribution; retain the original grass
    // term verbatim on mixed grassy/rocky slopes.
    albedo += (finish-original_rock)*mask;
    roughness = mix(roughness,mix(.94,.86,snow),mask);
}
