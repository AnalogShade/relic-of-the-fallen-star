@tool
class_name Luciole
extends Node3D

## Luciole nocturne stylisée.
## Vole en vol stationnaire doux (Lissajous), fait pulser sa lanterne émissive
## et active une OmniLight3D douce sous le contrôle du budget lumineux.

@export_enum("solaire", "celeste") var variant: String = "solaire":
	set(v):
		variant = v
		if is_node_ready():
			_update_variant()

@export var roam_radius: float = 2.2
@export var float_speed: float = 0.85
@export var base_scale_val: float = 1.0
@export var random_seed: int = 0

## Contrôlé par InsectManager : 0.0 (plein jour) à 1.0 (pleine nuit).
var night_weight: float = 0.0:
	set(w):
		night_weight = clampf(w, 0.0, 1.0)
		_update_night_state()

## Autorisation du budget lumineux (seules les lucioles proches ont la lumière allumée)
var light_budget_enabled: bool = false:
	set(v):
		light_budget_enabled = v
		if _light != null:
			_light.visible = light_budget_enabled and night_weight > 0.05

var home_position: Vector3
var _clock: float = 0.0
var _seed_x: float = 0.0
var _seed_y: float = 0.0
var _seed_z: float = 0.0
var _seed_pulse: float = 0.0
var _anim_player: AnimationPlayer
var _model_root: Node3D
var _light: OmniLight3D
var _lantern_material: StandardMaterial3D
var _current_target_offset: Vector3 = Vector3.ZERO
var _prev_pos: Vector3 = Vector3.ZERO

const SOLAIRE_SCENE = preload("res://assets/environment/insects/luciole_solaire.glb")
const CELESTE_SCENE = preload("res://assets/environment/insects/luciole_celeste.glb")

const COLOR_SOLAIRE = Color(0.92, 1.0, 0.35, 1.0)
const COLOR_CELESTE = Color(0.20, 0.95, 1.0, 1.0)


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
	_seed_pulse = rng.randf_range(0.0, TAU)
	_clock = rng.randf_range(0.0, 100.0)
	
	_setup_light()
	_update_variant()
	_update_night_state()


func _setup_light() -> void:
	if _light == null:
		_light = get_node_or_null("OmniLight3D") as OmniLight3D
		if _light == null:
			_light = OmniLight3D.new()
			_light.name = "OmniLight3D"
			add_child(_light)
	
	_light.omni_range = 3.2
	_light.omni_attenuation = 1.4
	_light.shadow_enabled = false
	_light.visible = false
	_light.light_color = COLOR_CELESTE if variant == "celeste" else COLOR_SOLAIRE
	_light.light_energy = 0.85


func _update_variant() -> void:
	# Retirer l'ancien modèle si existant
	if _model_root != null:
		_model_root.queue_free()
		_model_root = null
		_anim_player = null
		_lantern_material = null

	var scene := CELESTE_SCENE if variant == "celeste" else SOLAIRE_SCENE
	_model_root = scene.instantiate() as Node3D
	_model_root.name = "Model"
	add_child(_model_root)
	
	if _light != null:
		_light.light_color = COLOR_CELESTE if variant == "celeste" else COLOR_SOLAIRE

	# Configuration de l'AnimationPlayer
	_anim_player = _model_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim_player != null:
		var loop_name := "Luciole_Celeste_Armature_Hover_Loop" if variant == "celeste" else "Luciole_Solaire_Armature_Hover_Loop"
		if not _anim_player.has_animation(loop_name):
			# Fallback sur la première animation disponible
			var anim_list := _anim_player.get_animation_list()
			if not anim_list.is_empty():
				loop_name = anim_list[0]
		
		if _anim_player.has_animation(loop_name):
			var anim := _anim_player.get_animation(loop_name)
			anim.loop_mode = Animation.LOOP_LINEAR
			_anim_player.play(loop_name)
			_anim_player.seek(randf() * anim.length)
			_anim_player.speed_scale = randf_range(0.9, 1.25)

	# Recherche du matériau de la lanterne pour piloter l'émission
	_find_and_duplicate_lantern_material()


func _find_and_duplicate_lantern_material() -> void:
	if _model_root == null:
		return
	for child in _model_root.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		var count := mi.get_surface_override_material_count()
		if count == 0 and mi.mesh != null:
			count = mi.mesh.get_surface_count()
		for s in range(count):
			var mat := mi.get_active_material(s)
			if mat is StandardMaterial3D:
				var m_name := mat.resource_name
				if "Lantern" in m_name or "lantern" in m_name or "Solar" in m_name or "Celeste" in m_name:
					if not ("Body" in m_name or "Elytra" in m_name or "Eyes" in m_name or "Catchlight" in m_name or "Underwing" in m_name):
						_lantern_material = mat.duplicate() as StandardMaterial3D
						_lantern_material.emission_enabled = true
						mi.set_surface_override_material(s, _lantern_material)
						break
		if _lantern_material != null:
			break


func _update_night_state() -> void:
	if night_weight <= 0.001:
		visible = false
		if _light != null:
			_light.visible = false
		if _anim_player != null and _anim_player.is_playing():
			_anim_player.pause()
		return

	visible = true
	if _anim_player != null and not _anim_player.is_playing():
		_anim_player.play()

	# Transition d'échelle (émergence depuis la végétation)
	var scale_factor := base_scale_val * smoothstep(0.0, 0.35, night_weight)
	scale = Vector3.ONE * scale_factor

	# Mise à jour du budget lumière
	if _light != null:
		_light.visible = light_budget_enabled and night_weight > 0.05
		_light.light_energy = 0.85 * night_weight


func _process(delta: float) -> void:
	if night_weight <= 0.001 and not Engine.is_editor_hint():
		return

	_clock += delta * float_speed

	# Trajectoire de vol organique Lissajous 3D
	var ox := sin(_clock * 0.72 + _seed_x) * roam_radius + sin(_clock * 1.63 + _seed_x) * (roam_radius * 0.25)
	var oy := sin(_clock * 0.95 + _seed_y) * 0.45 + sin(_clock * 2.11) * 0.15
	var oz := cos(_clock * 0.61 + _seed_z) * roam_radius + cos(_clock * 1.47 + _seed_z) * (roam_radius * 0.25)
	
	var desired_pos := home_position + Vector3(ox, oy, oz)
	global_position = global_position.lerp(desired_pos, 1.0 - exp(-delta * 4.0))

	# Orientation fluide vers la direction de déplacement
	var velocity := global_position - _prev_pos
	_prev_pos = global_position
	if velocity.length_squared() > 0.00001:
		var forward := velocity.normalized()
		var current_fwd := -global_transform.basis.z
		var new_fwd := current_fwd.lerp(forward, delta * 3.5).normalized()
		if new_fwd.length_squared() > 0.001 and not new_fwd.is_equal_approx(Vector3.UP) and not new_fwd.is_equal_approx(Vector3.DOWN):
			look_at(global_position + new_fwd, Vector3.UP)

	# Pulsation douce de la lanterne (respiration lumineuse)
	var pulse := 0.78 + 0.32 * sin(_clock * 2.3 + _seed_pulse)
	if _lantern_material != null:
		var lantern_color := COLOR_CELESTE if variant == "celeste" else COLOR_SOLAIRE
		_lantern_material.emission = lantern_color
		_lantern_material.emission_energy_multiplier = 4.5 * pulse * night_weight

	# Ajustement de l'énergie lumineuse
	if _light != null and _light.visible:
		_light.light_energy = 0.85 * pulse * night_weight
