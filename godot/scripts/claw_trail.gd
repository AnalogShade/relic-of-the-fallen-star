@tool
class_name ClawTrail3D
extends MeshInstance3D

## Traînée stylisée d'attaque de griffes pour Godot 4.
## Génère des rubans énergétiques lumineux mauves/violets suivant les os du squelette
## ou des points de griffes configurables, avec dégradé de couleur et effilement des pointes.

enum PresetMode {
	TRIPLE_CLAW,     ## 3 traînées de griffes distinctes (index, majeur, annulaire)
	QUAD_CLAW,       ## 4 traînées de griffes (style fauve sauvage)
	SINGLE_BLADE,    ## 1 grande lame d'énergie tranchante
	FULL_SLASH_ARC,  ## Éventail / arc d'énergie plein
	CUSTOM_MARKERS   ## Suit les nœuds Marker3D enfants
}

# ==============================================================================
# --- Squelette et Sélection des Os ---
# ==============================================================================
@export_group("Squelette et Os")
## Chemin vers le squelette (si vide, détecte automatiquement le Skeleton3D parent/frère)
@export var skeleton_path: NodePath
## Nom de l'os principal à suivre (ex: "RightHand" pour la main droite de Naël)
@export var bone_name: String = "RightHand"
## Noms d'os supplémentaires pour rigs avec os de doigts individuels (optionnel)
@export var additional_bones: Array[String] = []

# ==============================================================================
# --- Configuration des Griffes ---
# ==============================================================================
@export_group("Configuration des Griffes")
## Mode de disposition des rubans
@export var preset_mode: PresetMode = PresetMode.TRIPLE_CLAW
## Longueur des griffes à partir de l'os (en mètres)
@export_range(0.05, 0.6, 0.01) var claw_length: float = 0.23
## Écartement latéral entre les pointes de griffes (en mètres)
@export_range(0.01, 0.25, 0.005) var claw_spread: float = 0.065
## Largeur de base de chaque ruban de griffe (en mètres)
@export_range(0.01, 0.2, 0.005) var ribbon_width: float = 0.065
## Activer également un arc d'énergie vaporeux reliant l'ensemble du balayage
@export var enable_arc_slash: bool = true
## Intensité relative de l'arc de fond (0 = invisible, 1 = pleine puissance)
@export_range(0.0, 2.0, 0.05) var arc_energy: float = 0.40
## Affinement progressif de la queue du ruban (donne un effet effilé stylisé)
@export var taper_tail: bool = true

# ==============================================================================
# --- Visuel & Dégradé Mauve ---
# ==============================================================================
@export_group("Dégradé et Matériau")
## Dégradé de couleur (0.0 = queue évanescente, 1.0 = tête/griffe éclatante)
@export var trail_gradient: Gradient
## Puissance de brillance / émission HDR (magnifié par le Glow du WorldEnvironment)
@export_range(0.5, 6.0, 0.1) var emission_energy: float = 2.4
## Durée de vie d'un segment de traînée en secondes
@export_range(0.05, 0.8, 0.01) var trail_lifetime: float = 0.32
## Mode de fusion (Additionnel pour un effet d'énergie magique stylisé)
@export var use_additive_blend: bool = true

# ==============================================================================
# --- Lissage de Courbe ---
# ==============================================================================
@export_group("Lissage de Courbe")
## Nombre d'échantillons interpolés par frame (lissage Catmull-Rom de l'arc)
@export_range(1, 6, 1) var subdivisions: int = 3
## Distance minimale de déplacement de la main pour créer une nouvelle tranche
@export_range(0.001, 0.05, 0.002) var min_motion_distance: float = 0.005

# ==============================================================================
# --- Synchronisation Automatique avec l'Animation ---
# ==============================================================================
@export_group("Synchronisation Animation")
## Écoute automatiquement l'AnimationPlayer pour déclencher la traînée au bon moment
@export var auto_sync_animation: bool = true
## Chemin vers l'AnimationPlayer (si vide, auto-détection)
@export var animation_player_path: NodePath
## Nom du clip d'attaque à écouter
@export var attack_animation_name: String = "Nael_Claw"
## Début de la fenêtre de balayage actif dans le clip (en secondes)
@export_range(0.0, 1.0, 0.01) var swing_start_time: float = 0.14
## Fin de la fenêtre de balayage actif dans le clip (en secondes)
@export_range(0.0, 1.0, 0.01) var swing_end_time: float = 0.50

