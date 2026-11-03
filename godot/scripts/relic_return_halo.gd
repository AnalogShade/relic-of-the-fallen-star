extends Node3D
## Completion reward: the existing F interaction handles travel, never proximity alone.
const LOOT_KEY := "cave/first_echo"
const RADIUS := 1.65
var activated := false
var material: ShaderMaterial
var lamp: OmniLight3D
var sparks: GPUParticles3D

func _ready() -> void:
	add_to_group("interactable")
	var disc := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(4.6, 4.6)
	disc.mesh = plane
	material = ShaderMaterial.new()
	material.shader = preload("res://shaders/relic_return_halo.gdshader")
	material.set_shader_parameter("awakening", 0.0)
	disc.material_override = material
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)
	lamp = OmniLight3D.new()
	lamp.position.y = 0.6
	lamp.light_color = Color("62e8cc")
	lamp.light_energy = 0.0
	lamp.omni_range = 4.5
	add_child(lamp)
	sparks = GPUParticles3D.new()
	sparks.amount = 32
	sparks.lifetime = 2.8
	sparks.emitting = false
	sparks.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 5, 6))
	var particles := ParticleProcessMaterial.new()
	particles.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	particles.emission_ring_axis = Vector3.UP
	particles.emission_ring_radius = 1.85
	particles.emission_ring_inner_radius = 1.4
	particles.emission_ring_height = 0.03
	particles.direction = Vector3.UP
	particles.spread = 12.0
	particles.initial_velocity_min = 0.25
	particles.initial_velocity_max = 0.65
	particles.gravity = Vector3.ZERO
	particles.scale_min = 0.018
	particles.scale_max = 0.045
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.35, 1.0, 0.85, 0.0))
	gradient.add_point(0.18, Color(0.45, 1.0, 0.85, 0.8))
	gradient.set_color(1, Color(1.0, 0.75, 0.35, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	particles.color_ramp = ramp
	sparks.process_material = particles
	var quad := QuadMesh.new()
	quad.size = Vector2(0.045, 0.045)
	var sparkle := StandardMaterial3D.new()
	sparkle.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sparkle.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sparkle.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sparkle.vertex_color_use_as_albedo = true
	sparkle.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = sparkle
	sparks.draw_pass_1 = quad
	add_child(sparks)
	visible = false
	_sync_unlock()

func _sync_unlock() -> void:
	if activated or not get_node("/root/Inventory").collected.has(LOOT_KEY): return
	activated = true
	show()
	sparks.emitting = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(material, "shader_parameter/awakening", 1.0, 1.2)
	tween.tween_property(lamp, "light_energy", 1.3, 1.2)

func _process(_delta: float) -> void:
	_sync_unlock()
	if activated:
		material.set_shader_parameter("presence", 1.0 if can_interact() else 0.0)

func interaction_text() -> String:
	return "Retourner à l’entrée de la grotte"

func can_interact() -> bool:
	var inventory := get_node("/root/Inventory")
	if not activated or not inventory.collected.has(LOOT_KEY) or inventory.is_open or get_node("/root/CabinTravel").busy: return false
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not player: return false
	var offset := player.global_position - global_position
	return Vector2(offset.x, offset.z).length() <= RADIUS and absf(offset.y) < 1.5

func interact() -> void:
	if can_interact():
		get_node("/root/CabinTravel").leave_subroom()
