// Image detail modulates the existing procedural green, never replaces its hue.
// Disabled until the material binds both project-local generated textures.
uniform bool hybrid_grass_enabled = false;
uniform float hybrid_grass_strength : hint_range(0.0, 1.0) = 0.72;
uniform float hybrid_grass_tile_meters : hint_range(0.5, 12.0) = 4.8;
uniform sampler2D hybrid_grass_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D hybrid_grass_b : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 hybrid_grass_mean_luma = vec2(0.182297, 0.171937);
uniform vec2 hybrid_grass_mean_luma_srgb = vec2(0.407655, 0.414639);

// Overlapping half-tile phases fade each source edge to zero. This also
// conceals imperfect generated seams without alpha or transparent terrain.
vec3 hybrid_grass_periodic(sampler2D image, vec2 uv) {
    vec2 w = 0.5 - 0.5 * cos(6.28318530718 * uv);
    return texture(image, uv).rgb * w.x * w.y
        + texture(image, uv + vec2(0.5, 0.0)).rgb * (1.0-w.x) * w.y
        + texture(image, uv + vec2(0.0, 0.5)).rgb * w.x * (1.0-w.y)
        + texture(image, uv + vec2(0.5)).rgb * (1.0-w.x) * (1.0-w.y);
}

float hybrid_grass_modulation(vec2 p) {
    vec2 uv = p / hybrid_grass_tile_meters;
    vec3 a = hybrid_grass_periodic(hybrid_grass_a, uv);
    vec3 b = hybrid_grass_periodic(hybrid_grass_b,
        mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * uv * 1.173 + vec2(0.37, 0.19));
    vec3 luminance = vec3(0.2126, 0.7152, 0.0722);
    // Compatibility renders in sRGB; Forward+/Mobile work in linear space.
    vec2 average = OUTPUT_IS_SRGB ? hybrid_grass_mean_luma_srgb : hybrid_grass_mean_luma;
    float la = dot(a, luminance) / average.x;
    float lb = dot(b, luminance) / average.y;
    float variant = smoothstep(0.25, 0.75, noise(p * 0.19 + vec2(41.0, 17.0)));
    return clamp(mix(la, lb, variant), 0.55, 1.65);
}

// Same footprint samples as stream_stones, with a conservative feather OUTSIDE
// its coverage. No image detail reaches even partially blended gravel banks.
float hybrid_grass_stream_clearance(vec3 p) {
    if (!stream_stones_enabled) { return 1.0; }
    vec2 uv = (p.xz-stream_rect.xy)/stream_rect.zw;
    if (any(lessThan(uv,vec2(0.0))) || any(greaterThan(uv,vec2(1.0)))) { return 1.0; }
    float width = 1.05 + noise(p.xz*1.7)*0.65;
    float coverage = 0.0;
    for (int i=0; i<13; i++) {
        float angle = float(i)*2.399963;
        vec2 offset = i == 0 ? vec2(0.0) : vec2(cos(angle),sin(angle))*width;
        float value = texture(stream_footprint,uv+offset/stream_rect.zw).r;
        coverage = max(coverage, value*(i==0 ? 1.0 : 0.9));
    }
    return 1.0-smoothstep(0.0, 0.12, coverage);
}
