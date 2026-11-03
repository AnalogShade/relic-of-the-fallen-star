shader_type sky;
render_mode disable_fog;

// One sky for both the background and outdoor ambient/reflected light.
// The existing DayNightCycle supplies all directions and colors, never LIGHT0/1
// (which could accidentally interpret a fill light as another sun).
uniform sampler2D cloud_noise : repeat_enable, filter_linear_mipmap;
uniform vec3 zenith_color : source_color = vec3(0.23, 0.46, 0.76);
uniform vec3 horizon_color : source_color = vec3(0.69, 0.79, 0.88);
uniform vec3 ground_color : source_color = vec3(0.19, 0.23, 0.20);
uniform vec3 sun_color : source_color = vec3(1.0, 0.94, 0.84);
uniform vec3 cloud_light_color : source_color = vec3(0.96, 0.97, 1.0);
uniform vec3 cloud_shadow_color : source_color = vec3(0.48, 0.56, 0.68);
uniform vec3 sun_direction = vec3(-0.35, 0.74, 0.57);
uniform vec3 moon_direction = vec3(0.35, -0.74, -0.57);
uniform float daylight = 1.0;
uniform float stars_visibility = 0.0;
uniform vec2 cloud_offset = vec2(0.0);

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float cloud_field(vec2 p) {
	return texture(cloud_noise, p * 0.11).r * 0.60
		+ texture(cloud_noise, p * 0.27 + vec2(0.31, 0.19)).r * 0.28
		+ texture(cloud_noise, p * 0.63).r * 0.12;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float height = max(dir.y, 0.0);
	float horizon = pow(1.0 - height, 3.0);
	vec3 color = mix(zenith_color, horizon_color, horizon);
	float sun_dot = max(dot(dir, sun_direction), 0.0);
	float sun_up = smoothstep(-0.10, 0.12, sun_direction.y);
	// Warm atmosphere near the real sun, including just below the horizon.
	float sunset = (1.0 - smoothstep(0.05, 0.45, abs(sun_direction.y))) * sun_up;
	color += sun_color * (pow(sun_dot, 12.0) * 0.16 * sun_up
		+ pow(sun_dot, 5.0) * horizon * sunset * 0.22);
	if (dir.y < 0.0) {
		color = mix(horizon_color, ground_color, smoothstep(0.0, 0.35, -dir.y));
	}

	// Exclude tiny bright discs and stars from diffuse/reflection filtering.
	if (!AT_CUBEMAP_PASS && dir.y > 0.0) {
		vec2 star_uv = vec2(atan(dir.z, dir.x) / TAU + 0.5, asin(dir.y) / PI + 0.5);
		vec2 grid = star_uv * vec2(780.0, 390.0);
		vec2 cell = floor(grid);
		vec2 center = vec2(hash21(cell + 17.0), hash21(cell + 43.0)) * 0.6 + 0.2;
		float seed = hash21(cell);
		float radius = mix(0.045, 0.12, hash21(cell + 71.0));
		float aa = max(length(fwidth(grid)) * 0.45, 0.01);
		float star = (1.0 - smoothstep(radius - aa, radius + aa, length(fract(grid) - center)));
		star *= step(0.983, seed) * mix(0.45, 2.0, hash21(cell + 5.0));
		vec3 star_color = mix(vec3(0.68, 0.80, 1.0), vec3(1.0, 0.88, 0.72), hash21(cell + 8.0));
		color += star_color * star * stars_visibility * smoothstep(0.0, 0.20, dir.y);
		float sun_disk = smoothstep(cos(0.010), cos(0.007), dot(dir, sun_direction));
		color += vec3(1.0, 0.92, 0.76) * sun_disk * 3.0 * sun_up;
		float moon_dot = max(dot(dir, moon_direction), 0.0);
		float moon_disk = smoothstep(cos(0.012), cos(0.010), moon_dot);
		color += vec3(0.64, 0.74, 0.95) * (moon_disk * 1.15 + pow(moon_dot, 180.0) * 0.10)
			* stars_visibility * smoothstep(-0.03, 0.08, moon_direction.y);
	}

	if (dir.y > 0.0) {
		vec2 p = dir.xz / (dir.y + 0.20) * 1.65;
		float field = cloud_field(p + cloud_offset);
		float cloud = smoothstep(0.47, 0.65, field);
		float upper = cloud_field(p * vec2(1.2, 3.3) + cloud_offset * 0.45 + vec2(7.3, 2.1));
		float wisps = smoothstep(0.54, 0.72, upper) * 0.28;
		float coverage = (cloud + wisps * (1.0 - cloud)) * smoothstep(0.015, 0.12, dir.y);
		// Lit edges and shaded bases give depth without expensive ray marching.
		float toward_light = cloud_field(p + cloud_offset + sun_direction.xz * 0.20);
		float edge = clamp((field - toward_light) * 7.0 + 0.55, 0.0, 1.0);
		float thickness = smoothstep(0.49, 0.69, field);
		vec3 clouds = mix(cloud_light_color, cloud_shadow_color, thickness * 0.70);
		clouds += cloud_light_color * edge * 0.17 * daylight;
		color = mix(color, clouds, clamp(coverage, 0.0, 1.0));
	}
	COLOR = max(color, vec3(0.0));
}
