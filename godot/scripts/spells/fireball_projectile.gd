extends Area3D
## Projectile magique avec une traînée animée et des tisons 3D.
## Déplacement en ligne droite dans la direction du personnage avec tisons 3D légers.

const FireballModelScene: PackedScene = preload("res://assets/spells/fireball.glb")
const ShardScene: PackedScene = preload("res://assets/spells/fireball_shard.glb")
const ImpactScene: PackedScene = preload("res://scenes/spells/fireball_impact.tscn")

static var _cached_shard_mesh: Mesh = null
static var _soft_shaders: Dictionary[bool, Shader] = {}

static func get_shard_mesh() -> Mesh:
	if _cached_shard_mesh != null:
		return _cached_shard_mesh
	if ShardScene:
		var tmp := ShardScene.instantiate()
		var mesh_inst := tmp.find_child("Fireball_Shard_Particle", true, false) as MeshInstance3D
		if mesh_inst and mesh_inst.mesh:
			_cached_shard_mesh = mesh_inst.mesh
		tmp.free()
	return _cached_shard_mesh

@export var speed: float = 20.0
@export var damage: float = 40.0
@export var lifetime: float = 20.0

var direction := Vector3.FORWARD
var time_alive := 0.0
var impacted := false
var light: OmniLight3D
var model: Node3D
var anim_player: AnimationPlayer
var shard_particles: CPUParticles3D
var visual_trails: Array[CPUParticles3D] = []
var halo: MeshInstance3D
var audio_3d: AudioStreamPlayer3D

func _init() -> void:
	_setup_components()

func _setup_components() -> void:
	if model != null: return
	
	# Instancier le modèle 3D animé (préchargé en mémoire)
	if FireballModelScene:
		model = FireballModelScene.instantiate()
		model.name = "FireballModel"
		# Rotation de PI pour orienter la tête de la boule de feu vers -Z (forward Godot)
		model.rotation.y = PI
		model.scale = Vector3.ONE * 0.95
		add_child(model)
		
		anim_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if anim_player and anim_player.has_animation("Fireball_Flight"):
			var anim := anim_player.get_animation("Fireball_Flight")
			anim.loop_mode = Animation.LOOP_LINEAR
			anim_player.play("Fireball_Flight")
	
	# Lumière dynamique légère
	light = OmniLight3D.new()
	light.name = "FireLight"
	light.light_color = Color(1.0, 0.5, 0.15)
	light.light_energy = 2.4
	light.omni_range = 6.0
	light.omni_attenuation = 1.2
	add_child(light)
	
	# Traînée de tisons optimisée (très légère sur le CPU, 8 particules max)
	_setup_shard_trail()
	_setup_magic_trails()
	
	# Audio 3D spatialisé du projectile en vol
	_setup_audio()

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 4 # Décor (1) + Ennemis (4)
	monitoring = true
	monitorable = false
	_setup_components()
	if audio_3d and audio_3d.stream and not audio_3d.playing:
		audio_3d.play()
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func warm_up(parent: Node) -> void:
	# Compatibility compiles materials on their first actual draw. This viewport
	# renders the real meshes and particles without displaying them in the game.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(64, 64)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	parent.add_child(viewport)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 0, 4)
	viewport.add_child(camera)
	camera.make_current()
	audio_3d.stream = null
	viewport.add_child(self)
	set_physics_process(false)
	var impact := ImpactScene.instantiate() as Node3D
	viewport.add_child(impact)
	for frame in 4:
		await RenderingServer.frame_post_draw
	viewport.queue_free()

func _setup_shard_trail() -> void:
	shard_particles = CPUParticles3D.new()
	shard_particles.name = "ShardTrail"
	# Coordonnées mondiales : les tisons se détachent et restent suspendus en arrière dans l'air
	shard_particles.local_coords = false
	shard_particles.amount = 8
	shard_particles.lifetime = 0.38
	shard_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	shard_particles.emission_sphere_radius = 0.1
	shard_particles.direction = Vector3(0, 0.1, 1.0)
	shard_particles.spread = 25.0
	shard_particles.initial_velocity_min = 0.4
	shard_particles.initial_velocity_max = 1.4
	shard_particles.angular_velocity_min = -180.0
	shard_particles.angular_velocity_max = 180.0
	shard_particles.scale_amount_min = 0.5
	shard_particles.scale_amount_max = 1.0
	
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.6, 0.7))
	curve.add_point(Vector2(1.0, 0.0))
	shard_particles.scale_amount_curve = curve
	
	# Réutiliser le maillage statique préchargé
	shard_particles.mesh = get_shard_mesh()
	add_child(shard_particles)