# ==============================================================================
# --- Contrôle Manuel ---
# ==============================================================================
@export_group("Contrôle Manuel")
## Émission active (génère des rubans)
@export var emitting: bool = false
## Bouton d'aperçu dans l'inspecteur Godot
@export var preview_burst: bool = false:
	set(val):
		if val:
			burst(0.25)
		preview_burst = false

# --- Variables Internes ---
var _skeleton: Skeleton3D
var _animator: AnimationPlayer
var _bone_idx: int = -1
var _additional_bone_indices: Array[int] = []
var _immediate_mesh: ImmediateMesh
var _material: StandardMaterial3D

var _slices: Array[Dictionary] = []
var _sim_time: float = 0.0
var _burst_timer: float = 0.0
var _tracking_left := false

func _ready() -> void:
	# Coordonnées globales pour que la traînée s'ancre dans l'air pendant le coup
	top_level = true
	global_transform = Transform3D.IDENTITY
	
	_setup_gradient()
	_setup_mesh_and_material()
	_resolve_skeleton()
	_resolve_animator()

func _setup_gradient() -> void:
	if trail_gradient == null:
		trail_gradient = Gradient.new()
		# Palette Mauve / Violet Néon Intense (très saturée, sans sur-exposition blanche) :
		# 0.0  : Améthyste nocturne évanescente (alpha = 0)
		# 0.30 : Violet royal saturé
		# 0.65 : Mauve électrique éclatant
		# 0.90 : Lilas magenta radiant
		# 1.0  : Pointe tranchante lilas vif
		trail_gradient.offsets = PackedFloat32Array([0.0, 0.30, 0.65, 0.90, 1.0])
		trail_gradient.colors = PackedColorArray([
			Color(0.35, 0.02, 0.65, 0.0),   # Queue transparente
			Color(0.55, 0.05, 0.90, 0.40),  # Violet profond
			Color(0.78, 0.16, 1.00, 0.75),  # Mauve électrique
			Color(0.92, 0.42, 1.00, 0.92),  # Lilas magenta
			Color(0.98, 0.65, 1.00, 1.0)    # Pointe néon éclatante
		])

func _setup_mesh_and_material() -> void:
	if _immediate_mesh == null:
		_immediate_mesh = ImmediateMesh.new()
		mesh = _immediate_mesh
	
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.vertex_color_use_as_albedo = true
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if use_additive_blend else BaseMaterial3D.BLEND_MODE_MIX
		_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		material_override = _material


func _resolve_skeleton() -> void:
	if not skeleton_path.is_empty():
		_skeleton = get_node_or_null(skeleton_path) as Skeleton3D
	
	if _skeleton == null:
		var p = get_parent()
		while p != null and _skeleton == null:
			if p is Skeleton3D:
				_skeleton = p
				break
			var found = p.find_child("*Skeleton*", true, false)
			if found is Skeleton3D:
				_skeleton = found
				break
			p = p.get_parent()
	
	if _skeleton:
		_bone_idx = _skeleton.find_bone(bone_name)
		_additional_bone_indices.clear()
		for b_name in additional_bones:
			var idx = _skeleton.find_bone(b_name)
			if idx >= 0:
				_additional_bone_indices.append(idx)

func _resolve_animator() -> void:
	if not animation_player_path.is_empty():
		_animator = get_node_or_null(animation_player_path) as AnimationPlayer
	if _animator == null:
		var p = get_parent()
		while p != null and _animator == null:
			if p is AnimationPlayer:
				_animator = p
				break
			var found = p.find_child("*AnimationPlayer*", true, false)
			if found is AnimationPlayer:
				_animator = found
				break
			p = p.get_parent()

## Déclenche un burst d'émission pendant une durée donnée
func burst(duration: float = 0.22) -> void:
	_burst_timer = duration
	emitting = true

## Démarre l'émission continue
func start_trail() -> void:
	emitting = true

## Arrête l'émission
func stop_trail() -> void:
	emitting = false
	_burst_timer = 0.0

## Efface immédiatement tout le maillage
func clear_trail() -> void:
	_slices.clear()
	if _immediate_mesh:
		_immediate_mesh.clear_surfaces()

