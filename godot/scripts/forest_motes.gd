extends MultiMeshInstance3D
## Quiet translucent pollen. Deterministic wandering, no emitted light.
@export_range(16, 240) var amount: int = 150
@export var radius: float = 19.0
var target: Node3D
var clock: float = 0.0
var seeds: Array[Vector3] = []
var phases: PackedFloat32Array = []

func _ready() -> void:
	target = get_parent().get_node_or_null("Original/Player")
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/forest_motes.gdshader")
	quad.material = material
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = quad
	multimesh.instance_count = amount
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var rng := RandomNumberGenerator.new()
	rng.seed = 72941
	for i in range(amount):
		seeds.append(Vector3(rng.randf_range(-radius, radius), rng.randf_range(0.6, 6.5), rng.randf_range(-radius, radius)))
		phases.append(rng.randf_range(0.0, TAU))
	if target != null:
		global_position = target.global_position
	_process(0.0)

func _process(delta: float) -> void:
	if target == null:
		return
	clock += delta
	# World-space drift stays continuous when walking; wrapping happens invisibly.
	global_position.y = lerpf(global_position.y, target.global_position.y, 1.0 - exp(-delta * 0.7))
	for i in range(amount):
		var phase := phases[i]
		var t := clock * (0.24 + float(i % 7) * 0.025)
		var p := seeds[i] + Vector3(sin(t + phase) * 1.2 + sin(t * 1.73 + phase) * 0.35,
			sin(t * 0.83 + phase) * 0.45, cos(t * 1.13 + phase) * 1.3)
		p.x = target.global_position.x + wrapf(p.x - target.global_position.x, -radius, radius)
		p.z = target.global_position.z + wrapf(p.z - target.global_position.z, -radius, radius)
		var distance := Vector2(p.x - target.global_position.x, p.z - target.global_position.z).length()
		var opacity := (1.0 - smoothstep(radius * 0.65, radius, distance)) * (0.22 + 0.12 * sin(t + phase))
		var size := 0.07 + float(i % 5) * 0.02
		p.x -= global_position.x
		p.z -= global_position.z
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), p))
		multimesh.set_instance_color(i, Color(0.81, 0.85, 0.69, opacity))
