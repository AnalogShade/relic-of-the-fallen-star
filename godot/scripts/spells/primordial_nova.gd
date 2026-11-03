extends Node3D
## One expanding wave; gameplay and visuals share the same radius and clock.
const RADIUS := 9.0
const EXPANSION := 0.65
const LIFETIME := 1.1
const SPIN_SPEED := 1.8 # Radians per second around Godot's vertical Y axis.
const ENERGY_TEXTURE := preload("res://assets/vfx/nova/energy_alpha_v1.png")
const VEIL_RADII := [0.94, 0.86]
const VEIL_HEIGHTS := [2.2, 4.4]
const VEIL_DELAYS := [0.08, 0.17]
const VEIL_EXPANSIONS := [0.75, 0.90]
const VEIL_ANGLES := [2.1, 4.2]
const VEIL_OPACITY := [0.85, 0.80]
const AURA_COUNT := 56
var damage := 95.0
var elapsed := 0.0
var struck: Dictionary = {}
var material: ShaderMaterial
var shell: MeshInstance3D
var light: OmniLight3D
var sparks: MultiMeshInstance3D
var spark_material: StandardMaterial3D
var veil_materials: Array[ShaderMaterial] = []
var texture_phase := 0.0
var aura: MultiMeshInstance3D
var aura_material: ShaderMaterial

func _ready() -> void:
	add_to_group("primordial_novas")
	material = ShaderMaterial.new()
	material.shader = preload("res://shaders/primordial_nova.gdshader")
	var texture_rotation := randf_range(0.0, TAU)
	texture_phase = texture_rotation
	material.set_shader_parameter("energy_texture", ENERGY_TEXTURE)
	material.set_shader_parameter("texture_rotation", texture_rotation)
	var disc := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	# Allow translucent wisps to extend beyond the solid wavefront without clipping.
	plane.size = Vector2.ONE * RADIUS * 2.8
	disc.mesh = plane
	disc.material_override = material
	disc.position.y = 0.22
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)
	shell = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 64
	sphere.rings = 24
	shell.mesh = sphere
	var skin := ShaderMaterial.new()
	skin.shader = preload("res://shaders/primordial_nova_shell.gdshader")
	skin.set_shader_parameter("energy_texture", ENERGY_TEXTURE)
	skin.set_shader_parameter("texture_rotation", texture_rotation)
	shell.material_override = skin
	shell.position.y = 0.7
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shell)
	# Elevated wave tiers have independent launch times and expansion speeds.
	for i in range(2):
		var veil := MeshInstance3D.new()
		veil.name = "EnergyVeil%d" % i
		veil.mesh = plane
		veil.position.y = VEIL_HEIGHTS[i]
		veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var veil_skin := material.duplicate() as ShaderMaterial
		veil_skin.set_shader_parameter("layer_opacity", VEIL_OPACITY[i])
		veil.material_override = veil_skin
		veil_materials.append(veil_skin)
		add_child(veil)
	light = OmniLight3D.new()
	light.light_color = Color("75ffe5")
	light.omni_range = 13.0
	light.position.y = 1.5
	add_child(light)
	sparks = MultiMeshInstance3D.new()
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	var mote := SphereMesh.new()
	mote.radius = 0.035
	mote.height = 0.12
	mote.radial_segments = 6
	mote.rings = 3
	batch.mesh = mote
	batch.instance_count = 72
	sparks.multimesh = batch
	spark_material = StandardMaterial3D.new()
	spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark_material.albedo_color = Color("aaffee")
	spark_material.emission_enabled = true
	spark_material.emission = Color("57eacb")
	spark_material.emission_energy_multiplier = 3.0
	sparks.material_override = spark_material
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sparks)
	_create_aura()
	_update_visuals()

func _create_aura() -> void:
	# Batched, clock-driven particles stay synchronized with the spell and pause.
	aura = MultiMeshInstance3D.new()
	aura.name = "AuraWisps"
	aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	batch.mesh = quad
	batch.instance_count = AURA_COUNT
	aura.multimesh = batch
	aura_material = ShaderMaterial.new()
	aura_material.shader = preload("res://shaders/primordial_nova_aura.gdshader")
	aura_material.set_shader_parameter("energy_texture", ENERGY_TEXTURE)
	aura.material_override = aura_material
	add_child(aura)