func _process(delta: float) -> void:
	if _skeleton == null or _bone_idx < 0:
		_resolve_skeleton()
		if _skeleton == null:
			return
	
	_sim_time += delta
	
	# Gestion du timer de burst
	if _burst_timer > 0.0:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			emitting = false
	
	# Auto-synchronisation avec l'AnimationPlayer
	if auto_sync_animation:
		if _animator == null:
			_resolve_animator()
		var left := _animator != null and _animator.current_animation == "Nael_Claw_Left"
		if left != _tracking_left:
			clear_trail()
			_tracking_left = left
			_bone_idx = _skeleton.find_bone("LeftHand" if left else bone_name)
		if _animator_playing_claw():
			var pos := _animator.current_animation_position
			var start := 0.12 if left else swing_start_time
			var end := 0.38 if left else swing_end_time
			if pos >= start and pos <= end:
				emitting = true
			else:
				emitting = false
		elif _burst_timer <= 0.0 and not _animator_playing_claw():
			emitting = false
	
	# Échantillonnage si actif
	if emitting:
		_sample_points(_sim_time)
	
	# Nettoyage des tranches trop anciennes
	_purge_expired_slices(_sim_time)
	
	# Génération du maillage
	_render_trail_mesh(_sim_time)

func _animator_playing_claw() -> bool:
	return _animator != null and _animator.is_playing() and _animator.current_animation in [attack_animation_name, "Nael_Claw_Left", "Nael_Claw_1", "Nael_Claw_2", "Nael_Claw_3"]

func _sample_points(current_time: float) -> void:
	var hand_tf: Transform3D = _skeleton.global_transform * _skeleton.get_bone_global_pose(_bone_idx)
	var hand_pos: Vector3 = hand_tf.origin
	
	# Vérification du seuil minimal de mouvement
	if _slices.size() > 0:
		var last_hand_pos: Vector3 = _slices[0].get("hand_origin", Vector3.ZERO)
		if hand_pos.distance_to(last_hand_pos) < min_motion_distance:
			return
	
	var tips: Array[Vector3] = []
	var bases: Array[Vector3] = []
	
	if not _additional_bone_indices.is_empty():
		for b_idx in _additional_bone_indices:
			var b_tf = _skeleton.global_transform * _skeleton.get_bone_global_pose(b_idx)
			tips.append(b_tf.origin)
			bases.append(b_tf.origin - b_tf.basis.y.normalized() * ribbon_width)
	else:
		_compute_claw_points(hand_tf, tips, bases)
	
	# Lissage de l'arc par sous-divisions Catmull-Rom
	if _slices.size() > 0 and subdivisions > 1:
		var prev_slice = _slices[0]
		var prev_tips: Array[Vector3] = prev_slice.get("claw_tips", [])
		var prev_bases: Array[Vector3] = prev_slice.get("claw_bases", [])
		var prev_time: float = prev_slice.get("time", current_time)
		var prev_origin: Vector3 = prev_slice.get("hand_origin", hand_pos)
		
		# Points antérieurs pour Catmull-Rom
		var p0_tips: Array[Vector3] = _slices[1].get("claw_tips", prev_tips) if _slices.size() > 1 else prev_tips
		var p0_bases: Array[Vector3] = _slices[1].get("claw_bases", prev_bases) if _slices.size() > 1 else prev_bases
		
		var sub_slices: Array[Dictionary] = []
		for sub in range(1, subdivisions):
			var t: float = float(sub) / float(subdivisions)
			var sub_time: float = lerpf(prev_time, current_time, t)
			var sub_tips: Array[Vector3] = []
			var sub_bases: Array[Vector3] = []
			
			for k in range(tips.size()):
				# Catmull-Rom simplifié entre p0, prev, curr, curr
				var tip_interp = _catmull_rom(p0_tips[k], prev_tips[k], tips[k], tips[k], t)
				var base_interp = _catmull_rom(p0_bases[k], prev_bases[k], bases[k], bases[k], t)
				sub_tips.append(tip_interp)
				sub_bases.append(base_interp)
			
			sub_slices.append({
				"time": sub_time,
				"claw_tips": sub_tips,
				"claw_bases": sub_bases,
				"hand_origin": prev_origin.lerp(hand_pos, t)
			})
		
		# Empiler les sous-tranches du plus récent au plus ancien
		for s in sub_slices:
			_slices.push_front(s)
	
	_slices.push_front({
		"time": current_time,
		"claw_tips": tips,
		"claw_bases": bases,
		"hand_origin": hand_pos
	})

