shader_type canvas_item;
render_mode unshaded;
uniform sampler2D scene_color : hint_screen_texture, filter_linear, repeat_disable;
uniform float pixel_radius : hint_range(0.5, 2.0) = 0.65;
uniform float softening : hint_range(0.0, 1.0) = 0.20;

void fragment() {
	// Normalized 5x5 Gaussian. Preserves colors and softens the final 3D image,
	// including the native AO grain. HUD is drawn on higher canvas layers.
	vec3 blurred = vec3(0.0);
	for (int y=-2; y<=2; y++) {
		float wy = y==0 ? 6.0 : (abs(y)==1 ? 4.0 : 1.0);
		for (int x=-2; x<=2; x++) {
			float wx = x==0 ? 6.0 : (abs(x)==1 ? 4.0 : 1.0);
			vec2 offset = vec2(float(x),float(y))*SCREEN_PIXEL_SIZE*pixel_radius;
			blurred += textureLod(scene_color, SCREEN_UV+offset, 0.0).rgb*wx*wy;
		}
	}
	vec3 original = textureLod(scene_color, SCREEN_UV, 0.0).rgb;
	COLOR = vec4(mix(original,blurred/256.0,softening),1.0);
}

