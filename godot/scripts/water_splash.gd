extends Node3D
## World-space one-shot: tiny lit droplets and a fading procedural surface ring.
const RING_SHADER = preload("res://shaders/water_step_ring.gdshader")
var strength := 1.0
var drift := Vector3.ZERO
var elapsed := 0.0
var ring_material: ShaderMaterial
var drops: CPUParticles3D

func _ready() -> void:
	var ring := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * (0.95 + strength * 0.32)
	ring.mesh = plane
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring_material = ShaderMaterial.new()
	ring_material.shader = RING_SHADER
	ring_material.set_shader_parameter("variation", randf() * TAU)
	ring.material_override = ring_material
	add_child(ring)
	drops = CPUParticles3D.new()
	drops.amount = int(10 + 9 * strength)
	drops.lifetime = 0.42 + strength * 0.09
	drops.one_shot = true
	drops.explosiveness = 1.0
	drops.randomness = 0.35
	drops.local_coords = false
	drops.direction = Vector3.UP + drift.limit_length(1.0) * 0.22
	drops.spread = 62.0
	drops.gravity = Vector3(0, -7.5, 0)
	drops.initial_velocity_min = 0.8 + strength * 0.2
	drops.initial_velocity_max = 1.3 + strength * 0.5
	drops.scale_amount_min = 0.012
	drops.scale_amount_max = 0.025 + strength * 0.006
	drops.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	drops.emission_sphere_radius = 0.065 + strength * 0.02
	var bead := SphereMesh.new()
	bead.radius = 0.5
	bead.height = 1.5
	bead.radial_segments = 6
	bead.rings = 3
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.68, 0.85, 0.90)
	material.roughness = 0.18
	bead.material = material
	drops.mesh = bead
	drops.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 0.6))
	shrink.add_point(Vector2(0.15, 1))
	shrink.add_point(Vector2(1, 0))
	drops.scale_amount_curve = shrink
	add_child(drops)
	drops.emitting = true

func _process(delta: float) -> void:
	elapsed += delta
	ring_material.set_shader_parameter("age", minf(elapsed / 0.95, 1.0))
	if elapsed > 1.05:
		queue_free()
