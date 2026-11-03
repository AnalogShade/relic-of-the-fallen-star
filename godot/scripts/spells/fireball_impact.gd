extends Node3D
## Effet visuel d'explosion à l'impact de la boule de feu (optimisé, sans lag).

const ShardScene: PackedScene = preload("res://assets/spells/fireball_shard.glb")
const ImpactSFX: AudioStream = null

static var _cached_shard_mesh: Mesh = null

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

var time := 0.0
var light: OmniLight3D
var particles: CPUParticles3D
var sound_player: AudioStreamPlayer3D

func _ready() -> void:
	light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.15)
	light.light_energy = 4.5
	light.omni_range = 8.0
	light.omni_attenuation = 1.5
	add_child(light)
	
	particles = CPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.amount = 14
	particles.lifetime = 0.45
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.2
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 3.0
	particles.initial_velocity_max = 6.0
	particles.angular_velocity_min = -240.0
	particles.angular_velocity_max = 240.0
	particles.scale_amount_min = 0.4
	particles.scale_amount_max = 1.0
	
	particles.mesh = get_shard_mesh()
		
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.6, 0.7))
	curve.add_point(Vector2(1.0, 0.0))
	particles.scale_amount_curve = curve
	add_child(particles)
	
	# Son d'impact préchargé
	if ImpactSFX:
		sound_player = AudioStreamPlayer3D.new()
		sound_player.bus = "SFX"
		sound_player.stream = ImpactSFX
		sound_player.pitch_scale = 0.65
		sound_player.volume_db = 2.0
		add_child(sound_player)
		sound_player.play()

func _process(delta: float) -> void:
	time += delta
	if light:
		light.light_energy = maxf(0.0, 4.5 * (1.0 - time / 0.22))
	if time >= 0.5:
		queue_free()
