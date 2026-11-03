@tool
extends Node3D
## Small hearth plumes, anchored to the authored chimney tops.
const LAYOUT := "res://assets/environment/castle_quarter_smoke.json"
@export_file("*.json") var layout_path := LAYOUT

func _ready() -> void:
	call_deferred("_build")

func _build() -> void:
	if get_child_count() > 0:
		return
	var houses: Variant = JSON.parse_string(FileAccess.get_file_as_string(layout_path))
	if not houses is Array:
		push_error("Chimney layout could not be loaded: " + layout_path)
		return
	var puff := _puff_mesh()
	for house: Dictionary in houses:
		var coords: Array = house["smoke_godot"]
		var particles := CPUParticles3D.new()
		particles.name = "Maison_%02d_Fumee" % int(house["house"])
		particles.position = Vector3(coords[0], coords[1], coords[2])
		particles.amount = 42
		particles.lifetime = 6.5
		particles.preprocess = 6.5
		particles.randomness = 0.3
		particles.lifetime_randomness = 0.2
		particles.local_coords = false
		particles.use_fixed_seed = true
		particles.seed = 1900 + int(house["house"])
		particles.mesh = puff
		particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		particles.emission_sphere_radius = 0.10
		particles.direction = Vector3(0.12, 1.0, 0.04).normalized()
		particles.spread = 9.0
		particles.gravity = Vector3(0.055, 0.035, 0.018)
		particles.initial_velocity_min = 0.65
		particles.initial_velocity_max = 0.9
		particles.angular_velocity_min = -14.0
		particles.angular_velocity_max = 14.0
		particles.angle_min = -180.0
		particles.angle_max = 180.0
		particles.scale_amount_min = 0.60
		particles.scale_amount_max = 0.85
		var growth := Curve.new()
		growth.min_value = 0.0
		growth.max_value = 3.0
		growth.add_point(Vector2(0.0, 0.35))
		growth.add_point(Vector2(0.35, 1.0))
		growth.add_point(Vector2(1.0, 2.8))
		particles.scale_amount_curve = growth
		var fade := Gradient.new()
		fade.offsets = PackedFloat32Array([0.0, 0.08, 0.35, 0.7, 1.0])
		fade.colors = PackedColorArray([Color(0.63,0.62,0.59,0.0), Color(0.65,0.64,0.62,0.32), Color(0.73,0.72,0.70,0.25), Color(0.79,0.78,0.76,0.10), Color(0.82,0.81,0.79,0.0)])
		particles.color_ramp = fade
		particles.draw_order = CPUParticles3D.DRAW_ORDER_VIEW_DEPTH
		particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		particles.visibility_aabb = AABB(Vector3(-3,-1,-3),Vector3(9,11,8))
		particles.visibility_range_end = 180.0
		particles.visibility_range_end_margin = 20.0
		add_child(particles)

func _puff_mesh() -> QuadMesh:
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 1247
	noise.frequency = 0.055
	noise.fractal_octaves = 3
	for y in range(128):
		for x in range(128):
			var uv := (Vector2(x,y) + Vector2(0.5,0.5)) / 64.0 - Vector2.ONE
			var cloud := noise.get_noise_2d(float(x),float(y)) * 0.5 + 0.5
			var radius := uv.length() + (cloud - 0.5) * 0.18
			var alpha := pow(maxf(0.0,1.0 - smoothstep(0.12, 1.0, radius)), 1.6)
			alpha *= lerpf(0.45, 1.0, cloud)
			image.set_pixel(x,y,Color(1.0,1.0,1.0,alpha))
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 1.0
	var quad := QuadMesh.new()
	quad.size = Vector2(1.1,1.1)
	quad.material = material
	return quad
