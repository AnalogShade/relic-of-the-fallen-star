# Nova energy alpha v1

Created with the built-in image_gen tool, using transparent_background=true.
Original output copied unchanged into this project as energy_alpha_v1.png.
RGBA, 1254 × 1254; alpha range 0–253, with 510,314 fully transparent pixels
and 1,062,202 partially transparent pixels. Mipmaps enabled for 3D rendering.

## Exact generation prompt

Use case: stylized-concept. Asset type: production-ready RGBA game VFX texture, square 1024x1024, to map across an expanding magical shockwave in Godot. Create a TOP-DOWN, FLAT, irregular annular burst of cyan/turquoise magical plasma on a genuinely transparent background. Central 55 percent of the image diameter is mostly empty transparent space. Ring centered at image center, outer diameter about 88 percent of canvas. The ring must be VERY uneven and organic: torn smoky wisps escaping outward, asymmetric rolling turbulent eddies, branching thin electric filaments, variable thickness, bright dense clusters alternating with very faint partially transparent arcs and several small gaps. Some faint wisps trail inward. Rich layered translucent vapor rather than an opaque white outline. Pale mint highlights, cyan body, cool turquoise wisps. Strong variation at large, medium and fine scales. Soft dissolving outer edges with real partial alpha. Recognizable round shockwave but absolutely no geometrically perfect continuous circle, no clean vector outline, no concentric perfect circles, no regular radial spokes, no uniform repetition. Flat unlit texture only, no perspective, no ground, no scene, no characters, no letters, no labels, no checkerboard baked into image, no black background, no drop shadow. Leave all four image borders completely transparent so the effect does not clip. Preserve subtle filaments and transparency.

## Integration

Used by the ground wave, masked shell and 56 batched billboard aura particles.
The main wave has two elevated companion layers at heights 2.2 and 4.4 metres,
radius multipliers 0.94 and 0.86, angular offsets 2.1 and 4.2 radians,
and opacity 0.85 and 0.80. They begin after 0.08 and 0.17 seconds and expand
over 0.75 and 0.90 seconds, independently of the main 0.65-second wave.
The whole effect rotates around Y at 1.8 radians/second, with smaller independent
texture drifts. Initial texture orientation is randomized per cast.
All motion and particle lifetimes use the spell clock, including inventory pause.

Previous production scripts/shaders were preserved in
diagnostics/nova_texture_20261030/before at repository root.
