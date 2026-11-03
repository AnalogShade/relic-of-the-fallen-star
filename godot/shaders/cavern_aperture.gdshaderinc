// EntranceFrame coordinates: the opening faces +Z. Only rays entering through
// the mouth may see darkness; rays entering through the roof/back/sides may not.
float cave_aperture(vec3 eye, vec3 surface) {
	vec3 ray = surface - eye;
	vec3 mouth = eye;
	if (eye.z > 0.1) {
		if (ray.z >= -0.00001) { return 0.0; }
		float t = (0.1 - eye.z) / ray.z;
		if (t > 1.0) { return 0.0; }
		mouth = eye + ray * t;
	} else {
		// Keep the effect while walking inside, but never from behind the cave.
		if (eye.z < -5.1) { return 0.0; }
	}
	vec2 aperture = (mouth.xy - vec2(0.0, 1.8)) / vec2(1.95, 2.45);
	return 1.0 - smoothstep(0.85, 1.0, length(aperture));
}
