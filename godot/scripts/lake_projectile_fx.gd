extends Node3D
## Small procedural billboard trails; world-space particles persist briefly after impact.
const ENERGY_SHADER = preload("res://shaders/lake_projectile_energy.gdshader")
const CORE_SHADER = preload("res://shaders/lake_projectile_core.gdshader")
static var materials := {}
var core: MeshInstance3D
var halo: MeshInstance3D
var trails: Array[CPUParticles3D] = []
var ended := false
var fade_time := 0.0

static func energy_material(key: String, tint: Color, broad := false) -> ShaderMaterial:
	if not materials.has(key):
		var material := ShaderMaterial.new()
		material.shader = ENERGY_SHADER
		material.render_priority = 3
		material.set_shader_parameter("tint", tint)
		material.set_shader_parameter("halo", 1.0 if broad else 0.0)
		materials[key] = material
	return materials[key]

func _ready() -> void:
	add_to_group("lake_projectile_fx")
	core = MeshInstance3D.new()
	core.name = "TurbulentCore"
	var mesh := SphereMesh.new()
	mesh.radius = 0.32
	mesh.height = 0.83
	mesh.radial_segments = 16
	mesh.rings = 8
	if not materials.has("core"):
		var material := ShaderMaterial.new()
		material.shader = CORE_SHADER
		materials.core = material
	mesh.material = materials.core
	core.mesh = mesh
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core)
	halo = MeshInstance3D.new()
	halo.name = "CyanHalo"
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 2.5
	quad.material = energy_material("halo", Color(0.08, 0.58, 1.0, 0.65), true)
	halo.mesh = quad
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(halo)
	_make_trail("CyanWake", 36, 0.55, 1.15, Color(0.08, 0.65, 1.0, 0.75), 0.12)
	_make_trail("VioletWisps", 18, 0.70, 1.5, Color(0.30, 0.10, 0.65, 0.32), 0.22)
	_make_trail("SpraySparks", 12, 0.40, 0.16, Color(0.45, 0.90, 1.0, 0.9), 0.3)

func _make_trail(label: String, count: int, lifetime: float, size: float, tint: Color, radius: float) -> void:
	var particles := CPUParticles3D.new()
	particles.name = label
	particles.amount = count
	particles.lifetime = lifetime
	particles.local_coords = false
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = radius
	particles.direction = Vector3.UP
	particles.spread = 180
	particles.initial_velocity_min = 0.2
	particles.initial_velocity_max = 0.8
	particles.gravity = Vector3(0, 0.25, 0)
	particles.scale_amount_min = 0.65
	particles.scale_amount_max = 1.1
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0, 0.5))
	scale_curve.add_point(Vector2(0.2, 1))
	scale_curve.add_point(Vector2(1, 0.02))
	particles.scale_amount_curve = scale_curve
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1, 1, 1, 0))
	particles.color_ramp = fade
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	quad.material = energy_material(label, tint)
	particles.mesh = quad
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particles)
	trails.append(particles)

func orient(direction: Vector3) -> void:
	if direction.length_squared() < 0.001: return
	core.quaternion = Quaternion(Vector3.UP, direction.normalized())

func finish(impact := true) -> void:
	if ended: return
	ended = true
	core.hide()
	for trail in trails: trail.emitting = false
	halo.visible = impact
	# Keep the world-space wake alive when the gameplay projectile is deleted.
	reparent(get_tree().current_scene, true)

func _process(delta: float) -> void:
	if ended:
		fade_time += delta
		halo.scale = Vector3.ONE * (1.0 + fade_time * 5.0)
		halo.transparency = clampf(fade_time / 0.22, 0, 1)
		if fade_time >= 0.75: queue_free()
	else:
		core.rotate_object_local(Vector3.UP, delta * 3.0)
		halo.scale = Vector3.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.014) * 0.08)