static func _soft_shader(additive: bool) -> Shader:
	if _soft_shaders.has(additive):
		return _soft_shaders[additive]
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, %s;
uniform vec4 tint : source_color;
varying float particle_seed;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}
void vertex() {
	particle_seed = dot(MODEL_MATRIX[3].xyz, vec3(0.71, 1.37, 0.93));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz), INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz), INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]);
}
void fragment() {
	float radius = length(UV * 2.0 - 1.0);
	vec2 flow = UV * 7.0 + vec2(particle_seed, -TIME * 2.7);
	float turbulence = noise(flow) * 0.62 + noise(flow * 2.1 + TIME) * 0.26 + noise(flow * 4.3) * 0.12;
	float soft = pow(max(0.0, 1.0 - radius + (turbulence - 0.5) * 0.3), 1.7);
	soft *= smoothstep(0.12, 0.72, turbulence);
	vec3 fire_color = mix(tint.rgb * 0.48, mix(tint.rgb, vec3(1.0, 0.82, 0.28), 0.35), turbulence);
	ALBEDO = fire_color;
	EMISSION = fire_color * 1.25;
	ALPHA = soft * tint.a * COLOR.a;
}
""" % ("blend_add" if additive else "blend_mix")
	_soft_shaders[additive] = shader
	return shader

func _soft_material(color: Color, additive: bool = true) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _soft_shader(additive)
	material.set_shader_parameter("tint", color)
	return material

func _make_soft_trail(node_name: String, count: int, duration: float, size: float, tint: Color, spread_radius: float, additive: bool) -> void:
	var particles := CPUParticles3D.new()
	particles.name = node_name
	particles.local_coords = false
	particles.amount = count
	particles.lifetime = duration
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = spread_radius
	particles.direction = Vector3(0, 0.15, 1)
	particles.spread = 40.0
	particles.initial_velocity_min = 0.3
	particles.initial_velocity_max = 1.3
	particles.gravity = Vector3(0, 0.35, 0)
	particles.scale_amount_min = 0.7
	particles.scale_amount_max = 1.2
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0, 0.5))
	scale_curve.add_point(Vector2(0.3, 1.0))
	scale_curve.add_point(Vector2(1, 0.05))
	particles.scale_amount_curve = scale_curve
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1, 1, 1, 0))
	particles.color_ramp = fade
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE * size
	mesh.material = _soft_material(tint, additive)
	particles.mesh = mesh
	add_child(particles)
	visual_trails.append(particles)

func _setup_magic_trails() -> void:
	# World-space particles leave a 15–20 metre comet wake at normal speed.
	_make_soft_trail("FlameWake", 110, 0.9, 1.25, Color(1.0, 0.24, 0.025, 0.65), 0.12, true)
	_make_soft_trail("MistWake", 45, 1.15, 2.1, Color(0.42, 0.18, 0.09, 0.28), 0.25, false)
	_make_soft_trail("FlyingSparks", 32, 0.7, 0.25, Color(1.0, 0.65, 0.12, 1.0), 0.45, true)
	halo = MeshInstance3D.new()
	halo.name = "FireHalo"
	var halo_mesh := QuadMesh.new()
	halo_mesh.size = Vector2.ONE * 2.8
	halo_mesh.material = _soft_material(Color(1.0, 0.32, 0.045, 0.32))
	halo.mesh = halo_mesh
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(halo)
	var waves := CPUParticles3D.new()
	waves.name = "HeatWaves"
	waves.amount = 12
	waves.lifetime = 0.65
	waves.local_coords = false
	waves.rotation.x = PI * 0.5
	waves.direction = Vector3.UP
	waves.spread = 12.0
	waves.gravity = Vector3.ZERO
	waves.initial_velocity_min = 0.5
	waves.initial_velocity_max = 1.5
	waves.scale_amount_min = 0.5
	waves.scale_amount_max = 0.8
	var expansion := Curve.new()
	expansion.add_point(Vector2(0, 0.3))
	expansion.add_point(Vector2(1, 1.8))
	waves.scale_amount_curve = expansion
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 0.6, 0.15, 0.65))
	fade.set_color(1, Color(1, 0.2, 0.02, 0))
	waves.color_ramp = fade
	var ring := TorusMesh.new()
	ring.inner_radius = 0.55
	ring.outer_radius = 0.59
	ring.rings = 16
	ring.ring_segments = 6
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1, 0.65, 0.2, 0.65)
	ring.material = mat
	waves.mesh = ring
	add_child(waves)
	visual_trails.append(waves)

func _setup_audio() -> void:
	if audio_3d != null: return
	audio_3d = AudioStreamPlayer3D.new()
	audio_3d.name = "FireFlightAudio3D"
	audio_3d.bus = "SFX"
	audio_3d.max_distance = 60.0
	audio_3d.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	audio_3d.unit_size = 8.0
	audio_3d.volume_db = -3.0
	add_child(audio_3d)

func launch(start_pos: Vector3, dir: Vector3) -> void:
	direction = dir.normalized()
	if is_inside_tree():
		global_position = start_pos
		if direction.length_squared() > 0.001:
			look_at(global_position + direction, Vector3.UP)
	else:
		position = start_pos
		if direction.length_squared() > 0.001:
			basis = Basis.looking_at(direction, Vector3.UP)

func _physics_process(delta: float) -> void:
	if impacted: return
	
	time_alive += delta
	if time_alive >= lifetime:
		explode()
		return
	
	# Pulsation douce de la lumière
	if light:
		light.light_energy = 2.2 + 0.3 * sin(time_alive * 20.0)
	if halo:
		halo.scale = Vector3.ONE * (1.0 + 0.08 * sin(time_alive * 15.0))
	
	# Déplacement en ligne droite
	var move_step := direction * speed * delta
	var current_pos: Vector3 = global_position if is_inside_tree() else position
	var world3d := get_world_3d()
	if world3d:
		var space_state := world3d.direct_space_state
		var query := PhysicsRayQueryParameters3D.create(current_pos, current_pos + move_step)
		query.exclude = [get_rid()]
		query.collision_mask = 1 | 4 | 8 | 16
		query.collide_with_areas = true
		query.collide_with_bodies = true
		
		var hit := space_state.intersect_ray(query)
		if not hit.is_empty():
			if is_inside_tree():
				global_position = hit.position
			else:
				position = hit.position
			_handle_hit(hit.collider)
			return
	
	# Détection de proximité des ennemis
	for enemy in get_tree().get_nodes_in_group("enemy") + get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy is Node3D:
			if current_pos.distance_to(enemy.global_position + Vector3(0, 1.0, 0)) < 1.2:
				_handle_hit(enemy)
				return
	
	if is_inside_tree():
		global_position += move_step
	else:
		position += move_step

func _on_body_entered(body: Node) -> void:
	if impacted or body.is_in_group("player"): return
	_handle_hit(body)

func _on_area_entered(area: Area3D) -> void:
	if impacted or area.is_in_group("player"): return
	_handle_hit(area)

func _handle_hit(target: Object) -> void:
	if impacted: return
	var enemy := target as Node
	if enemy and enemy.is_in_group("player"):
		return
		
	impacted = true
	var damage_target: Node = enemy
	while damage_target != null:
		if damage_target.has_method("take_damage"):
			var hit_pos: Vector3 = global_position if is_inside_tree() else position
			if "combat" in damage_target:
				damage_target.take_damage(damage, hit_pos, "fireball")
			else:
				damage_target.take_damage(damage, hit_pos)
			break
		damage_target = damage_target.get_parent()
	
	explode()

func explode() -> void:
	impacted = true
	var current_pos: Vector3 = global_position if is_inside_tree() else position
	var p := get_parent()
	if p and ImpactScene:
		var impact: Node3D = ImpactScene.instantiate() as Node3D
		p.add_child(impact)
		if impact.is_inside_tree():
			impact.global_position = current_pos
		else:
			impact.position = current_pos
	
	if shard_particles:
		shard_particles.emitting = false
	
	for trail in visual_trails:
		trail.emitting = false
	if model:
		model.hide()
	if halo:
		halo.hide()
	if light:
		light.hide()
	if audio_3d:
		audio_3d.stop()
	set_deferred("monitoring", false)
	# Let the world-space wake dissolve naturally after the impact.
	if is_inside_tree():
		get_tree().create_timer(1.2).timeout.connect(queue_free)
	else:
		queue_free()