func _physics_process(delta: float) -> void:
	var bag := get_node_or_null("/root/Inventory")
	if bag and bag.is_open: return
	elapsed += delta
	var radius := RADIUS * clampf(elapsed / EXPANSION, 0, 1)
	if elapsed <= EXPANSION + delta:
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(enemy) or struck.has(enemy.get_instance_id()) or not enemy.has_method("take_damage"): continue
			if "health" in enemy and enemy.health <= 0: continue
			var offset: Vector3 = enemy.global_position - global_position
			if absf(offset.y) > 3.5 or Vector2(offset.x, offset.z).length() > radius: continue
			# Solid walls stop the wave, including enemies in another room.
			var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, enemy.global_position + Vector3.UP, 1)
			if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
			struck[enemy.get_instance_id()] = true
			enemy.take_damage(damage, global_position, "nova")
			if enemy is CharacterBody3D and "health" in enemy and enemy.health > 0:
				preload("res://scripts/hit_feedback.gd").hit(enemy, global_position, 18.0)
	_update_visuals()
	if elapsed >= LIFETIME: queue_free()

func _update_visuals() -> void:
	rotation.y = elapsed * SPIN_SPEED
	var progress := clampf(elapsed / EXPANSION, 0.0, 1.0)
	var radius := maxf(0.08, RADIUS * progress)
	var fade := 1.0 - smoothstep(0.55, LIFETIME, elapsed)
	material.set_shader_parameter("radius", radius)
	material.set_shader_parameter("age", elapsed)
	material.set_shader_parameter("fade", fade)
	for i in range(veil_materials.size()):
		var layer_age := maxf(0.0, elapsed - VEIL_DELAYS[i])
		var layer_progress := clampf(layer_age / VEIL_EXPANSIONS[i], 0.0, 1.0)
		var layer_radius := maxf(0.08, RADIUS * VEIL_RADII[i] * layer_progress)
		veil_materials[i].set_shader_parameter("radius", layer_radius)
		veil_materials[i].set_shader_parameter("age", layer_age)
		veil_materials[i].set_shader_parameter("fade", fade * smoothstep(0.0, 0.10, layer_age))
		var drift := 0.45 if i == 0 else -0.35
		veil_materials[i].set_shader_parameter("texture_rotation", texture_phase + VEIL_ANGLES[i] + layer_age * drift)
	shell.scale = Vector3(radius, maxf(0.12, radius * 0.32), radius)
	shell.material_override.set_shader_parameter("fade", fade)
	shell.material_override.set_shader_parameter("age", elapsed)
	light.light_energy = fade * (2.0 + 2.0 * (1.0 - progress))
	spark_material.albedo_color.a = fade
	for i in range(72):
		var angle := i * 2.399963
		var distance := radius * (0.65 + 0.35 * sin(i * 7.13) * sin(i * 7.13))
		var point := Vector3(cos(angle) * distance, 0.4 + sin(i * 3.7) * 0.25 + progress * (0.6 + fmod(i * 0.37, 1.4)), sin(angle) * distance)
		sparks.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, point))
	_update_aura(fade)

func _update_aura(fade: float) -> void:
	aura_material.set_shader_parameter("fade", fade)
	for i in range(AURA_COUNT):
		var seed_value := fmod(i * 0.618034 + 0.17, 1.0)
		var birth := seed_value * 0.60
		var life := 0.38 + fmod(i * 0.137, 0.30)
		var age := elapsed - birth
		var t := clampf(age / life, 0.0, 1.0)
		var opacity := smoothstep(0.0, 0.15, t) * (1.0 - smoothstep(0.4, 1.0, t)) * 0.48
		if age <= 0.0 or age >= life: opacity = 0.0
		var angle := i * 2.399963 + age * 0.65
		var distance := RADIUS * birth / EXPANSION + maxf(age, 0.0) * 1.25
		var height := 0.35 + maxf(age, 0.0) * (1.7 + seed_value * 1.5)
		var point := Vector3(cos(angle) * distance, height, sin(angle) * distance)
		var size := 0.4 + t * (1.0 + seed_value * 0.8)
		aura.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), point))
		aura.multimesh.set_instance_custom_data(i, Color(opacity, seed_value, fmod(i * 0.371 + t * 0.15, 1.0), 1.0))
