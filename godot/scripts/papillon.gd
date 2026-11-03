@tool
class_name Papillon
extends Node3D

## Papillon diurne stylisé.
## Vole de fleur en fleur autour des arbustes à baies et clairières ensoleillées,
## avec alternance naturelle de battements d'ailes et de vols planés.

@export_enum("morpho", "monarque", "emeraude") var species: String = "morpho":
	set(s):
		species = s
		if is_node_ready():
			_update_species()

@export var roam_radius: float = 2.4
@export var flight_speed: float = 1.2
@export var base_scale_val: float = 1.0
@export var random_seed: int = 0

## Contrôlé par InsectManager : 1.0 (plein jour) à 0.0 (pleine nuit).
var day_weight: float = 1.0:
	set(w):
		day_weight = clampf(w, 0.0, 1.0)
		_update_day_state()

var home_position: Vector3
var _clock: float = 0.0
var _seed_x: float = 0.0
var _seed_y: float = 0.0
var _seed_z: float = 0.0
var _burst_timer: float = 0.0
var _is_gliding: bool = false
var _anim_player: AnimationPlayer
var _model_root: Node3D
var _prev_pos: Vector3 = Vector3.ZERO

const MORPHO_SCENE = preload("res://assets/environment/insects/papillon_morpho.glb")
const MONARQUE_SCENE = preload("res://assets/environment/insects/papillon_monarque.glb")
const EMERAUDE_SCENE = preload("res://assets/environment/insects/papillon_emeraude.glb")


func _ready() -> void:
	home_position = global_position
	_prev_pos = global_position
	
	var rng := RandomNumberGenerator.new()
	if random_seed != 0:
		rng.seed = random_seed
	else:
		rng.randomize()
	
	_seed_x = rng.randf_range(0.0, TAU)
	_seed_y = rng.randf_range(0.0, TAU)
	_seed_z = rng.randf_range(0.0, TAU)
	_clock = rng.randf_range(0.0, 100.0)
	_burst_timer = rng.randf_range(1.0, 3.0)
	
	_update_species()
	_update_day_state()


func _update_species() -> void:
	if _model_root != null:
		_model_root.queue_free()
		_model_root = null
		_anim_player = null

	var scene: PackedScene
	match species:
		"monarque":
			scene = MONARQUE_SCENE
		"emeraude":
			scene = EMERAUDE_SCENE
		_:
			scene = MORPHO_SCENE

	_model_root = scene.instantiate() as Node3D
	_model_root.name = "Model"
	add_child(_model_root)

	_anim_player = _model_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim_player != null:
		var clip_name := "Papillon_Morpho_Armature_Flap_Loop"
		match species:
			"monarque":
				clip_name = "Papillon_Monarque_Armature_Flap_Loop"
			"emeraude":
				clip_name = "Papillon_Emeraude_Armature_Flap_Loop"
		
		if not _anim_player.has_animation(clip_name):
			var anim_list := _anim_player.get_animation_list()
			if not anim_list.is_empty():
				clip_name = anim_list[0]
				
		if _anim_player.has_animation(clip_name):
			var anim := _anim_player.get_animation(clip_name)
			anim.loop_mode = Animation.LOOP_LINEAR
			_anim_player.play(clip_name)
			_anim_player.seek(randf() * anim.length)
			_anim_player.speed_scale = randf_range(1.0, 1.35)


func _update_day_state() -> void:
	if day_weight <= 0.001:
		visible = false
		if _anim_player != null and _anim_player.is_playing():
			_anim_player.pause()
		return

	visible = true
	if _anim_player != null and not _anim_player.is_playing():
		_anim_player.play()

	# Transition d'échelle (posé délicat / envol)
	var scale_factor := base_scale_val * smoothstep(0.0, 0.35, day_weight)
	scale = Vector3.ONE * scale_factor


func _process(delta: float) -> void:
	if day_weight <= 0.001 and not Engine.is_editor_hint():
		return

	_clock += delta * flight_speed

	# Rythme organique : alternance battements dynamiques et courtes glissades
	_burst_timer -= delta
	if _burst_timer <= 0.0:
		_is_gliding = not _is_gliding
		_burst_timer = randf_range(0.6, 1.2) if _is_gliding else randf_range(1.8, 3.5)
		if _anim_player != null:
			_anim_player.speed_scale = randf_range(0.2, 0.45) if _is_gliding else randf_range(1.05, 1.4)

	# Trajectoire en huit / spirale douce au-dessus des fleurs
	var figure_eight_t := _clock * 0.85
	var ox := sin(figure_eight_t + _seed_x) * roam_radius
	var oz := sin(figure_eight_t * 2.0 + _seed_z) * (roam_radius * 0.6)
	var oy := sin(_clock * 1.5 + _seed_y) * 0.35 + (0.3 if not _is_gliding else -0.1)
	
	# Quand le jour s'achève, le papillon descend vers le niveau du feuillage (home)
	oy = lerpf(-0.2, oy, day_weight)

	var desired_pos := home_position + Vector3(ox, oy, oz)
	global_position = global_position.lerp(desired_pos, 1.0 - exp(-delta * 3.5))

	# Orientation et inclinaison (banking) en vol
	var velocity := global_position - _prev_pos
	_prev_pos = global_position
	if velocity.length_squared() > 0.00001:
		var forward := velocity.normalized()
		var current_fwd := -global_transform.basis.z
		var new_fwd := current_fwd.lerp(forward, delta * 4.5).normalized()
		if new_fwd.length_squared() > 0.001 and not new_fwd.is_equal_approx(Vector3.UP) and not new_fwd.is_equal_approx(Vector3.DOWN):
			# Léger roulis selon le virage horizontal
			var turn_angle := current_fwd.signed_angle_to(new_fwd, Vector3.UP)
			var up_tilted := Vector3.UP.rotated(new_fwd, clampf(turn_angle * 1.8, -0.4, 0.4))
			look_at(global_position + new_fwd, up_tilted)