func _catmull_rom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2: float = t * t
	var t3: float = t2 * t
	return 0.5 * (
		(2.0 * p1) +
		(-p0 + p2) * t +
		(2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
		(-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)

func _compute_claw_points(hand_tf: Transform3D, tips: Array[Vector3], bases: Array[Vector3]) -> void:
	var finger_dir: Vector3 = hand_tf.basis.y.normalized()
	var palm_lateral: Vector3 = hand_tf.basis.z.normalized()
	var hand_pos: Vector3 = hand_tf.origin
	
	var offsets: Array[float] = []
	match preset_mode:
		PresetMode.SINGLE_BLADE:
			offsets = [0.0]
		PresetMode.TRIPLE_CLAW:
			offsets = [-1.0, 0.0, 1.0]
		PresetMode.QUAD_CLAW:
			offsets = [-1.5, -0.5, 0.5, 1.5]
		PresetMode.FULL_SLASH_ARC:
			offsets = [-1.0, 1.0]
		_:
			offsets = [-1.0, 0.0, 1.0]
	
	for off in offsets:
		var lateral = palm_lateral * (off * claw_spread)
		var len_mul = 1.0 if absf(off) < 0.1 else 0.93
		var tip_pos = hand_pos + lateral + (finger_dir * (claw_length * len_mul))
		var base_pos = tip_pos - (finger_dir * ribbon_width)
		tips.append(tip_pos)
		bases.append(base_pos)

func _purge_expired_slices(current_time: float) -> void:
	var valid_count: int = 0
	for i in range(_slices.size()):
		if (current_time - _slices[i].time) <= trail_lifetime:
			valid_count = i + 1
		else:
			break
	_slices.resize(valid_count)

func _render_trail_mesh(current_time: float) -> void:
	_immediate_mesh.clear_surfaces()
	
	var count = _slices.size()
	if count < 2:
		return
	
	var num_claws = _slices[0].get("claw_tips", []).size()
	if num_claws == 0:
		return
	
	# 1. Rubans des griffes individuelles
	for k in range(num_claws):
		_immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _material)
		for i in range(count):
			var s = _slices[i]
			var age: float = current_time - s.time
			var ratio: float = clampf(1.0 - (age / trail_lifetime), 0.0, 1.0)
			
			var base_col: Color = trail_gradient.sample(ratio)
			# Conserver une saturation violette/mauve profonde sans blanchir la teinte
			var col: Color = Color(
				clampf(base_col.r * (1.0 + (emission_energy - 1.0) * 0.25), 0.0, 1.0),
				clampf(base_col.g * 0.55, 0.0, 0.60), # Vert très bas pour que le violet/mauve reste éclatant
				clampf(base_col.b * (1.0 + (emission_energy - 1.0) * 0.35), 0.0, 1.0),
				base_col.a
			)
			
			var tip: Vector3 = s.claw_tips[k]
			var base: Vector3 = s.claw_bases[k]
			
			# Effilement : vers la queue, la largeur se rétrécit en pointe fine
			if taper_tail:
				var taper_factor = pow(ratio, 0.65)
				base = tip.lerp(base, taper_factor)
			
			# Sommet intérieur (légèrement plus sombre et diffus)
			_immediate_mesh.surface_set_color(Color(col.r * 0.65, col.g * 0.45, col.b * 0.85, col.a * 0.7))
			_immediate_mesh.surface_set_uv(Vector2(0.0, ratio))
			_immediate_mesh.surface_add_vertex(base)
			
			# Sommet extérieur (tranchant vif éclatant)
			_immediate_mesh.surface_set_color(col)
			_immediate_mesh.surface_set_uv(Vector2(1.0, ratio))
			_immediate_mesh.surface_add_vertex(tip)
		
		_immediate_mesh.surface_end()
	
	# 2. Arc d'énergie global reliant les griffes extérieures (voile d'énergie mauve)
	if enable_arc_slash and num_claws >= 2 and arc_energy > 0.01:
		_immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _material)
		for i in range(count):
			var s = _slices[i]
			var age: float = current_time - s.time
			var ratio: float = clampf(1.0 - (age / trail_lifetime), 0.0, 1.0)
			
			var base_col: Color = trail_gradient.sample(ratio)
			var col: Color = Color(
				clampf(base_col.r * 0.8, 0.0, 1.0),
				clampf(base_col.g * 0.3, 0.0, 0.4),
				clampf(base_col.b * 0.95, 0.0, 1.0),
				base_col.a * 0.55 * arc_energy
			)
			
			var tip_left: Vector3 = s.claw_tips[0]
			var tip_right: Vector3 = s.claw_tips[num_claws - 1]
			
			_immediate_mesh.surface_set_color(Color(col.r * 0.6, col.g * 0.3, col.b * 0.7, col.a * 0.5))
			_immediate_mesh.surface_set_uv(Vector2(0.0, ratio))
			_immediate_mesh.surface_add_vertex(tip_left)
			
			_immediate_mesh.surface_set_color(col)
			_immediate_mesh.surface_set_uv(Vector2(1.0, ratio))
			_immediate_mesh.surface_add_vertex(tip_right)
		
		_immediate_mesh.surface_end()

