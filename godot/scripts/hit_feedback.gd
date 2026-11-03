extends Node
## Shared damage feedback. Recoil uses the body's collision-aware movement.

static func clear_recoil(actor: CharacterBody3D) -> void:
	actor.remove_meta("hit_recoil")
	actor.remove_meta("hit_recoil_time")

static func apply_recoil(actor: CharacterBody3D, delta: float) -> void:
	var remaining: float = actor.get_meta("hit_recoil_time", 0.0)
	if remaining <= 0.0: return
	var impulse: Vector3 = actor.get_meta("hit_recoil", Vector3.ZERO)
	actor.velocity.x = impulse.x * remaining / 0.22
	actor.velocity.z = impulse.z * remaining / 0.22
	actor.set_meta("hit_recoil_time", maxf(0.0, remaining - delta))

static func hit(actor: CharacterBody3D, source: Vector3, strength: float) -> void:
	var direction := actor.global_position - source
	direction.y = 0.0
	if direction.length_squared() < 0.001: direction = actor.global_basis.z
	direction = direction.normalized()
	actor.set_meta("hit_recoil", direction * strength)
	actor.set_meta("hit_recoil_time", 0.22)
	var feedback := actor.get_node_or_null("HitFeedback")
	if feedback == null:
		feedback = load("res://scripts/hit_feedback.gd").new()
		feedback.name = "HitFeedback"
		actor.add_child(feedback)
	feedback.flash()
	impact(actor, direction)

var overlays: Dictionary = {}
var flash_material: ShaderMaterial
var elapsed := 1.0

func flash() -> void:
	if flash_material == null:
		var shader := Shader.new()
		shader.code = "shader_type spatial; render_mode unshaded, blend_mix, depth_draw_never; uniform float strength = 0.7; void fragment(){ ALBEDO=vec3(1.0,0.015,0.025); EMISSION=vec3(0.5,0.0,0.0); ALPHA=strength; }"
		flash_material = ShaderMaterial.new()
		flash_material.shader = shader
	if overlays.is_empty():
		for mesh in get_parent().find_children("*", "MeshInstance3D", true, false):
			overlays[mesh] = mesh.material_overlay
			mesh.material_overlay = flash_material
	elapsed = 0.0
	flash_material.set_shader_parameter("strength", 0.8)

func _process(delta: float) -> void:
	if overlays.is_empty(): return
	elapsed += delta
	flash_material.set_shader_parameter("strength", (0.8 if elapsed < 0.09 or elapsed > 0.17 else 0.25) * maxf(0.0, 1.0 - elapsed / 0.36))
	if elapsed >= 0.36:
		for mesh in overlays:
			if is_instance_valid(mesh): mesh.material_overlay = overlays[mesh]
		overlays.clear()

static func impact(actor: Node3D, direction: Vector3) -> void:
	var spark := MeshInstance3D.new()
	spark.name = "HitImpact"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.85, 0.85)
	spark.mesh = quad
	spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded, cull_disabled, depth_draw_never; uniform float fade = 1.0; void vertex(){ MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]); } void fragment(){ vec2 p=(UV-0.5)*2.0; float a=atan(p.y,p.x); float r=length(p); float edge=0.24+0.65*pow(abs(cos(a*4.0)),12.0); float mask=1.0-smoothstep(edge-0.06,edge,r); ALBEDO=mix(vec3(1.0,0.55,0.06),vec3(1.0,0.97,0.8),1.0-smoothstep(0.0,0.4,r)); EMISSION=ALBEDO*1.8; ALPHA=mask*fade; }"
	var material := ShaderMaterial.new()
	material.shader = shader
	spark.material_override = material
	actor.get_tree().current_scene.add_child(spark)
	spark.global_position = actor.global_position + Vector3.UP * 0.9 - direction * 0.35
	var tween := spark.create_tween().set_parallel(true)
	spark.scale = Vector3.ONE * 0.45
	tween.tween_property(spark, "scale", Vector3.ONE * 1.3, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(_fade_impact.bind(material), 1.0, 0.0, 0.22)
	tween.chain().tween_callback(spark.queue_free)

static func _fade_impact(value: float, material: ShaderMaterial) -> void:
	material.set_shader_parameter("fade", value)
