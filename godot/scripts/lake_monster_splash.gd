extends Node3D
## A handful of RGBA splash cards, one instanced draw, no 3D droplets or particle simulation.
const SPLASH_TEXTURE = preload("res://assets/effects/lake_splash/splash_fan_rgba.png")
const CARD_SHADER = preload("res://shaders/lake_splash_billboard.gdshader")
const RING_SHADER = preload("res://shaders/water_step_ring.gdshader")
static var card_mesh: QuadMesh
var large := true
var elapsed := 0.0
var duration := 2.3
var sheets: MultiMeshInstance3D
var sheet_material: ShaderMaterial
var ring_material: ShaderMaterial

func _ready() -> void:
	duration = 2.3 if large else 1.15
	if card_mesh == null:
		card_mesh = QuadMesh.new()
		card_mesh.size = Vector2.ONE
	sheets = MultiMeshInstance3D.new()
	sheets.name = "SplashCards"
	sheets.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_custom_data = true
	instances.mesh = card_mesh
	instances.instance_count = 12 if large else 4
	for i in range(instances.instance_count):
		var angle := i * TAU / instances.instance_count + randf_range(-0.15, 0.15)
		var radius := randf_range(5.8, 7.0) if large else randf_range(0.05, 0.65)
		var width := randf_range(3.5, 5.0) if large else randf_range(0.65, 1.15)
		var height := randf_range(3.5, 5.5) if large else randf_range(0.65, 1.1)
		var transform := Transform3D(Basis.IDENTITY.scaled(Vector3(width, height, 1)), Vector3(cos(angle) * radius, 0, sin(angle) * radius))
		instances.set_instance_transform(i, transform)
		instances.set_instance_custom_data(i, Color(randf(), randf(), randf_range(0.65, 0.95), 1))
	sheets.multimesh = instances
	# Billboard size and growth happen in the shader; expand bounds to include that displacement.
	sheets.custom_aabb = AABB(Vector3(-12, -1, -12), Vector3(24, 8, 24))
	sheet_material = ShaderMaterial.new()
	sheet_material.shader = CARD_SHADER
	# Water is transparent too; draw the spray after it, while retaining depth tests.
	sheet_material.render_priority = 2
	sheet_material.set_shader_parameter("splash_texture", SPLASH_TEXTURE)
	sheets.material_override = sheet_material
	add_child(sheets)
	var ring := MeshInstance3D.new()
	ring.name = "SurfaceRing"
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * (28.0 if large else 3.5)
	ring.mesh = plane
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring_material = ShaderMaterial.new()
	ring_material.shader = RING_SHADER
	ring_material.render_priority = 1
	ring_material.set_shader_parameter("variation", randf() * TAU)
	ring.material_override = ring_material
	add_child(ring)

func _process(delta: float) -> void:
	elapsed += delta
	var age := minf(elapsed / duration, 1.0)
	sheet_material.set_shader_parameter("age", age)
	ring_material.set_shader_parameter("age", age)
	if elapsed >= duration: queue_free()
